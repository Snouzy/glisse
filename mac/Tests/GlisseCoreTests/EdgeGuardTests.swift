import Testing
import CoreGraphics
@testable import GlisseCore

@Suite("Passage du bord")
struct EdgeGuardTests {
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 600)

    @Test func crossesAfterEnoughPushAgainstTheRightEdge() {
        var guardian = EdgeGuard(edge: .right, resistance: 60)
        // Le curseur est collé au bord droit, la souris pousse vers la droite.
        #expect(guardian.push(at: CGPoint(x: 999, y: 300), dx: 30, in: screen) == false)
        #expect(guardian.push(at: CGPoint(x: 999, y: 300), dx: 30, in: screen) == true)
    }

    @Test func pushAwayFromTheEdgeResetsTheCount() {
        var guardian = EdgeGuard(edge: .right, resistance: 60)
        #expect(guardian.push(at: CGPoint(x: 999, y: 300), dx: 40, in: screen) == false)
        #expect(guardian.push(at: CGPoint(x: 999, y: 300), dx: -5, in: screen) == false)
        #expect(guardian.push(at: CGPoint(x: 999, y: 300), dx: 40, in: screen) == false)
        #expect(guardian.push(at: CGPoint(x: 999, y: 300), dx: 40, in: screen) == true)
    }

    @Test func noCrossingAwayFromTheEdge() {
        var guardian = EdgeGuard(edge: .right, resistance: 10)
        #expect(guardian.push(at: CGPoint(x: 500, y: 300), dx: 100, in: screen) == false)
        #expect(guardian.push(at: CGPoint(x: 500, y: 300), dx: 100, in: screen) == false)
    }

    @Test func leftEdgeNeedsALeftwardPush() {
        var guardian = EdgeGuard(edge: .left, resistance: 20)
        #expect(guardian.push(at: CGPoint(x: 0, y: 10), dx: 15, in: screen) == false)
        #expect(guardian.push(at: CGPoint(x: 0, y: 10), dx: -15, in: screen) == false)
        #expect(guardian.push(at: CGPoint(x: 0, y: 10), dx: -15, in: screen) == true)
    }

    @Test func zeroResistanceCrossesAtOnce() {
        var guardian = EdgeGuard(edge: .right, resistance: 0)
        #expect(guardian.push(at: CGPoint(x: 999.5, y: 300), dx: 1, in: screen) == true)
    }
}
