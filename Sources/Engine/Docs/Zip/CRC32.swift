import Foundation

/// CRC-32 (IEEE 802.3, reflected, polynomial 0xEDB88320) as used by ZIP and gzip.
/// Slicing-by-4 table lookup: fast enough for multi-megabyte parts.
public struct CRC32: Sendable {
    public private(set) var value: UInt32 = 0

    public init() {}

    private static let tables: [[UInt32]] = {
        var t0 = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB8_8320 ^ (c >> 1)) : (c >> 1) }
            t0[i] = c
        }
        var tables = [t0]
        for k in 1..<4 {
            var t = [UInt32](repeating: 0, count: 256)
            for i in 0..<256 {
                let prev = tables[k - 1][i]
                t[i] = (prev >> 8) ^ t0[Int(prev & 0xFF)]
            }
            tables.append(t)
        }
        return tables
    }()

    public mutating func update(_ data: Data) {
        data.withUnsafeBytes { update(UnsafeRawBufferPointer($0)) }
    }

    public mutating func update(_ buffer: UnsafeRawBufferPointer) {
        let t = Self.tables
        let t0 = t[0], t1 = t[1], t2 = t[2], t3 = t[3]
        var c = ~value
        var i = 0
        let n = buffer.count
        while i + 4 <= n {
            c ^= UInt32(buffer[i]) | UInt32(buffer[i + 1]) << 8 | UInt32(buffer[i + 2]) << 16 | UInt32(buffer[i + 3]) << 24
            c = t3[Int(c & 0xFF)] ^ t2[Int((c >> 8) & 0xFF)] ^ t1[Int((c >> 16) & 0xFF)] ^ t0[Int(c >> 24)]
            i += 4
        }
        while i < n {
            c = t0[Int((c ^ UInt32(buffer[i])) & 0xFF)] ^ (c >> 8)
            i += 1
        }
        value = ~c
    }

    public static func checksum(_ data: Data) -> UInt32 {
        var c = CRC32()
        c.update(data)
        return c.value
    }
}
