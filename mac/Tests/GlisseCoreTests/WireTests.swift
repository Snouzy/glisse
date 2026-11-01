import Testing
@testable import GlisseCore

@Suite("Protocole série")
struct WireTests {
    @Test func moveLine() {
        #expect(Wire.move(dx: 12, dy: -3) == "M 12 -3\n")
    }

    @Test func scrollLine() {
        #expect(Wire.scroll(dz: -1, dh: 2) == "S -1 2\n")
    }

    @Test func buttonsLine() {
        #expect(Wire.buttons(.left) == "B 1\n")
        #expect(Wire.buttons([.left, .right]) == "B 3\n")
        #expect(Wire.buttons([.back, .forward]) == "B 24\n")
        #expect(Wire.buttons([]) == "B 0\n")
    }

    @Test func releaseAndStatus() {
        #expect(Wire.release == "R\n")
        #expect(Wire.status == "?\n")
    }

    @Test func macButtonNumbersMapToMask() {
        // CGEvent numérote : 0 gauche, 1 droit, 2 milieu, 3 arrière, 4 avant.
        #expect(MouseButtons(macButton: 0) == .left)
        #expect(MouseButtons(macButton: 1) == .right)
        #expect(MouseButtons(macButton: 2) == .middle)
        #expect(MouseButtons(macButton: 3) == .back)
        #expect(MouseButtons(macButton: 4) == .forward)
        #expect(MouseButtons(macButton: 9) == nil)
    }

    @Test func parsesStatusReply() {
        #expect(Wire.parse("glisse 0.1 paired 1 connected 1") == .status(paired: true, connected: true))
        #expect(Wire.parse("paired 0") == .paired(false))
        #expect(Wire.parse("bonds cleared") == nil)
    }
}
