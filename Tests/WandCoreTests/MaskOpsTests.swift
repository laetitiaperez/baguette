import Testing
@testable import WandCore

@Suite struct MaskOpsTests {
    private func row(_ v: [UInt8]) -> Mask { Mask(width: v.count, height: 1, values: v) }

    @Test func combineReplace() {
        let r = MaskOps.combine(row([0, 100, 255]), row([50, 50, 0]), mode: .replace)
        #expect(r?.values == [50, 50, 0])
    }
    @Test func combineAdd() {
        let r = MaskOps.combine(row([0, 100, 255]), row([50, 50, 0]), mode: .add)
        #expect(r?.values == [50, 100, 255])
    }
    @Test func combineSubtract() {
        let r = MaskOps.combine(row([0, 100, 255]), row([50, 50, 0]), mode: .subtract)
        #expect(r?.values == [0, 50, 255])
    }
    @Test func combineNilOldSubtractIsNil() {
        #expect(MaskOps.combine(nil, row([50, 50, 0]), mode: .subtract) == nil)
    }
    @Test func combineNilOldAddIsNew() {
        #expect(MaskOps.combine(nil, row([50, 50, 0]), mode: .add)?.values == [50, 50, 0])
    }
    @Test func combineEmptyResultIsNil() {
        #expect(MaskOps.combine(row([10, 20]), row([0, 0]), mode: .replace) == nil)
        #expect(MaskOps.combine(row([10, 20]), row([255, 255]), mode: .subtract) == nil)
    }
    @Test func invertFlipsValues() {
        #expect(MaskOps.invert(row([0, 100, 255])).values == [255, 155, 0])
    }
    @Test func featherZeroIsIdentity() {
        let m = row([255, 255, 0, 10, 0])
        #expect(MaskOps.feather(m, radius: 0) == m)
    }
    @Test func featherSoftensStep() {
        var m = Mask(width: 21, height: 1)
        for x in 0..<10 { m[x, 0] = 255 }
        let f = MaskOps.feather(m, radius: 4)
        #expect(f.width == 21 && f.height == 1)
        for x in 1..<21 { #expect(f[x, 0] <= f[x - 1, 0]) }
        #expect(f[0, 0] == 255)
        #expect(f[20, 0] == 0)
        #expect(f.values.contains { $0 > 0 && $0 < 255 })
    }
    @Test func featherWorksVertically() {
        var m = Mask(width: 1, height: 21)
        for y in 0..<10 { m[0, y] = 255 }
        let f = MaskOps.feather(m, radius: 4)
        for y in 1..<21 { #expect(f[0, y] <= f[0, y - 1]) }
        #expect(f.values.contains { $0 > 0 && $0 < 255 })
    }
}
