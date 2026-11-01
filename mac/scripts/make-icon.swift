// Dessine l'icône de Glisse (un iPhone, le curseur qui y glisse) et écrit Resources/AppIcon.icns.
// Usage : swift scripts/make-icon.swift
import AppKit

func cursor(at tip: CGPoint, scale s: CGFloat, alpha: CGFloat) {
    // La flèche de macOS, pointe en `tip`, environ 190 px de haut à l'échelle 1024.
    let p = NSBezierPath()
    let pts: [(CGFloat, CGFloat)] = [(0, 0), (0, 190), (46, 150), (84, 232), (124, 214), (86, 134), (140, 130)]
    p.move(to: CGPoint(x: tip.x, y: tip.y))
    for (x, y) in pts.dropFirst() { p.line(to: CGPoint(x: tip.x + x * s, y: tip.y + y * s)) }
    p.close()
    p.lineJoinStyle = .round
    NSColor(white: 0.08, alpha: alpha).setStroke()
    p.lineWidth = 26 * s
    p.stroke()
    NSColor(white: 1, alpha: alpha).setFill()
    p.fill()
}

func draw(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
        let s = size / 1024
        let body = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
        let tile = NSBezierPath(roundedRect: body, xRadius: 185 * s, yRadius: 185 * s)
        NSGradient(starting: NSColor(srgbRed: 0.36, green: 0.42, blue: 0.98, alpha: 1),
                   ending: NSColor(srgbRed: 0.16, green: 0.18, blue: 0.55, alpha: 1))!.draw(in: tile, angle: 90)

        // L'iPhone, à droite, posé en portrait.
        let phone = NSRect(x: 520 * s, y: 230 * s, width: 300 * s, height: 580 * s)
        let shell = NSBezierPath(roundedRect: phone, xRadius: 56 * s, yRadius: 56 * s)
        NSColor(white: 0.07, alpha: 1).setFill()
        shell.fill()
        let screen = NSBezierPath(roundedRect: phone.insetBy(dx: 16 * s, dy: 16 * s), xRadius: 44 * s, yRadius: 44 * s)
        NSGradient(starting: NSColor(srgbRed: 0.62, green: 0.74, blue: 1.0, alpha: 1),
                   ending: NSColor(srgbRed: 0.30, green: 0.40, blue: 0.95, alpha: 1))!.draw(in: screen, angle: 70)
        let island = NSBezierPath(roundedRect: NSRect(x: 620 * s, y: 258 * s, width: 100 * s, height: 28 * s), xRadius: 14 * s, yRadius: 14 * s)
        NSColor(white: 0.07, alpha: 1).setFill()
        island.fill()

        // Le curseur arrive de la gauche et entre dans l'iPhone, avec une traînée.
        for (i, x) in [230.0, 330.0, 430.0].enumerated() {
            cursor(at: CGPoint(x: x * s, y: 420 * s), scale: 0.82 * s, alpha: 0.18 + 0.14 * CGFloat(i))
        }
        cursor(at: CGPoint(x: 560 * s, y: 440 * s), scale: 1.0 * s, alpha: 1)
        return true
    }
}

let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("GlisseIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = CGFloat(base * scale)
        let image = draw(size: pixels)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixels), pixelsHigh: Int(pixels),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
try FileManager.default.createDirectory(atPath: "Resources", withIntermediateDirectories: true)
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", "Resources/AppIcon.icns"]
try task.run()
task.waitUntilExit()
// Et une version PNG pour le README.
try FileManager.default.copyItem(at: iconset.appendingPathComponent("icon_512x512@2x.png"), to: URL(fileURLWithPath: "../docs/images/icon.png"))
print(task.terminationStatus == 0 ? "Resources/AppIcon.icns, ../docs/images/icon.png" : "iconutil a échoué")
