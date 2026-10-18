import Foundation
import CoreGraphics

/// Reduces an RGBA image to an indexed palette of at most 256 colours with
/// full per-entry alpha (like pngquant): exact palette when the image already
/// has few colours, otherwise variance-driven median cut in premultiplied
/// space, two k-means refinement passes, then Floyd–Steinberg dithering.
struct PaletteQuantizer {
    struct Color: Equatable {
        var r: UInt8, g: UInt8, b: UInt8, a: UInt8
    }

    struct Result {
        var palette: [Color]
        var indices: [UInt8]
        var width: Int
        var height: Int
        /// True when every pixel kept its exact value.
        var exact: Bool
    }

    let maxColors: Int
    var dither = true

    init(maxColors: Int, dither: Bool = true) {
        self.maxColors = min(256, max(2, maxColors))
        self.dither = dither
    }

    /// `pixels`: unpremultiplied RGBA8, row-major.
    func quantize(pixels: [UInt8], width: Int, height: Int) -> Result {
        if let exact = exactPalette(pixels, width, height) { return exact }
        let bins = histogram(pixels)
        var palette = medianCut(bins)
        palette = refine(palette, bins: bins, passes: 2)
        let indices = map(pixels, width: width, height: height, palette: palette)
        return Result(palette: palette.map(\.color), indices: indices, width: width, height: height, exact: false)
    }

    // MARK: Exact path

    private func exactPalette(_ px: [UInt8], _ w: Int, _ h: Int) -> Result? {
        var lookup: [UInt32: UInt8] = [:]
        var palette: [Color] = []
        var indices = [UInt8](repeating: 0, count: w * h)
        var i = 0, p = 0
        while i < px.count {
            // Fully transparent pixels collapse to one entry.
            let a = px[i + 3]
            let key: UInt32 = a == 0 ? 0 : (UInt32(px[i]) << 24 | UInt32(px[i + 1]) << 16 | UInt32(px[i + 2]) << 8 | UInt32(a))
            if let idx = lookup[key] {
                indices[p] = idx
            } else {
                guard palette.count < maxColors else { return nil }
                let idx = UInt8(palette.count)
                lookup[key] = idx
                palette.append(a == 0 ? Color(r: 0, g: 0, b: 0, a: 0) : Color(r: px[i], g: px[i + 1], b: px[i + 2], a: a))
                indices[p] = idx
            }
            i += 4; p += 1
        }
        return Result(palette: palette, indices: indices, width: w, height: h, exact: true)
    }

    // MARK: Histogram (premultiplied, 5-5-5-4 bits)

    struct Bin {
        var r: Double, g: Double, b: Double, a: Double // premultiplied means
        var count: Double
    }

    private static func key(_ r: Int, _ g: Int, _ b: Int, _ a: Int) -> Int {
        (r >> 3) << 14 | (g >> 3) << 9 | (b >> 3) << 4 | (a >> 4)
    }

    private func histogram(_ px: [UInt8]) -> [Bin] {
        let n = 1 << 19
        var count = [UInt32](repeating: 0, count: n)
        var sr = [UInt64](repeating: 0, count: n), sg = sr, sb = sr, sa = sr
        var i = 0
        while i < px.count {
            let a = Int(px[i + 3])
            let r = Int(px[i]) * a / 255, g = Int(px[i + 1]) * a / 255, b = Int(px[i + 2]) * a / 255
            let k = Self.key(r, g, b, a)
            count[k] &+= 1
            sr[k] &+= UInt64(r); sg[k] &+= UInt64(g); sb[k] &+= UInt64(b); sa[k] &+= UInt64(a)
            i += 4
        }
        var bins: [Bin] = []
        bins.reserveCapacity(4096)
        for k in 0..<n where count[k] > 0 {
            let c = Double(count[k])
            bins.append(Bin(r: Double(sr[k]) / c, g: Double(sg[k]) / c, b: Double(sb[k]) / c, a: Double(sa[k]) / c, count: c))
        }
        return bins
    }

    // MARK: Median cut

    struct Entry {
        var r: Double, g: Double, b: Double, a: Double
        var color: Color {
            // Back to straight alpha.
            let alpha = max(0, min(255, a))
            if alpha < 0.5 { return Color(r: 0, g: 0, b: 0, a: 0) }
            func c(_ v: Double) -> UInt8 { UInt8(max(0, min(255, (v * 255 / alpha).rounded()))) }
            return Color(r: c(r), g: c(g), b: c(b), a: UInt8(alpha.rounded()))
        }
    }

    private struct Box {
        var start: Int, end: Int // half-open range into the bin array
        var sse: Double
        var axis: Int
    }

