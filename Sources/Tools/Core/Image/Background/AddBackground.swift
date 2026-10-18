import Foundation
import CoreGraphics
import ImageIO

/// The "put it on a nice canvas" look (tool 8): the image sits centred on a
/// solid, gradient or image fill with padding, rounded corners and a soft
/// shadow. Padding is a percentage of the image's longest edge, the corner
/// radius a percentage of its shortest edge. Option "angle" (degrees, editor
/// only, default 135, CSS convention: 0° up, 90° right) sets the gradient direction.
public struct BackdropStyle: Sendable, Hashable {
    public enum Fill: String, Sendable, CaseIterable { case solid, gradient, image }

    public var fill: Fill
    public var color1: String
    public var color2: String
    public var angle: Double
    public var imagePath: String
    public var padding: Double
    public var cornerRadius: Double
    public var shadow: Bool

    public init(options o: OptionValues) {
        fill = Fill(rawValue: o.string("fill", default: "gradient")) ?? .gradient
        color1 = o.string("color1", default: "#6E56F8")
        color2 = o.string("color2", default: "#22C3A6")
        angle = o.double("angle", default: 135)
        imagePath = o.string("imagePath", default: "")
        padding = min(40, max(0, o.double("padding", default: 10)))
        cornerRadius = min(20, max(0, o.double("cornerRadius", default: 4)))
        shadow = o.bool("shadow", default: true)
    }

    public var options: OptionValues {
        OptionValues(["fill": .string(fill.rawValue), "color1": .string(color1), "color2": .string(color2),
                      "angle": .double(angle), "imagePath": .string(imagePath), "padding": .int(Int(padding.rounded())),
                      "cornerRadius": .int(Int(cornerRadius.rounded())), "shadow": .bool(shadow)])
    }
}

public enum BackgroundComposer {
    /// Padding in pixels for a subject of `size`.
    public static func paddingPixels(for size: CGSize, style: BackdropStyle) -> Int {
        Int((max(size.width, size.height) * CGFloat(style.padding) / 100).rounded())
    }

    public static func canvasSize(for size: CGSize, style: BackdropStyle) -> CGSize {
        let pad = CGFloat(paddingPixels(for: size, style: style))
        return CGSize(width: size.width + 2 * pad, height: size.height + 2 * pad)
    }

    /// Composites `subject` onto the styled canvas. `backgroundImage` is used
    /// for `.image` fills (aspect-filled); missing images fall back to the gradient.
    public static func compose(subject: CGImage, style: BackdropStyle, backgroundImage: CGImage? = nil) throws -> CGImage {
        let size = CGSize(width: subject.width, height: subject.height)
        let pad = CGFloat(paddingPixels(for: size, style: style))
        let canvas = canvasSize(for: size, style: style)
        let cs = ImageSupport.colorSpace(of: subject)
        guard let ctx = ImageSupport.makeContext(width: Int(canvas.width), height: Int(canvas.height), colorSpace: cs,
                                                 deep: ImageSupport.isDeep(subject), opaque: true) else {
            throw ConversionError.other(L("The image couldn’t be processed."), detail: "background context")
        }
        ctx.interpolationQuality = .high
        let full = CGRect(origin: .zero, size: canvas)
        paintFill(style, in: ctx, rect: full, backgroundImage: backgroundImage)

        let frame = CGRect(x: pad, y: pad, width: size.width, height: size.height)
        let radius = min(size.width, size.height) * CGFloat(style.cornerRadius) / 100
        let cutout = ImageSupport.hasAlpha(subject)
        let shadowBlur = max(4, max(pad * 0.55, min(size.width, size.height) * 0.025))
        let shadowColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.32)
        let shadowOffset = CGSize(width: 0, height: -shadowBlur * 0.35)
        if cutout {
            // Transparent subjects (cut-outs): the shadow follows the subject's shape.
            ctx.saveGState()
            if style.shadow { ctx.setShadow(offset: shadowOffset, blur: shadowBlur, color: shadowColor) }
            ctx.draw(subject, in: frame)
            ctx.restoreGState()
        } else {
            let shape = CGPath(roundedRect: frame, cornerWidth: radius, cornerHeight: radius, transform: nil)
            if style.shadow {
                ctx.saveGState()
                ctx.setShadow(offset: shadowOffset, blur: shadowBlur, color: shadowColor)
                ctx.addPath(shape)
                ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
                ctx.fillPath()
                ctx.restoreGState()
            }
            ctx.saveGState()
            ctx.addPath(shape)
            ctx.clip()
            ctx.draw(subject, in: frame)
            ctx.restoreGState()
        }
        guard let out = ctx.makeImage() else { throw ConversionError.other(L("The image couldn’t be processed."), detail: "background makeImage") }
        return out
    }

    static func paintFill(_ style: BackdropStyle, in ctx: CGContext, rect: CGRect, backgroundImage: CGImage?) {
        switch style.fill {
        case .solid:
            ctx.setFillColor(HexColor.cgColor(style.color1))
            ctx.fill(rect)
        case .image where backgroundImage != nil:
            guard let bg = backgroundImage else { return }
            // Aspect-fill, centred.
            let s = max(rect.width / CGFloat(bg.width), rect.height / CGFloat(bg.height))
            let w = CGFloat(bg.width) * s, h = CGFloat(bg.height) * s
            ctx.draw(bg, in: CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h))
        case .gradient, .image:
            let colors = [HexColor.cgColor(style.color1), HexColor.cgColor(style.color2)] as CFArray
            guard let gradient = CGGradient(colorsSpace: ImageSupport.srgb, colors: colors, locations: [0, 1]) else { return }
            // CSS convention: 0° = towards the top, 90° = towards the right,
            // 135° = towards the bottom-right. The gradient spans the whole rect.
            let rad = style.angle * .pi / 180
            let dx = CGFloat(sin(rad)), dy = CGFloat(cos(rad)) // y up in CG
            let half = (abs(dx) * rect.width + abs(dy) * rect.height) / 2
            let c = CGPoint(x: rect.midX, y: rect.midY)
            ctx.drawLinearGradient(gradient, start: CGPoint(x: c.x - dx * half, y: c.y - dy * half),
                                   end: CGPoint(x: c.x + dx * half, y: c.y + dy * half),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
    }
}

struct AddBackgroundRunner: ToolRunner {
    let id = ToolIDs.addBackground

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let style = BackdropStyle(options: request.options)
        var backgroundImage: CGImage?
        if style.fill == .image {
            guard !style.imagePath.isEmpty else {
                throw ConversionError.other(L("Choose a background image first."), detail: "addBackground: empty imagePath")
            }
            let url = URL(fileURLWithPath: (style.imagePath as NSString).expandingTildeInPath)
            backgroundImage = try ImageSupport.decode(url).image
        }
        return try await PixelToolPipeline(request: request, context: context).run { decoded in
            try BackgroundComposer.compose(subject: decoded.image, style: style, backgroundImage: backgroundImage)
        }
    }
}
