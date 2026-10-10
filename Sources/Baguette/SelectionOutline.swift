import CoreGraphics
import Foundation
import WandCore

/// Rendus d'un masque de sélection : contour (pixels ≥ 128) et image d'alpha pour la teinte.
struct SelectionOutline {
    /// Contour en coordonnées pixels (origine en haut à gauche) : segments horizontaux et verticaux
    /// sur les bords des pixels, fusionnés en lignes continues.
    let path: CGPath
    let segmentCount: Int

    init(mask: Mask) {
        let w = mask.width, h = mask.height
        let path = CGMutablePath()
        var count = 0

        mask.values.withUnsafeBufferPointer { values in
            guard let box = Self.boundingBox(values, width: w, height: h) else { return }
            @inline(__always) func selected(_ x: Int, _ y: Int) -> Bool {
                x >= 0 && y >= 0 && x < w && y < h && values[y * w + x] >= 128
            }
            func segment(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) {
                path.move(to: CGPoint(x: x0, y: y0))
                path.addLine(to: CGPoint(x: x1, y: y1))
                count += 1
            }
            // Bords horizontaux : entre la rangée y−1 et la rangée y.
            for y in box.minY...(box.maxY + 1) {
                var start = -1
                for x in box.minX...(box.maxX + 1) {
                    let edge = x <= box.maxX && selected(x, y - 1) != selected(x, y)
                    if edge {
                        if start < 0 { start = x }
                    } else if start >= 0 {
                        segment(start, y, x, y)
                        start = -1
                    }
                }
            }
            // Bords verticaux : entre la colonne x−1 et la colonne x, parcourus rangée par rangée.
            var starts = [Int](repeating: -1, count: box.maxX - box.minX + 2)
            for y in box.minY...(box.maxY + 1) {
                for x in box.minX...(box.maxX + 1) {
                    let i = x - box.minX
                    let edge = y <= box.maxY && selected(x - 1, y) != selected(x, y)
                    if edge {
                        if starts[i] < 0 { starts[i] = y }
                    } else if starts[i] >= 0 {
                        segment(x, starts[i], x, y)
                        starts[i] = -1
                    }
                }
            }
        }
        self.path = path
        self.segmentCount = count
    }

    /// Plus petit rectangle contenant les pixels ≥ 128, ou `nil` s'il n'y en a pas.
    private static func boundingBox(_ values: UnsafeBufferPointer<UInt8>, width w: Int, height h: Int)
        -> (minX: Int, minY: Int, maxX: Int, maxY: Int)? {
        var minX = w, minY = h, maxX = -1, maxY = -1
        for y in 0..<h {
            let row = y * w
            for x in 0..<w where values[row + x] >= 128 {
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                maxY = y
            }
        }
        return maxX < 0 ? nil : (minX, minY, maxX, maxY)
    }

    /// Image gris + alpha (blanc prémultiplié, alpha = masque) servant de masque de calque à la teinte.
    static func alphaImage(_ mask: Mask) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: mask.values.count * 2)
        mask.values.withUnsafeBufferPointer { src in
            bytes.withUnsafeMutableBufferPointer { dst in
                for i in 0..<src.count {
                    dst[2 * i] = src[i]
                    dst[2 * i + 1] = src[i]
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: mask.width, height: mask.height, bitsPerComponent: 8, bitsPerPixel: 16,
                       bytesPerRow: mask.width * 2, space: CGColorSpaceCreateDeviceGray(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}
