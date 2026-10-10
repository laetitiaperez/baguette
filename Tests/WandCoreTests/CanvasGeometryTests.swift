import CoreGraphics
import Testing
@testable import WandCore

@Suite struct CanvasGeometryTests {
    let geo = CanvasGeometry(imageSize: CGSize(width: 100, height: 50), zoom: 2, origin: CGPoint(x: 10, y: 10))

    @Test func pixelAtTopLeft() {
        let p = geo.pixel(at: CGPoint(x: 10, y: 10))
        #expect(p?.x == 0 && p?.y == 0)
    }

    @Test func pixelAtBottomRightInside() {
        let p = geo.pixel(at: CGPoint(x: 209.9, y: 109.9))
        #expect(p?.x == 99 && p?.y == 49)
    }

    @Test func pixelOutsideIsNil() {
        #expect(geo.pixel(at: CGPoint(x: 210, y: 10)) == nil)
        #expect(geo.pixel(at: CGPoint(x: 9.9, y: 10)) == nil)
        #expect(geo.pixel(at: CGPoint(x: 10, y: 9.9)) == nil)
        #expect(geo.pixel(at: CGPoint(x: 10, y: 110)) == nil)
    }

    @Test func rectForPixel() {
        #expect(geo.rect(forPixelX: 3, y: 4) == CGRect(x: 16, y: 18, width: 2, height: 2))
    }

    @Test func fitLargeImageCentred() {
        let g = CanvasGeometry.fit(imageSize: CGSize(width: 1000, height: 500), in: CGSize(width: 520, height: 520))
        #expect(abs(g.zoom - 0.48) < 1e-9)
        #expect(abs(g.origin.x - 20) < 1e-9)
        #expect(abs(g.origin.y - 140) < 1e-9)
    }

    @Test func fitSmallImageNotEnlarged() {
        let g = CanvasGeometry.fit(imageSize: CGSize(width: 10, height: 10), in: CGSize(width: 520, height: 520))
        #expect(g.zoom == 1)
        #expect(abs(g.origin.x - 255) < 1e-9)
        #expect(abs(g.origin.y - 255) < 1e-9)
    }

    @Test func fitDegenerateSizes() {
        let a = CanvasGeometry.fit(imageSize: .zero, in: CGSize(width: 520, height: 520))
        #expect(a.zoom == 1 && a.origin == .zero)
        let b = CanvasGeometry.fit(imageSize: CGSize(width: 10, height: 10), in: .zero)
        #expect(b.zoom == 1 && b.origin == .zero)
    }
}
