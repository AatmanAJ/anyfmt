import AppKit
import XCTest
@testable import RadialMenu

/// Painted surfaces and banded hovers (hosts that don't want vibrancy).
@MainActor
final class SurfaceStyleTests: XCTestCase {
    private func styled() -> RadialMenuStyle {
        var style = RadialMenuStyle(accentColor: NSColor(srgbHex: 0x2766EE))
        let s = RadialMenuStyle.Surface(disc: .black, segment: NSColor(srgbHex: 0x2A2A2A), hub: NSColor(srgbHex: 0x1F1F1F),
                                        stroke: NSColor(srgbHex: 0x3A3A3A), content: .white, secondaryContent: .gray,
                                        highlightContent: .black, pill: NSColor(srgbHex: 0x1F1F1F), pillText: .white)
        style.surface = RadialMenuStyle.SurfaceSet(light: s, dark: s)
        style.highlightBands = [NSColor(srgbHex: 0xFF2600), NSColor(srgbHex: 0xFF9500), NSColor(srgbHex: 0xFFCAA0)]
        return style
    }

    func testSurfaceMeansNoVibrancyAndNoGlow() {
        let view = RadialMenuView(style: styled(), materialMode: .live)
        XCTAssertFalse(view.subviews.contains { $0 is NSVisualEffectView }, "painted, not glass")
        let p = RadialPalette(style: styled(), appearance: .dark, hitAlpha: 0.01)
        XCTAssertEqual(p.glowOpacity, 0)
        XCTAssertEqual(p.highlightBands?.count, 3)
        XCTAssertEqual(p.highlightContent.usingColorSpace(.sRGB)?.whiteComponentApprox ?? 1, 0, accuracy: 0.01,
                       "dark text on the bands")
    }

    func testBandsFallBackToFlatForAccessibility() {
        for a in [RadialAppearance(isDark: true, increaseContrast: true), RadialAppearance(isDark: true, reduceTransparency: true)] {
            let p = RadialPalette(style: styled(), appearance: a, hitAlpha: 0.01)
            XCTAssertNil(p.highlightBands, "flat accent under \(a)")
            // A painted surface names its own highlight text, flat accent or not (dark here).
            XCTAssertEqual(p.highlightContent.usingColorSpace(.sRGB)?.whiteComponentApprox ?? 1, 0, accuracy: 0.01,
                           "the surface's highlight text on the flat accent")
        }
    }

    func testDefaultStyleIsUnchanged() {
        let view = RadialMenuView(style: RadialMenuStyle(), materialMode: .live)
        XCTAssertTrue(view.subviews.contains { $0 is NSVisualEffectView }, "vibrancy by default")
        XCTAssertNil(RadialPalette(style: RadialMenuStyle(), appearance: .dark, hitAlpha: 0.01).highlightBands)
    }

    func testBandImageRenders() {
        let colors = [NSColor.red.cgColor, NSColor.orange.cgColor, NSColor.white.cgColor]
        let image = SegmentNode.bandImage(size: CGSize(width: 60, height: 40), colors: colors, scale: 2)
        XCTAssertEqual(image?.width, 120)
        XCTAssertEqual(image?.height, 80)
        XCTAssertNil(SegmentNode.bandImage(size: CGSize(width: 60, height: 40), colors: [NSColor.red.cgColor], scale: 2))
    }
}

private extension NSColor {
    /// Rough brightness for assertions (0 = black, 1 = white).
    var whiteComponentApprox: CGFloat { (redComponent + greenComponent + blueComponent) / 3 }
}