    private func medianCut(_ input: [Bin]) -> [Entry] {
        var bins = input
        guard bins.count > maxColors else { return bins.map { Entry(r: $0.r, g: $0.g, b: $0.b, a: $0.a) } }
        var boxes = [describe(&bins, 0, bins.count)]
        while boxes.count < maxColors {
            guard let target = boxes.indices.filter({ boxes[$0].end - boxes[$0].start > 1 }).max(by: { boxes[$0].sse < boxes[$1].sse }),
                  boxes[target].sse > 0 else { break }
            let box = boxes[target]
            let axis = box.axis
            bins[box.start..<box.end].sort { value($0, axis) < value($1, axis) }
            // Weighted median split.
            let total = bins[box.start..<box.end].reduce(0) { $0 + $1.count }
            var acc = 0.0, split = box.start + 1
            for i in box.start..<box.end {
                acc += bins[i].count
                if acc >= total / 2 { split = min(max(i + 1, box.start + 1), box.end - 1); break }
            }
            boxes[target] = describe(&bins, box.start, split)
            boxes.append(describe(&bins, split, box.end))
        }
        return boxes.map { box in
            var r = 0.0, g = 0.0, b = 0.0, a = 0.0, c = 0.0
            for i in box.start..<box.end {
                let bin = bins[i]
                r += bin.r * bin.count; g += bin.g * bin.count; b += bin.b * bin.count; a += bin.a * bin.count; c += bin.count
            }
            return Entry(r: r / c, g: g / c, b: b / c, a: a / c)
        }
    }

    private func value(_ b: Bin, _ axis: Int) -> Double {
        switch axis { case 0: b.r; case 1: b.g; case 2: b.b; default: b.a }
    }

    private func describe(_ bins: inout [Bin], _ start: Int, _ end: Int) -> Box {
        var mean = [0.0, 0.0, 0.0, 0.0], c = 0.0
        for i in start..<end {
            let b = bins[i]
            mean[0] += b.r * b.count; mean[1] += b.g * b.count; mean[2] += b.b * b.count; mean[3] += b.a * b.count; c += b.count
        }
        guard c > 0 else { return Box(start: start, end: end, sse: 0, axis: 0) }
        for k in 0..<4 { mean[k] /= c }
        var variance = [0.0, 0.0, 0.0, 0.0]
        for i in start..<end {
            let b = bins[i]
            let d = [b.r - mean[0], b.g - mean[1], b.b - mean[2], b.a - mean[3]]
            for k in 0..<4 { variance[k] += d[k] * d[k] * b.count }
        }
        // Green matters most to the eye; alpha edges matter a lot when present.
        let weighted = [variance[0] * 0.9, variance[1] * 1.2, variance[2] * 0.7, variance[3] * 1.0]
        let axis = weighted.indices.max { weighted[$0] < weighted[$1] } ?? 0
        return Box(start: start, end: end, sse: weighted.reduce(0, +), axis: axis)
    }

    // MARK: Refinement

    private func refine(_ palette: [Entry], bins: [Bin], passes: Int) -> [Entry] {
        var p = palette
        for _ in 0..<passes {
            var acc = [(Double, Double, Double, Double, Double)](repeating: (0, 0, 0, 0, 0), count: p.count)
            for b in bins {
                let i = nearest(b.r, b.g, b.b, b.a, in: p)
                acc[i].0 += b.r * b.count; acc[i].1 += b.g * b.count; acc[i].2 += b.b * b.count; acc[i].3 += b.a * b.count
                acc[i].4 += b.count
            }
            for i in p.indices where acc[i].4 > 0 {
                p[i] = Entry(r: acc[i].0 / acc[i].4, g: acc[i].1 / acc[i].4, b: acc[i].2 / acc[i].4, a: acc[i].3 / acc[i].4)
            }
        }
        return p
    }

    private func nearest(_ r: Double, _ g: Double, _ b: Double, _ a: Double, in p: [Entry]) -> Int {
        var best = 0, bestD = Double.greatestFiniteMagnitude
        for (i, e) in p.enumerated() {
            let dr = r - e.r, dg = g - e.g, db = b - e.b, da = a - e.a
            let d = dr * dr * 0.9 + dg * dg * 1.2 + db * db * 0.7 + da * da
            if d < bestD { bestD = d; best = i }
        }
        return best
    }

    // MARK: Mapping + dithering

