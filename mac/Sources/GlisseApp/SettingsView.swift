import SwiftUI
import GlisseCore

/// La fenêtre des réglages. Les valeurs vivent dans UserDefaults (mêmes clés que `Preferences`) ; chaque
/// changement est appliqué tout de suite au contrôleur.
struct SettingsView: View {
    @AppStorage("edge") private var edge: String = Edge.right.rawValue
    @AppStorage("gain") private var gain: Double = 2.0
    @AppStorage("linearity") private var linearity: Double = 0.75
    @AppStorage("resistance") private var resistance: Double = 80
    @AppStorage("returnResistance") private var returnResistance: Double = 300
    @AppStorage("phoneWidth") private var phoneWidth: Double = Preferences.shared.phoneSize.width
    @AppStorage("phoneHeight") private var phoneHeight: Double = Preferences.shared.phoneSize.height
    @AppStorage("device") private var device: String = Device.iPhone.rawValue
    @AppStorage("language") private var language: String = Language.system.rawValue
    @AppStorage("invertScroll") private var invertScroll: Bool = false
    @AppStorage("backButtonSendsBack") private var backButtonSendsBack: Bool = true
    @AppStorage("portPath") private var portPath: String = ""

    let actions: SettingsActions
    @StateObject private var recorder = HotKeyRecorder()
    @State private var hotKey = Preferences.shared.hotKey

