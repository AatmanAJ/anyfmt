import Foundation
import CoreGraphics
import ImageIO

/// Collage options (ToolSchemas.collage). `order` (editor only) is a comma
/// list of 1-based input indices.
public struct CollageStyle: Sendable, Hashable {
    public enum Layout: String, Sendable, CaseIterable { case grid, row, column }
    public var layout: Layout
    public var gap: Int
    public var background: String
    public var width: Int

    public init(options o: OptionValues) {
        layout = Layout(rawValue: o.string("layout", default: "grid")) ?? .grid
        gap = min(400, max(0, o.int("gap", default: 16)))
        background = o.string("color1", default: "#FFFFFF")
        width = min(16384, max(256, o.int("width", default: 3000)))
    }
}

/// Layout that never crops: every image keeps its full frame.
/// - row: one row, equal heights; column: one column, equal widths;
/// - grid: "justified" rows (like a photo library). Images stay in order and
///   each row is scaled to fill the width exactly; rows are chosen by dynamic
///   programming so their heights are as even as possible.
public struct CollageLayout: Sendable, Equatable {
    /// Canvas size in pixels.
    public let canvas: CGSize
    /// One frame per input (same order as `aspects`), pixels, origin top-left.
    public let frames: [CGRect]

    public static func make(aspects input: [CGFloat], style: CollageStyle) -> CollageLayout {
        let aspects = input.map { $0.isFinite && $0 > 0 ? $0 : 1 }
        let W = CGFloat(style.width), g = CGFloat(style.gap)
        guard !aspects.isEmpty else { return CollageLayout(canvas: CGSize(width: W, height: W), frames: []) }
        var rows: [[Int]]
        switch style.layout {
        case .row: rows = [Array(aspects.indices)]
        case .column: rows = aspects.indices.map { [$0] }
        case .grid: rows = justifiedRows(aspects, width: W, gap: g)
        }
        var frames = [CGRect](repeating: .zero, count: aspects.count)
        var y = g
        for row in rows {
            let sum = row.reduce(0) { $0 + aspects[$1] }
            let h = max(1, (W - g * CGFloat(row.count + 1)) / sum)
            var x = g
            for (k, i) in row.enumerated() {
                // Last frame absorbs rounding so every row ends exactly at the right gap.
                let w = k == row.count - 1 ? (W - g - x) : aspects[i] * h
                frames[i] = CGRect(x: x.rounded(), y: y.rounded(), width: (x + w).rounded() - x.rounded(), height: (y + h).rounded() - y.rounded())
                x += w + g
            }
            y += h + g
        }
        return CollageLayout(canvas: CGSize(width: W, height: y.rounded()), frames: frames)
    }

    /// Partition into contiguous rows minimising squared deviation from an
    /// ideal row height (≈ √n images per row).
    static func justifiedRows(_ a: [CGFloat], width W: CGFloat, gap g: CGFloat) -> [[Int]] {
        let n = a.count
        guard n > 2 else { return [Array(a.indices)] }
        let perRow = max(1, Int(Double(n).squareRoot().rounded()))
        let sorted = a.sorted()
        let median = sorted[n / 2]
        let ideal = (W - g * CGFloat(perRow + 1)) / (CGFloat(perRow) * median)
        func height(_ i: Int, _ j: Int) -> CGFloat { // row of a[i...j]
            let sum = a[i...j].reduce(0, +)
            return (W - g * CGFloat(j - i + 2)) / sum
        }
        var best = [CGFloat](repeating: .greatestFiniteMagnitude, count: n + 1)
        var from = [Int](repeating: 0, count: n + 1)
        best[0] = 0
        for j in 1...n {
            for i in max(0, j - max(perRow * 2, 3))..<j {
                let h = height(i, j - 1)
                guard h > 0 else { continue }
                let d = (h - ideal) / ideal
                let cost = best[i] + d * d
                if cost < best[j] { best[j] = cost; from[j] = i }
            }
        }
        var rows: [[Int]] = []
        var j = n
        while j > 0 { let i = from[j]; rows.insert(Array(i..<j), at: 0); j = i }
        return rows
    }
}

