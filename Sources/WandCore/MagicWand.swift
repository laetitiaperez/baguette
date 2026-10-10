// Port de photocraft (storytold/photocraft, crates/algo/src/selection.rs), MIT OR Apache-2.0.

/// Baguette magique : sélection par similarité de couleur à partir d'un pixel.
public enum MagicWand {
    /// Sélectionne les pixels similaires au pixel `(x, y)`.
    /// - `tolerance` : 0...255 (borné), écart maximal admis sur chacun des 4 canaux.
    /// - `contiguous` : vrai = zone connectée en 4-voisinage ; faux = toute l'image.
    /// - `antiAlias` : accepté, ignoré pour l'instant (ajouté en Tâche 3).
    public static func select(_ image: RGBAImage, x: Int, y: Int, tolerance: Int, contiguous: Bool, antiAlias: Bool) -> Mask {
        let w = image.width, h = image.height
        var mask = Mask(width: w, height: h)
        guard x >= 0, x < w, y >= 0, y < h else { return mask }
        let tol = Int32(min(max(tolerance, 0), 255))

        var marks = [UInt8](repeating: 0, count: w * h)
        image.pixels.withUnsafeBufferPointer { px in
            let words = UnsafeRawPointer(px.baseAddress!).assumingMemoryBound(to: UInt32.self)
            marks.withUnsafeMutableBufferPointer { marksBuffer in
                let marks = marksBuffer.baseAddress!
                let s = 4 * (y * w + x)
                let t0 = Int32(px[s]), t1 = Int32(px[s + 1]), t2 = Int32(px[s + 2]), t3 = Int32(px[s + 3])
                // Les pixels totalement transparents se ressemblent, quel que soit leur RVB caché.
                let targetWord = words[y * w + x]
                @inline(__always) func similar(_ i: Int) -> Bool {
                    if words[i] == targetWord { return true }  // chemin rapide : couleur identique
                    let o = 4 * i
                    let a = Int32(px[o + 3])
                    if t3 == 0 && a == 0 { return true }
                    return abs(Int32(px[o]) - t0) <= tol
                        && abs(Int32(px[o + 1]) - t1) <= tol
                        && abs(Int32(px[o + 2]) - t2) <= tol
                        && abs(a - t3) <= tol
                }

                if contiguous {
                    // Remplissage par segments : on remplit une plage, puis on cherche des germes au-dessus et en dessous.
                    var stack: [(Int, Int)] = [(x, y)]
                    while let (sx, sy) = stack.popLast() {
                        let row = sy * w
                        if marks[row + sx] != 0 { continue }
                        var l = sx, r = sx
                        while l > 0 && marks[row + l - 1] == 0 && similar(row + l - 1) { l -= 1 }
                        while r + 1 < w && marks[row + r + 1] == 0 && similar(row + r + 1) { r += 1 }
                        (marks + row + l).update(repeating: 255, count: r - l + 1)
                        for ny in [sy - 1, sy + 1] where ny >= 0 && ny < h {
                            let nrow = ny * w
                            var inRun = false
                            var nx = l
                            while nx <= r {
                                let ok = marks[nrow + nx] == 0 && similar(nrow + nx)
                                if ok && !inRun { stack.append((nx, ny)) }
                                inRun = ok
                                nx += 1
                            }
                        }
                    }
                } else {
                    var i = 0
                    let n = w * h
                    while i < n {
                        if similar(i) { marks[i] = 255 }
                        i += 1
                    }
                }
            }
        }
        mask.values = marks
        return mask
    }
}
