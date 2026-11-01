import AppKit

/// Une fenêtre presque invisible posée sous le curseur parqué pendant que la souris est sur l'iPhone. Un
/// clic qui échapperait au tap tombe dedans et ne fait rien, au lieu d'atteindre la fenêtre du dessous.
/// Elle est au-dessus de tout, sur tous les bureaux, et n'active jamais Glisse.
final class Shield {
    private var panel: NSPanel?
    private let size: CGFloat = 24

    /// `point` est en coordonnées CoreGraphics (origine en haut à gauche de l'écran principal).
    func show(around point: CGPoint) {
        let mainHeight = CGDisplayBounds(CGMainDisplayID()).height
        let origin = NSPoint(x: point.x - size / 2, y: mainHeight - point.y - size / 2)
        let frame = NSRect(origin: origin, size: NSSize(width: size, height: size))
        let panel = self.panel ?? makePanel()
        panel.setFrame(frame, display: false)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.isOpaque = false
        // Noir à 1 % : invisible, mais assez présent pour recevoir les clics (une fenêtre transparente les laisse passer).
        panel.backgroundColor = .black
        panel.alphaValue = 0.01
        panel.hasShadow = false
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.contentView = ShieldView()
        return panel
    }
}

/// Avale les clics sans rien faire.
private final class ShieldView: NSView {
    override var acceptsFirstResponder: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {}
    override func rightMouseDown(with event: NSEvent) {}
    override func rightMouseUp(with event: NSEvent) {}
    override func otherMouseDown(with event: NSEvent) {}
    override func otherMouseUp(with event: NSEvent) {}
    override func scrollWheel(with event: NSEvent) {}
}
