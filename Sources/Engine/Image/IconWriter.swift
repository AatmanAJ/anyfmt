import Foundation
import ImageIO

/// Multi-size icon files. The source is centred on a transparent square canvas
/// first, then resampled to every standard size (largest capped by `maxDimension`).
enum IconWriter {
    /// Windows icon sizes. 256 is the format's maximum.
    static let icoSizes = [16, 24, 32, 48, 64, 128, 256]

    /// macOS icon element types that hold PNG data, as (type, pixel size).
    /// `ic11`…`ic14` and `ic10` are the @2x variants; `icp4`…`icp6` the small 1x ones.
    /// ImageIO's own ICNS writer silently drops 64 and 1024, so we write the container ourselves.
    static let icnsElements: [(type: String, size: Int)] = [
        ("icp4", 16), ("ic11", 32), ("icp5", 32), ("ic12", 64), ("icp6", 64),
        ("ic07", 128), ("ic13", 256), ("ic08", 256), ("ic14", 512), ("ic09", 512), ("ic10", 1024),
    ]

    static func sizes(_ all: [Int], cap: Int) -> [Int] {
        let capped = cap > 0 ? all.filter { $0 <= cap } : all
        return capped.isEmpty ? [all[0]] : capped
    }

    /// Square, sRGB, alpha-preserving master for icon resampling.
    static func master(_ input: ImageInput) throws -> CGImage {
        // Decode no larger than the biggest icon we can need (1024), oriented.
        let decoded = try ImageOps.decode(input, maxPixelSize: 1024)
        let srgb = ImageOps.prepare(decoded, flattenOnto: nil, colorSpace: ImageOps.sRGB, maxBits: 8)
        guard let square = ImageOps.paddedToSquare(srgb) else {
            throw ConversionError.engineFailed("ImageIO", status: 0, detail: "could not pad icon canvas")
        }
        return square
    }

    /// ImageIO's ICO writer caps files at 6 images and rejects 24 px, so we write
    /// the container ourselves: 32-bit BGRA DIBs with an AND mask below 256 px (what
    /// every Windows version reads) and a PNG for 256 px (Vista and later).
    static func writeICO(_ input: ImageInput, to url: URL, maxDimension: Int) throws {
        let square = try master(input)
        var entries: [(size: Int, data: Data)] = []
        for s in sizes(icoSizes, cap: maxDimension) {
            guard let img = ImageOps.resized(square, width: s, height: s) else { continue }
            let data = s >= 256 ? ImageWriter.pngData(img) : dib(img)
            guard let data else { throw ConversionError.engineFailed("ImageIO", status: 0, detail: "could not encode \(s)px icon") }
            entries.append((s, data))
        }
        try icoContainer(entries).write(to: url, options: .withoutOverwriting)
    }

    /// ICONDIR + ICONDIRENTRY table + image data, all little-endian.
    static func icoContainer(_ entries: [(size: Int, data: Data)]) -> Data {
        var out = Data()
        out.append(le16(0)); out.append(le16(1)); out.append(le16(UInt16(entries.count)))
        var offset = 6 + 16 * entries.count
        for e in entries {
            let dim = UInt8(e.size >= 256 ? 0 : e.size) // 0 means 256
            out.append(contentsOf: [dim, dim, 0, 0])
            out.append(le16(1)); out.append(le16(32))
            out.append(le32(UInt32(e.data.count))); out.append(le32(UInt32(offset)))
            offset += e.data.count
        }
        for e in entries { out.append(e.data) }
        return out
    }

    /// BITMAPINFOHEADER + bottom-up straight-alpha BGRA rows + 1-bit AND mask
    /// (set where fully transparent, for renderers that ignore alpha).
    static func dib(_ image: CGImage) -> Data? {
        let w = image.width, h = image.height
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        let drawn: Bool = rgba.withUnsafeMutableBytes { buf in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: ImageOps.sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        guard drawn else { return nil }
        let maskStride = ((w + 31) / 32) * 4
        var out = Data()
        out.append(le32(40)); out.append(le32(UInt32(w))); out.append(le32(UInt32(h * 2)))
        out.append(le16(1)); out.append(le16(32)); out.append(le32(0))
        out.append(le32(UInt32(w * h * 4 + maskStride * h)))
        out.append(le32(0)); out.append(le32(0)); out.append(le32(0)); out.append(le32(0))
        var mask = [UInt8](repeating: 0, count: maskStride * h)
        // Bitmap memory row 0 is the top; DIB rows run bottom-up.
        for row in 0..<h {
            let src = (h - 1 - row) * w * 4
            for x in 0..<w {
                let i = src + x * 4
                let a = Int(rgba[i + 3])
                func straight(_ c: UInt8) -> UInt8 { a == 0 ? 0 : UInt8(min(255, (Int(c) * 255 + a / 2) / a)) }
                out.append(contentsOf: [straight(rgba[i + 2]), straight(rgba[i + 1]), straight(rgba[i]), UInt8(a)])
                if a == 0 { mask[row * maskStride + x / 8] |= UInt8(0x80 >> (x % 8)) }
            }
        }
        out.append(contentsOf: mask)
        return out
    }

    private static func le16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
    private static func le32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }

    static func writeICNS(_ input: ImageInput, to url: URL, maxDimension: Int) throws {
        let square = try master(input)
        let wanted = Set(sizes(icnsElements.map(\.size), cap: maxDimension))
        var pngBySize: [Int: Data] = [:]
        for s in wanted.sorted(by: >) {
            guard let img = ImageOps.resized(square, width: s, height: s), let png = ImageWriter.pngData(img) else {
                throw ConversionError.engineFailed("ImageIO", status: 0, detail: "could not encode \(s)px icon")
            }
            pngBySize[s] = png
        }
        let elements = icnsElements.compactMap { e in pngBySize[e.size].map { (e.type, $0) } }
        try icnsContainer(elements).write(to: url, options: .withoutOverwriting)
    }

    /// `icns` container: big-endian (OSType, length incl. 8-byte header) chunks,
    /// led by a table of contents, as written by Apple's iconutil.
    static func icnsContainer(_ elements: [(String, Data)]) -> Data {
        func chunk(_ type: String, _ payload: Data) -> Data {
            var d = Data(type.utf8.prefix(4))
            d.append(bigEndian(UInt32(payload.count + 8)))
            d.append(payload)
            return d
        }
        var toc = Data()
        var body = Data()
        for (type, payload) in elements {
            toc.append(Data(type.utf8.prefix(4)))
            toc.append(bigEndian(UInt32(payload.count + 8)))
            body.append(chunk(type, payload))
        }
        let content = chunk("TOC ", toc) + body
        var out = Data("icns".utf8)
        out.append(bigEndian(UInt32(content.count + 8)))
        out.append(content)
        return out
    }

    private static func bigEndian(_ v: UInt32) -> Data { withUnsafeBytes(of: v.bigEndian) { Data($0) } }
}