/// Tool 9: Collage (combine ≥ 2).
struct CollageRunner: ToolRunner {
    let id = ToolIDs.collage

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let inputs = OrderOption.apply(request.options.string("order", default: ""), to: request.inputs)
        guard inputs.count >= 2 else { throw ConversionError.other(L("A collage needs at least two images."), detail: "collage inputs \(inputs.count)") }
        let style = CollageStyle(options: request.options)
        let sizes = try inputs.map { url -> CGSize in
            guard let s = ImageSupport.pixelSize(of: url) else { throw ConversionError.unreadable(url, detail: "no pixel size") }
            return s
        }
        let layout = CollageLayout.make(aspects: sizes.map { $0.width / max(1, $0.height) }, style: style)
        let anyWide = inputs.contains { url in
            guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let img = CGImageSourceCreateImageAtIndex(src, 0, nil), let cs = img.colorSpace else { return false }
            return cs.isWideGamutRGB
        }
        let cs = anyWide ? ImageSupport.displayP3 : ImageSupport.srgb
        guard let ctx = ImageSupport.makeContext(width: Int(layout.canvas.width), height: Int(layout.canvas.height),
                                                 colorSpace: cs, deep: false, opaque: true) else {
            throw ConversionError.other(L("The collage is too large to create."), detail: "collage context \(layout.canvas)")
        }
        ctx.interpolationQuality = .high
        ctx.setFillColor(HexColor.cgColor(style.background, fallback: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)))
        ctx.fill(CGRect(origin: .zero, size: layout.canvas))
        let H = layout.canvas.height
        for (i, url) in inputs.enumerated() {
            try Task.checkCancellation()
            let f = layout.frames[i]
            // Decode at (about) the drawn size: fast and memory-friendly for big batches.
            let maxEdge = Int(max(f.width, f.height).rounded(.up))
            guard let img = ImageSupport.thumbnail(url, maxPixelSize: maxEdge) else { throw ConversionError.unreadable(url, detail: "thumbnail") }
            ctx.draw(img, in: CGRect(x: f.minX, y: H - f.maxY, width: f.width, height: f.height))
            context.progress(0.1 + 0.7 * Double(i + 1) / Double(inputs.count))
        }
        guard let image = ctx.makeImage() else { throw ConversionError.other(L("The image couldn’t be processed."), detail: "collage makeImage") }
        let first = Formats.detect(inputs[0])
        let format: FormatID = [Formats.jpg, Formats.heic, Formats.png, Formats.tiff].contains(first ?? "") ? (first ?? Formats.png) : Formats.png
        let out = ToolOutput(request: request)
        let scratch = out.scratch
        defer { try? FileManager.default.removeItem(at: scratch) }
        let props: [String: Any] = request.metadata == .stripAll ? [:] : [kCGImagePropertyOrientation as String: 1]
        let data = try await ImageEncoder(context: context, scratch: scratch).encode(image, as: format, quality: 0.9, properties: props)
        let url = try out.write(data, ext: Formats.extension(for: format))
        context.progress(1)
        return ConversionOutput(url)
    }
}

/// "order" options: comma-separated 1-based input indices. Unknown or
/// repeated indices are ignored; an empty or unusable value keeps drag order.
public enum OrderOption {
    public static func apply<T>(_ value: String, to items: [T]) -> [T] {
        var seen = Set<Int>()
        let picked = value.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 >= 1 && $0 <= items.count && seen.insert($0).inserted }
        return picked.isEmpty ? items : picked.map { items[$0 - 1] }
    }

    /// Formats 0-based positions as the 1-based option value.
    public static func format(_ indices: [Int]) -> String { indices.map { String($0 + 1) }.joined(separator: ",") }
}
