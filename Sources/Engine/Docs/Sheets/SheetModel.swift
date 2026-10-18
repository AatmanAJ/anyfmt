import Foundation

/// A workbook: sheets → rows → typed cells. Formulas are represented by their
/// cached values (we convert data, not spreadsheets' logic).
public struct Workbook: Sendable, Hashable {
    public var sheets: [Sheet]
    public init(sheets: [Sheet]) { self.sheets = sheets }
}

public struct Sheet: Sendable, Hashable {
    public var name: String
    public var rows: [[Cell]]

    public init(name: String, rows: [[Cell]]) {
        self.name = name
        self.rows = rows
    }

    public var columnCount: Int { rows.map(\.count).max() ?? 0 }

    /// Drops trailing empty cells and rows.
    public var trimmed: Sheet {
        var r = rows.map { row -> [Cell] in
            var row = row
            while let l = row.last, l == .empty { row.removeLast() }
            return row
        }
        while let l = r.last, l.isEmpty { r.removeLast() }
        return Sheet(name: name, rows: r)
    }

    /// The first row reads as column titles: all non-empty text, at least one more row.
    public var hasHeaderRow: Bool {
        guard rows.count > 1, let first = rows.first, !first.isEmpty else { return false }
        var seen = Set<String>()
        for c in first {
            guard case .string(let s) = c, !s.trimmingCharacters(in: .whitespaces).isEmpty, seen.insert(s).inserted else { return false }
        }
        return true
    }
}

public enum Cell: Sendable, Hashable {
    case empty
    case string(String)
    case number(Double)
    case bool(Bool)
    /// Wall-clock date (stored as UTC); `time` = has a time-of-day component.
    case date(Date, time: Bool)

    public var isEmpty: Bool { self == .empty }

    /// Display text (ISO dates, shortest round-trip numbers, TRUE/FALSE).
    public var text: String {
        switch self {
        case .empty: ""
        case .string(let s): s
        case .number(let d): Cell.format(d)
        case .bool(let b): b ? "TRUE" : "FALSE"
        case .date(let d, let t): Cell.isoString(d, time: t)
        }
    }

    public static func format(_ d: Double) -> String {
        guard d.isFinite else { return d.isNaN ? "NaN" : (d > 0 ? "Infinity" : "-Infinity") }
        if d == d.rounded(), abs(d) < 1e15 { return String(Int64(d)) }
        return "\(d)"
    }

    // Dates are wall-clock values kept as UTC seconds. Calendar maths is done by hand
    // (Hinnant's civil-day algorithms): DateFormatter is far too slow per CSV cell.