    private func map(_ px: [UInt8], width w: Int, height h: Int, palette: [Entry]) -> [UInt8] {
        var indices = [UInt8](repeating: 0, count: w * h)
        var cache = [UInt16](repeating: 0, count: 1 << 19) // index + 1, 0 = unknown
        let colors = palette.map(\.color)
        let strength: Float = dither ? 0.8 : 0
        // Error rows (straight RGBA) with one pixel of padding on each side.
        var cur = [Float](repeating: 0, count: (w + 2) * 4)
        var next = cur
        for y in 0..<h {
            for x in 0..<w {
                let i = (y * w + x) * 4
                let e = (x + 1) * 4
                let a0 = Float(px[i + 3])
                var r = Float(px[i]) + cur[e], g = Float(px[i + 1]) + cur[e + 1], b = Float(px[i + 2]) + cur[e + 2]
                var a = a0 + cur[e + 3]
                r = max(0, min(255, r)); g = max(0, min(255, g)); b = max(0, min(255, b)); a = max(0, min(255, a))
                let ia = Int(a.rounded())
                let pr = Int(r.rounded()) * ia / 255, pg = Int(g.rounded()) * ia / 255, pb = Int(b.rounded()) * ia / 255
                let k = Self.key(pr, pg, pb, ia)
                var idx: Int
                if cache[k] != 0 {
                    idx = Int(cache[k]) - 1
                } else {
                    idx = nearest(Double(pr), Double(pg), Double(pb), Double(ia), in: palette)
                    cache[k] = UInt16(idx + 1)
                }
                indices[y * w + x] = UInt8(idx)
                guard strength > 0, a0 > 0 else { continue }
                let c = colors[idx]
                let er = (r - Float(c.r)) * strength, eg = (g - Float(c.g)) * strength
                let eb = (b - Float(c.b)) * strength, ea = (a - Float(c.a)) * strength
                // Floyd–Steinberg: 7/16 right, 3/16 down-left, 5/16 down, 1/16 down-right.
                for (row, off, wgt) in [(0, 1, Float(7) / 16), (1, -1, Float(3) / 16), (1, 0, Float(5) / 16), (1, 1, Float(1) / 16)] {
                    let j = (x + 1 + off) * 4
                    if row == 0 {
                        cur[j] += er * wgt; cur[j + 1] += eg * wgt; cur[j + 2] += eb * wgt; cur[j + 3] += ea * wgt
                    } else {
                        next[j] += er * wgt; next[j + 1] += eg * wgt; next[j + 2] += eb * wgt; next[j + 3] += ea * wgt
                    }
                }
            }
            swap(&cur, &next)
            for k in next.indices { next[k] = 0 }
        }
        return indices
    }
}

/// Writes indexed (palette) PNGs, packing to 1/2/4 bits when the palette is small.
enum PalettePNGWriter {
    static func write(_ q: PaletteQuantizer.Result, colorSpace: CGColorSpace, dpi: Double?, metadataChunks: [PNGChunks.Chunk]) -> Data? {
        // Transparent entries first so tRNS stays short.
        let order = q.palette.indices.sorted { (q.palette[$0].a < 255 ? 0 : 1, $0) < (q.palette[$1].a < 255 ? 0 : 1, $1) }
        var remap = [UInt8](repeating: 0, count: q.palette.count)
        for (newIndex, old) in order.enumerated() { remap[old] = UInt8(newIndex) }
        let palette = order.map { q.palette[$0] }
        let n = palette.count
        let depth = n <= 2 ? 1 : n <= 4 ? 2 : n <= 16 ? 4 : 8
        let perByte = 8 / depth
        let rowBytes = (q.width + perByte - 1) / perByte
        var raw = Data(capacity: (rowBytes + 1) * q.height)
        var row = [UInt8](repeating: 0, count: rowBytes)
        for y in 0..<q.height {
            for k in row.indices { row[k] = 0 }
            for x in 0..<q.width {
                let v = remap[Int(q.indices[y * q.width + x])]
                let byte = x / perByte, shift = 8 - depth * (x % perByte + 1)
                row[byte] |= v << UInt8(shift)
            }
            raw.append(0) // filter: none (best for palette data)
            raw.append(contentsOf: row)
        }
        guard let idat = PNGChunks.deflate(raw) else { return nil }

        var chunks: [PNGChunks.Chunk] = []
        var ihdr = Data()
        func be32(_ v: Int) -> Data { var x = UInt32(v).bigEndian; return Data(bytes: &x, count: 4) }
        ihdr.append(be32(q.width)); ihdr.append(be32(q.height))
        ihdr.append(contentsOf: [UInt8(depth), 3, 0, 0, 0])
        chunks.append(.init(type: "IHDR", data: ihdr))
        if colorSpace.name == CGColorSpace.sRGB {
            chunks.append(.init(type: "sRGB", data: Data([0])))
        } else if let icc = colorSpace.copyICCData() as Data?, let z = PNGChunks.deflate(icc) {
            chunks.append(.init(type: "iCCP", data: Data("ICC Profile".utf8) + Data([0, 0]) + z))
        }
        var plte = Data(capacity: n * 3)
        for c in palette { plte.append(contentsOf: [c.r, c.g, c.b]) }
        chunks.append(.init(type: "PLTE", data: plte))
        let transparent = palette.prefix { $0.a < 255 }
        if !transparent.isEmpty { chunks.append(.init(type: "tRNS", data: Data(transparent.map(\.a)))) }
        if let dpi, dpi > 0 {
            let ppm = Int((dpi / 0.0254).rounded())
            chunks.append(.init(type: "pHYs", data: be32(ppm) + be32(ppm) + Data([1])))
        }
        chunks += metadataChunks
        chunks.append(.init(type: "IDAT", data: idat))
        chunks.append(.init(type: "IEND", data: Data()))
        return PNGChunks.build(chunks)
    }
}
