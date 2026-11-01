import Foundation

/// Les boutons de la souris, dans l'ordre du descripteur HID du dongle (gauche, droit, milieu, arrière, avant).
public struct MouseButtons: OptionSet, Sendable, Hashable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    public static let left = MouseButtons(rawValue: 1)
    public static let right = MouseButtons(rawValue: 2)
    public static let middle = MouseButtons(rawValue: 4)
    public static let back = MouseButtons(rawValue: 8)
    public static let forward = MouseButtons(rawValue: 16)

    /// Le numéro de bouton de CGEvent (`mouseEventButtonNumber`) : 0 gauche, 1 droit, 2 milieu, 3 arrière, 4 avant.
    public init?(macButton: Int64) {
        guard (0...4).contains(macButton) else { return nil }
        self.init(rawValue: 1 << UInt8(macButton))
    }
}

/// Ce que le dongle renvoie sur le port série.
public enum WireReply: Equatable, Sendable {
    case status(paired: Bool, connected: Bool)
    case paired(Bool)
}

/// Le protocole texte entre le Mac et le dongle : une commande par ligne.
public enum Wire {
    public static func move(dx: Int, dy: Int) -> String { "M \(dx) \(dy)\n" }
    public static func scroll(dz: Int, dh: Int) -> String { "S \(dz) \(dh)\n" }
    public static func buttons(_ buttons: MouseButtons) -> String { "B \(buttons.rawValue)\n" }
    public static let release = "R\n"
    public static let status = "?\n"
    public static let forgetPairing = "!\n"

    public static func parse(_ line: String) -> WireReply? {
        let words = line.split(separator: " ").map(String.init)
        if words.first == "glisse", let p = words.firstIndex(of: "paired"), p + 1 < words.count,
           let c = words.firstIndex(of: "connected"), c + 1 < words.count {
            return .status(paired: words[p + 1] == "1", connected: words[c + 1] == "1")
        }
        if words.count == 2, words[0] == "paired" {
            return .paired(words[1] == "1")
        }
        return nil
    }
}
