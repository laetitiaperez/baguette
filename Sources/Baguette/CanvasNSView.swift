import AppKit
import QuartzCore
import WandCore

/// Vue de document du canevas : damier, image, teinte et contour de sélection (calques Core Animation),
/// clics de baguette, curseur et zoom. Elle vit dans un `NSScrollView` qui fait défiler l'image
/// lorsqu'elle dépasse la fenêtre.
@MainActor
final class CanvasNSView: NSView {
    /// Clic sur un pixel de l'image, avec le mode déduit des touches ⇧ / ⌥.
    var onClick: ((_ x: Int, _ y: Int, _ mode: SelectionMode) -> Void)?

    private static let margin: CGFloat = 20
    private static let zoomRange: ClosedRange<CGFloat> = 0.01...32

    private var image: RGBAImage?
    private var selection: Mask?
    /// Contour de la sélection en coordonnées pixels (y vers le bas).
    private var outlinePath: CGPath?
    private(set) var zoom: CGFloat = 1
    /// Vrai tant que l'utilisateur n'a pas zoomé : l'image suit la taille de la fenêtre.
    private var fitsWindow = true
    private var imageOrigin: CGPoint = .zero

    private let contentLayer = CALayer()
    private let checkerLayer = CALayer()
    private let imageLayer = CALayer()
    private let tintLayer = CALayer()
    private let tintMaskLayer = CALayer()
    private let outlineLayer = CAShapeLayer()
    private let antsLayer = CAShapeLayer()

