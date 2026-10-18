import Foundation

/// Read-only ZIP access for OOXML/ODF/EPUB packages. Reads the central
/// directory (ZIP64 aware), inflates entries on demand and verifies CRC-32.
/// Paths are validated so nothing can escape a target directory (zip-slip).
public struct ZipReader: Sendable {
    public struct Entry: Sendable, Hashable {
        public let path: String
        public let method: UInt16
        public let flags: UInt16
        public let crc32: UInt32
        public let compressedSize: Int
        public let uncompressedSize: Int
        public let localHeaderOffset: Int
        public let externalAttributes: UInt32
        public var isDirectory: Bool { path.hasSuffix("/") }
        public var isEncrypted: Bool { flags & 1 != 0 }
        /// Unix mode bits when the archive was made on a Unix host (0 otherwise).
        public var unixMode: UInt32 { externalAttributes >> 16 }
        public var isSymlink: Bool { (unixMode & 0o170000) == 0o120000 }
    }

    public enum Failure: Error, Sendable, CustomStringConvertible {
        case notAZip, truncated, unsupportedMethod(UInt16), encrypted(String), crcMismatch(String), unsafePath(String), missing(String), tooLarge(String)
        public var description: String {
            switch self {
            case .notAZip: "not a zip archive"
            case .truncated: "truncated zip archive"
            case .unsupportedMethod(let m): "unsupported compression method \(m)"
            case .encrypted(let p): "encrypted entry \(p)"
            case .crcMismatch(let p): "CRC mismatch in \(p)"
            case .unsafePath(let p): "unsafe path \(p)"
            case .missing(let p): "missing entry \(p)"
            case .tooLarge(let p): "entry too large \(p)"
            }
        }
    }

    public let entries: [Entry]
    private let data: Data
    private let byPath: [String: Int]
    private let byLowerPath: [String: Int]
    /// Upper bound for one inflated entry (zip-bomb guard), 2 GB.
    public static let maxEntrySize = 1 << 31

    public init(url: URL) throws {
        try self.init(data: Data(contentsOf: url, options: .alwaysMapped))
    }

    public init(data: Data) throws {
        self.data = data
        let bytes = ByteView(data)
        guard data.count >= 22 else { throw Failure.notAZip }
        // End of central directory: scan backwards (comment ≤ 65535 bytes).
        var eocd = -1
        let lowest = max(0, data.count - 22 - 0xFFFF)
        var i = data.count - 22
        while i >= lowest {
            if bytes.u32(i) == 0x0605_4B50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw Failure.notAZip }
        var total = Int(bytes.u16(eocd + 10))
        var cdSize = Int(bytes.u32(eocd + 12))
        var cdOffset = Int(bytes.u32(eocd + 16))
        // ZIP64 end of central directory locator sits right before the EOCD.
        if (total == 0xFFFF || cdSize == 0xFFFF_FFFF || cdOffset == 0xFFFF_FFFF), eocd >= 20, bytes.u32(eocd - 20) == 0x0706_4B50 {
            let z64 = Int(bytes.u64(eocd - 20 + 8))
            guard z64 + 56 <= data.count, bytes.u32(z64) == 0x0606_4B50 else { throw Failure.truncated }
            total = Int(bytes.u64(z64 + 32))
            cdSize = Int(bytes.u64(z64 + 40))
            cdOffset = Int(bytes.u64(z64 + 48))
        }
        guard cdOffset >= 0, cdOffset + cdSize <= data.count else { throw Failure.truncated }
        var list: [Entry] = []
        list.reserveCapacity(total)
        var p = cdOffset
        let end = cdOffset + cdSize
        while p + 46 <= end, bytes.u32(p) == 0x0201_4B50 {
            let flags = bytes.u16(p + 8)
            let method = bytes.u16(p + 10)
            let crc = bytes.u32(p + 16)
            var csize = Int(bytes.u32(p + 20))
            var usize = Int(bytes.u32(p + 24))
            let nameLen = Int(bytes.u16(p + 28))
            let extraLen = Int(bytes.u16(p + 30))
            let commentLen = Int(bytes.u16(p + 32))
            let ext = bytes.u32(p + 38)
            var offset = Int(bytes.u32(p + 42))
            guard p + 46 + nameLen + extraLen + commentLen <= data.count else { throw Failure.truncated }
            let nameBytes = data.subdata(in: data.startIndex + p + 46 ..< data.startIndex + p + 46 + nameLen)
            let name = Self.decodeName(nameBytes, utf8Flag: flags & 0x0800 != 0)
            // ZIP64 extended information extra field (0x0001).
            var e = p + 46 + nameLen
            let extraEnd = e + extraLen
            while e + 4 <= extraEnd {
                let tag = bytes.u16(e), size = Int(bytes.u16(e + 2))
                if tag == 0x0001 {
                    var q = e + 4
                    let limit = min(e + 4 + size, extraEnd)
                    if usize == 0xFFFF_FFFF, q + 8 <= limit { usize = Int(bytes.u64(q)); q += 8 }
                    if csize == 0xFFFF_FFFF, q + 8 <= limit { csize = Int(bytes.u64(q)); q += 8 }
                    if offset == 0xFFFF_FFFF, q + 8 <= limit { offset = Int(bytes.u64(q)) }
                }
                e += 4 + size
            }
            list.append(Entry(path: name, method: method, flags: flags, crc32: crc, compressedSize: csize,
                              uncompressedSize: usize, localHeaderOffset: offset, externalAttributes: ext))
            p += 46 + nameLen + extraLen + commentLen
        }
        entries = list
        var d: [String: Int] = [:], l: [String: Int] = [:]
        for (i, e) in list.enumerated() {
            let key = Self.normalize(e.path)
            if d[key] == nil { d[key] = i }
            if l[key.lowercased()] == nil { l[key.lowercased()] = i }
        }
        byPath = d
        byLowerPath = l
    }