    /// Days since 1970-01-01 of a proleptic Gregorian date.
    static func daysFromCivil(_ y: Int, _ m: Int, _ d: Int) -> Int {
        let y2 = m <= 2 ? y - 1 : y
        let era = (y2 >= 0 ? y2 : y2 - 399) / 400
        let yoe = y2 - era * 400
        let doy = (153 * ((m + 9) % 12) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    static func civilFromDays(_ days: Int) -> (Int, Int, Int) {
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
    }

    static func daysInMonth(_ y: Int, _ m: Int) -> Int {
        switch m {
        case 2: (y % 4 == 0 && y % 100 != 0) || y % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    /// `yyyy-MM-dd` or `yyyy-MM-dd HH:mm:ss`.
    public static func isoString(_ date: Date, time: Bool) -> String {
        let secs = Int(date.timeIntervalSince1970.rounded())
        let days = Int((Double(secs) / 86400).rounded(.down))
        let rem = secs - days * 86400
        let (y, m, d) = civilFromDays(days)
        func p2(_ v: Int) -> String { v < 10 ? "0\(v)" : "\(v)" }
        let year = y >= 0 && y < 10000 ? String(String(y + 10000).dropFirst()) : "\(y)"
        var s = "\(year)-\(p2(m))-\(p2(d))"
        if time { s += " \(p2(rem / 3600)):\(p2(rem % 3600 / 60)):\(p2(rem % 60))" }
        return s
    }

    /// Excel serial day number (1900 system, epoch 1899-12-30) ↔ Date.
    public static func excelSerial(_ d: Date) -> Double { d.timeIntervalSince1970 / 86400 + 25569 }
    public static func date(fromExcelSerial s: Double, date1904: Bool = false) -> Date {
        let days = s + (date1904 ? 1462 : 0)
        // Round to the millisecond to undo float noise.
        let secs = ((days - 25569) * 86400 * 1000).rounded() / 1000
        return Date(timeIntervalSince1970: secs)
    }

    /// Infers a typed cell from text (CSV/TSV): numbers, TRUE/FALSE, ISO dates.
    public static func infer(_ raw: String, decimalComma: Bool = false) -> Cell {
        if raw.isEmpty { return .empty }
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return .string(raw) }
        let n = s.utf8.count
        if n == 4, s.caseInsensitiveCompare("TRUE") == .orderedSame { return .bool(true) }
        if n == 5, s.caseInsensitiveCompare("FALSE") == .orderedSame { return .bool(false) }
        if let v = number(s, decimalComma: decimalComma) { return .number(v) }
        if let d = isoDate(s) { return d }
        return .string(raw)
    }

    @inline(__always) static func isDigit(_ c: UInt8) -> Bool { c >= 0x30 && c <= 0x39 }

    /// `[-+]? (digits [. digits] | . digits) [e [-+] digits]`, keeping identifiers
    /// like `007` and numbers beyond double precision (> 15 digits) as text.
    static func number(_ s: String, decimalComma: Bool) -> Double? {
        var b = Array(s.utf8)
        guard let f = b.first, isDigit(f) || f == 0x2D || f == 0x2B || f == 0x2E else { return nil }
        if decimalComma, let comma = b.firstIndex(of: 0x2C), !b.contains(0x2E) {
            let before = b[..<comma].drop { $0 == 0x2D || $0 == 0x2B }
            let after = b[(comma + 1)...]
            if !before.isEmpty, !after.isEmpty, before.allSatisfy(isDigit), after.allSatisfy(isDigit) { b[comma] = 0x2E }
        }
        var i = 0
        let n = b.count
        if b[i] == 0x2D || b[i] == 0x2B { i += 1 }
        let intStart = i
        while i < n, isDigit(b[i]) { i += 1 }
        let intLen = i - intStart
        var fracLen = 0
        if i < n, b[i] == 0x2E {
            i += 1
            let fs = i
            while i < n, isDigit(b[i]) { i += 1 }
            fracLen = i - fs
        }
        guard intLen + fracLen > 0 else { return nil }
        if i < n, b[i] == 0x65 || b[i] == 0x45 {
            i += 1
            if i < n, b[i] == 0x2D || b[i] == 0x2B { i += 1 }
            let es = i
            while i < n, isDigit(b[i]) { i += 1 }
            guard i > es else { return nil }
        }
        guard i == n else { return nil }
        if intLen > 1, b[intStart] == 0x30 { return nil }
        if intLen + fracLen > 15 { return nil }
        return Double(String(decoding: b, as: UTF8.self))
    }

    /// `yyyy-MM-dd`, optionally `[T ]HH:mm[:ss[.fff]]` and a `Z`/`±HH[:]MM` suffix
    /// (accepted; the wall-clock time is kept as written).
    static func isoDate(_ s: String) -> Cell? {
        let b = Array(s.utf8)
        guard b.count >= 10, b[4] == 0x2D, b[7] == 0x2D else { return nil }
        func num(_ r: Range<Int>) -> Int? {
            guard r.lowerBound >= 0, r.upperBound <= b.count else { return nil }
            var v = 0
            for k in r {
                guard isDigit(b[k]) else { return nil }
                v = v * 10 + Int(b[k] - 0x30)
            }
            return v
        }
        guard let y = num(0..<4), let mo = num(5..<7), let d = num(8..<10), (1...12).contains(mo), d >= 1, d <= daysInMonth(y, mo) else { return nil }
        var secs = daysFromCivil(y, mo, d) * 86400
        if b.count == 10 { return .date(Date(timeIntervalSince1970: TimeInterval(secs)), time: false) }
        guard b.count >= 16, b[10] == 0x54 || b[10] == 0x20, b[13] == 0x3A, let h = num(11..<13), let mi = num(14..<16), h < 24, mi < 60 else { return nil }
        var i = 16
        var sec = 0
        if i < b.count, b[i] == 0x3A {
            guard let sv = num(17..<19), sv < 61 else { return nil }
            sec = sv
            i = 19
            if i < b.count, b[i] == 0x2E {
                i += 1
                let start = i
                while i < b.count, isDigit(b[i]) { i += 1 }
                guard i > start else { return nil }
            }
        }
        if i < b.count {
            if b[i] == 0x5A {
                i += 1
            } else if b[i] == 0x2B || b[i] == 0x2D {
                guard num((i + 1)..<(i + 3)) != nil else { return nil }
                i += 3
                if i < b.count, b[i] == 0x3A { i += 1 }
                guard num(i..<(i + 2)) != nil else { return nil }
                i += 2
            }
        }
        guard i == b.count else { return nil }
        secs += h * 3600 + mi * 60 + sec
        return .date(Date(timeIntervalSince1970: TimeInterval(secs)), time: true)
    }
}

// MARK: - JSON with key order preserved

/// Minimal JSON value that keeps object key order (Foundation's parser doesn't),
/// so JSON → table columns follow the file.
public indirect enum JSONValue: Sendable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([(String, JSONValue)])

    public static func == (a: JSONValue, b: JSONValue) -> Bool {
        switch (a, b) {
        case (.null, .null): true
        case (.bool(let x), .bool(let y)): x == y
        case (.number(let x), .number(let y)): x == y
        case (.string(let x), .string(let y)): x == y
        case (.array(let x), .array(let y)): x == y
        case (.object(let x), .object(let y)): x.count == y.count && zip(x, y).allSatisfy { $0.0 == $1.0 && $0.1 == $1.1 }
        default: false
        }
    }

    public func hash(into h: inout Hasher) {
        switch self {
        case .null: h.combine(0)
        case .bool(let b): h.combine(b)
        case .number(let n): h.combine(n)
        case .string(let s): h.combine(s)
        case .array(let a): h.combine(a)
        case .object(let o): for (k, v) in o { h.combine(k); h.combine(v) }
        }
    }

    public struct ParseError: Error, Sendable { public let offset: Int }

    public static func parse(_ data: Data) throws -> JSONValue {
        var bytes = [UInt8](data)
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes.removeFirst(3) }
        var p = JSONParser(bytes: bytes)
        p.skipWS()
        let v = try p.value(depth: 0)
        p.skipWS()
        guard p.i == bytes.count else { throw ParseError(offset: p.i) }
        return v
    }

    /// Compact serialisation (for nested values placed in a single cell).
    public var compact: String {
        switch self {
        case .null: "null"
        case .bool(let b): b ? "true" : "false"
        case .number(let n): Cell.format(n)
        case .string(let s): JSONValue.quote(s)
        case .array(let a): "[" + a.map(\.compact).joined(separator: ",") + "]"
        case .object(let o): "{" + o.map { JSONValue.quote($0.0) + ":" + $0.1.compact }.joined(separator: ",") + "}"
        }
    }

    public static func quote(_ s: String) -> String {
        var out = "\""
        for u in s.unicodeScalars {
            switch u {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if u.value < 0x20 { out += String(format: "\\u%04x", u.value) } else { out.unicodeScalars.append(u) }
            }
        }
        return out + "\""
    }
}

private struct JSONParser {
    let bytes: [UInt8]
    var i = 0

