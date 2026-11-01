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

    /// Le port série du dongle ; vide pour le trouver tout seul.
    var portPath: String {
        get { defaults.string(forKey: "portPath") ?? "" }
        set { defaults.set(newValue, forKey: "portPath") }
    }
}
