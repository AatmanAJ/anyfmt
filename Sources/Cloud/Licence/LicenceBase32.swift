import Foundation

/// Crockford base32 (https://www.crockford.com/base32.html), no padding,
/// no check symbol. Used only for licence keys, so people can read them
/// aloud and type them without confusing 0/O or 1/I/L.
enum LicenceBase32 {
    static let alphabet: [Character] = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")

    private static let decodeTable: [UInt8: UInt8] = {
        var t: [UInt8: UInt8] = [:]
        for (i, c) in alphabet.enumerated() {
            t[c.asciiValue!] = UInt8(i)
            t[Character(c.lowercased()).asciiValue!] = UInt8(i)
        }
        // Crockford's aliases for characters people mistype.
        let aliases: [(Character, UInt8)] = [("O", 0), ("o", 0), ("I", 1), ("i", 1), ("L", 1), ("l", 1)]
        for (alias, value) in aliases { t[alias.asciiValue!] = value }
        return t
    }()

    static func encode(_ data: Data) -> String {
        var out = ""
        out.reserveCapacity((data.count * 8 + 4) / 5)
        var buffer: UInt32 = 0
        var bits = 0
        for byte in data {
            buffer = ((buffer << 8) | UInt32(byte)) & 0x1FFF
            bits += 8
            while bits >= 5 {
                bits -= 5
                out.append(alphabet[Int((buffer >> UInt32(bits)) & 0x1F)])
            }
        }
        if bits > 0 {
            out.append(alphabet[Int((buffer << UInt32(5 - bits)) & 0x1F)])
        }
        return out
    }

    /// Decodes symbols only (callers strip separators first). Returns nil on
    /// an unknown symbol, an impossible length, or non-zero trailing bits, so
    /// every byte string has exactly one accepted spelling (up to case/aliases).
    static func decode(_ text: some StringProtocol) -> Data? {
        var out = Data()
        out.reserveCapacity(text.utf8.count * 5 / 8)
        var buffer: UInt32 = 0
        var bits = 0
        for ch in text.utf8 {
            guard let v = decodeTable[ch] else { return nil }
            buffer = (buffer << 5) | UInt32(v)
            bits += 5
            if bits >= 8 {
                bits -= 8
                out.append(UInt8((buffer >> UInt32(bits)) & 0xFF))
            }
            buffer &= (1 << UInt32(bits)) - 1
        }
        // Leftover bits are padding: fewer than 5 and all zero.
        guard bits < 5, buffer == 0 else { return nil }
        return out
    }
}
