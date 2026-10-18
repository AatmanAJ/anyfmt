import Foundation

/// Minimal reader/writer for the WebP RIFF container (Google's "WebP Container
/// Specification"). ffmpeg's libwebp wrapper writes bare bitstreams, so we add
/// what it can't: the ICC profile, EXIF/XMP, and exact per-frame durations.
///
/// Layout: "RIFF" <u32 size> "WEBP", then chunks of <fourcc> <u32 LE size> <payload>
/// padded to an even length. Extended files start with VP8X, then ICCP, then the
/// image (ANIM+ANMF… or ALPH+VP8 / VP8L), then EXIF and XMP.
struct WebPContainer {
    struct Chunk: Equatable {
        var fourCC: String
        var payload: Data
    }

    var chunks: [Chunk]

    // VP8X flag bits.
    static let iccFlag: UInt8 = 0x20
    static let alphaFlag: UInt8 = 0x10
    static let exifFlag: UInt8 = 0x08
    static let xmpFlag: UInt8 = 0x04
    static let animationFlag: UInt8 = 0x02

    init(chunks: [Chunk]) { self.chunks = chunks }

    init?(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 12, String(decoding: bytes[0..<4], as: UTF8.self) == "RIFF",
              String(decoding: bytes[8..<12], as: UTF8.self) == "WEBP" else { return nil }
        var list: [Chunk] = []
        var i = 12
        while i + 8 <= bytes.count {
            let fourCC = String(decoding: bytes[i..<i + 4], as: UTF8.self)
            let size = Int(Self.readLE(bytes, i + 4, 4))
            let start = i + 8
            guard start + size <= bytes.count else { return nil }
            list.append(Chunk(fourCC: fourCC, payload: Data(bytes[start..<start + size])))
            i = start + size + (size & 1)
        }
        guard !list.isEmpty else { return nil }
        chunks = list
    }

    var data: Data {
        var body = Data("WEBP".utf8)
        for c in chunks {
            body.append(Data(c.fourCC.utf8.prefix(4)))
            body.append(Self.le(UInt32(c.payload.count), 4))
            body.append(c.payload)
            if c.payload.count & 1 == 1 { body.append(0) }
        }
        return Data("RIFF".utf8) + Self.le(UInt32(body.count), 4) + body
    }

    var isAnimated: Bool { chunks.contains { $0.fourCC == "ANMF" } }
    var frameCount: Int { isAnimated ? chunks.filter { $0.fourCC == "ANMF" }.count : 1 }

    /// Frame durations in milliseconds (animated files only).
    var frameDurations: [Int] {
        chunks.filter { $0.fourCC == "ANMF" && $0.payload.count >= 16 }.map { Int(Self.readLE([UInt8]($0.payload), 12, 3)) }
    }

    /// Adds an ICC profile, EXIF (raw TIFF structure, no "Exif\0\0" prefix) and XMP,
    /// converting a simple file into the extended format when needed.
    mutating func embed(icc: Data?, exif: Data?, xmp: Data?, canvasWidth: Int, canvasHeight: Int, hasAlpha: Bool) {
        chunks.removeAll { ["ICCP", "EXIF", "XMP "].contains($0.fourCC) }
        var flags: UInt8 = 0
        if let i = chunks.firstIndex(where: { $0.fourCC == "VP8X" }), let f = chunks[i].payload.first {
            flags = f
            chunks.remove(at: i)
        }
        flags &= ~(Self.iccFlag | Self.exifFlag | Self.xmpFlag)
        if hasAlpha { flags |= Self.alphaFlag }
        if isAnimated { flags |= Self.animationFlag }
        if icc != nil { flags |= Self.iccFlag }
        if exif != nil { flags |= Self.exifFlag }
        if xmp != nil { flags |= Self.xmpFlag }
        let needsExtended = flags & (Self.iccFlag | Self.exifFlag | Self.xmpFlag | Self.animationFlag) != 0
            || chunks.contains { $0.fourCC == "ALPH" }
        guard needsExtended else { return }
        var vp8x = Data([flags, 0, 0, 0])
        vp8x.append(Self.le(UInt32(max(1, canvasWidth) - 1), 3))
        vp8x.append(Self.le(UInt32(max(1, canvasHeight) - 1), 3))
        var out = [Chunk(fourCC: "VP8X", payload: vp8x)]
        if let icc { out.append(Chunk(fourCC: "ICCP", payload: icc)) }
        out.append(contentsOf: chunks)
        if let exif { out.append(Chunk(fourCC: "EXIF", payload: exif)) }
        if let xmp { out.append(Chunk(fourCC: "XMP ", payload: xmp)) }
        chunks = out
    }

    /// Rewrites ANMF durations from the source's frame delays.
    ///
    /// The encoder was fed one frame per millisecond, so an ANMF lasting `n` ms
    /// stands for `n` consecutive source frames (libwebp merges identical frames).
    /// The last ANMF takes whatever source time is left.
    mutating func applyTiming(sourceDelays: [Double], loopCount: Int) {
        let anmf = chunks.indices.filter { chunks[$0].fourCC == "ANMF" && chunks[$0].payload.count >= 16 }
        guard !anmf.isEmpty, !sourceDelays.isEmpty else { return }
        var cursor = 0
        for (n, idx) in anmf.enumerated() {
            var payload = [UInt8](chunks[idx].payload)
            let encoded = max(1, Int(Self.readLE(payload, 12, 3)))
            let take = n == anmf.count - 1 ? max(1, sourceDelays.count - cursor) : encoded
            let end = min(sourceDelays.count, cursor + take)
            let seconds = cursor < end ? sourceDelays[cursor..<end].reduce(0, +) : sourceDelays.last ?? 0.1
            cursor = end
            let ms = UInt32(min(0xFF_FFFF, max(1, Int((seconds * 1000).rounded()))))
            payload.replaceSubrange(12..<15, with: [UInt8](Self.le(ms, 3)))
            chunks[idx].payload = Data(payload)
        }
        if let a = chunks.firstIndex(where: { $0.fourCC == "ANIM" }), chunks[a].payload.count >= 6 {
            var p = [UInt8](chunks[a].payload)
            p.replaceSubrange(4..<6, with: [UInt8](Self.le(UInt32(min(65535, max(0, loopCount))), 2)))
            chunks[a].payload = Data(p)
        }
    }

    // MARK: Little-endian helpers

    static func le(_ v: UInt32, _ bytes: Int) -> Data {
        Data((0..<bytes).map { UInt8((v >> (8 * UInt32($0))) & 0xFF) })
    }

    static func readLE(_ b: [UInt8], _ at: Int, _ count: Int) -> UInt32 {
        var v: UInt32 = 0
        for k in 0..<count where at + k < b.count { v |= UInt32(b[at + k]) << (8 * UInt32(k)) }
        return v
    }
}
