import AppKit
import GlisseCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let controller = Controller()
    private let settingsWindow = SettingsWindow()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.imagePosition = .imageOnly
        controller.onChange = { [weak self] in self?.refresh() }
        controller.start()
        refresh()
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        let symbol: String
        let hint: String
        if !EventTap.isTrusted {
            symbol = "hand.raised.slash"; hint = "Glisse : autorise l'Accessibilité dans Réglages Système"
        } else if !controller.serial.isOpen {
            symbol = "iphone.slash"; hint = "Glisse : dongle absent"
        } else if !controller.canCross {
            symbol = "iphone.badge.exclamationmark"; hint = "Glisse : iPhone non relié"
        } else if controller.side == .phone {
            symbol = "iphone.gen3.radiowaves.left.and.right"; hint = "Glisse : la souris est sur l'iPhone"
        } else {
            symbol = "iphone"; hint = "Glisse : prêt, pousse le curseur au bord"
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: hint)
            ?? NSImage(systemSymbolName: "iphone", accessibilityDescription: hint)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = hint
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let state = NSMenuItem(title: controller.side == .phone ? "La souris est sur l'iPhone" : "La souris est sur le Mac", action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)
        let dongle = NSMenuItem(title: controller.statusText, action: nil, keyEquivalent: "")
        dongle.isEnabled = false
        menu.addItem(dongle)
        if !EventTap.isTrusted {
            let warn = NSMenuItem(title: "Sans Accessibilité, Glisse voit la souris mais ne peut pas la retenir", action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
            let perm = NSMenuItem(title: "Autoriser Glisse dans Accessibilité…", action: #selector(openAccessibility), keyEquivalent: "")
            perm.target = self
            menu.addItem(perm)
        }
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: controller.side == .phone ? "Revenir au Mac" : "Passer sur l'iPhone", action: #selector(toggleSide),
                                keyEquivalent: KeyLabel.menuEquivalent(for: controller.hotKey.keyCode))
        toggle.keyEquivalentModifierMask = KeyLabel.menuModifiers(controller.hotKey.flags)
        toggle.target = self
        toggle.isEnabled = controller.canCross || controller.side == .phone
        menu.addItem(toggle)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: "Réglages…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let reset = NSMenuItem(title: "Redémarrer le dongle", action: #selector(resetDongle), keyEquivalent: "")
        reset.target = self
        reset.isEnabled = controller.serial.isOpen
        menu.addItem(reset)
        let forget = NSMenuItem(title: "Oublier l'appairage du dongle…", action: #selector(forgetPairing), keyEquivalent: "")
        forget.target = self
        forget.isEnabled = controller.serial.isOpen
        menu.addItem(forget)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quitter Glisse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    @objc private func toggleSide() { controller.toggle() }

    @objc private func openSettings() {
        settingsWindow.show(SettingsActions(
            status: { [weak self] in self?.controller.statusText ?? "" },
            apply: { [weak self] in self?.controller.applyPreferences(); self?.refresh() },
            forgetPairing: { [weak self] in self?.forgetPairing() },
            resetDongle: { [weak self] in self?.controller.resetDongle() },
            setHotKeyEnabled: { [weak self] on in self?.controller.hotKeyEnabled = on }))
    }

    /// Irréversible côté dongle : l'iPhone devra oublier « Glisse » et se réappairer. On demande d'abord.
    @objc private func forgetPairing() {
        let alert = NSAlert()
        alert.messageText = "Oublier l'appairage du dongle ?"
        alert.informativeText = "Le dongle efface ses liens Bluetooth. Il faudra ensuite oublier « Glisse » dans les réglages Bluetooth de l'iPhone et le réappairer depuis AssistiveTouch."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Oublier")
        alert.addButton(withTitle: "Annuler")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        controller.serial.write(Wire.forgetPairing)
    }

    @objc private func resetDongle() { controller.resetDongle() }

    @objc private func openAccessibility() {
        EventTap.askForTrust()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
