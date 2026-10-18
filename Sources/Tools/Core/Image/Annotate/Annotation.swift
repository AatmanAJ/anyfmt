import Foundation
import CoreGraphics
import CoreText

/// One mark on an image. Coordinates are normalised (0…1, origin top-left)
/// so the same JSON renders identically at preview and full resolution.
/// Stroke width and font size are fractions of the image's shorter side.
///
/// JSON (options key "annotations" is an array of these):
/// `{"kind":"arrow","points":[[0.1,0.2],[0.6,0.5]],"color":"#FF3B30","width":0.008}`
/// - arrow, line: points = [start, end]
/// - box, ellipse, highlight: points = [corner, opposite corner]
/// - text: points = [top-left anchor], text, fontSize
/// - freehand: points = the stroke path
public struct Annotation: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case arrow, line, box, ellipse, text, highlight, freehand
    }

    public var id: UUID
    public var kind: Kind
    public var points: [CGPoint]
    public var color: String
    public var width: Double
    public var text: String?
    public var fontSize: Double?

    public init(id: UUID = UUID(), kind: Kind, points: [CGPoint], color: String = "#FF3B30",
                width: Double = 0.008, text: String? = nil, fontSize: Double? = nil) {
        self.id = id
        self.kind = kind
        self.points = points
        self.color = color
        self.width = width
        self.text = text
        self.fontSize = fontSize
    }

    enum CodingKeys: String, CodingKey { case id, kind, points, color, width, text, fontSize }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decode(Kind.self, forKey: .kind)
        let raw = try c.decodeIfPresent([[Double]].self, forKey: .points) ?? []
        points = raw.compactMap { $0.count >= 2 ? CGPoint(x: $0[0], y: $0[1]) : nil }
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#FF3B30"
        width = try c.decodeIfPresent(Double.self, forKey: .width) ?? 0.008
        text = try c.decodeIfPresent(String.self, forKey: .text)
        fontSize = try c.decodeIfPresent(Double.self, forKey: .fontSize)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(points.map { [Self.round($0.x), Self.round($0.y)] }, forKey: .points)
        try c.encode(color, forKey: .color)
        try c.encode(Self.round(width), forKey: .width)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(fontSize.map { Self.round($0) }, forKey: .fontSize)
    }

    private static func round(_ v: CGFloat) -> Double { (Double(v) * 100_000).rounded() / 100_000 }
    private static func round(_ v: Double) -> Double { (v * 100_000).rounded() / 100_000 }

    /// Decodes the options value; malformed JSON yields no annotations.
    public static func decodeList(_ json: String) -> [Annotation] {
        guard let data = json.data(using: .utf8), !json.isEmpty else { return [] }
        return (try? JSONDecoder().decode([Annotation].self, from: data)) ?? []
    }

    public static func encodeList(_ list: [Annotation]) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let data = try? enc.encode(list) else { return "[]" }
        return String(decoding: data, as: UTF8.self)
    }

    public static let defaultFontSize = 0.05
}

/// Draws annotations with Core Graphics. Used at full resolution by the
/// runner and, through SwiftUI's `Canvas`, by the editor's live overlay.
public enum AnnotationRenderer {
    /// Draws into `ctx`, whose user space must be `size` points with the
    /// origin at the top-left (y down).
    public static func draw(_ list: [Annotation], in ctx: CGContext, size: CGSize) {
        for a in list { draw(a, in: ctx, size: size) }
    }

