import Foundation
import zlib

// Minimal, byte-exact readers/writers for the container layers of PNG, WebP
// and JPEG. Used to edit or strip metadata without touching compressed pixel
// data, and to emit palette PNGs from the quantiser.

// MARK: - PNG

enum PNGChunks {
    static let signature: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

    struct Chunk: Equatable {
        var type: String
        var data: Data
    }

    /// Chunks that hold metadata rather than pixels or colour information.
    static let metadataTypes: Set<String> = ["tEXt", "zTXt", "iTXt", "eXIf", "tIME"]

    static func parse(_ data: Data) -> [Chunk]? {
        let bytes = [UInt8](data)
        guard bytes.count >= 8, Array(bytes[0..<8]) == signature else { return nil }
        var chunks: [Chunk] = []
        var i = 8
        while i + 8 <= bytes.count {
            let length = Int(UInt32(bytes[i]) << 24 | UInt32(bytes[i + 1]) << 16 | UInt32(bytes[i + 2]) << 8 | UInt32(bytes[i + 3]))
            guard let type = String(bytes: bytes[(i + 4)..<(i + 8)], encoding: .ascii), i + 12 + length <= bytes.count else { return nil }
            chunks.append(Chunk(type: type, data: Data(bytes[(i + 8)..<(i + 8 + length)])))
            i += 12 + length
            if type == "IEND" { break }
        }
        guard chunks.first?.type == "IHDR", chunks.last?.type == "IEND" else { return nil }
        return chunks
    }

    static func build(_ chunks: [Chunk]) -> Data {
        var out = Data(signature)
        for c in chunks { append(c, to: &out) }
        return out
    }

    static func append(_ chunk: Chunk, to out: inout Data) {
        var len = UInt32(chunk.data.count).bigEndian
        out.append(Data(bytes: &len, count: 4))
        let typeBytes = Data(chunk.type.utf8)
        out.append(typeBytes)
        out.append(chunk.data)
        var crc = UInt32(crc32(0, nil, 0))
        typeBytes.withUnsafeBytes { crc = UInt32(crc32(uLong(crc), $0.bindMemory(to: Bytef.self).baseAddress, uInt($0.count))) }
        chunk.data.withUnsafeBytes { crc = UInt32(crc32(uLong(crc), $0.bindMemory(to: Bytef.self).baseAddress, uInt($0.count))) }
        var be = crc.bigEndian
        out.append(Data(bytes: &be, count: 4))
    }

    /// zlib stream (RFC 1950) at `level`.
    static func deflate(_ data: Data, level: Int32 = 9) -> Data? {
        var destLen = compressBound(uLong(data.count))
        var dest = Data(count: Int(destLen))
        let rc: Int32 = dest.withUnsafeMutableBytes { d in
            data.withUnsafeBytes { s in
                compress2(d.bindMemory(to: Bytef.self).baseAddress, &destLen,
                          s.bindMemory(to: Bytef.self).baseAddress, uLong(data.count), level)
            }
        }
        guard rc == Z_OK else { return nil }
        dest.count = Int(destLen)
        return dest
    }

    /// Removes metadata chunks. Returns nil if `data` isn't a PNG.
    static func stripped(_ data: Data) -> Data? {
        guard let chunks = parse(data) else { return nil }
        return build(chunks.filter { !metadataTypes.contains($0.type) })
    }
}

// MARK: - WebP (RIFF)

enum WebPChunks {
    struct Chunk {
        var fourcc: String
        var payload: Data
    }

    /// VP8X feature flags.
    static let iccFlag: UInt8 = 0x20, alphaFlag: UInt8 = 0x10, exifFlag: UInt8 = 0x08, xmpFlag: UInt8 = 0x04

