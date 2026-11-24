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
        let device = Preferences.shared.device.name
        let symbol: String
        let hint: String
        if !EventTap.isTrusted {
            symbol = "hand.raised.slash"; hint = NSLocalizedString("Glisse : autorise l'Accessibilité dans Réglages Système", comment: "")
        } else if !controller.serial.isOpen {
            symbol = "iphone.slash"; hint = NSLocalizedString("Glisse : dongle absent", comment: "")
        } else if !controller.canCross {
            symbol = "iphone.badge.exclamationmark"; hint = String(format: NSLocalizedString("Glisse : %1$@ non relié", comment: ""), device)
        } else if controller.side == .phone {
            symbol = "iphone.gen3.radiowaves.left.and.right"; hint = String(format: NSLocalizedString("Glisse : la souris est sur l'%1$@", comment: ""), device)
        } else {
            symbol = "iphone"; hint = NSLocalizedString("Glisse : prêt, pousse le curseur au bord", comment: "")
        }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: hint)
            ?? NSImage(systemSymbolName: "iphone", accessibilityDescription: hint)
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.toolTip = hint
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let device = Preferences.shared.device.name
        let menu = NSMenu()
        let stateText = controller.side == .phone
            ? String(format: NSLocalizedString("La souris est sur l'%1$@", comment: ""), device)
            : NSLocalizedString("La souris est sur le Mac", comment: "")
        let state = NSMenuItem(title: stateText, action: nil, keyEquivalent: "")
        state.isEnabled = false
        menu.addItem(state)
        let dongle = NSMenuItem(title: controller.statusText, action: nil, keyEquivalent: "")
        dongle.isEnabled = false
        menu.addItem(dongle)
        if !EventTap.isTrusted {
            let warn = NSMenuItem(title: NSLocalizedString("Sans Accessibilité, Glisse voit la souris mais ne peut pas la retenir", comment: ""), action: nil, keyEquivalent: "")
            warn.isEnabled = false
            menu.addItem(warn)
            let perm = NSMenuItem(title: NSLocalizedString("Autoriser Glisse dans Accessibilité…", comment: ""), action: #selector(openAccessibility), keyEquivalent: "")
            perm.target = self
            menu.addItem(perm)
        }
        menu.addItem(.separator())

        let toggleTitle = controller.side == .phone
            ? NSLocalizedString("Revenir au Mac", comment: "")
            : String(format: NSLocalizedString("Passer sur l'%1$@", comment: ""), device)
        let toggle = NSMenuItem(title: toggleTitle, action: #selector(toggleSide),
                                keyEquivalent: KeyLabel.menuEquivalent(for: controller.hotKey.keyCode))
        toggle.keyEquivalentModifierMask = KeyLabel.menuModifiers(controller.hotKey.flags)
        toggle.target = self
        toggle.isEnabled = controller.canCross || controller.side == .phone
        menu.addItem(toggle)

        let edgeTitle = NSLocalizedString("Sortie du curseur", comment: "")
        let edgeItem = NSMenuItem(title: edgeTitle, action: nil, keyEquivalent: "")
        let edgeMenu = NSMenu(title: edgeTitle)
        for edge in [Edge.left, Edge.right] {
            let title = edge == .left
                ? NSLocalizedString("Bord gauche", comment: "")
                : NSLocalizedString("Bord droit", comment: "")
            let item = NSMenuItem(title: title, action: #selector(chooseEdge(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = edge.rawValue
            item.state = Preferences.shared.edge == edge ? .on : .off
            edgeMenu.addItem(item)
        }
        edgeItem.submenu = edgeMenu
        menu.addItem(edgeItem)
        menu.addItem(.separator())

        let settings = NSMenuItem(title: NSLocalizedString("Réglages…", comment: ""), action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())

        let reset = NSMenuItem(title: NSLocalizedString("Redémarrer le dongle", comment: ""), action: #selector(resetDongle), keyEquivalent: "")
        reset.target = self
        reset.isEnabled = controller.serial.isOpen
        menu.addItem(reset)
        let forget = NSMenuItem(title: NSLocalizedString("Oublier l'appairage du dongle…", comment: ""), action: #selector(forgetPairing), keyEquivalent: "")
        forget.target = self
        forget.isEnabled = controller.serial.isOpen
        menu.addItem(forget)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: NSLocalizedString("Quitter Glisse", comment: ""), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    @objc private func toggleSide() { controller.toggle() }

    /// Changer le bord de sortie depuis la barre des menus, sans ouvrir les Réglages.
    @objc private func chooseEdge(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let edge = Edge(rawValue: raw) else { return }
        Preferences.shared.edge = edge
        controller.applyPreferences()
        refresh()
    }

    @objc private func openSettings() {
        settingsWindow.show(SettingsActions(
            status: { [weak self] in self?.controller.statusText ?? "" },
            apply: { [weak self] in self?.controller.applyPreferences(); self?.refresh() },
            forgetPairing: { [weak self] in self?.forgetPairing() },
            resetDongle: { [weak self] in self?.controller.resetDongle() },
            setHotKeyEnabled: { [weak self] on in self?.controller.hotKeyEnabled = on }))
    }

    /// Irréversible côté dongle : l'appareil devra oublier « Glisse » et se réappairer. On demande d'abord.
    @objc private func forgetPairing() {
        let device = Preferences.shared.device.name
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("Oublier l'appairage du dongle ?", comment: "")
        alert.informativeText = String(format: NSLocalizedString("Le dongle efface ses liens Bluetooth. Il faudra ensuite oublier « Glisse » dans les réglages Bluetooth de l'%1$@ et le réappairer depuis AssistiveTouch.", comment: ""), device)
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("Oublier", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Annuler", comment: ""))
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
