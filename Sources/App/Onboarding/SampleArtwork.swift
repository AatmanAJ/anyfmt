import AppKit
import AnyfmtCore

/// The "photo" inside Sample.heic: a sunset over a lake in anyfmt's heat colours
/// with black hills, drawn in code so the app ships no sample image.
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
        typealias P = DesignTokens.Primitive
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let horizon = s * 0.34

        // Sky: deep ember at the top, through flame and orange, to peach at the horizon.
        let sky = [color(P.ember700), color(P.ember600), color(P.ember500), color(P.amber400), color(P.peach200)] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: sky, locations: [0, 0.3, 0.55, 0.78, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: horizon), options: [.drawsAfterEndLocation])
        }

        // The sun, low, half behind the far hills.
        let sun = CGPoint(x: s * 0.62, y: horizon + s * 0.16)
        ctx.setFillColor(color(P.cream100))
        ctx.fillEllipse(in: CGRect(x: sun.x - s * 0.12, y: sun.y - s * 0.12, width: s * 0.24, height: s * 0.24))

        // Far ridge.
        ctx.setFillColor(color(P.ink800))
        ridge(ctx, s, base: horizon, points: [(0, 0.12), (0.12, 0.2), (0.24, 0.14), (0.38, 0.27), (0.5, 0.17), (0.62, 0.12), (0.78, 0.16), (0.9, 0.22), (1, 0.1)])
        // Near ridge.
        ctx.setFillColor(color(P.ink1000))
        ridge(ctx, s, base: horizon, points: [(0, 0.2), (0.1, 0.08), (0.22, 0.13), (0.3, 0.04), (0.46, 0.1), (0.6, 0.02), (0.72, 0.09), (0.86, 0.05), (1, 0.14)])

        // Lake: dark water with the sun's light in streaks.
        let lake = [color(P.ink800), color(P.ink1000)] as CFArray
        if let g = CGGradient(colorsSpace: space, colors: lake, locations: [0, 1]) {
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: 0, width: s, height: horizon))
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: horizon), end: .zero, options: [])
            ctx.restoreGState()
        }
        ctx.setFillColor(color(P.amber400, 0.85))
        for (x, y, w) in [(0.52, 0.28, 0.2), (0.55, 0.23, 0.14), (0.5, 0.18, 0.18), (0.57, 0.13, 0.08), (0.2, 0.08, 0.1)] {
            let r = CGRect(x: s * x, y: s * y, width: s * w, height: s * 0.01)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: r.height / 2, cornerHeight: r.height / 2, transform: nil))
        }
        ctx.fillPath()
        // A bright line where water meets land.
        ctx.setFillColor(color(P.peach200, 0.7))
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