    static func parse(_ data: Data) -> [Chunk]? {
        let b = [UInt8](data)
        guard b.count >= 12, String(bytes: b[0..<4], encoding: .ascii) == "RIFF",
              String(bytes: b[8..<12], encoding: .ascii) == "WEBP" else { return nil }
        var chunks: [Chunk] = []
        var i = 12
        while i + 8 <= b.count {
            guard let fourcc = String(bytes: b[i..<(i + 4)], encoding: .ascii) else { return nil }
            let size = Int(UInt32(b[i + 4]) | UInt32(b[i + 5]) << 8 | UInt32(b[i + 6]) << 16 | UInt32(b[i + 7]) << 24)
            guard i + 8 + size <= b.count else { return nil }
            chunks.append(Chunk(fourcc: fourcc, payload: Data(b[(i + 8)..<(i + 8 + size)])))
            i += 8 + size + (size & 1)
        }
        return chunks.isEmpty ? nil : chunks
    }

    static func build(_ chunks: [Chunk]) -> Data {
        func le32(_ v: Int) -> Data { var x = UInt32(v).littleEndian; return Data(bytes: &x, count: 4) }
        var body = Data()
        for c in chunks {
            body.append(Data(c.fourcc.utf8))
            body.append(le32(c.payload.count))
            body.append(c.payload)
            if c.payload.count & 1 == 1 { body.append(0) }
        }
        return Data("RIFF".utf8) + le32(body.count + 4) + Data("WEBP".utf8) + body
    }

    /// Removes EXIF and XMP chunks and clears their VP8X flags. ICC is kept.
    static func stripped(_ data: Data) -> Data? {
        guard var chunks = parse(data) else { return nil }
        chunks.removeAll { $0.fourcc == "EXIF" || $0.fourcc == "XMP " }
        if let i = chunks.firstIndex(where: { $0.fourcc == "VP8X" }), !chunks[i].payload.isEmpty {
            chunks[i].payload[chunks[i].payload.startIndex] &= ~(exifFlag | xmpFlag)
        }
        return build(chunks)
    }

    /// Replaces the EXIF and XMP chunks (nil removes), adding a VP8X header
    /// to simple files when needed. Image data is untouched.
    static func replacingMetadata(_ data: Data, exif: Data?, xmp: Data?, width: Int, height: Int, hasAlpha: Bool) -> Data? {
        guard var chunks = parse(data) else { return nil }
        chunks.removeAll { $0.fourcc == "EXIF" || $0.fourcc == "XMP " }
        if !chunks.contains(where: { $0.fourcc == "VP8X" }) {
            guard exif != nil || xmp != nil else { return build(chunks) }
            var p = Data(count: 10)
            p[0] = hasAlpha ? alphaFlag : 0
            let w = max(0, width - 1), h = max(0, height - 1)
            p[4] = UInt8(w & 0xFF); p[5] = UInt8((w >> 8) & 0xFF); p[6] = UInt8((w >> 16) & 0xFF)
            p[7] = UInt8(h & 0xFF); p[8] = UInt8((h >> 8) & 0xFF); p[9] = UInt8((h >> 16) & 0xFF)
            chunks.insert(Chunk(fourcc: "VP8X", payload: p), at: 0)
        }
        if let i = chunks.firstIndex(where: { $0.fourcc == "VP8X" }), !chunks[i].payload.isEmpty {
            let s = chunks[i].payload.startIndex
            var flags = chunks[i].payload[s] & ~(exifFlag | xmpFlag)
            if exif != nil { flags |= exifFlag }
            if xmp != nil { flags |= xmpFlag }
            chunks[i].payload[s] = flags
        }
        // Spec order: metadata chunks come after the image data.
        if let exif { chunks.append(Chunk(fourcc: "EXIF", payload: exif)) }
        if let xmp { chunks.append(Chunk(fourcc: "XMP ", payload: xmp)) }
        return build(chunks)
    }
}

// MARK: - JPEG

enum JPEGSegments {
    struct Segment {
        /// Marker byte (the xx in 0xFFxx).
        let marker: UInt8
        /// Full segment bytes including 0xFF, marker and length.
        let bytes: Data
        var payload: Data { bytes.count > 4 ? bytes.subdata(in: 4..<bytes.count) : Data() }

