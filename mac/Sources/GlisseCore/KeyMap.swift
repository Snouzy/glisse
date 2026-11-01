import CoreGraphics

/// Du code de touche virtuel de macOS (`kVK_*`) au code d'usage HID (page 7). Les touches sont positionnelles
/// des deux côtés : la disposition (AZERTY, QWERTY) est appliquée par l'iPhone, comme pour un clavier Bluetooth.
public enum KeyMap {
    private static let table: [Int64: UInt8] = [
        0: 0x04, 1: 0x16, 2: 0x07, 3: 0x09, 4: 0x0B, 5: 0x0A, 6: 0x1D, 7: 0x1B, 8: 0x06, 9: 0x19,
        10: 0x64, 11: 0x05, 12: 0x14, 13: 0x1A, 14: 0x08, 15: 0x15, 16: 0x1C, 17: 0x17, 18: 0x1E, 19: 0x1F,
        20: 0x20, 21: 0x21, 22: 0x23, 23: 0x22, 24: 0x2E, 25: 0x26, 26: 0x24, 27: 0x2D, 28: 0x25, 29: 0x27,
        30: 0x30, 31: 0x12, 32: 0x18, 33: 0x2F, 34: 0x0C, 35: 0x13, 36: 0x28, 37: 0x0F, 38: 0x0D, 39: 0x34,
        40: 0x0E, 41: 0x33, 42: 0x31, 43: 0x36, 44: 0x38, 45: 0x11, 46: 0x10, 47: 0x37, 48: 0x2B, 49: 0x2C,
        50: 0x35, 51: 0x2A, 53: 0x29, 57: 0x39,
        64: 0x6C, 65: 0x63, 67: 0x55, 69: 0x57, 71: 0x53, 75: 0x54, 76: 0x58, 78: 0x56, 79: 0x6D, 80: 0x6E,
        81: 0x67, 82: 0x62, 83: 0x59, 84: 0x5A, 85: 0x5B, 86: 0x5C, 87: 0x5D, 88: 0x5E, 89: 0x5F, 90: 0x6F,
        91: 0x60, 92: 0x61,
        96: 0x3E, 97: 0x3F, 98: 0x40, 99: 0x3C, 100: 0x41, 101: 0x42, 103: 0x44, 105: 0x68, 106: 0x6B,
        107: 0x69, 109: 0x43, 111: 0x45, 113: 0x6A, 114: 0x49, 115: 0x4A, 116: 0x4B, 117: 0x4C, 118: 0x3D,
        119: 0x4D, 120: 0x3B, 121: 0x4E, 122: 0x3A, 123: 0x50, 124: 0x4F, 125: 0x51, 126: 0x52,
    ]

    public static func usage(forMacKeyCode code: Int64) -> UInt8? { table[code] }

    /// L'octet de modificateurs du rapport clavier HID (variantes gauches : iOS ne distingue pas).
    public static func modifiers(from flags: CGEventFlags) -> UInt8 {
        var m: UInt8 = 0
        if flags.contains(.maskControl) { m |= 0x01 }
        if flags.contains(.maskShift) { m |= 0x02 }
        if flags.contains(.maskAlternate) { m |= 0x04 }
        if flags.contains(.maskCommand) { m |= 0x08 }
        return m
    }
}

/// L'état du clavier tel qu'envoyé à l'iPhone : modificateurs et jusqu'à six touches tenues. Chaque méthode
/// rend la ligne à envoyer au dongle, ou nil quand rien n'a changé (répétition automatique du Mac, par exemple).
public struct KeyboardState: Sendable {
    private var modifiers: UInt8 = 0
    private var keys: [UInt8] = []

    public init() {}

    public mutating func press(macKeyCode: Int64, flags: CGEventFlags) -> String? {
        guard let usage = KeyMap.usage(forMacKeyCode: macKeyCode) else { return self.flags(flags) }
        let mods = KeyMap.modifiers(from: flags)
        if keys.contains(usage) && mods == modifiers { return nil }
        if !keys.contains(usage) {
            guard keys.count < 6 else { return nil }
            keys.append(usage)
        }
        modifiers = mods
        return report
    }

    public mutating func release(macKeyCode: Int64, flags: CGEventFlags) -> String? {
        guard let usage = KeyMap.usage(forMacKeyCode: macKeyCode) else { return self.flags(flags) }
        let mods = KeyMap.modifiers(from: flags)
        guard keys.contains(usage) || mods != modifiers else { return nil }
        keys.removeAll { $0 == usage }
        modifiers = mods
        return report
    }

    /// Les modificateurs ont changé (⇧, ⌘… pressés ou relâchés seuls).
    public mutating func flags(_ flags: CGEventFlags) -> String? {
        let mods = KeyMap.modifiers(from: flags)
        guard mods != modifiers else { return nil }
        modifiers = mods
        return report
    }

    public mutating func releaseAll() -> String {
        modifiers = 0
        keys = []
        return report
    }

    private var report: String {
        var padded = keys
        while padded.count < 6 { padded.append(0) }
        return "K \(modifiers) " + padded.map(String.init).joined(separator: " ") + "\n"
    }
}
