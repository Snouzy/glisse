import AppKit

/// La langue de l'interface : celle du Mac par défaut, ou choisie dans les Réglages.
/// macOS choisit le dossier `.lproj` au lancement d'après `AppleLanguages` : un changement demande donc
/// de relancer l'app.
enum Language: String, CaseIterable {
    case system
    case fr
    case en

    /// La langue choisie dans les Réglages, gardée sous « language » (absente = celle du Mac).
    static var current: Language {
        Language(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .system
    }

    /// Écrit `AppleLanguages`, que macOS lit au lancement. La clé absente veut dire « la langue du Mac ».
    func apply() {
        let defaults = UserDefaults.standard
        switch self {
        case .system: defaults.removeObject(forKey: "AppleLanguages")
        case .fr: defaults.set(["fr"], forKey: "AppleLanguages")
        case .en: defaults.set(["en"], forKey: "AppleLanguages")
        }
    }

    /// Relance l'app pour que macOS relise `AppleLanguages`. Faux si le binaire ne tourne pas dans un
    /// `.app` : là, il n'y a rien à relancer, il faut quitter et rouvrir à la main.
    @discardableResult
    static func relaunch() -> Bool {
        let bundleURL = Bundle.main.bundleURL
        guard bundleURL.pathExtension == "app" else { return false }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { app, _ in
            guard app != nil else { return }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        return true
    }
}
