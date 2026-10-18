import AppKit
import HaloCore

/// The "photo" inside Sample.heic: a twilight lake in Halo's iris and mint,
/// drawn in code so the app ships no sample image.
enum SampleArtwork {
    /// Square thumbnail, rendered at 2× for Retina.
    static func thumbnail(size: CGFloat) -> NSImage {
        let px = Int(size * 2)
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSImage(size: NSSize(width: size, height: size))
        }
        draw(in: ctx, side: CGFloat(px))
        guard let cg = ctx.makeImage() else { return NSImage(size: NSSize(width: size, height: size)) }
        return NSImage(cgImage: cg, size: NSSize(width: size, height: size))
    }

    private static func color(_ hex: Int, _ alpha: CGFloat = 1) -> CGColor {
        NSColor(hex: hex, alpha: alpha).cgColor
    }

    /// CoreGraphics coordinates: origin bottom-left.
    private static func draw(in ctx: CGContext, side s: CGFloat) {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let horizon = s * 0.34

        // Sky: deep iris at the top, fading to mint at the horizon.
        let sky = [color(0x2B2178), color(0x6E56F8), color(0xA493FF), color(0x9BE7D8)] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: sky, locations: [0, 0.45, 0.78, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: horizon), options: [.drawsAfterEndLocation])
        }

        // A few stars.
        ctx.setFillColor(color(0xFFFFFF, 0.8))
        for (x, y, r) in [(0.14, 0.9, 0.006), (0.32, 0.82, 0.004), (0.86, 0.88, 0.005), (0.52, 0.94, 0.003), (0.74, 0.79, 0.003)] {
            ctx.fillEllipse(in: CGRect(x: s * x, y: s * y, width: s * r * 2, height: s * r * 2))
        }

        // Moon with a soft glow.
        let moon = CGPoint(x: s * 0.67, y: s * 0.6)
        if let glow = CGGradient(colorsSpace: space, colors: [color(0xFFFFFF, 0.55), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1]) {
            ctx.drawRadialGradient(glow, startCenter: moon, startRadius: 0, endCenter: moon, endRadius: s * 0.24, options: [])
        }
        ctx.setFillColor(color(0xFDFBFF))
        ctx.fillEllipse(in: CGRect(x: moon.x - s * 0.075, y: moon.y - s * 0.075, width: s * 0.15, height: s * 0.15))

        // Far ridge.
        ctx.setFillColor(color(0x5B4BD6, 0.85))
        ridge(ctx, s, base: horizon, points: [(0, 0.12), (0.12, 0.2), (0.24, 0.14), (0.38, 0.27), (0.5, 0.17), (0.62, 0.22), (0.78, 0.12), (0.9, 0.18), (1, 0.1)])
        // Near ridge.
        ctx.setFillColor(color(0x231A63))
        ridge(ctx, s, base: horizon, points: [(0, 0.2), (0.1, 0.08), (0.22, 0.13), (0.3, 0.04), (0.46, 0.1), (0.6, 0.02), (0.72, 0.09), (0.86, 0.05), (1, 0.14)])

        // Lake: the sky reflected, darker, with light streaks.
        let lake = [color(0x7C6BE8), color(0x2E2580)] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: lake, locations: [0, 1]) {
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 0, width: s, height: horizon))
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: horizon), end: .zero, options: [])
            ctx.restoreGState()
        }
        ctx.setFillColor(color(0xFFFFFF, 0.35))
        for (x, y, w) in [(0.6, 0.27, 0.14), (0.63, 0.22, 0.08), (0.57, 0.17, 0.12), (0.64, 0.12, 0.05), (0.2, 0.08, 0.1)] {
            let r = CGRect(x: s * x, y: s * y, width: s * w, height: s * 0.008)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: r.height / 2, cornerHeight: r.height / 2, transform: nil))
        }
        ctx.fillPath()
        // Mint line where water meets land.
        ctx.setFillColor(color(0x3DD9BF, 0.55))
        ctx.fill(CGRect(x: 0, y: horizon - s * 0.004, width: s, height: s * 0.006))
    }

    /// Filled ridge: points are (x, height above `base`) in unit coordinates.
    private static func ridge(_ ctx: CGContext, _ s: CGFloat, base: CGFloat, points: [(CGFloat, CGFloat)]) {
        ctx.beginPath()
        ctx.move(to: CGPoint(x: 0, y: base))
        for (x, h) in points { ctx.addLine(to: CGPoint(x: s * x, y: base + s * h)) }
        ctx.addLine(to: CGPoint(x: s, y: base))
        ctx.closePath()
        ctx.fillPath()
    }
}
