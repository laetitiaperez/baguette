/// Efface la zone sélectionnée : l'opacité de chaque pixel est multipliée par `(255 - masque) / 255`.
/// Les canaux RVB ne changent pas. Le masque doit avoir la taille de l'image.
public func erase(_ image: RGBAImage, mask: Mask) -> RGBAImage {
    precondition(image.width == mask.width && image.height == mask.height, "erase : le masque doit avoir la taille de l'image")
    var out = image
    let count = image.width * image.height
    out.pixels.withUnsafeMutableBufferPointer { px in
        mask.values.withUnsafeBufferPointer { m in
            for i in 0..<count {
                let keep = 255 - Int(m[i])
                if keep == 255 { continue }
                let a = Int(px[4 * i + 3])
                px[4 * i + 3] = UInt8((a * keep + 127) / 255)
            }
        }
    }
    return out
}