        func payloadHasPrefix(_ prefix: String) -> Bool {
            let p = Data(prefix.utf8)
            return payload.count >= p.count && payload.prefix(p.count) == p
        }

        var isExif: Bool { marker == 0xE1 && payloadHasPrefix("Exif\0") }
        var isXMP: Bool { marker == 0xE1 && (payloadHasPrefix("http://ns.adobe.com/xap/1.0/\0") || payloadHasPrefix("http://ns.adobe.com/xmp/extension/\0")) }
        var isIPTC: Bool { marker == 0xED }
        var isICC: Bool { marker == 0xE2 && payloadHasPrefix("ICC_PROFILE\0") }
        var isMPF: Bool { marker == 0xE2 && payloadHasPrefix("MPF\0") }
        var isJFIF: Bool { marker == 0xE0 }
        var isAdobe: Bool { marker == 0xEE }
        var isComment: Bool { marker == 0xFE }
        var isAppOrComment: Bool { (0xE0...0xEF).contains(marker) || marker == 0xFE }
    }

    struct File {
        /// Segments between SOI and the first SOS.
        var header: [Segment]
        /// From the first SOS up to and including the primary image's EOI.
        var scan: Data
        /// Bytes after the primary EOI (MPF secondary images, gain maps, trailers).
        var trailer: Data
    }

    static func parse(_ data: Data) -> File? {
        let b = [UInt8](data)
        guard b.count > 4, b[0] == 0xFF, b[1] == 0xD8 else { return nil }
        var header: [Segment] = []
        var i = 2
        while i + 4 <= b.count {
            guard b[i] == 0xFF else { return nil }
            var m = i + 1
            while m < b.count && b[m] == 0xFF { m += 1 } // fill bytes
            guard m < b.count else { return nil }
            let marker = b[m]
            if marker == 0xDA { // SOS: the rest is entropy-coded data + further segments
                let scanStart = i
                guard let end = endOfImage(b, from: m + 1) else { return nil }
                return File(header: header, scan: Data(b[scanStart..<end]), trailer: Data(b[end...]))
            }
            guard m + 2 < b.count else { return nil }
            let len = Int(b[m + 1]) << 8 | Int(b[m + 2])
            guard len >= 2, m + 1 + len <= b.count else { return nil }
            header.append(Segment(marker: marker, bytes: Data([0xFF] + b[(m)..<(m + 1 + len)])))
            i = m + 1 + len
        }
        return nil
    }

    /// Index just past the EOI (FFD9) that ends the primary image.
    private static func endOfImage(_ b: [UInt8], from start: Int) -> Int? {
        var i = start
        // Skip the SOS segment's own header.
        guard i + 1 < b.count else { return nil }
        i += Int(b[i]) << 8 | Int(b[i + 1])
        while i + 1 < b.count {
            if b[i] != 0xFF { i += 1; continue }
            let next = b[i + 1]
            switch next {
            case 0x00, 0xFF, 0xD0...0xD7:
                i += next == 0xFF ? 1 : 2
            case 0xD9:
                return i + 2
            default:
                // Another marker segment inside the scan sequence (DHT, SOS, DQT, DRI …).
                guard i + 3 < b.count else { return nil }
                i += 2 + (Int(b[i + 2]) << 8 | Int(b[i + 3]))
            }
        }
        return nil
    }

    static func build(_ file: File, includeTrailer: Bool = true) -> Data {
        var out = Data([0xFF, 0xD8])
        for s in file.header { out.append(s.bytes) }
        out.append(file.scan)
        if includeTrailer { out.append(file.trailer) }
        return out
    }

    /// An APP1 XMP segment for `xmp`, or nil when it doesn't fit in one segment.
    static func xmpSegment(_ xmp: Data) -> Segment? {
        let payload = Data("http://ns.adobe.com/xap/1.0/\0".utf8) + xmp
        guard payload.count + 2 <= 0xFFFF else { return nil }
        let len = payload.count + 2
        return Segment(marker: 0xE1, bytes: Data([0xFF, 0xE1, UInt8(len >> 8), UInt8(len & 0xFF)]) + payload)
    }
}
