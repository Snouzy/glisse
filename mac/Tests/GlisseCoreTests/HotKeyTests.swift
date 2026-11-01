import Testing
import CoreGraphics
@testable import GlisseCore

@Suite("Raccourci")
struct HotKeyTests {
    @Test func defaultIsControlOptionCommandP() {
        let h = HotKey.default
        #expect(h.keyCode == 35)
        #expect(h.matches(keyCode: 35, flags: [.maskControl, .maskAlternate, .maskCommand]))
    }

    @Test func requiresExactlyTheSameModifiers() {
        let h = HotKey(keyCode: 35, flags: [.maskControl, .maskCommand])
        #expect(h.matches(keyCode: 35, flags: [.maskControl, .maskCommand]))
        #expect(!h.matches(keyCode: 35, flags: [.maskControl, .maskCommand, .maskShift]))
        #expect(!h.matches(keyCode: 35, flags: [.maskCommand]))
        #expect(!h.matches(keyCode: 36, flags: [.maskControl, .maskCommand]))
    }

    @Test func ignoresFlagsThatAreNotModifiers() {
        let h = HotKey(keyCode: 35, flags: [.maskCommand])
        // Verr. maj, pavé numérique et les bits internes de macOS ne comptent pas.
        #expect(h.matches(keyCode: 35, flags: [.maskCommand, .maskAlphaShift, .maskNonCoalesced]))
    }

    @Test func modifierSymbolsInMacOrder() {
        #expect(HotKey(keyCode: 35, flags: [.maskCommand, .maskControl, .maskShift, .maskAlternate]).modifierSymbols == "⌃⌥⇧⌘")
        #expect(HotKey(keyCode: 122, flags: []).modifierSymbols == "")
    }

    @Test func plainKeysNeedAModifierExceptFunctionKeys() {
        #expect(!HotKey(keyCode: 35, flags: []).isUsable)       // P seul : non
        #expect(HotKey(keyCode: 122, flags: []).isUsable)       // F1 seul : oui
        #expect(HotKey(keyCode: 35, flags: [.maskShift]).isUsable == false)  // ⇧P : non, ça tape un P
        #expect(HotKey(keyCode: 35, flags: [.maskControl]).isUsable)
    }

    @Test func roundTripsThroughRawValues() {
        let h = HotKey(keyCode: 49, flags: [.maskControl, .maskAlternate])
        let back = HotKey(keyCode: h.keyCode, rawModifiers: h.rawModifiers)
        #expect(back == h)
    }
}