    init(bytes: [UInt8]) { self.bytes = bytes }

    mutating func skipWS() {
        while i < bytes.count, bytes[i] == 0x20 || bytes[i] == 0x0A || bytes[i] == 0x0D || bytes[i] == 0x09 { i += 1 }
    }

    mutating func value(depth: Int) throws -> JSONValue {
        guard depth < 512, i < bytes.count else { throw JSONValue.ParseError(offset: i) }
        switch bytes[i] {
        case UInt8(ascii: "{"):
            i += 1
            var pairs: [(String, JSONValue)] = []
            skipWS()
            if i < bytes.count, bytes[i] == UInt8(ascii: "}") { i += 1; return .object(pairs) }
            while true {
                skipWS()
                let k = try string()
                skipWS()
                guard i < bytes.count, bytes[i] == UInt8(ascii: ":") else { throw JSONValue.ParseError(offset: i) }
                i += 1
                skipWS()
                pairs.append((k, try value(depth: depth + 1)))
                skipWS()
                guard i < bytes.count else { throw JSONValue.ParseError(offset: i) }
                if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                if bytes[i] == UInt8(ascii: "}") { i += 1; return .object(pairs) }
                throw JSONValue.ParseError(offset: i)
            }
        case UInt8(ascii: "["):
            i += 1
            var items: [JSONValue] = []
            skipWS()
            if i < bytes.count, bytes[i] == UInt8(ascii: "]") { i += 1; return .array(items) }
            while true {
                skipWS()
                items.append(try value(depth: depth + 1))
                skipWS()
                guard i < bytes.count else { throw JSONValue.ParseError(offset: i) }
                if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
                if bytes[i] == UInt8(ascii: "]") { i += 1; return .array(items) }
                throw JSONValue.ParseError(offset: i)
            }
        case UInt8(ascii: "\""):
            return .string(try string())
        case UInt8(ascii: "t"):
            try literal("true"); return .bool(true)
        case UInt8(ascii: "f"):
            try literal("false"); return .bool(false)
        case UInt8(ascii: "n"):
            try literal("null"); return .null
        default:
            return .number(try number())
        }
    }

