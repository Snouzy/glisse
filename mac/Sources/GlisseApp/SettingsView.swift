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
    @AppStorage("phoneWidth") private var phoneWidth: Double = 1200
    @AppStorage("phoneHeight") private var phoneHeight: Double = 2600
    @AppStorage("invertScroll") private var invertScroll: Bool = false
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
                        .help("Si l'iPhone ne trouve plus « Glisse » : le dongle redémarre et repart en annonce, sans perdre l'appairage.")
                    Button("Oublier l'appairage…", action: actions.forgetPairing)
                        .help("Efface les liens Bluetooth du dongle. Demande confirmation.")
                }
            }

            Section("Raccourci") {
                HStack {
                    Text("Passer sur l'iPhone et revenir")
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
                        Text(recorder.isRecording
                             ? (recorder.pendingModifiers.isEmpty ? "Appuie sur la combinaison…" : HotKey(keyCode: 0, flags: recorder.pendingModifiers).modifierSymbols + "…")
                             : KeyLabel.display(hotKey))
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
                Picker("L'iPhone est", selection: $edge) {
                    Text("à droite du Mac").tag(Edge.right.rawValue)
                    Text("à gauche du Mac").tag(Edge.left.rawValue)
                }
                .pickerStyle(.segmented)
                slider("Résistance au bord", value: $resistance, in: 0...300, step: 10,
                       format: "\(Int(resistance)) pt",
                       help: "Combien pousser contre le bord de l'écran avant de passer sur l'iPhone.")
            }

            Section("Souris sur l'iPhone") {
                slider("Vitesse", value: $gain, in: 0.25...5, step: 0.25,
                       format: "× \(gain.formatted())",
                       help: "Unités envoyées à l'iPhone par point de déplacement sur le Mac.")
                slider("Linéarité", value: $linearity, in: 0.4...1, step: 0.05,
                       format: linearity >= 0.999 ? "proportionnel" : linearity.formatted(.number.precision(.fractionLength(2))),
                       help: "À 1, le mouvement est proportionnel. En dessous, les petits gestes sont amplifiés et les grands retenus, pour compenser l'accélération d'iOS.")
                Toggle("Inverser la molette", isOn: $invertScroll)
            }

            Section("Retour au Mac") {
                slider("Résistance au retour", value: $returnResistance, in: 0...1500, step: 50,
                       format: "\(Int(returnResistance)) u",
                       help: "Combien pousser contre le bord côté Mac, sur l'iPhone, avant de revenir. Absorbe l'écart entre le curseur estimé et le vrai.")
                slider("Largeur de l'iPhone", value: $phoneWidth, in: 400...4000, step: 100,
                       format: "\(Int(phoneWidth)) u",
                       help: "Ce que le curseur parcourt d'un bord à l'autre, en unités de souris. Trop petit : on revient au Mac trop tôt.")
                slider("Hauteur de l'iPhone", value: $phoneHeight, in: 800...8000, step: 100,
                       format: "\(Int(phoneHeight)) u",
                       help: "Même unité, pour la hauteur.")
            }

            Section {
                Text("\(KeyLabel.display(hotKey)) bascule la souris à la main. Sur l'iPhone, réglez la vitesse du pointeur au minimum dans Accessibilité › Toucher › AssistiveTouch.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
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
        .onChange(of: invertScroll) { actions.apply() }
        .onChange(of: portPath) { actions.apply() }
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, format: String, help: String) -> some View {
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
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 760),
                             styleMask: [.titled, .closable], backing: .buffered, defer: false)
            w.contentView = NSHostingView(rootView: view)
            w.title = "Réglages de Glisse"
            w.isReleasedWhenClosed = false
            w.setFrameAutosaveName("GlisseSettings")
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
