import Foundation
import CoreGraphics

/// Irreversible redaction. Every style destroys the information in each
/// region instead of hiding it:
/// - pixelate: very large blocks (a region is at most a few blocks across),
///   each the average of its pixels plus a little deterministic noise, so
///   neither the original values nor fine detail survive (depixelation
///   attacks need small blocks);
/// - blur: the same coarse averaging, then smooth bilinear reconstruction:
///   it looks like a heavy blur but only the coarse grid's information exists;
/// - solid: an opaque fill.
/// Output files never carry an embedded thumbnail of the original.
public enum Redactor {
    public enum Style: String, Sendable, CaseIterable {
        case blur, pixelate, solid
    }

    /// "x,y,w,h;x,y,w,h" normalised rects, origin top-left.
    public static func parseRegions(_ s: String) -> [CGRect] {
        s.split(separator: ";").compactMap { CropGeometry.parseRect(String($0)) }
            .map { $0.standardized.intersection(CGRect(x: 0, y: 0, width: 1, height: 1)) }
            .filter { !$0.isNull && $0.width > 0 && $0.height > 0 }
    }

    public static func format(_ rects: [CGRect]) -> String {
        rects.map(CropGeometry.format).joined(separator: ";")
    }

    /// Pixel rect covering a normalised region completely (rounded outward).
    static func pixelRect(_ r: CGRect, width: Int, height: Int) -> (x0: Int, y0: Int, x1: Int, y1: Int) {
        let x0 = max(0, Int((r.minX * CGFloat(width)).rounded(.down)))
        let y0 = max(0, Int((r.minY * CGFloat(height)).rounded(.down)))
        let x1 = min(width, Int((r.maxX * CGFloat(width)).rounded(.up)))
        let y1 = min(height, Int((r.maxY * CGFloat(height)).rounded(.up)))
        return (x0, y0, max(x0 + 1, x1), max(y0 + 1, y1))
    }

    /// Block edge in pixels for a region: never fewer than 12 px, and big
    /// enough that the region is at most ~4 blocks across its short side.
    static func blockSize(regionWidth w: Int, regionHeight h: Int, imageWidth: Int, imageHeight: Int) -> Int {
        max(12, Int((Double(min(w, h)) / 4).rounded(.up)), Int((Double(max(w, h)) / 16).rounded(.up)),
            Int((Double(min(imageWidth, imageHeight)) / 64).rounded(.up)))
    }

