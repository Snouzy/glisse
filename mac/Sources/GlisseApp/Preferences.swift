import Foundation
import GlisseCore

/// Les réglages, dans UserDefaults (`io.snouzy.glisse`).
final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    /// Le bord du Mac par lequel on passe sur l'iPhone.
    var edge: Edge {
        get { Edge(rawValue: defaults.string(forKey: "edge") ?? "") ?? .right }
        set { defaults.set(newValue.rawValue, forKey: "edge") }
    }

    /// Unités de souris envoyées par point de déplacement sur le Mac.
    var gain: Double {
        get { defaults.object(forKey: "gain") as? Double ?? 2.0 }
        set { defaults.set(newValue, forKey: "gain") }
    }

    /// Exposant de la courbe de réponse : 1 = proportionnel, en dessous les petits gestes sont amplifiés et
    /// les grands retenus, pour compenser l'accélération qu'iOS ajoute par-dessus celle de macOS.
    var linearity: Double {
        get { defaults.object(forKey: "linearity") as? Double ?? 0.75 }
        set { defaults.set(newValue, forKey: "linearity") }
    }

    /// Points de poussée contre le bord avant de passer sur l'iPhone.
    var resistance: Double {
        get { defaults.object(forKey: "resistance") as? Double ?? 80 }
        set { defaults.set(newValue, forKey: "resistance") }
    }

    /// Unités de poussée contre le bord côté Mac, sur l'iPhone, avant de revenir au Mac.
    var returnResistance: Double {
        get { defaults.object(forKey: "returnResistance") as? Double ?? 300 }
        set { defaults.set(newValue, forKey: "returnResistance") }
    }

    /// La taille de l'iPhone en unités de souris : ce que le curseur iOS parcourt d'un bord à l'autre.
    /// Dépend de la vitesse du pointeur réglée dans iOS ; à ajuster à l'usage.
    var phoneSize: CGSize {
        get {
            let w = defaults.object(forKey: "phoneWidth") as? Double ?? 1200
            let h = defaults.object(forKey: "phoneHeight") as? Double ?? 2600
            return CGSize(width: w, height: h)
        }
        set {
            defaults.set(newValue.width, forKey: "phoneWidth")
            defaults.set(newValue.height, forKey: "phoneHeight")
        }
    }

    /// Inverser le sens de la molette envoyée à l'iPhone.
    var invertScroll: Bool {
        get { defaults.bool(forKey: "invertScroll") }
        set { defaults.set(newValue, forKey: "invertScroll") }
    }

    /// Le raccourci qui bascule la souris entre le Mac et l'iPhone.
    var hotKey: HotKey {
        get {
            guard let code = defaults.object(forKey: "hotKeyCode") as? Int,
                  let mods = defaults.object(forKey: "hotKeyModifiers") as? Int else { return .default }
            return HotKey(keyCode: Int64(code), rawModifiers: UInt64(mods))
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: "hotKeyCode")
            defaults.set(Int(newValue.rawModifiers), forKey: "hotKeyModifiers")
        }
    }

    /// Le port série du dongle ; vide pour le trouver tout seul.
    var portPath: String {
        get { defaults.string(forKey: "portPath") ?? "" }
        set { defaults.set(newValue, forKey: "portPath") }
    }
}
