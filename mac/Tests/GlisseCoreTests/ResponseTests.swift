import Testing
import CoreGraphics
@testable import GlisseCore

@Suite("Courbe de réponse")
struct ResponseTests {
    @Test func linearIsIdentityTimesGain() {
        let r = Response(gain: 2, linearity: 1)
        #expect(r.apply(dx: 10, dy: 0) == CGVector(dx: 20, dy: 0))
        #expect(r.apply(dx: -3, dy: 4) == CGVector(dx: -6, dy: 8))
    }

    @Test func zeroStaysZero() {
        let r = Response(gain: 2, linearity: 0.6)
        #expect(r.apply(dx: 0, dy: 0) == .zero)
    }

    @Test func belowOneBoostsSlowAndTamesFastMoves() {
        let r = Response(gain: 1, linearity: 0.6)
        // La référence est à 10 points par événement : là, rien ne change.
        #expect(abs(r.apply(dx: 10, dy: 0).dx - 10) < 1e-9)
        #expect(r.apply(dx: 1, dy: 0).dx > 1)
        #expect(r.apply(dx: 50, dy: 0).dx < 50)
        #expect(r.apply(dx: 50, dy: 0).dx > 10)
    }

    @Test func keepsDirection() {
        let r = Response(gain: 1.5, linearity: 0.7)
        let out = r.apply(dx: 30, dy: -40)
        #expect(abs(out.dx / out.dy - (30.0 / -40.0)) < 1e-9)
        #expect(out.dx > 0 && out.dy < 0)
    }
}
