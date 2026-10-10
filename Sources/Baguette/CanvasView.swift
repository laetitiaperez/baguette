import AppKit
import SwiftUI
import WandCore

/// Canevas SwiftUI : un `NSScrollView` dont le document est un `CanvasNSView`.
struct CanvasView: NSViewRepresentable {
    let model: AppModel
    let image: RGBAImage?
    let selection: Mask?

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .windowBackgroundColor
        let canvas = CanvasNSView(frame: .zero)
        let editor = model.editor
        canvas.onClick = { [weak editor] x, y, mode in editor?.click(x: x, y: y, mode: mode) }
        scrollView.documentView = canvas
        model.canvas = canvas
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        (scrollView.documentView as? CanvasNSView)?.show(image: image, selection: selection)
    }
}

/// Curseur baguette (SF Symbol), avec un badge « + » (ajouter) ou « − » (soustraire).
@MainActor
enum WandCursor {
    private static let replace = make(badge: nil)
    private static let add = make(badge: "+")
    private static let subtract = make(badge: "−")

    static func cursor(for mode: SelectionMode) -> NSCursor {
        switch mode {
        case .replace: replace
        case .add: add
        case .subtract: subtract
        }
    }

    private static func make(badge: String?) -> NSCursor {
        let size = NSSize(width: 28, height: 28)
        let symbolRect = NSRect(x: 2, y: 8, width: 18, height: 18)
        let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let base = NSImage(systemSymbolName: "wand.and.rays", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        let image = NSImage(size: size, flipped: false) { _ in
            if let base {
                // Halo blanc puis symbole noir : lisible sur fond clair comme sombre.
                let halo = base.withSymbolConfiguration(.init(paletteColors: [.white])) ?? base
                for dx in [-1.0, 0, 1] {
                    for dy in [-1.0, 0, 1] where dx != 0 || dy != 0 {
                        halo.draw(in: symbolRect.offsetBy(dx: dx, dy: dy))
                    }
                }
                (base.withSymbolConfiguration(.init(paletteColors: [.black])) ?? base).draw(in: symbolRect)
            }
            if let badge {
                let circle = NSRect(x: 16, y: 1, width: 11, height: 11)
                NSColor.white.setFill()
                NSBezierPath(ovalIn: circle.insetBy(dx: -1, dy: -1)).fill()
                NSColor.black.setFill()
                NSBezierPath(ovalIn: circle).fill()
                NSColor.white.setFill()
                NSRect(x: circle.minX + 2.5, y: circle.midY - 0.75, width: 6, height: 1.5).fill()
                if badge == "+" {
                    NSRect(x: circle.midX - 0.75, y: circle.minY + 2.5, width: 1.5, height: 6).fill()
                }
            }
            return true
        }
        // Point chaud : le bout de la baguette, au centre des rayons du symbole.
        let hotSpot = NSPoint(x: symbolRect.minX + symbolRect.width * 0.5,
                              y: size.height - symbolRect.maxY + symbolRect.height * 0.5)
        return NSCursor(image: image, hotSpot: hotSpot)
    }
}
