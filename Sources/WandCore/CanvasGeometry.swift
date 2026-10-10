import CoreGraphics

/// Conversion entre points de vue (origine en haut à gauche) et pixels de l'image.
public struct CanvasGeometry: Sendable {
    public var imageSize: CGSize
    public var zoom: CGFloat
    /// Coin haut-gauche de l'image, en points de vue.
    public var origin: CGPoint

    public init(imageSize: CGSize, zoom: CGFloat, origin: CGPoint) {
        self.imageSize = imageSize
        self.zoom = zoom
        self.origin = origin
    }

    /// Pixel situé sous un point de vue, ou `nil` s'il est hors de l'image.
    public func pixel(at viewPoint: CGPoint) -> (x: Int, y: Int)? {
        guard zoom > 0 else { return nil }
        let fx = floor((viewPoint.x - origin.x) / zoom)
        let fy = floor((viewPoint.y - origin.y) / zoom)
        guard fx >= 0, fy >= 0, fx < imageSize.width, fy < imageSize.height else { return nil }
        return (Int(fx), Int(fy))
    }

    /// Rectangle (en points de vue) occupé par un pixel.
    public func rect(forPixelX x: Int, y: Int) -> CGRect {
        CGRect(x: origin.x + CGFloat(x) * zoom,
               y: origin.y + CGFloat(y) * zoom,
               width: zoom, height: zoom)
    }

    /// Ajuste l'image dans la vue (marge de chaque côté), centrée, sans agrandir au-delà de 100 %.
    public static func fit(imageSize: CGSize, in viewSize: CGSize, margin: CGFloat = 20) -> CanvasGeometry {
        guard imageSize.width > 0, imageSize.height > 0, viewSize.width > 0, viewSize.height > 0 else {
            return CanvasGeometry(imageSize: imageSize, zoom: 1, origin: .zero)
        }
        let availW = max(viewSize.width - 2 * margin, 1)
        let availH = max(viewSize.height - 2 * margin, 1)
        let zoom = min(availW / imageSize.width, availH / imageSize.height, 1)
        let origin = CGPoint(x: (viewSize.width - imageSize.width * zoom) / 2,
                             y: (viewSize.height - imageSize.height * zoom) / 2)
        return CanvasGeometry(imageSize: imageSize, zoom: zoom, origin: origin)
    }
}
