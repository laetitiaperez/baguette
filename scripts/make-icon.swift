#!/usr/bin/env swift
// Génère Sources/Baguette/Resources/AppIcon.icns : le SF Symbol « wand.and.stars » en blanc sur un carré
// arrondi au dégradé violet (grille d'icône macOS : 824 × 824 dans 1024 × 1024).
// Usage : swift scripts/make-icon.swift   (depuis la racine du dépôt ; nécessite iconutil)
import AppKit

let output = URL(fileURLWithPath: "Sources/Baguette/Resources/AppIcon.icns")
let iconset = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")

/// Dessine l'icône dans un carré de `pixels` de côté.
func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    // Carré arrondi avec ombre portée légère.
    let tile = NSRect(x: 100, y: 100, width: 824, height: 824)
    let path = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 24
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Dégradé violet, plus clair en haut.
    let gradient = NSGradient(colors: [
        NSColor(srgbRed: 0.33, green: 0.16, blue: 0.70, alpha: 1),
        NSColor(srgbRed: 0.55, green: 0.30, blue: 0.93, alpha: 1),
        NSColor(srgbRed: 0.78, green: 0.52, blue: 1.00, alpha: 1),
    ])!
    gradient.draw(in: path, angle: 90)

    // Reflet discret sur la moitié haute.
    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    NSGradient(starting: NSColor.white.withAlphaComponent(0.18), ending: NSColor.white.withAlphaComponent(0))!
        .draw(in: NSRect(x: 100, y: 512, width: 824, height: 412), angle: 270)
    NSGraphicsContext.restoreGraphicsState()

    // Symbole blanc centré, avec une ombre douce.
    let config = NSImage.SymbolConfiguration(pointSize: 470, weight: .medium)
        .applying(.init(paletteColors: [.white]))
    if let symbol = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let size = symbol.size
        let scale = min(560 / size.width, 560 / size.height)
        let drawn = NSSize(width: size.width * scale, height: size.height * scale)
        let rect = NSRect(x: 512 - drawn.width / 2, y: 512 - drawn.height / 2,
                          width: drawn.width, height: drawn.height)
        NSGraphicsContext.saveGraphicsState()
        let glow = NSShadow()
        glow.shadowColor = NSColor(srgbRed: 0.20, green: 0.05, blue: 0.45, alpha: 0.45)
        glow.shadowOffset = NSSize(width: 0, height: -8)
        glow.shadowBlurRadius = 18
        glow.set()
        symbol.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()
    } else {
        fatalError("SF Symbol wand.and.stars introuvable")
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let fm = FileManager.default
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try render(pixels: points * scale).write(to: iconset.appendingPathComponent(name))
    }
}
try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", output.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil a échoué") }
try? fm.removeItem(at: iconset)
print("→ \(output.path)")
