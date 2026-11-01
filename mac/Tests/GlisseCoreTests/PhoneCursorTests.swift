import Testing
import CoreGraphics
@testable import GlisseCore

@Suite("Curseur virtuel sur l'iPhone")
struct PhoneCursorTests {
    // L'iPhone est à droite du Mac : son bord gauche touche le Mac. 400 × 800 unités de souris.
    func cursor(gain: Double = 1, returnResistance: Double = 0) -> PhoneCursor {
        PhoneCursor(size: CGSize(width: 400, height: 800), macSide: .left, gain: gain, returnResistance: returnResistance)
    }

    @Test func entersJustInsideTheMacSideAtTheSameHeight() {
        var c = cursor()
        c.enter(yFraction: 0.5)
        #expect(c.position == CGPoint(x: 0, y: 400))
    }

    @Test func movesAndReportsIntegerUnits() {
        var c = cursor()
        c.enter(yFraction: 0)
        #expect(c.move(dx: 10, dy: 5) == .moved(dx: 10, dy: 5))
        #expect(c.position == CGPoint(x: 10, y: 5))
    }

    @Test func gainScalesAndCarriesTheRemainder() {
        var c = cursor(gain: 0.5)
        c.enter(yFraction: 0)
        #expect(c.move(dx: 1, dy: 0) == .moved(dx: 0, dy: 0))
        #expect(c.move(dx: 1, dy: 0) == .moved(dx: 1, dy: 0))
        #expect(c.move(dx: 3, dy: 1) == .moved(dx: 1, dy: 0))  // 1.5 → 1, reste 0.5 ; 0.5 → 0, reste 0.5
        #expect(c.move(dx: 1, dy: 1) == .moved(dx: 1, dy: 1))
    }

    @Test func clampsToThePhoneOnTheFarSides() {
        var c = cursor()
        c.enter(yFraction: 0.5)
        _ = c.move(dx: 1000, dy: 1000)
        #expect(c.position == CGPoint(x: 399, y: 799))
        _ = c.move(dx: 0, dy: -5000)
        #expect(c.position.y == 0)
    }

    @Test func returnsToTheMacWhenLeavingByTheMacSide() {
        var c = cursor()
        c.enter(yFraction: 0.25)
        _ = c.move(dx: 20, dy: 0)
        #expect(c.move(dx: -30, dy: 40) == .returnedToMac(yFraction: 0.3))
    }

    @Test func macOnTheRightSideWhenThePhoneIsLeftOfTheMac() {
        var c = PhoneCursor(size: CGSize(width: 400, height: 800), macSide: .right, gain: 1, returnResistance: 0)
        c.enter(yFraction: 0)
        #expect(c.position == CGPoint(x: 399, y: 0))
        #expect(c.move(dx: 5, dy: 0) == .returnedToMac(yFraction: 0))
    }

    @Test func returnNeedsAPushAgainstTheMacSide() {
        var c = cursor(returnResistance: 100)
        c.enter(yFraction: 0.5)
        // Au bord, pousser dehors sans atteindre la résistance : on reste, et le mouvement part quand même
        // au dongle pour que le vrai curseur iOS vienne se coller au bord.
        #expect(c.move(dx: -60, dy: 0) == .moved(dx: -60, dy: 0))
        #expect(c.position.x == 0)
        #expect(c.move(dx: -60, dy: 0) == .returnedToMac(yFraction: 0.5))
    }

    @Test func movingBackInsideResetsTheReturnPush() {
        var c = cursor(returnResistance: 100)
        c.enter(yFraction: 0.5)
        _ = c.move(dx: -60, dy: 0)
        _ = c.move(dx: 10, dy: 0)
        _ = c.move(dx: -10, dy: 0)
        #expect(c.move(dx: -60, dy: 0) == .moved(dx: -60, dy: 0))
        #expect(c.move(dx: -40, dy: 0) == .returnedToMac(yFraction: 0.5))
    }

    @Test func slidingAlongTheMacSideDoesNotReturn() {
        var c = cursor(returnResistance: 100)
        c.enter(yFraction: 0.5)
        // Vers le haut à gauche : la poussée horizontale est faible, le déplacement surtout vertical.
        for _ in 0..<20 { _ = c.move(dx: -2, dy: -15) }
        #expect(c.position == CGPoint(x: 0, y: 100))
        #expect(c.move(dx: -2, dy: -15) == .moved(dx: -2, dy: -15))
    }
}
