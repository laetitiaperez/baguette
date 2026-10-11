import Testing
@testable import WandCore

@Suite struct EraseTests {
    private func erased(maskValue: UInt8) -> (UInt8, UInt8, UInt8, UInt8) {
        let img = RGBAImage(width: 1, height: 1, fill: (10, 20, 30, 200))
        let mask = Mask(width: 1, height: 1, value: maskValue)
        return erase(img, mask: mask).pixel(x: 0, y: 0)
    }
    @Test func fullyMaskedBecomesTransparent() {
        let p = erased(maskValue: 255)
        #expect(p.3 == 0 && p.0 == 10 && p.1 == 20 && p.2 == 30)
    }
    @Test func unmaskedIsUnchanged() {
        let p = erased(maskValue: 0)
        #expect(p == (10, 20, 30, 200))
    }
    @Test func partialMaskScalesAlpha() {
        let p = erased(maskValue: 128)
        #expect(p.3 == 100 && p.0 == 10 && p.1 == 20 && p.2 == 30)
    }
}
