// Port de photocraft (storytold/photocraft, crates/algo/src/selection.rs), MIT OR Apache-2.0.

import Foundation

/// Manière de combiner une nouvelle sélection avec l'ancienne.
public enum SelectionMode: Sendable { case replace, add, subtract }

/// Opérations sur les masques de sélection.
public enum MaskOps {
    /// Combine l'ancien masque avec le nouveau. Retourne `nil` si le résultat est vide.
    /// Les deux masques doivent avoir la même taille.
    public static func combine(_ old: Mask?, _ new: Mask, mode: SelectionMode) -> Mask? {
        let result: Mask
        switch (mode, old) {
        case (.replace, _), (.add, nil):
            result = new
        case (.subtract, nil):
            return nil
        case (.add, let old?):
            precondition(old.width == new.width && old.height == new.height, "combine : tailles différentes")
            var r = old
            for i in 0..<r.values.count { r.values[i] = max(old.values[i], new.values[i]) }
            result = r
        case (.subtract, let old?):
            precondition(old.width == new.width && old.height == new.height, "combine : tailles différentes")
            var r = old
            for i in 0..<r.values.count { r.values[i] = old.values[i] &- min(old.values[i], new.values[i]) }
            result = r
        }
        return result.isEmpty ? nil : result
    }

    /// Inverse la sélection : chaque valeur `v` devient `255 - v`.
    public static func invert(_ m: Mask) -> Mask {
        var r = m
        for i in 0..<r.values.count { r.values[i] = 255 - m.values[i] }
        return r
    }

    /// Contour progressif : flou gaussien séparable (σ = rayon / 2), bords répétés.
    /// Un rayon ≤ 0 retourne le masque tel quel.
    public static func feather(_ m: Mask, radius: Double) -> Mask {
        guard radius > 0, m.width > 0, m.height > 0 else { return m }
        let half = Int(radius.rounded(.up))
        let sigma = radius / 2
        var kernel = (-half...half).map { Float(exp(-Double($0 * $0) / (2 * sigma * sigma))) }
        let sum = kernel.reduce(0, +)
        kernel = kernel.map { $0 / sum }

        let w = m.width, h = m.height
        var tmp = [Float](repeating: 0, count: w * h)
        var out = m

        m.values.withUnsafeBufferPointer { src in
            tmp.withUnsafeMutableBufferPointer { tmp in
                kernel.withUnsafeBufferPointer { k in
                    // Passe horizontale : une rangée à la fois, avec des indices bornés (bords répétés).
                    for y in 0..<h {
                        let base = y * w
                        for x in 0..<w {
                            var acc: Float = 0
                            for j in 0..<k.count {
                                let sx = min(max(x + j - half, 0), w - 1)
                                acc += k[j] * Float(src[base + sx])
                            }
                            tmp[base + x] = acc
                        }
                    }
                    // Passe verticale : on accumule rangée par rangée pour rester linéaire en mémoire.
                    out.values.withUnsafeMutableBufferPointer { dst in
                        var acc = [Float](repeating: 0, count: w)
                        acc.withUnsafeMutableBufferPointer { acc in
                            for y in 0..<h {
                                for x in 0..<w { acc[x] = 0 }
                                for j in 0..<k.count {
                                    let row = min(max(y + j - half, 0), h - 1) * w
                                    let weight = k[j]
                                    for x in 0..<w { acc[x] += weight * tmp[row + x] }
                                }
                                let base = y * w
                                for x in 0..<w { dst[base + x] = UInt8(min(max(acc[x].rounded(), 0), 255)) }
                            }
                        }
                    }
                }
            }
        }
        return out
    }
}
