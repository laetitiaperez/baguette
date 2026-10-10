// Port de photocraft (storytold/photocraft, crates/algo/src/selection.rs), MIT OR Apache-2.0.

/// Baguette magique : sélection par similarité de couleur à partir d'un pixel.
public enum MagicWand {
    /// Sélectionne les pixels similaires au pixel `(x, y)`.
    /// - `tolerance` : 0...255 (borné), écart maximal admis sur chacun des 4 canaux.
    /// - `contiguous` : vrai = zone connectée en 4-voisinage ; faux = toute l'image.
    /// - `antiAlias` : vrai = adoucit les bords du résultat avec `antialias(_:)`.
    public static func select(_ image: RGBAImage, x: Int, y: Int, tolerance: Int, contiguous: Bool, antiAlias: Bool) -> Mask {
        let w = image.width, h = image.height
        guard x >= 0, x < w, y >= 0, y < h else { return Mask(width: w, height: h) }
        let tol = Int32(min(max(tolerance, 0), 255))

        var marks = [UInt8](repeating: 0, count: w * h)
        image.pixels.withUnsafeBufferPointer { px in
            // Le tampon [UInt8] est aligné sur 16 octets en pratique (≥ 4) et n'est lu que via ce mot, sans écriture : pas d'alias gênant.
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
                    // Cherche, sur la rangée `ny`, les débuts de plages similaires entre `l` et `r`.
                    func scanRow(_ ny: Int, _ l: Int, _ r: Int) {
                        let nrow = ny * w
                        var inRun = false
                        var nx = l
                        while nx <= r {
                            let ok = marks[nrow + nx] == 0 && (words[nrow + nx] == targetWord || similar(nrow + nx))
                            if ok && !inRun { stack.append((nx, ny)) }
                            inRun = ok
                            nx += 1
                        }
                    }
                    while let (sx, sy) = stack.popLast() {
                        let row = sy * w
                        if marks[row + sx] != 0 { continue }
                        var l = sx, r = sx
                        while l > 0 && marks[row + l - 1] == 0 && (words[row + l - 1] == targetWord || similar(row + l - 1)) { l -= 1 }
                        while r + 1 < w && marks[row + r + 1] == 0 && (words[row + r + 1] == targetWord || similar(row + r + 1)) { r += 1 }
                        (marks + row + l).update(repeating: 255, count: r - l + 1)
                        if sy > 0 { scanRow(sy - 1, l, r) }
                        if sy + 1 < h { scanRow(sy + 1, l, r) }
                    }
                } else {
                    var i = 0
                    let n = w * h
                    while i < n {
                        if words[i] == targetWord || similar(i) { marks[i] = 255 }
                        i += 1
                    }
                }
            }
        }
        let result = Mask(width: w, height: h, values: marks)
        return antiAlias ? antialias(result) : result
    }

    /// Adoucit les bords : un pixel dont un voisin 3×3 diffère prend une valeur issue de la moyenne 3×3
    /// (sélectionné, > 127 : 0,5 + 0,5·moy ; sinon 0,5·moy). Hors image, un voisin vaut le pixel lui-même.
    public static func antialias(_ mask: Mask) -> Mask {
        let w = mask.width, h = mask.height
        let src = mask.values
        var out = src
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                let center = src[i]
                var sum = 0
                var edge = false
                for dy in -1...1 {
                    for dx in -1...1 {
                        let xx = x + dx, yy = y + dy
                        let v = (xx < 0 || yy < 0 || xx >= w || yy >= h) ? center : src[yy * w + xx]
                        if v != center { edge = true }
                        sum += Int(v)
                    }
                }
                if edge {
                    let avg = Double(sum) / (9 * 255)
                    let value = center > 127 ? 0.5 + 0.5 * avg : 0.5 * avg
                    out[i] = UInt8((value * 255).rounded())
                }
            }
        }
        return Mask(width: w, height: h, values: out)
    }
}
