import AppKit
import SwiftUI

/// Rend les captures du README hors écran, sans rien afficher : `GlisseApp --screenshots docs/images`.
enum Screenshots {
    static func run(into directory: String) throws {
        let dir = URL(fileURLWithPath: directory)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let actions = SettingsActions(status: { "Dongle sur usbserial-0001, relié à l'iPhone (15 ms)" },
                                      apply: {}, forgetPairing: {}, resetDongle: {}, setHotKeyEnabled: { _ in })
        for (name, appearance) in [("settings-light", NSAppearance.Name.aqua), ("settings-dark", .darkAqua)] {
            let view = SettingsView(actions: actions)
            try render(view, size: NSSize(width: 520, height: 985), appearance: appearance,
                       to: dir.appendingPathComponent("\(name).png"))
        }
        print("==> Captures dans \(directory)")
    }

    private static func render<V: View>(_ view: V, size: NSSize, appearance: NSAppearance.Name, to url: URL) throws {
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        host.appearance = NSAppearance(named: appearance)
        // Une fenêtre jamais affichée donne au rendu un contexte complet (couleurs du thème, flous).
        let window = NSWindow(contentRect: host.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        window.appearance = host.appearance
        host.layoutSubtreeIfNeeded()
        let scale: CGFloat = 2
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { throw CocoaError(.fileWriteUnknown) }
        rep.size = size
        rep.pixelsWide = Int(size.width * scale)
        rep.pixelsHigh = Int(size.height * scale)
        host.cacheDisplay(in: host.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        try png.write(to: url)
    }
}
