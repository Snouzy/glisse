import AppKit
import Carbon.HIToolbox
import SwiftUI
import GlisseCore

/// Le nom d'une touche et son équivalent pour un NSMenuItem.
enum KeyLabel {
    private static let special: [Int64: (name: String, menu: String)] = [
        36: ("↩", "\r"), 76: ("⌤", "\u{3}"), 48: ("⇥", "\t"), 49: ("Espace", " "), 51: ("⌫", "\u{8}"),
        53: ("⎋", "\u{1B}"), 117: ("⌦", "\u{7F}"), 71: ("⌧", ""),
        123: ("←", String(UnicodeScalar(NSLeftArrowFunctionKey)!)), 124: ("→", String(UnicodeScalar(NSRightArrowFunctionKey)!)),
        125: ("↓", String(UnicodeScalar(NSDownArrowFunctionKey)!)), 126: ("↑", String(UnicodeScalar(NSUpArrowFunctionKey)!)),
        115: ("↖", String(UnicodeScalar(NSHomeFunctionKey)!)), 119: ("↘", String(UnicodeScalar(NSEndFunctionKey)!)),
        116: ("⇞", String(UnicodeScalar(NSPageUpFunctionKey)!)), 121: ("⇟", String(UnicodeScalar(NSPageDownFunctionKey)!)),
    ]
    private static let functionKeys: [Int64: Int] = [
        122: 1, 120: 2, 99: 3, 118: 4, 96: 5, 97: 6, 98: 7, 100: 8, 101: 9, 109: 10, 103: 11, 111: 12,
        105: 13, 107: 14, 113: 15, 106: 16, 64: 17, 79: 18, 80: 19, 90: 20,
    ]

    static func name(for keyCode: Int64) -> String {
        if let s = special[keyCode] { return s.name }
        if let n = functionKeys[keyCode] { return "F\(n)" }
        return character(for: keyCode)?.uppercased() ?? "touche \(keyCode)"
    }

    /// Le caractère de la touche sur la disposition clavier en cours, sans modificateur.
    static func character(for keyCode: Int64) -> String? {
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let ptr = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
        var deadKeys: UInt32 = 0
        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = data.withUnsafeBytes { raw -> OSStatus in
            let layout = raw.baseAddress!.assumingMemoryBound(to: UCKeyboardLayout.self)
            return UCKeyTranslate(layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
                                  UInt32(kUCKeyTranslateNoDeadKeysMask), &deadKeys, chars.count, &length, &chars)
        }
        guard status == noErr, length > 0 else { return nil }
        let s = String(utf16CodeUnits: chars, count: length)
        return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : s
    }

    static func display(_ hotKey: HotKey) -> String { hotKey.modifierSymbols + name(for: hotKey.keyCode) }

    /// Ce qu'il faut donner à `NSMenuItem.keyEquivalent` ; vide si la touche n'a pas d'équivalent.
    static func menuEquivalent(for keyCode: Int64) -> String {
        if let s = special[keyCode] { return s.menu }
        if let n = functionKeys[keyCode] { return String(UnicodeScalar(NSF1FunctionKey + n - 1)!) }
        return character(for: keyCode)?.lowercased() ?? ""
    }

    static func menuModifiers(_ flags: CGEventFlags) -> NSEvent.ModifierFlags {
        var m: NSEvent.ModifierFlags = []
        if flags.contains(.maskControl) { m.insert(.control) }
        if flags.contains(.maskAlternate) { m.insert(.option) }
        if flags.contains(.maskShift) { m.insert(.shift) }
        if flags.contains(.maskCommand) { m.insert(.command) }
        return m
    }

    static func eventFlags(_ m: NSEvent.ModifierFlags) -> CGEventFlags {
        var f: CGEventFlags = []
        if m.contains(.control) { f.insert(.maskControl) }
        if m.contains(.option) { f.insert(.maskAlternate) }
        if m.contains(.shift) { f.insert(.maskShift) }
        if m.contains(.command) { f.insert(.maskCommand) }
        return f
    }
}

/// Enregistre un raccourci : on clique, on appuie la combinaison, c'est pris. Échap annule.
@MainActor
final class HotKeyRecorder: ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var pendingModifiers: CGEventFlags = []
    private var monitor: Any?
    /// Appelé au début et à la fin de l'enregistrement, pour que le raccourci en place ne se déclenche pas pendant.
    var onRecordingChange: ((Bool) -> Void)?

    func start(_ onRecord: @escaping (HotKey) -> Void) {
        guard !isRecording else { return }
        isRecording = true
        pendingModifiers = []
        onRecordingChange?(true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self else { return event }
            let flags = KeyLabel.eventFlags(event.modifierFlags)
            if event.type == .flagsChanged { self.pendingModifiers = flags; return nil }
            if event.keyCode == 53, flags.isEmpty { self.stop(); return nil }
            let hotKey = HotKey(keyCode: Int64(event.keyCode), flags: flags)
            guard hotKey.isUsable else { NSSound.beep(); return nil }
            self.stop()
            onRecord(hotKey)
            return nil
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
        pendingModifiers = []
        onRecordingChange?(false)
    }
}
