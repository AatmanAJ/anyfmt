import Foundation

/// Minimal in-memory ZIP writer for the packages we generate (DOCX, XLSX, PPTX,
/// ODT, ODS, EPUB). Deflate via the Compression framework, CRC-32, UTF-8 names
/// (flag bit 11 when needed), optional fixed timestamps so output is byte-for-byte
/// reproducible. Entries are written in the order added, which matters for EPUB
/// and ODF (`mimetype` first, stored).
public struct ZipWriter {
    public struct Options: Sendable {
        /// Fixed 1980-01-01 00:00 timestamps for reproducible output.
        public var deterministic: Bool
        public var date: Date
        public init(deterministic: Bool = false, date: Date = Date()) {
            self.deterministic = deterministic
            self.date = date
        }
    }

    public enum Failure: Error, Sendable { case duplicate(String), tooLarge, invalidName(String) }

    private let options: Options
    private var body = Data()
    private var central = Data()
    private var count = 0
    private var names = Set<String>()
    private let dosTime: UInt16
    private let dosDate: UInt16

    public init(options: Options = Options()) {
        self.options = options
        if options.deterministic {
            dosTime = 0
            dosDate = (0 << 9) | (1 << 5) | 1
        } else {
            let c = Calendar(identifier: .gregorian).dateComponents(in: .current, from: options.date)
            let year = max(1980, min(2107, c.year ?? 1980))
            dosTime = UInt16(((c.hour ?? 0) << 11) | ((c.minute ?? 0) << 5) | ((c.second ?? 0) / 2))
            dosDate = UInt16(((year - 1980) << 9) | ((c.month ?? 1) << 5) | (c.day ?? 1))
        }
    }

    public var entryNames: Set<String> { names }

    /// Adds a file. `compress: false` stores it (required for EPUB/ODF `mimetype`).
    public mutating func add(_ path: String, _ content: Data, compress: Bool = true) throws {
        try validate(path)
        let crc = CRC32.checksum(content)
        var payload = content
        var method: UInt16 = 0
        if compress && content.count > 64 {
            let deflated = try Deflate.compress(content)
            if deflated.count < content.count {
                payload = deflated
                method = 8
            }
        }
        try appendEntry(path, payload: payload, method: method, crc: crc, size: content.count, isDirectory: false)
    }

    public mutating func add(_ path: String, _ text: String, compress: Bool = true) throws {
        try add(path, Data(text.utf8), compress: compress)
    }

    public mutating func addDirectory(_ path: String) throws {
        let p = path.hasSuffix("/") ? path : path + "/"
        try validate(p)
        try appendEntry(p, payload: Data(), method: 0, crc: 0, size: 0, isDirectory: true)
    }

    private func validate(_ path: String) throws {
        if path.isEmpty || path.hasPrefix("/") || path.split(separator: "/").contains("..") {
            throw Failure.invalidName(path)
        }
        if names.contains(path) { throw Failure.duplicate(path) }
    }

    private mutating func appendEntry(_ path: String, payload: Data, method: UInt16, crc: UInt32, size: Int, isDirectory: Bool) throws {
        guard payload.count < 0xFFFF_FFFF, size < 0xFFFF_FFFF, body.count < 0xFFFF_FFFF else { throw Failure.tooLarge }
        names.insert(path)
        let nameData = Data(path.utf8)
        let flags: UInt16 = path.utf8.contains { $0 >= 0x80 } ? 0x0800 : 0
        let offset = UInt32(body.count)

        var local = Data()
        local.le32(0x0403_4B50)
        local.le16(20)
        local.le16(flags)
        local.le16(method)
        local.le16(dosTime)
        local.le16(dosDate)
        local.le32(crc)
        local.le32(UInt32(payload.count))
        local.le32(UInt32(size))
        local.le16(UInt16(nameData.count))
        local.le16(0)
        local.append(nameData)
        body.append(local)
        body.append(payload)

        var c = Data()
        c.le32(0x0201_4B50)
        c.le16((3 << 8) | 20)   // made by: Unix, spec 2.0
        c.le16(20)
        c.le16(flags)
        c.le16(method)
        c.le16(dosTime)
        c.le16(dosDate)
        c.le32(crc)
        c.le32(UInt32(payload.count))
        c.le32(UInt32(size))
        c.le16(UInt16(nameData.count))
        c.le16(0)   // extra
        c.le16(0)   // comment
        c.le16(0)   // disk
        c.le16(0)   // internal attrs
        let mode: UInt32 = isDirectory ? (0o040755 << 16) | 0x10 : (0o100644 << 16)
        c.le32(mode)
        c.le32(offset)
        c.append(nameData)
        central.append(c)
        count += 1
    }

    /// The finished archive.
    public func finish() throws -> Data {
        guard count < 0xFFFF, central.count < 0xFFFF_FFFF else { throw Failure.tooLarge }
        var out = body
        let cdOffset = UInt32(out.count)
        out.append(central)
        var end = Data()
        end.le32(0x0605_4B50)
        end.le16(0)
        end.le16(0)
        end.le16(UInt16(count))
        end.le16(UInt16(count))
        end.le32(UInt32(central.count))
        end.le32(cdOffset)
        end.le16(0)
        out.append(end)
        return out
    }

    public func write(to url: URL) throws {
        try finish().write(to: url, options: .atomic)
    }
}

extension Data {
    mutating func le16(_ v: UInt16) {
        append(UInt8(v & 0xFF))
        append(UInt8(v >> 8))
    }

    mutating func le32(_ v: UInt32) {
        append(UInt8(v & 0xFF))
        append(UInt8((v >> 8) & 0xFF))
        append(UInt8((v >> 16) & 0xFF))
        append(UInt8(v >> 24))
    }
}