    /// Names are UTF-8 when flagged; many tools write UTF-8 without the flag, so try that, then CP437-ish Latin-1.
    static func decodeName(_ d: Data, utf8Flag: Bool) -> String {
        if let s = String(data: d, encoding: .utf8) { return s }
        return String(data: d, encoding: .isoLatin1) ?? String(decoding: d, as: UTF8.self)
    }

    static func normalize(_ path: String) -> String {
        var p = path.replacingOccurrences(of: "\\", with: "/")
        while p.hasPrefix("./") { p.removeFirst(2) }
        if p.hasPrefix("/") { p.removeFirst() }
        return p
    }

    /// Case-sensitive lookup with a case-insensitive fallback (OPC part names are case-insensitive).
    public func entry(_ path: String) -> Entry? {
        let key = Self.normalize(path)
        if let i = byPath[key] { return entries[i] }
        if let i = byLowerPath[key.lowercased()] { return entries[i] }
        return nil
    }

    public func contains(_ path: String) -> Bool { entry(path) != nil }

    public func data(_ path: String) throws -> Data {
        guard let e = entry(path) else { throw Failure.missing(path) }
        return try data(for: e)
    }

    /// Entry contents decoded as text (UTF-8, falling back to Latin-1).
    public func text(_ path: String) throws -> String {
        let d = try data(path)
        return String(data: d, encoding: .utf8) ?? String(data: d, encoding: .isoLatin1) ?? String(decoding: d, as: UTF8.self)
    }

    public func data(for e: Entry) throws -> Data {
        if e.isEncrypted { throw Failure.encrypted(e.path) }
        let bytes = ByteView(data)
        let h = e.localHeaderOffset
        guard h + 30 <= data.count, bytes.u32(h) == 0x0403_4B50 else { throw Failure.truncated }
        let start = h + 30 + Int(bytes.u16(h + 26)) + Int(bytes.u16(h + 28))
        guard start + e.compressedSize <= data.count else { throw Failure.truncated }
        guard e.uncompressedSize <= Self.maxEntrySize else { throw Failure.tooLarge(e.path) }
        let raw = data.subdata(in: data.startIndex + start ..< data.startIndex + start + e.compressedSize)
        let out: Data
        switch e.method {
        case 0: out = raw
        case 8:
            do {
                out = try Deflate.decompress(raw, expectedSize: e.uncompressedSize, limit: max(e.uncompressedSize, 1) + 1024)
            } catch Deflate.Failure.tooLarge {
                throw Failure.tooLarge(e.path)
            }
        default: throw Failure.unsupportedMethod(e.method)
        }
        if CRC32.checksum(out) != e.crc32 { throw Failure.crcMismatch(e.path) }
        return out
    }

    /// Resolves an entry path to a location inside `root`, or throws if it would escape it.
    public static func safeDestination(for path: String, in root: URL) throws -> URL {
        let p = normalize(path)
        let parts = p.split(separator: "/", omittingEmptySubsequences: true)
        if path.hasPrefix("/") || path.hasPrefix("\\") || parts.contains("..") || parts.isEmpty || p.contains("\0") {
            throw Failure.unsafePath(path)
        }
        var u = root
        for part in parts { u.appendPathComponent(String(part)) }
        let rootPath = root.standardizedFileURL.path
        let dest = u.standardizedFileURL.path
        guard dest == rootPath || dest.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/") else {
            throw Failure.unsafePath(path)
        }
        return u
    }

    /// Extracts everything into `root` (must exist). Symlink entries are written as
    /// plain files containing their target text, never as links.
    public func extractAll(to root: URL) throws {
        let fm = FileManager.default
        for e in entries {
            let dest = try Self.safeDestination(for: e.path, in: root)
            if e.isDirectory {
                try fm.createDirectory(at: dest, withIntermediateDirectories: true)
                continue
            }
            try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data(for: e).write(to: dest)
        }
    }
}

/// Little-endian integer reads relative to a Data's start index.
struct ByteView {
    let data: Data
    init(_ d: Data) { data = d }
    @inline(__always) func u8(_ i: Int) -> UInt8 { data[data.startIndex + i] }
    @inline(__always) func u16(_ i: Int) -> UInt16 { UInt16(u8(i)) | UInt16(u8(i + 1)) << 8 }
    @inline(__always) func u32(_ i: Int) -> UInt32 { UInt32(u16(i)) | UInt32(u16(i + 2)) << 16 }
    @inline(__always) func u64(_ i: Int) -> UInt64 { UInt64(u32(i)) | UInt64(u32(i + 4)) << 32 }
}
