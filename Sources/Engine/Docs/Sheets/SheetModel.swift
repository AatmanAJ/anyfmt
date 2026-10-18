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
        case .date(let d, let t): t ? Cell.dateTimeFormatter.string(from: d) : Cell.dateFormatter.string(from: d)
        }
    }

    public static func format(_ d: Double) -> String {
        guard d.isFinite else { return d.isNaN ? "NaN" : (d > 0 ? "Infinity" : "-Infinity") }
        if d == d.rounded(), abs(d) < 1e15 { return String(Int64(d)) }
        return "\(d)"
    }

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static let dateTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

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
        let s = raw.trimmingCharacters(in: .whitespaces)
        if s.isEmpty { return raw.isEmpty ? .empty : .string(raw) }
        let upper = s.uppercased()
        if upper == "TRUE" { return .bool(true) }
        if upper == "FALSE" { return .bool(false) }
        if let n = number(s, decimalComma: decimalComma) { return .number(n) }
        if let d = isoDate(s) { return d }
        return .string(raw)
    }

    static func number(_ s: String, decimalComma: Bool) -> Double? {
        var t = s
        if decimalComma, t.range(of: #"^[-+]?\d+,\d+$"#, options: .regularExpression) != nil { t = t.replacingOccurrences(of: ",", with: ".") }
        guard t.range(of: #"^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$"#, options: .regularExpression) != nil else { return nil }
        // Keep identifiers like 007 or long digit strings as text.
        let digits = t.filter(\.isNumber)
        let intPart = t.drop { $0 == "-" || $0 == "+" }.prefix { $0 != "." && $0 != "e" && $0 != "E" }
        if intPart.count > 1, intPart.hasPrefix("0") { return nil }
        if digits.count > 15 { return nil }
        return Double(t)
    }

    static func isoDate(_ s: String) -> Cell? {
        guard s.count >= 10, s.range(of: #"^\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2}(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?)?$"#, options: .regularExpression) != nil else { return nil }
        if s.count == 10 { return dateFormatter.date(from: s).map { .date($0, time: false) } }
        var t = s.replacingOccurrences(of: "T", with: " ")
        if let dot = t.firstIndex(of: ".") { t = String(t[..<dot]) }
        if t.hasSuffix("Z") { t.removeLast() }
        if let r = t.range(of: #"[+-]\d{2}:?\d{2}$"#, options: .regularExpression) { t = String(t[..<r.lowerBound]) }
        if t.count == 16 { t += ":00" }
        return dateTimeFormatter.date(from: t).map { .date($0, time: true) }
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