    mutating func literal(_ s: String) throws {
        let b = Array(s.utf8)
        guard i + b.count <= bytes.count, Array(bytes[i..<i + b.count]) == b else { throw JSONValue.ParseError(offset: i) }
        i += b.count
    }

    mutating func number() throws -> Double {
        let start = i
        while i < bytes.count, "+-0123456789.eE".utf8.contains(bytes[i]) { i += 1 }
        guard i > start, let d = Double(String(decoding: bytes[start..<i], as: UTF8.self)) else { throw JSONValue.ParseError(offset: start) }
        return d
    }

    mutating func string() throws -> String {
        guard i < bytes.count, bytes[i] == UInt8(ascii: "\"") else { throw JSONValue.ParseError(offset: i) }
        i += 1
        var buf: [UInt8] = []
        while i < bytes.count {
            let c = bytes[i]
            if c == UInt8(ascii: "\"") { i += 1; return String(decoding: buf, as: UTF8.self) }
            if c == UInt8(ascii: "\\") {
                i += 1
                guard i < bytes.count else { break }
                let e = bytes[i]
                switch e {
                case UInt8(ascii: "n"): buf.append(0x0A)
                case UInt8(ascii: "t"): buf.append(0x09)
                case UInt8(ascii: "r"): buf.append(0x0D)
                case UInt8(ascii: "b"): buf.append(0x08)
                case UInt8(ascii: "f"): buf.append(0x0C)
                case UInt8(ascii: "u"):
                    guard i + 4 < bytes.count, var v = UInt32(String(decoding: bytes[(i + 1)...(i + 4)], as: UTF8.self), radix: 16) else { throw JSONValue.ParseError(offset: i) }
                    i += 4
                    // Surrogate pair.
                    if (0xD800...0xDBFF).contains(v), i + 6 < bytes.count, bytes[i + 1] == UInt8(ascii: "\\"), bytes[i + 2] == UInt8(ascii: "u"),
                       let lo = UInt32(String(decoding: bytes[(i + 3)...(i + 6)], as: UTF8.self), radix: 16), (0xDC00...0xDFFF).contains(lo) {
                        v = 0x10000 + ((v - 0xD800) << 10) + (lo - 0xDC00)
                        i += 6
                    }
                    let scalar = Unicode.Scalar(v) ?? "\u{FFFD}"
                    buf.append(contentsOf: Array(String(Character(scalar)).utf8))
                default: buf.append(e)
                }
                i += 1
                continue
            }
            buf.append(c)
            i += 1
        }
        throw JSONValue.ParseError(offset: i)
    }
}
