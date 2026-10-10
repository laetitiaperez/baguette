import Testing
@testable import WandCore

private func row(_ pixels: [(UInt8, UInt8, UInt8, UInt8)]) -> RGBAImage {
    var img = RGBAImage(width: pixels.count, height: 1, fill: (0, 0, 0, 0))
    for (i, p) in pixels.enumerated() { img.setPixel(x: i, y: 0, p) }
    return img
}

private func gray(_ v: UInt8) -> (UInt8, UInt8, UInt8, UInt8) { (v, v, v, 255) }

@Suite struct MagicWandTests {
    @Test func contiguousVsGlobal() {
        let k = gray(0), wh = gray(255)
        let img = row([k, k, wh, k, k])
        let c = MagicWand.select(img, x: 0, y: 0, tolerance: 0, contiguous: true, antiAlias: false)
        let g = MagicWand.select(img, x: 0, y: 0, tolerance: 0, contiguous: false, antiAlias: false)
        #expect(c.values == [255, 255, 0, 0, 0])
        #expect(g.values == [255, 255, 0, 255, 255])
    }

    @Test func tolerance() {
        let img = row([gray(100), gray(110), gray(140)])
        func sel(_ t: Int) -> [UInt8] {
            MagicWand.select(img, x: 0, y: 0, tolerance: t, contiguous: false, antiAlias: false).values
        }
        #expect(sel(10) == [255, 255, 0])
        #expect(sel(9) == [255, 0, 0])
        #expect(sel(40) == [255, 255, 255])
    }

    @Test func alphaCountsAsChannel() {
        let img = row([(0, 0, 0, 255), (0, 0, 0, 200)])
        let m = MagicWand.select(img, x: 0, y: 0, tolerance: 50, contiguous: false, antiAlias: false)
        #expect(m.values == [255, 0])
    }

    @Test func transparentPixelsMatchRegardlessOfHiddenRGB() {
        let img = row([(255, 0, 0, 0), (0, 255, 0, 0), (0, 0, 255, 255)])
        let a = MagicWand.select(img, x: 0, y: 0, tolerance: 0, contiguous: true, antiAlias: false)
        let b = MagicWand.select(img, x: 2, y: 0, tolerance: 0, contiguous: true, antiAlias: false)
        #expect(a.values == [255, 255, 0])
        #expect(b.values == [0, 0, 255])
    }

    @Test func fourConnectivity() {
        var img = RGBAImage(width: 2, height: 2, fill: gray(0))
        img.setPixel(x: 1, y: 0, gray(255))
        img.setPixel(x: 0, y: 1, gray(255))
        let m = MagicWand.select(img, x: 0, y: 0, tolerance: 0, contiguous: true, antiAlias: false)
        #expect(m.values == [255, 0, 0, 0])
    }

    @Test func seedOutsideImage() {
        let img = row([gray(0), gray(0), gray(0)])
        #expect(MagicWand.select(img, x: -1, y: 0, tolerance: 0, contiguous: true, antiAlias: false).isEmpty)
        #expect(MagicWand.select(img, x: 3, y: 0, tolerance: 0, contiguous: true, antiAlias: false).isEmpty)
    }

    @Test func largeImageIsFast() {
        let img = RGBAImage(width: 6000, height: 4000, fill: (10, 20, 30, 255))
        let clock = ContinuousClock()
        var mask = Mask(width: 0, height: 0)
        let d = clock.measure {
            mask = MagicWand.select(img, x: 0, y: 0, tolerance: 0, contiguous: true, antiAlias: false)
        }
        #expect(mask.values.allSatisfy { $0 == 255 })
        #expect(d < .seconds(5))
    }
}