    private var flagsMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
        setUpLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) non pris en charge") }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    var geometry: CanvasGeometry {
        CanvasGeometry(imageSize: image.map { CGSize(width: $0.width, height: $0.height) } ?? .zero,
                       zoom: zoom, origin: imageOrigin)
    }

    // MARK: - Contenu

    /// Met à jour l'image et la sélection affichées. Les rendus coûteux (CGImage, contour, teinte)
    /// ne sont recalculés que si le tampon de pixels a changé.
    func show(image newImage: RGBAImage?, selection newSelection: Mask?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        if !Self.sameBuffer(newImage?.pixels, image?.pixels) {
            image = newImage
            imageLayer.contents = newImage.map { ImageFile.cgImage($0) }
            relayout()
        }
        if !Self.sameBuffer(newSelection?.values, selection?.values) {
            selection = newSelection
            updateSelectionLayers()
        }
    }

    /// Deux tableaux partagent-ils le même stockage ? Comme la vue garde une copie de l'ancien tableau,
    /// son adresse ne peut pas être réutilisée par un nouveau : l'égalité d'adresse est fiable.
    private static func sameBuffer(_ a: [UInt8]?, _ b: [UInt8]?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (a?, b?):
            return a.count == b.count
                && a.withUnsafeBufferPointer { pa in b.withUnsafeBufferPointer { pb in pa.baseAddress == pb.baseAddress } }
        default: return false
        }
    }

    // MARK: - Calques

    private func setUpLayers() {
        guard let root = layer else { return }
        contentLayer.isGeometryFlipped = !root.contentsAreFlipped()
        root.addSublayer(contentLayer)

        tintMaskLayer.anchorPoint = .zero
        tintLayer.mask = tintMaskLayer

        outlineLayer.fillColor = nil
        outlineLayer.strokeColor = NSColor.black.cgColor
        outlineLayer.lineWidth = 1
        antsLayer.fillColor = nil
        antsLayer.strokeColor = NSColor.white.cgColor
        antsLayer.lineWidth = 1
        antsLayer.lineDashPattern = [4, 4]

        for sublayer in [checkerLayer, imageLayer, tintLayer, outlineLayer, antsLayer] {
            sublayer.anchorPoint = .zero
            contentLayer.addSublayer(sublayer)
        }
        updateColors()
    }

    /// Couleurs système résolues pour l'apparence courante (clair / sombre).
    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            checkerLayer.backgroundColor = Self.checkerPattern(
                light: .controlBackgroundColor, dark: .unemphasizedSelectedContentBackgroundColor)
            tintLayer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        updateColors()
        CATransaction.commit()
    }

    /// Motif de damier : cases de 8 pt.
    private static func checkerPattern(light: NSColor, dark: NSColor) -> CGColor {
        let side: CGFloat = 8
        let tile = NSImage(size: NSSize(width: 2 * side, height: 2 * side))
        tile.addRepresentation(checkerTile(side: side, scale: 2, light: light.cgColor, dark: dark.cgColor))
        return NSColor(patternImage: tile).cgColor
    }

    private static func checkerTile(side: CGFloat, scale: CGFloat, light: CGColor, dark: CGColor) -> NSBitmapImageRep {
        let px = Int(2 * side * scale)
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: 2 * side, height: 2 * side)
        if let ctx = NSGraphicsContext(bitmapImageRep: rep)?.cgContext {
            let s = side * scale
            ctx.setFillColor(light)
            ctx.fill(CGRect(x: 0, y: 0, width: 2 * s, height: 2 * s))
            ctx.setFillColor(dark)
            ctx.fill(CGRect(x: 0, y: 0, width: s, height: s))
            ctx.fill(CGRect(x: s, y: s, width: s, height: s))
        }
        return rep
    }

    private func updateSelectionLayers() {
        guard let selection else {
            outlinePath = nil
            tintMaskLayer.contents = nil
            tintLayer.isHidden = true
            outlineLayer.path = nil
            antsLayer.path = nil
            antsLayer.removeAllAnimations()
            return
        }
        let outline = SelectionOutline(mask: selection)
        outlinePath = outline.path
        tintMaskLayer.contents = SelectionOutline.alphaImage(selection)
        tintLayer.isHidden = false
        // Au-delà, l'animation du pointillé coûterait trop cher à chaque image.
        if outline.segmentCount <= 100_000 {
            if antsLayer.animation(forKey: "ants") == nil {
                let march = CABasicAnimation(keyPath: "lineDashPhase")
                march.fromValue = 0
                march.toValue = 8
                march.duration = 0.6
                march.repeatCount = .infinity
                antsLayer.add(march, forKey: "ants")
            }
        } else {
            antsLayer.removeAllAnimations()
        }
        layoutLayers()
    }

    /// Place les calques sur le rectangle de l'image au zoom courant.
    private func layoutLayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        contentLayer.frame = bounds
        guard let image else { return }
        let rect = CGRect(origin: imageOrigin,
                          size: CGSize(width: CGFloat(image.width) * zoom, height: CGFloat(image.height) * zoom))
        for sublayer in [checkerLayer, imageLayer, tintLayer, outlineLayer, antsLayer] {
            sublayer.frame = rect
        }
        tintMaskLayer.frame = tintLayer.bounds
        let filter: CALayerContentsFilter = zoom > 1 ? .nearest : .linear
        imageLayer.magnificationFilter = filter
        tintMaskLayer.magnificationFilter = filter

        var scale = CGAffineTransform(scaleX: zoom, y: zoom)
        let scaled = outlinePath.flatMap { $0.copy(using: &scale) }
        outlineLayer.path = scaled
        antsLayer.path = scaled
    }

    // MARK: - Mise en page et zoom

    /// Recalcule la taille du document et la position de l'image (centrée si elle est plus petite que la vue).
    private func relayout() {
        guard let image, let clip = enclosingScrollView?.contentView else {
            layoutLayers()
            return
        }
        let visible = clip.bounds.size
        let imageSize = CGSize(width: image.width, height: image.height)
        if fitsWindow {
            zoom = CanvasGeometry.fit(imageSize: imageSize, in: visible, margin: Self.margin).zoom
        }
        let scaled = CGSize(width: imageSize.width * zoom, height: imageSize.height * zoom)
        let docSize = CGSize(width: max(scaled.width + 2 * Self.margin, visible.width),
                             height: max(scaled.height + 2 * Self.margin, visible.height))
        if frame.size != docSize { setFrameSize(docSize) }
        imageOrigin = CGPoint(x: (docSize.width - scaled.width) / 2, y: (docSize.height - scaled.height) / 2)
        layoutLayers()
    }

    /// Le document suit la taille de la zone visible (fenêtre redimensionnée, barres affichées…).
    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        NotificationCenter.default.removeObserver(self, name: NSView.frameDidChangeNotification, object: nil)
        guard let clip = superview as? NSClipView else { return }
        clip.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(visibleAreaDidResize),
                                               name: NSView.frameDidChangeNotification, object: clip)
    }

    @objc private func visibleAreaDidResize(_ notification: Notification) {
        relayout()
    }

    /// Zoom multiplicatif centré sur le milieu de la zone visible.
    func zoom(by factor: CGFloat) {
        guard let clip = enclosingScrollView?.contentView else { return }
        let visible = clip.bounds
        setZoom(zoom * factor, anchor: CGPoint(x: visible.midX, y: visible.midY))
    }

    /// Ajuste l'image à la fenêtre (⌘0) ; c'est aussi l'état au chargement d'une image.
    func zoomToFit() {
        fitsWindow = true
        relayout()
        enclosingScrollView?.contentView.scroll(to: .zero)
        enclosingScrollView?.reflectScrolledClipView(enclosingScrollView!.contentView)
    }

    /// Change le zoom en gardant immobile le point `anchor` (coordonnées de la vue).
    private func setZoom(_ newZoom: CGFloat, anchor: CGPoint) {
        guard image != nil, let scrollView = enclosingScrollView else { return }
        let clip = scrollView.contentView
        let clamped = min(max(newZoom, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        let imagePoint = CGPoint(x: (anchor.x - imageOrigin.x) / zoom, y: (anchor.y - imageOrigin.y) / zoom)
        let offset = CGPoint(x: anchor.x - clip.bounds.minX, y: anchor.y - clip.bounds.minY)

        fitsWindow = false
        zoom = clamped
        relayout()

        let newAnchor = CGPoint(x: imageOrigin.x + imagePoint.x * zoom, y: imageOrigin.y + imagePoint.y * zoom)
        let target = NSRect(origin: CGPoint(x: newAnchor.x - offset.x, y: newAnchor.y - offset.y),
                            size: clip.bounds.size)
        clip.scroll(to: clip.constrainBoundsRect(target).origin)
        scrollView.reflectScrolledClipView(clip)
    }

    override func magnify(with event: NSEvent) {
        setZoom(zoom * (1 + event.magnification), anchor: convert(event.locationInWindow, from: nil))
    }

    // MARK: - Clic

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        guard let pixel = geometry.pixel(at: point) else { return }
        onClick?(pixel.x, pixel.y, Self.mode(for: event.modifierFlags))
    }

    private static func mode(for flags: NSEvent.ModifierFlags) -> SelectionMode {
        if flags.contains(.shift) { return .add }
        if flags.contains(.option) { return .subtract }
        return .replace
    }

    // MARK: - Curseur

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas { removeTrackingArea(area) }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.cursorUpdate, .activeInKeyWindow, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }

    override func cursorUpdate(with event: NSEvent) {
        WandCursor.cursor(for: Self.mode(for: event.modifierFlags)).set()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if let flagsMonitor { NSEvent.removeMonitor(flagsMonitor) }
        flagsMonitor = nil
        guard newWindow != nil else { return }
        // ⇧ / ⌥ enfoncées ou relâchées sans bouger la souris : mettre à jour le badge du curseur.
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            MainActor.assumeIsolated { self?.modifiersChanged(event.modifierFlags) }
            return event
        }
    }

    private func modifiersChanged(_ flags: NSEvent.ModifierFlags) {
        guard let window, window.isKeyWindow else { return }
        let location = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        guard visibleRect.contains(location) else { return }
        WandCursor.cursor(for: Self.mode(for: flags)).set()
    }
}