    public static func draw(_ a: Annotation, in ctx: CGContext, size: CGSize) {
        let unit = min(size.width, size.height)
        let pts = a.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        let lineWidth = max(1, CGFloat(a.width) * unit)
        let color = HexColor.cgColor(a.color)
        ctx.saveGState()
        defer { ctx.restoreGState() }
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        ctx.setLineWidth(lineWidth)
        ctx.setStrokeColor(color)
        ctx.setFillColor(color)
        let shadow = { ctx.setShadow(offset: CGSize(width: 0, height: lineWidth * 0.35), blur: lineWidth * 1.2,
                                     color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.35)) }
        switch a.kind {
        case .arrow, .line:
            guard pts.count >= 2 else { return }
            shadow()
            // One transparency layer so the shadow (and any translucency) applies to shaft + head as a whole.
            ctx.beginTransparencyLayer(auxiliaryInfo: nil)
            let parts = arrowParts(from: pts[0], to: pts[pts.count - 1], lineWidth: lineWidth, head: a.kind == .arrow)
            ctx.addPath(parts.shaft)
            ctx.strokePath()
            if let head = parts.head {
                ctx.addPath(head)
                ctx.fillPath()
                ctx.setLineWidth(lineWidth * 0.5)
                ctx.addPath(head)
                ctx.strokePath()
            }
            ctx.endTransparencyLayer()
        case .box:
            guard let r = rect(pts) else { return }
            shadow()
            let radius = min(lineWidth * 1.5, min(r.width, r.height) / 2)
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
            ctx.strokePath()
        case .ellipse:
            guard let r = rect(pts) else { return }
            shadow()
            ctx.strokeEllipse(in: r)
        case .highlight:
            guard let r = rect(pts) else { return }
            // Multiply keeps text under the marker crisp; a light normal-blend
            // tint on top keeps the mark visible on dark backgrounds too.
            ctx.setBlendMode(.multiply)
            ctx.setFillColor(color.copy(alpha: min(color.alpha, 0.5)) ?? color)
            ctx.fill(r)
            ctx.setBlendMode(.normal)
            ctx.setFillColor(color.copy(alpha: min(color.alpha, 0.14)) ?? color)
            ctx.fill(r)
        case .freehand:
            guard pts.count >= 2 else {
                if let p = pts.first { ctx.fillEllipse(in: CGRect(x: p.x - lineWidth / 2, y: p.y - lineWidth / 2, width: lineWidth, height: lineWidth)) }
                return
            }
            shadow()
            ctx.addPath(smoothPath(pts))
            ctx.strokePath()
        case .text:
            guard let p = pts.first, let text = a.text, !text.isEmpty else { return }
            drawText(text, at: p, fontSize: CGFloat(a.fontSize ?? Annotation.defaultFontSize) * unit, color: color, in: ctx)
        }
    }

    /// Rendered bounds (normalised), for selection and hit testing.
    public static func bounds(of a: Annotation, imageSize size: CGSize) -> CGRect {
        let unit = min(size.width, size.height)
        let pts = a.points.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
        var r: CGRect
        switch a.kind {
        case .text:
            guard let p = pts.first else { return .null }
            let s = textSize(a.text ?? "", fontSize: CGFloat(a.fontSize ?? Annotation.defaultFontSize) * unit)
            r = CGRect(origin: p, size: s)
        default:
            guard let first = pts.first else { return .null }
            r = pts.dropFirst().reduce(CGRect(origin: first, size: .zero)) { $0.union(CGRect(origin: $1, size: .zero)) }
            let pad = CGFloat(a.width) * unit * (a.kind == .arrow ? 2.5 : 0.75)
            r = r.insetBy(dx: -pad, dy: -pad)
        }
        return CGRect(x: r.minX / size.width, y: r.minY / size.height, width: r.width / size.width, height: r.height / size.height)
    }

    /// Topmost annotation under a normalised point.
    public static func hitTest(_ list: [Annotation], at p: CGPoint, imageSize: CGSize, tolerance: CGFloat = 0.01) -> Annotation? {
        list.last { bounds(of: $0, imageSize: imageSize).insetBy(dx: -tolerance, dy: -tolerance).contains(p) }
    }

    /// Composites annotations over `image` at full resolution.
    public static func render(_ list: [Annotation], over image: CGImage) throws -> CGImage {
        let w = image.width, h = image.height
        guard let ctx = ImageSupport.makeContext(width: w, height: h, colorSpace: ImageSupport.colorSpace(of: image),
                                                 deep: ImageSupport.isDeep(image), opaque: !ImageSupport.hasAlpha(image)) else {
            throw ConversionError.other(L("The image couldn’t be processed."), detail: "annotate context")
        }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        draw(list, in: ctx, size: CGSize(width: w, height: h))
        guard let out = ctx.makeImage() else { throw ConversionError.other(L("The image couldn’t be processed."), detail: "annotate makeImage") }
        return out
    }

    // MARK: Geometry

    private static func rect(_ pts: [CGPoint]) -> CGRect? {
        guard pts.count >= 2 else { return nil }
        let r = CGRect(x: min(pts[0].x, pts[1].x), y: min(pts[0].y, pts[1].y),
                       width: abs(pts[1].x - pts[0].x), height: abs(pts[1].y - pts[0].y))
        return r.width > 0.5 || r.height > 0.5 ? r : nil
    }

    /// Shaft (stroke) and head (fill) of an arrow. The shaft stops inside the
    /// head so the tip stays sharp.
    static func arrowParts(from a: CGPoint, to b: CGPoint, lineWidth w: CGFloat, head: Bool) -> (shaft: CGPath, head: CGPath?) {
        let dx = b.x - a.x, dy = b.y - a.y
        let len = max(0.001, (dx * dx + dy * dy).squareRoot())
        let ux = dx / len, uy = dy / len
        let nx = -uy, ny = ux
        let headLength = head ? min(len * 0.6, max(w * 4.2, 10)) : 0
        let headHalf = headLength * 0.62
        let shaft = CGMutablePath()
        shaft.move(to: a)
        shaft.addLine(to: head ? CGPoint(x: b.x - ux * headLength * 0.85, y: b.y - uy * headLength * 0.85) : b)
        guard head else { return (shaft, nil) }
        let base = CGPoint(x: b.x - ux * headLength, y: b.y - uy * headLength)
        let tri = CGMutablePath()
        tri.move(to: b)
        tri.addLine(to: CGPoint(x: base.x + nx * headHalf, y: base.y + ny * headHalf))
        tri.addLine(to: CGPoint(x: base.x - nx * headHalf, y: base.y - ny * headHalf))
        tri.closeSubpath()
        return (shaft, tri)
    }

    /// Quadratic smoothing through segment midpoints.
    static func smoothPath(_ pts: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        guard let first = pts.first else { return path }
        path.move(to: first)
        if pts.count == 2 { path.addLine(to: pts[1]); return path }
        for i in 1..<(pts.count - 1) {
            let mid = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2)
            path.addQuadCurve(to: mid, control: pts[i])
        }
        if let last = pts.last { path.addLine(to: last) }
        return path
    }

    // MARK: Text

    private static func font(_ size: CGFloat) -> CTFont {
        let base = CTFontCreateUIFontForLanguage(.system, max(4, size), nil) ?? CTFontCreateWithName("Helvetica" as CFString, max(4, size), nil)
        return CTFontCreateCopyWithSymbolicTraits(base, max(4, size), nil, .traitBold, .traitBold) ?? base
    }

    private static func lines(_ text: String, fontSize: CGFloat, color: CGColor?) -> [CTLine] {
        let f = font(fontSize)
        return text.components(separatedBy: "\n").map { line in
            var attrs: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): f]
            if let color { attrs[NSAttributedString.Key(kCTForegroundColorAttributeName as String)] = color }
            return CTLineCreateWithAttributedString(NSAttributedString(string: line.isEmpty ? " " : line, attributes: attrs))
        }
    }

    static func textSize(_ text: String, fontSize: CGFloat) -> CGSize {
        let ls = lines(text, fontSize: fontSize, color: nil)
        let lineHeight = fontSize * 1.22
        let width = ls.map { CGFloat(CTLineGetTypographicBounds($0, nil, nil, nil)) }.max() ?? 0
        return CGSize(width: width + fontSize * 0.1, height: lineHeight * CGFloat(max(1, ls.count)))
    }

    private static func drawText(_ text: String, at origin: CGPoint, fontSize: CGFloat, color: CGColor, in ctx: CGContext) {
        let ls = lines(text, fontSize: fontSize, color: color)
        let lineHeight = fontSize * 1.22
        let f = font(fontSize)
        let ascent = CTFontGetAscent(f)
        ctx.saveGState()
        // y-down user space: flip glyphs back upright.
        ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        // A soft halo keeps text legible on any background.
        let luminance = (color.components ?? [0, 0, 0]).prefix(3).enumerated().reduce(0.0) { acc, e in
            acc + Double(e.element) * [0.2126, 0.7152, 0.0722][e.offset]
        }
        let halo = luminance > 0.6 ? CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.55) : CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.7)
        ctx.setShadow(offset: .zero, blur: fontSize * 0.18, color: halo)
        for (i, line) in ls.enumerated() {
            ctx.textPosition = CGPoint(x: origin.x, y: origin.y + ascent + CGFloat(i) * lineHeight)
            CTLineDraw(line, ctx)
        }
        ctx.restoreGState()
    }
}

struct AnnotateImageRunner: ToolRunner {
    let id = ToolIDs.annotateImage

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let list = Annotation.decodeList(request.options.string("annotations", default: "[]"))
        return try await PixelToolPipeline(request: request, context: context).run { decoded in
            list.isEmpty ? decoded.image : try AnnotationRenderer.render(list, over: decoded.image)
        }
    }
}
