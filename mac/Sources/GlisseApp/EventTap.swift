import CoreGraphics
import AppKit
import os

let log = Logger(subsystem: "io.snouzy.glisse", category: "app")

/// Un CGEventTap sur la souris et le clavier. Le gestionnaire rend l'événement à laisser passer, ou nil pour l'avaler.
final class EventTap {
    typealias Handler = (CGEventType, CGEvent) -> CGEvent?
    private var port: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let handler: Handler

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    var isRunning: Bool { port != nil }

    /// Démarre l'écoute. Demande l'accès Accessibilité à macOS s'il manque (une fenêtre système, une fois).
    func start() -> Bool {
        guard port == nil else { return true }
        let mask: CGEventMask = [
            CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged,
            .scrollWheel, .keyDown, .keyUp, .flagsChanged,
        ].reduce(0) { $0 | (1 << $1.rawValue) }

        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<EventTap>.fromOpaque(info).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    log.error("tap désactivé (\(type.rawValue)), réactivation")
                    tap.reenable()
                    return Unmanaged.passUnretained(event)
                }
                guard let out = tap.handler(type, event) else { return nil }
                return Unmanaged.passUnretained(out)
            },
            userInfo: info
        ) else {
            log.error("tapCreate a échoué, Accessibilité : \(AXIsProcessTrusted())")
            return false
        }
        log.notice("tap créé, Accessibilité : \(AXIsProcessTrusted())")
        port = tap
        let source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    private func reenable() {
        if let port { CGEvent.tapEnable(tap: port, enable: true) }
    }

    func stop() {
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let port { CGEvent.tapEnable(tap: port, enable: false) }
        runLoopSource = nil
        port = nil
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func askForTrust() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
