import AppKit
import GlisseCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let controller = Controller()
    private let prefs = Preferences.shared

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

        let toggle = NSMenuItem(title: controller.side == .phone ? "Revenir au Mac" : "Passer sur l'iPhone", action: #selector(toggleSide), keyEquivalent: "p")
        toggle.keyEquivalentModifierMask = [.control, .option, .command]
        toggle.target = self
        toggle.isEnabled = controller.canCross || controller.side == .phone
        menu.addItem(toggle)
        menu.addItem(.separator())

        let edge = NSMenu()
        for e in Edge.allCases {
            let item = NSMenuItem(title: e == .right ? "À droite du Mac" : "À gauche du Mac", action: #selector(setEdge(_:)), keyEquivalent: "")
            item.representedObject = e.rawValue
            item.state = prefs.edge == e ? .on : .off
            item.target = self
            edge.addItem(item)
        }
        let edgeItem = NSMenuItem(title: "L'iPhone est", action: nil, keyEquivalent: "")
        edgeItem.submenu = edge
        menu.addItem(edgeItem)

        let gain = NSMenu()
        for g in [0.5, 0.75, 1.0, 1.5, 2.0, 3.0] {
            let item = NSMenuItem(title: g == 1 ? "Normale" : "× \(g.formatted())", action: #selector(setGain(_:)), keyEquivalent: "")
            item.representedObject = g
            item.state = abs(prefs.gain - g) < 0.001 ? .on : .off
            item.target = self
            gain.addItem(item)
        }
        let gainItem = NSMenuItem(title: "Vitesse sur l'iPhone", action: nil, keyEquivalent: "")
        gainItem.submenu = gain
        menu.addItem(gainItem)

        let size = NSMenu()
        for (label, w, h) in [("Petit (800 × 1700)", 800.0, 1700.0), ("Moyen (1200 × 2600)", 1200.0, 2600.0), ("Grand (1800 × 3900)", 1800.0, 3900.0)] {
            let item = NSMenuItem(title: label, action: #selector(setSize(_:)), keyEquivalent: "")
            item.representedObject = [w, h]
            item.state = prefs.phoneSize == CGSize(width: w, height: h) ? .on : .off
            item.target = self
            size.addItem(item)
        }
        let sizeItem = NSMenuItem(title: "Chemin avant de revenir", action: nil, keyEquivalent: "")
        sizeItem.submenu = size
        menu.addItem(sizeItem)

        let back = NSMenu()
        for (label, r) in [("Faible (100)", 100.0), ("Normale (300)", 300.0), ("Forte (600)", 600.0), ("Très forte (1200)", 1200.0)] {
            let item = NSMenuItem(title: label, action: #selector(setReturnResistance(_:)), keyEquivalent: "")
            item.representedObject = r
            item.state = abs(prefs.returnResistance - r) < 0.001 ? .on : .off
            item.target = self
            back.addItem(item)
        }
        let backItem = NSMenuItem(title: "Résistance au retour", action: nil, keyEquivalent: "")
        backItem.submenu = back
        menu.addItem(backItem)

        let invert = NSMenuItem(title: "Inverser la molette", action: #selector(toggleInvert), keyEquivalent: "")
        invert.state = prefs.invertScroll ? .on : .off
        invert.target = self
        menu.addItem(invert)
        menu.addItem(.separator())

        let forget = NSMenuItem(title: "Oublier l'appairage du dongle", action: #selector(forgetPairing), keyEquivalent: "")
        forget.target = self
        forget.isEnabled = controller.serial.isOpen
        menu.addItem(forget)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quitter Glisse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        return menu
    }

    @objc private func toggleSide() { controller.toggle() }

    @objc private func setEdge(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let e = Edge(rawValue: raw) else { return }
        prefs.edge = e
        controller.applyPreferences()
        refresh()
    }

    @objc private func setGain(_ sender: NSMenuItem) {
        guard let g = sender.representedObject as? Double else { return }
        prefs.gain = g
        controller.applyPreferences()
        refresh()
    }

    @objc private func setSize(_ sender: NSMenuItem) {
        guard let wh = sender.representedObject as? [Double], wh.count == 2 else { return }
        prefs.phoneSize = CGSize(width: wh[0], height: wh[1])
        controller.applyPreferences()
        refresh()
    }

    @objc private func setReturnResistance(_ sender: NSMenuItem) {
        guard let r = sender.representedObject as? Double else { return }
        prefs.returnResistance = r
        controller.applyPreferences()
        refresh()
    }

    @objc private func toggleInvert() {
        prefs.invertScroll.toggle()
        refresh()
    }

    @objc private func forgetPairing() {
        controller.serial.write(Wire.forgetPairing)
    }

    @objc private func openAccessibility() {
        EventTap.askForTrust()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
