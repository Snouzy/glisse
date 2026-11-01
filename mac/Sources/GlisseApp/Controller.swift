import AppKit
import CoreGraphics
import GlisseCore

/// Où est la souris.
enum Side: Equatable {
    case mac
    case phone
}

/// Le chef d'orchestre : regarde le curseur, passe sur l'iPhone au bord, y envoie la souris, revient.
final class Controller {
    private(set) var side: Side = .mac { didSet { if side != oldValue { onChange?() } } }
    private(set) var dongle: (paired: Bool, connected: Bool)?
    var onChange: (() -> Void)?

    let serial: SerialPort
    private var tap: EventTap!
    private var edgeGuard: EdgeGuard
    private var cursor: PhoneCursor
    private var buttons: MouseButtons = []
    /// L'écran et la hauteur où le curseur a quitté le Mac, pour le remettre au même endroit.
    private var exitDisplay: CGRect = .zero
    private let prefs = Preferences.shared
    private let shield = Shield()
    /// Où le curseur du Mac est parqué pendant que la souris est sur l'iPhone.
    private var parked: CGPoint = .zero

    /// ⌃⌥⌘P bascule à la main.
    private let hotKeyCode: Int64 = 35  // P
    private let hotKeyFlags: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]

    init() {
        serial = SerialPort(preferredPath: { Preferences.shared.portPath })
        edgeGuard = EdgeGuard(edge: prefs.edge, resistance: prefs.resistance)
        cursor = PhoneCursor(size: prefs.phoneSize, macSide: prefs.edge.opposite, gain: prefs.gain, returnResistance: prefs.returnResistance)
        tap = EventTap { [weak self] type, event in self?.handle(type, event) ?? event }
        serial.onLine = { [weak self] line in self?.received(line) }
        serial.onStateChange = { [weak self] in
            guard let self else { return }
            if !self.serial.isOpen {
                self.dongle = nil
                if self.side == .phone { self.returnToMac(yFraction: 0.5, pointerAtMacSide: false) }
                self.phonePointerAtMacSide = false
            }
            self.onChange?()
        }
    }

    func start() {
        CursorHider.allowHidingInBackground()
        serial.start()
        if !EventTap.isTrusted { EventTap.askForTrust() }
        startTapWhenAllowed()
    }

    /// Sans l'autorisation Accessibilité le tap refuse de se créer : on réessaie jusqu'à ce qu'elle soit donnée.
    private func startTapWhenAllowed() {
        if tap.start() { onChange?(); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.startTapWhenAllowed() }
    }

    /// À rappeler quand un réglage change.
    func applyPreferences() {
        edgeGuard = EdgeGuard(edge: prefs.edge, resistance: prefs.resistance)
        cursor = PhoneCursor(size: prefs.phoneSize, macSide: prefs.edge.opposite, gain: prefs.gain, returnResistance: prefs.returnResistance)
    }

    var statusText: String {
        guard serial.isOpen, let path = serial.path else { return "Dongle absent" }
        let name = (path as NSString).lastPathComponent
        guard let dongle else { return "Dongle sur \(name), en attente" }
        if dongle.paired { return "Dongle sur \(name), relié à l'iPhone" }
        if dongle.connected { return "Dongle sur \(name), iPhone en cours d'appairage" }
        return "Dongle sur \(name), iPhone non relié"
    }

    var canCross: Bool { serial.isOpen && (dongle?.paired ?? false) }

    func toggle() {
        switch side {
        case .mac:
            guard canCross else { NSSound.beep(); return }
            let location = CGEvent(source: nil)?.location ?? .zero
            let display = Displays.bounds(containing: location) ?? Displays.main
            enterPhone(from: display, yFraction: (location.y - display.minY) / display.height)
        case .phone:
            returnToMac(yFraction: cursor.position.y / cursor.size.height, pointerAtMacSide: false)
        }
    }

    // MARK: - Événements

    private func handle(_ type: CGEventType, _ event: CGEvent) -> CGEvent? {
        if type == .keyDown {
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift])
            if code == hotKeyCode, flags == hotKeyFlags {
                DispatchQueue.main.async { self.toggle() }
                return nil
            }
            return event
        }
        switch side {
        case .mac: return watchEdge(type, event)
        case .phone: return forward(type, event)
        }
    }

    private func watchEdge(_ type: CGEventType, _ event: CGEvent) -> CGEvent? {
        if type == .leftMouseDown || type == .rightMouseDown || type == .otherMouseDown {
            log.notice("clic \(event.getIntegerValueField(.mouseEventButtonNumber)) laissé au Mac en \(event.location.x, format: .fixed(precision: 0)),\(event.location.y, format: .fixed(precision: 0))")
        }
        guard type == .mouseMoved, canCross else { return event }
        let location = event.location
        guard let display = Displays.bounds(containing: location) else { return event }
        // Un autre écran de ce côté : le curseur y passe, ce n'est pas le bord du Mac.
        let beyond = CGPoint(x: prefs.edge == .right ? display.maxX + 1 : display.minX - 2, y: location.y)
        if Displays.bounds(containing: beyond) != nil { edgeGuard.reset(); return event }
        let dx = Double(event.getIntegerValueField(.mouseEventDeltaX))
        if edgeGuard.push(at: location, dx: dx, in: display) {
            enterPhone(from: display, yFraction: (location.y - display.minY) / display.height)
            return nil
        }
        return event
    }

    private func forward(_ type: CGEventType, _ event: CGEvent) -> CGEvent? {
        // La dissociation souris/curseur ne tient pas pour une app en arrière-plan : on re-parque le curseur
        // à chaque événement, comme Synergy. Les deltas de l'événement, eux, restent ceux de la souris.
        if event.location != parked { CGWarpMouseCursorPosition(parked) }
        switch type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            let dx = Double(event.getIntegerValueField(.mouseEventDeltaX))
            let dy = Double(event.getIntegerValueField(.mouseEventDeltaY))
            switch cursor.move(dx: dx, dy: dy) {
            case .moved(let ux, let uy):
                if ux != 0 || uy != 0 { serial.write(Wire.move(dx: ux, dy: uy)) }
            case .returnedToMac(let y):
                DispatchQueue.main.async { self.returnToMac(yFraction: y) }
            }
        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            log.notice("clic \(event.getIntegerValueField(.mouseEventButtonNumber)) retenu pour l'iPhone")
            if let b = MouseButtons(macButton: event.getIntegerValueField(.mouseEventButtonNumber)) {
                buttons.insert(b)
                serial.write(Wire.buttons(buttons))
            }
        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            if let b = MouseButtons(macButton: event.getIntegerValueField(.mouseEventButtonNumber)) {
                buttons.remove(b)
                serial.write(Wire.buttons(buttons))
            }
        case .scrollWheel:
            var dz = Int(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
            var dh = Int(event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
            if prefs.invertScroll { dz = -dz; dh = -dh }
            if dz != 0 || dh != 0 { serial.write(Wire.scroll(dz: dz, dh: dh)) }
        default:
            return event
        }
        return nil
    }

    // MARK: - Passages

    /// Le vrai pointeur iOS est-il collé au bord côté Mac ? Oui juste après un retour par le bord ; non au
    /// premier passage, après ⌃⌥⌘P ou une reconnexion du dongle : on l'y envoie alors d'une grande poussée.
    private var phonePointerAtMacSide = false

    private func enterPhone(from display: CGRect, yFraction: Double) {
        exitDisplay = display
        side = .phone
        buttons = []
        cursor.enter(yFraction: yFraction)
        log.notice("→ iPhone, hauteur \(yFraction, format: .fixed(precision: 2))")
        if !phonePointerAtMacSide {
            serial.write(Wire.move(dx: prefs.edge == .right ? -4000 : 4000, dy: 0))
            phonePointerAtMacSide = true
        }
        // Le curseur du Mac ne bouge plus, les deltas continuent d'arriver.
        CGAssociateMouseAndMouseCursorPosition(0)
        CursorHider.hide()
        let x = prefs.edge == .right ? display.maxX - 1 : display.minX
        parked = CGPoint(x: x, y: display.minY + yFraction * display.height)
        CGWarpMouseCursorPosition(parked)
        shield.show(around: parked)
    }

    private func returnToMac(yFraction: Double, pointerAtMacSide: Bool = true) {
        guard side == .phone else { return }
        log.notice("→ Mac, hauteur \(yFraction, format: .fixed(precision: 2)), pointeur iOS au bord : \(pointerAtMacSide)")
        phonePointerAtMacSide = pointerAtMacSide
        serial.write(Wire.release)
        buttons = []
        side = .mac
        edgeGuard.reset()
        let display = exitDisplay == .zero ? Displays.main : exitDisplay
        let x = prefs.edge == .right ? display.maxX - 2 : display.minX + 1
        let y = display.minY + min(max(yFraction, 0), 1) * (display.height - 1)
        CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
        CGAssociateMouseAndMouseCursorPosition(1)
        CursorHider.show()
        shield.hide()
    }

    private func received(_ line: String) {
        switch Wire.parse(line) {
        case .status(let paired, let connected):
            dongle = (paired, connected)
        case .paired(let paired):
            dongle = (paired, paired || (dongle?.connected ?? false))
            if !paired {
                if side == .phone { returnToMac(yFraction: 0.5, pointerAtMacSide: false) }
                phonePointerAtMacSide = false
            }
        case nil:
            return
        }
        onChange?()
    }
}

extension Edge {
    var opposite: Edge { self == .right ? .left : .right }
}

/// Les écrans en coordonnées CoreGraphics (origine en haut à gauche de l'écran principal, y vers le bas).
enum Displays {
    static var main: CGRect { CGDisplayBounds(CGMainDisplayID()) }

    static func bounds(containing point: CGPoint) -> CGRect? {
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        guard CGGetActiveDisplayList(16, &ids, &count) == .success else { return nil }
        for id in ids.prefix(Int(count)) {
            let b = CGDisplayBounds(id)
            if b.contains(point) { return b }
        }
        return nil
    }
}