    /// - Parameter referenceSize: full-resolution size when `image` is a
    ///   downsampled preview, so blocks scale exactly like the saved file's.
    public static func apply(_ image: CGImage, regions: [CGRect], style: Style,
                             fill: CGColor = CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1),
                             referenceSize: CGSize? = nil) throws -> CGImage {
        guard !regions.isEmpty else { return image }
        let w = image.width, h = image.height
        let cs = ImageSupport.colorSpace(of: image)
        let opaque = !ImageSupport.hasAlpha(image)
        guard let ctx = ImageSupport.makeContext(width: w, height: h, colorSpace: cs, deep: false, opaque: opaque),
              let data = ctx.data else {
            throw ConversionError.other(L("The image couldn’t be processed."), detail: "redact context")
        }
        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        let rowBytes = ctx.bytesPerRow
        let px = data.bindMemory(to: UInt8.self, capacity: rowBytes * h)
        // Bitmap rows run top-down in memory, matching the top-left region origin.
        for (index, region) in regions.enumerated() {
            let r = pixelRect(region, width: w, height: h)
            switch style {
            case .solid:
                // Fill in the bitmap's own space; CG colour-matches the fill colour.
                ctx.saveGState()
                ctx.setFillColor(fill.copy(alpha: 1) ?? fill)
                ctx.fill(CGRect(x: r.x0, y: h - r.y1, width: r.x1 - r.x0, height: r.y1 - r.y0))
                ctx.restoreGState()
            case .pixelate, .blur:
                let block: Int
                if let ref = referenceSize, ref.width > 0, ref.height > 0 {
                    let full = pixelRect(region, width: Int(ref.width), height: Int(ref.height))
                    let fullBlock = blockSize(regionWidth: full.x1 - full.x0, regionHeight: full.y1 - full.y0,
                                              imageWidth: Int(ref.width), imageHeight: Int(ref.height))
                    block = max(1, Int((Double(fullBlock) * Double(w) / Double(ref.width)).rounded()))
                } else {
                    block = blockSize(regionWidth: r.x1 - r.x0, regionHeight: r.y1 - r.y0, imageWidth: w, imageHeight: h)
                }
                let grid = averages(px, rowBytes: rowBytes, r, block: block, seed: UInt64(index + 1))
                if style == .pixelate {
                    paintBlocks(px, rowBytes: rowBytes, r, block: block, grid: grid)
                } else {
                    paintSmooth(px, rowBytes: rowBytes, r, block: block, grid: grid, seed: UInt64(index + 1))
                }
            }
        }
        guard let out = ctx.makeImage() else { throw ConversionError.other(L("The image couldn’t be processed."), detail: "redact makeImage") }
        return out
    }

    // MARK: Block averaging

    private struct Grid {
        var cols: Int, rows: Int
        var values: [SIMD4<Float>] // premultiplied RGBA, 0…255
        subscript(c: Int, r: Int) -> SIMD4<Float> { values[r * cols + c] }
    }

    private static func averages(_ px: UnsafeMutablePointer<UInt8>, rowBytes: Int, _ r: (x0: Int, y0: Int, x1: Int, y1: Int),
                                 block: Int, seed: UInt64) -> Grid {
        let cols = max(1, (r.x1 - r.x0 + block - 1) / block), rows = max(1, (r.y1 - r.y0 + block - 1) / block)
        var sums = [SIMD4<Float>](repeating: .zero, count: cols * rows)
        var counts = [Float](repeating: 0, count: cols * rows)
        for y in r.y0..<r.y1 {
            let row = px + y * rowBytes
            let gy = (y - r.y0) / block
            for x in r.x0..<r.x1 {
                let p = row + x * 4
                let g = gy * cols + (x - r.x0) / block
                sums[g] += SIMD4(Float(p[0]), Float(p[1]), Float(p[2]), Float(p[3]))
                counts[g] += 1
            }
        }
        var rng = SplitMix(seed: seed &* 0x9E37_79B9_7F4A_7C15)
        let values = sums.indices.map { i -> SIMD4<Float> in
            var v = sums[i] / max(1, counts[i])
            // ±3 levels of deterministic noise: block values never equal any source pixel by construction of an average alone.
            let n = SIMD4<Float>(rng.unit() * 6 - 3, rng.unit() * 6 - 3, rng.unit() * 6 - 3, 0)
            v = v + n
            v.w = sums[i].w / max(1, counts[i])
            let a = v.w
            return SIMD4(min(a, max(0, v.x)), min(a, max(0, v.y)), min(a, max(0, v.z)), a)
        }
        return Grid(cols: cols, rows: rows, values: values)
    }

    private static func paintBlocks(_ px: UnsafeMutablePointer<UInt8>, rowBytes: Int, _ r: (x0: Int, y0: Int, x1: Int, y1: Int),
                                    block: Int, grid: Grid) {
        for y in r.y0..<r.y1 {
            let row = px + y * rowBytes
            let gy = (y - r.y0) / block
            for x in r.x0..<r.x1 {
                store(grid[(x - r.x0) / block, gy], at: row + x * 4)
            }
        }
    }

    /// Bilinear reconstruction from block centres plus fine noise against banding.
    private static func paintSmooth(_ px: UnsafeMutablePointer<UInt8>, rowBytes: Int, _ r: (x0: Int, y0: Int, x1: Int, y1: Int),
                                    block: Int, grid: Grid, seed: UInt64) {
        var rng = SplitMix(seed: seed &* 0xD1B5_4A32_D192_ED03)
        let b = Float(block)
        for y in r.y0..<r.y1 {
            let row = px + y * rowBytes
            let fy = max(0, min(Float(grid.rows - 1), (Float(y - r.y0) + 0.5) / b - 0.5))
            let y0 = Int(fy), y1 = min(grid.rows - 1, y0 + 1)
            let ty = fy - Float(y0)
            for x in r.x0..<r.x1 {
                let fx = max(0, min(Float(grid.cols - 1), (Float(x - r.x0) + 0.5) / b - 0.5))
                let x0 = Int(fx), x1 = min(grid.cols - 1, x0 + 1)
                let tx = fx - Float(x0)
                let top = grid[x0, y0] * (1 - tx) + grid[x1, y0] * tx
                let bottom = grid[x0, y1] * (1 - tx) + grid[x1, y1] * tx
                var v = top * (1 - ty) + bottom * ty
                let n = rng.unit() * 2 - 1
                v.x += n; v.y += n; v.z += n
                store(v, at: row + x * 4)
            }
        }
    }

    @inline(__always)
    private static func store(_ v: SIMD4<Float>, at p: UnsafeMutablePointer<UInt8>) {
        let a = max(0, min(255, v.w))
        p[0] = UInt8(max(0, min(a, v.x)).rounded())
        p[1] = UInt8(max(0, min(a, v.y)).rounded())
        p[2] = UInt8(max(0, min(a, v.z)).rounded())
        p[3] = UInt8(a.rounded())
    }
}

/// Small deterministic PRNG (SplitMix64) so redactions are reproducible.
struct SplitMix {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
    mutating func unit() -> Float { Float(next() >> 40) / Float(1 << 24) }
}

struct RedactImageRunner: ToolRunner {
    let id = ToolIDs.redactImage

    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let regions = Redactor.parseRegions(request.options.string("regions", default: ""))
        guard !regions.isEmpty else {
            throw ConversionError.other(L("Draw at least one area to redact."), detail: "redact: no regions")
        }
        let style = Redactor.Style(rawValue: request.options.string("style", default: "pixelate")) ?? .pixelate
        let fill = HexColor.cgColor(request.options.string("color", default: "#000000"))
        return try await PixelToolPipeline(request: request, context: context).run { decoded in
            try Redactor.apply(decoded.image, regions: regions, style: style, fill: fill)
        }
    }
}