    var body: some View {
        Form {
            Section("Dongle") {
                TimelineView(.periodic(from: .now, by: 2)) { _ in
                    LabeledContent("État", value: actions.status())
                }
                TextField("Port série", text: $portPath, prompt: Text("détecté tout seul"))
                    .help("Laisser vide pour prendre le premier port USB série trouvé.")
                HStack {
                    Button("Redémarrer le dongle", action: actions.resetDongle)
                        .help("Si l'appareil ne trouve plus « Glisse » : le dongle redémarre et repart en annonce, sans perdre l'appairage.")
                    Button("Oublier l'appairage…", action: actions.forgetPairing)
                        .help("Efface les liens Bluetooth du dongle. Demande confirmation.")
                }
            }

            Section("Raccourci") {
                HStack {
                    Text("Passer sur l'appareil et revenir")
                    Spacer()
                    Button {
                        if recorder.isRecording { recorder.stop() } else {
                            recorder.start { newKey in
                                Preferences.shared.hotKey = newKey
                                hotKey = newKey
                                actions.apply()
                            }
                        }
                    } label: {
                        Text(hotKeyLabel)
                            .monospaced()
                            .frame(minWidth: 180)
                    }
                    .help("Clique, puis appuie sur la combinaison voulue. Il faut ⌃, ⌥ ou ⌘, ou une touche F. Échap annule.")
                    Button("Par défaut") {
                        recorder.stop()
                        Preferences.shared.hotKey = .default
                        hotKey = .default
                        actions.apply()
                    }
                    .disabled(hotKey == .default)
                }
            }

            Section("Position") {
                Picker("Appareil", selection: $device) {
                    Text("iPhone").tag(Device.iPhone.rawValue)
                    Text("iPad").tag(Device.iPad.rawValue)
                }
                .pickerStyle(.segmented)
                Picker("L'appareil est", selection: $edge) {
                    Text("à droite du Mac").tag(Edge.right.rawValue)
                    Text("à gauche du Mac").tag(Edge.left.rawValue)
                }
                .pickerStyle(.segmented)
                slider("Résistance au bord", value: $resistance, in: 0...300, step: 10,
                       format: "\(Int(resistance)) pt",
                       help: "Combien pousser contre le bord de l'écran avant de passer sur l'appareil.")
            }

            Section("Souris sur l'appareil") {
                slider("Vitesse", value: $gain, in: 0.25...5, step: 0.25,
                       format: "× \(gain.formatted())",
                       help: "Unités envoyées à l'appareil par point de déplacement sur le Mac.")
                slider("Linéarité", value: $linearity, in: 0.4...1, step: 0.05,
                       format: linearity >= 0.999 ? NSLocalizedString("proportionnel", comment: "") : linearity.formatted(.number.precision(.fractionLength(2))),
                       help: "À 1, le mouvement est proportionnel. En dessous, les petits gestes sont amplifiés et les grands retenus, pour compenser l'accélération d'iOS.")
                Toggle("Inverser la molette", isOn: $invertScroll)
                Toggle("Bouton arrière → ⌘[", isOn: $backButtonSendsBack)
                    .help("Le bouton arrière de la souris envoie ⌘[ à l'appareil au lieu d'un clic : retour en arrière dans les apps qui gèrent ce raccourci.")
            }

            Section("Retour au Mac") {
                slider("Résistance au retour", value: $returnResistance, in: 0...1500, step: 50,
                       format: "\(Int(returnResistance)) u",
                       help: "Combien pousser contre le bord côté Mac, sur l'appareil, avant de revenir. Absorbe l'écart entre le curseur estimé et le vrai.")
                slider("Largeur de l'écran", value: $phoneWidth, in: 400...4000, step: 100,
                       format: "\(Int(phoneWidth)) u",
                       help: "Ce que le curseur parcourt d'un bord à l'autre, en unités de souris. Trop petit : on revient au Mac trop tôt.")
                slider("Hauteur de l'écran", value: $phoneHeight, in: 800...8000, step: 100,
                       format: "\(Int(phoneHeight)) u",
                       help: "Même unité, pour la hauteur.")
            }

            Section {
                Text(String(format: NSLocalizedString("%1$@ bascule la souris à la main. Sur l'appareil, réglez la vitesse du pointeur au minimum dans Accessibilité › Toucher › AssistiveTouch.", comment: ""), KeyLabel.display(hotKey)))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Section("Langue") {
                Picker("Langue", selection: $language) {
                    Text("Système").tag(Language.system.rawValue)
                    Text("Français").tag(Language.fr.rawValue)
                    Text("English").tag(Language.en.rawValue)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text("Le changement s'applique au prochain lancement.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Relancer Glisse") { Language.relaunch() }
                    .help("Quitte Glisse et le rouvre tout de suite pour appliquer la langue.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .onAppear { recorder.onRecordingChange = { actions.setHotKeyEnabled(!$0) } }
        .onDisappear { recorder.stop() }
        .onChange(of: edge) { actions.apply() }
        .onChange(of: gain) { actions.apply() }
        .onChange(of: linearity) { actions.apply() }
        .onChange(of: resistance) { actions.apply() }
        .onChange(of: returnResistance) { actions.apply() }
        .onChange(of: phoneWidth) { actions.apply() }
        .onChange(of: phoneHeight) { actions.apply() }
        .onChange(of: device) { applyDevicePreset() }
        .onChange(of: language) { (Language(rawValue: language) ?? .system).apply() }
        .onChange(of: invertScroll) { actions.apply() }
        .onChange(of: portPath) { actions.apply() }
    }

    /// Ce qu'affiche le bouton du raccourci : la combinaison en place, ou la touche en cours d'enregistrement.
    private var hotKeyLabel: LocalizedStringKey {
        if recorder.isRecording {
            if recorder.pendingModifiers.isEmpty { return "Appuie sur la combinaison…" }
            return LocalizedStringKey(HotKey(keyCode: 0, flags: recorder.pendingModifiers).modifierSymbols + "…")
        }
        return LocalizedStringKey(KeyLabel.display(hotKey))
    }

    /// Changer d'appareil remet la taille d'écran du modèle, puis l'applique tout de suite.
    private func applyDevicePreset() {
        guard let preset = Device(rawValue: device) else { return }
        phoneWidth = preset.screenSize.width
        phoneHeight = preset.screenSize.height
        actions.apply()
    }

    private func slider(_ title: LocalizedStringKey, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, format: String, help: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text(format).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
        .help(help)
    }
}

/// Ce que la fenêtre peut demander à l'app.
struct SettingsActions {
    let status: () -> String
    let apply: () -> Void
    let forgetPairing: () -> Void
    let resetDongle: () -> Void
    let setHotKeyEnabled: (Bool) -> Void
}

/// La fenêtre, une seule, rouverte au même endroit.
final class SettingsWindow {
    private var window: NSWindow?

    func show(_ actions: SettingsActions) {
        if window == nil {
            let view = SettingsView(actions: actions)
            // Sans taille explicite, un Form groupé dans un NSHostingController donne une fenêtre de 1 × 32.
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 880),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.contentView = NSHostingView(rootView: view)
            w.title = NSLocalizedString("Réglages de Glisse", comment: "")
            w.isReleasedWhenClosed = false
            w.setFrameAutosaveName("GlisseSettings")
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
