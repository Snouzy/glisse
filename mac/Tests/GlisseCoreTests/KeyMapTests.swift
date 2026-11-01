import Testing
import CoreGraphics
@testable import GlisseCore

@Suite("Clavier")
struct KeyMapTests {
    @Test func lettersDigitsAndArrows() {
        #expect(KeyMap.usage(forMacKeyCode: 0) == 0x04)    // A
        #expect(KeyMap.usage(forMacKeyCode: 12) == 0x14)   // Q
        #expect(KeyMap.usage(forMacKeyCode: 18) == 0x1E)   // 1
        #expect(KeyMap.usage(forMacKeyCode: 29) == 0x27)   // 0
        #expect(KeyMap.usage(forMacKeyCode: 36) == 0x28)   // Retour
        #expect(KeyMap.usage(forMacKeyCode: 49) == 0x2C)   // Espace
        #expect(KeyMap.usage(forMacKeyCode: 51) == 0x2A)   // Effacer
        #expect(KeyMap.usage(forMacKeyCode: 123) == 0x50)  // ←
        #expect(KeyMap.usage(forMacKeyCode: 126) == 0x52)  // ↑
        #expect(KeyMap.usage(forMacKeyCode: 10) == 0x64)   // touche ISO à gauche du 1 (claviers européens)
    }

    @Test func modifiersAndFnAreNotKeys() {
        #expect(KeyMap.usage(forMacKeyCode: 55) == nil)   // ⌘
        #expect(KeyMap.usage(forMacKeyCode: 56) == nil)   // ⇧
        #expect(KeyMap.usage(forMacKeyCode: 63) == nil)   // fn
        #expect(KeyMap.usage(forMacKeyCode: 200) == nil)
    }

    @Test func modifierByteFromFlags() {
        #expect(KeyMap.modifiers(from: []) == 0)
        #expect(KeyMap.modifiers(from: [.maskControl]) == 0x01)
        #expect(KeyMap.modifiers(from: [.maskShift]) == 0x02)
        #expect(KeyMap.modifiers(from: [.maskAlternate]) == 0x04)
        #expect(KeyMap.modifiers(from: [.maskCommand]) == 0x08)
        #expect(KeyMap.modifiers(from: [.maskShift, .maskCommand]) == 0x0A)
    }

    @Test func keyboardStateBuildsReportsAndIgnoresRepeats() {
        var state = KeyboardState()
        #expect(state.press(macKeyCode: 0, flags: []) == "K 0 4 0 0 0 0 0\n")
        // Le Mac répète la touche tenue : rien de neuf à envoyer, iOS répète de son côté.
        #expect(state.press(macKeyCode: 0, flags: []) == nil)
        #expect(state.press(macKeyCode: 1, flags: [.maskShift]) == "K 2 4 22 0 0 0 0\n")
        #expect(state.release(macKeyCode: 0, flags: [.maskShift]) == "K 2 22 0 0 0 0 0\n")
        #expect(state.flags([]) == "K 0 22 0 0 0 0 0\n")
        #expect(state.flags([]) == nil)
        #expect(state.releaseAll() == "K 0 0 0 0 0 0 0\n")
    }

    @Test func atMostSixKeys() {
        var state = KeyboardState()
        for code in [0, 1, 2, 3, 4, 5] { _ = state.press(macKeyCode: Int64(code), flags: []) }
        #expect(state.press(macKeyCode: 6, flags: []) == nil)
    }
}
