import CoreGraphics

/// Le raccourci qui fait passer la souris sur l'iPhone et revenir : une touche et ses modificateurs.
public struct HotKey: Equatable, Sendable {
    public var keyCode: Int64
    public var flags: CGEventFlags

    /// Les seuls bits qui comptent : ⌃ ⌥ ⇧ ⌘. Verr. maj, fn, pavé numérique et les bits internes sont ignorés.
    public static let modifierMask: CGEventFlags = [.maskControl, .maskAlternate, .maskShift, .maskCommand]
    /// ⌃⌥⌘P.
    public static let `default` = HotKey(keyCode: 35, flags: [.maskControl, .maskAlternate, .maskCommand])
    /// Les codes des touches F1 à F20, utilisables sans modificateur.
    private static let functionKeys: Set<Int64> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90]

    public init(keyCode: Int64, flags: CGEventFlags) {
        self.keyCode = keyCode
        self.flags = flags.intersection(Self.modifierMask)
    }

    public init(keyCode: Int64, rawModifiers: UInt64) {
        self.init(keyCode: keyCode, flags: CGEventFlags(rawValue: rawModifiers))
    }

    public var rawModifiers: UInt64 { flags.rawValue }

    public func matches(keyCode: Int64, flags: CGEventFlags) -> Bool {
        keyCode == self.keyCode && flags.intersection(Self.modifierMask) == self.flags
    }

    /// Une touche seule taperait un caractère ; il faut ⌃, ⌥ ou ⌘ (⇧ seul ne suffit pas), sauf pour une touche F.
    public var isUsable: Bool {
        if Self.functionKeys.contains(keyCode) { return true }
        return !flags.intersection([.maskControl, .maskAlternate, .maskCommand]).isEmpty
    }

    /// Les symboles des modificateurs dans l'ordre d'Apple : ⌃⌥⇧⌘.
    public var modifierSymbols: String {
        var s = ""
        if flags.contains(.maskControl) { s += "⌃" }
        if flags.contains(.maskAlternate) { s += "⌥" }
        if flags.contains(.maskShift) { s += "⇧" }
        if flags.contains(.maskCommand) { s += "⌘" }
        return s
    }
}
