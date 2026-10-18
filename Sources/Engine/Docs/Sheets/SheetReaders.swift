import Foundation

public enum SheetIO {
    public static let readable: [FormatID] = [Formats.xlsx, Formats.ods, Formats.csv, Formats.tsv, Formats.json]
    public static let writable: [FormatID] = [Formats.xlsx, Formats.ods, Formats.csv, Formats.tsv, Formats.json, Formats.html, Formats.pdf]

    public static func read(_ url: URL, format: FormatID) throws -> Workbook {
        do {
            switch format {
            case Formats.xlsx: return try XLSXReader.read(ZipReader(url: url))
            case Formats.ods: return try ODSReader.read(ZipReader(url: url))
            case Formats.csv, Formats.tsv:
                let data = try Data(contentsOf: url)
                let sheet = CSVReader.read(data, delimiter: format == Formats.tsv ? "\t" : nil, name: url.deletingPathExtension().lastPathComponent)
                return Workbook(sheets: [sheet])
            case Formats.json:
                return Workbook(sheets: [try JSONTable.read(Data(contentsOf: url), name: url.deletingPathExtension().lastPathComponent)])
            default:
                throw ConversionError.unsupported(from: format, to: Formats.csv)
            }
        } catch let e as ConversionError {
            throw e
        } catch {
            throw ConversionError.unreadable(url, detail: "\(error)")
        }
    }
}

// MARK: - XLSX

public enum XLSXReader {
    public static func read(_ zip: ZipReader) throws -> Workbook {
        var wbPath = "xl/workbook.xml"
        if let rels = try? XMLTree.parse(zip.data("_rels/.rels")) {
            for r in rels.children("Relationship") where (r["Type"] ?? "").hasSuffix("/officeDocument") {
                if let t = r["Target"] { wbPath = OPC.resolve(t, relativeTo: "") }
            }
        }
        let wb = try XMLTree.parse(zip.data(wbPath))
        let date1904 = ["1", "true"].contains(wb.first("workbookPr")?["date1904"] ?? "")
        let rels = OPC.rels(zip, for: wbPath)
        var shared: [String] = []
        if let ssPath = rels.values.first(where: { $0.type.hasSuffix("/sharedStrings") })?.target, let ss = try? XMLTree.parse(zip.data(ssPath)) {
            shared = ss.children("si").map(richText)
        }
        var dateStyles = Set<Int>(), timeStyles = Set<Int>()
        if let stPath = rels.values.first(where: { $0.type.hasSuffix("/styles") })?.target, let st = try? XMLTree.parse(zip.data(stPath)) {
            var custom: [Int: String] = [:]
            for f in st.first("numFmts")?.children("numFmt") ?? [] {
                if let id = f["numFmtId"].flatMap(Int.init) { custom[id] = f["formatCode"] ?? "" }
            }
            for (k, xf) in (st.first("cellXfs")?.children("xf") ?? []).enumerated() {
                let id = xf["numFmtId"].flatMap(Int.init) ?? 0
                let (isDate, hasTime) = dateKind(id, code: custom[id])
                if isDate { dateStyles.insert(k) }
                if hasTime { timeStyles.insert(k) }
            }
        }
        var sheets: [Sheet] = []
        for s in wb.first("sheets")?.children("sheet") ?? [] {
            let name = s["name"] ?? "Sheet\(sheets.count + 1)"
            guard let rid = s["r:id"] ?? s["id"], let rel = rels[rid], let x = try? XMLTree.parse(zip.data(rel.target)) else { continue }
            sheets.append(sheet(x, name: name, shared: shared, dateStyles: dateStyles, timeStyles: timeStyles, date1904: date1904).trimmed)
        }
        return Workbook(sheets: sheets)
    }

    static func richText(_ si: XNode) -> String {
        if let t = si.child("t") { return t.text }
        return si.children("r").compactMap { $0.child("t")?.text }.joined()
    }

    /// Built-in date formats (14–22, 27–36, 45–47, 50–58) or custom codes with date/time tokens.
    static func dateKind(_ id: Int, code: String?) -> (Bool, Bool) {
        if (14...17).contains(id) || (27...31).contains(id) || (34...36).contains(id) || (50...58).contains(id) { return (true, false) }
        if (18...21).contains(id) || (32...33).contains(id) || (45...47).contains(id) { return (true, true) }
        if id == 22 { return (true, true) }
        guard let code else { return (false, false) }
        var s = code.lowercased()
        s = s.replacingOccurrences(of: #""[^"]*""#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\[(?![hms]+\])[^\]]*\]"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\\."#, with: "", options: .regularExpression)
        if s.contains("general") { return (false, false) }
        let date = s.contains("y") || s.contains("d") || (s.contains("m") && !s.contains("h") && !s.contains("s"))
        let time = s.contains("h") || s.contains("s")
        return (date || time, time)
    }

    static func columnIndex(_ ref: String) -> Int? {
        var n = 0
        var any = false
        for c in ref.uppercased() {
            guard let a = c.asciiValue, a >= 65, a <= 90 else { break }
            n = n * 26 + Int(a - 64)
            any = true
        }
        return any ? n - 1 : nil
    }

    static func sheet(_ x: XNode, name: String, shared: [String], dateStyles: Set<Int>, timeStyles: Set<Int>, date1904: Bool) -> Sheet {
        var rows: [[Cell]] = []
        guard let data = x.first("sheetData") else { return Sheet(name: name, rows: []) }
        var nextRow = 0
        for r in data.children("row") {
            let ri = (r["r"].flatMap(Int.init).map { $0 - 1 }) ?? nextRow
            guard ri >= 0, ri < 1_048_576 else { continue }
            // Pad up to sparse row index (bounded).
            if ri > rows.count, ri - rows.count < 100_000 { rows.append(contentsOf: Array(repeating: [], count: ri - rows.count)) }
            var row: [Cell] = []
            var nextCol = 0
            for c in r.children("c") {
                let ci = c["r"].flatMap(columnIndex) ?? nextCol
                guard ci < 16384 else { continue }
                while row.count < ci { row.append(.empty) }
                let style = c["s"].flatMap(Int.init) ?? 0
                let v = c.child("v")?.text
                var cell: Cell = .empty
                switch c["t"] ?? "n" {
                case "s": if let i = v.flatMap(Int.init), i >= 0, i < shared.count { cell = .string(shared[i]) }
                case "str": cell = v.map(Cell.string) ?? .empty
                case "inlineStr": cell = c.child("is").map { .string(richText($0)) } ?? .empty
                case "b": cell = .bool(v == "1" || v?.lowercased() == "true")
                case "e": cell = v.map(Cell.string) ?? .empty
                case "d": cell = v.flatMap(Cell.isoDate) ?? v.map(Cell.string) ?? .empty
                default:
                    if let v, let d = Double(v) {
                        if dateStyles.contains(style) {
                            cell = .date(Cell.date(fromExcelSerial: d, date1904: date1904), time: timeStyles.contains(style) || d != d.rounded())
                        } else {
                            cell = .number(d)
                        }
                    }
                }
                if row.count == ci { row.append(cell) } else if ci < row.count { row[ci] = cell }
                nextCol = ci + 1
            }
            if ri < rows.count { rows[ri] = row } else { rows.append(row) }
            nextRow = ri + 1
        }
        return Sheet(name: name, rows: rows)
    }
}

// MARK: - ODS

public enum ODSReader {
    public static func read(_ zip: ZipReader) throws -> Workbook {
        let content = try XMLTree.parse(zip.data("content.xml"))
        guard let ss = content.first("spreadsheet") else { return Workbook(sheets: []) }
        var sheets: [Sheet] = []
        for t in ss.children("table") {
            var rows: [[Cell]] = []
            collectRows(t, into: &rows)
            sheets.append(Sheet(name: t["table:name"] ?? "Sheet\(sheets.count + 1)", rows: rows).trimmed)
        }
        return Workbook(sheets: sheets)
    }

    static func collectRows(_ node: XNode, into rows: inout [[Cell]]) {
        for e in node.elements {
            switch e.name {
            case "table-row":
                let rep = e["table:number-rows-repeated"].flatMap(Int.init) ?? 1
                let row = cells(e)
                let count = row.allSatisfy(\.isEmpty) ? min(rep, 2000) : min(rep, 100_000)
                for _ in 0..<count { rows.append(row) }
            case "table-header-rows", "table-rows", "table-row-group":
                collectRows(e, into: &rows)
            default: break
            }
        }
    }

    static func cells(_ row: XNode) -> [Cell] {
        var out: [Cell] = []
        for c in row.elements where c.name == "table-cell" || c.name == "covered-table-cell" {
            let rep = c["table:number-columns-repeated"].flatMap(Int.init) ?? 1
            let cell = value(c)
            let count = cell.isEmpty ? min(rep, 2000) : min(rep, 16384)
            for _ in 0..<count { out.append(cell) }
        }
        while let l = out.last, l.isEmpty { out.removeLast() }
        return out
    }

    static func value(_ c: XNode) -> Cell {
        let text = c.children("p").map(cellText).joined(separator: "\n")
        switch c["office:value-type"] ?? c["calcext:value-type"] ?? "" {
        case "float", "percentage", "currency":
            return (c["office:value"].flatMap(Double.init)).map(Cell.number) ?? (text.isEmpty ? .empty : .string(text))
        case "boolean":
            return .bool((c["office:boolean-value"] ?? "false") == "true")
        case "date":
            if let v = c["office:date-value"], let d = Cell.isoDate(v) { return d }
            return text.isEmpty ? .empty : .string(text)
        case "time":
            return text.isEmpty ? .empty : .string(text)
        case "string":
            return .string(c["office:string-value"] ?? text)
        default:
            return text.isEmpty ? .empty : .string(text)
        }
    }

    static func cellText(_ p: XNode) -> String {
        var s = ""
        for ch in p.children {
            switch ch {
            case .text(let t): s += t
            case .element(let e):
                switch e.name {
                case "s": s += String(repeating: " ", count: max(1, e["text:c"].flatMap(Int.init) ?? 1))
                case "tab": s += "\t"
                case "line-break": s += "\n"
                case "annotation": break
                default: s += cellText(e)
                }
            }
        }
        return s
    }
}

// MARK: - CSV / TSV

public enum CSVReader {
    /// RFC 4180 parsing with BOM handling and delimiter sniffing (`,` `;` tab `|`).
    public static func read(_ data: Data, delimiter: Character? = nil, name: String = "Sheet1", inferTypes: Bool = true) -> Sheet {
        let text = TextDecoding.decode(data)
        let delim = delimiter ?? sniff(text)
        let rows = parse(text, delimiter: delim)
        let decimalComma = delim == ";"
        let cells = rows.map { r in r.map { inferTypes ? Cell.infer($0, decimalComma: decimalComma) : ($0.isEmpty ? .empty : .string($0)) } }
        return Sheet(name: name, rows: cells).trimmed
    }

    public static func sniff(_ text: String) -> Character {
        let candidates: [Character] = [",", ";", "\t", "|"]
        let sample = parseLines(text, limit: 30)
        var best: Character = ","
        var bestScore = -1
        for c in candidates {
            let counts = sample.map { line in countOutsideQuotes(line, c) }.filter { $0 > 0 }
            guard !counts.isEmpty else { continue }
            var freq: [Int: Int] = [:]
            for n in counts { freq[n, default: 0] += 1 }
            let consistent = freq.values.max() ?? 0
            let score = consistent * 100 + (counts.max() ?? 0)
            if score > bestScore { bestScore = score; best = c }
        }
        return best
    }

    static func parseLines(_ text: String, limit: Int) -> [String] {
        var lines: [String] = []
        var cur = ""
        var inQuotes = false
        for ch in text {
            if ch == "\"" { inQuotes.toggle() }
            if (ch == "\n" || ch == "\r\n" || ch == "\r") && !inQuotes {
                lines.append(cur); cur = ""
                if lines.count >= limit { break }
                continue
            }
            cur.append(ch)
        }
        if !cur.isEmpty, lines.count < limit { lines.append(cur) }
        return lines.filter { !$0.isEmpty }
    }

    static func countOutsideQuotes(_ line: String, _ c: Character) -> Int {
        var n = 0
        var q = false
        for ch in line {
            if ch == "\"" { q.toggle() } else if ch == c && !q { n += 1 }
        }
        return n
    }

    public static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var fieldStarted = false
        let it = Array(text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text)
        var i = 0
        let n = it.count
        while i < n {
            let ch = it[i]
            if inQuotes {
                if ch == "\"" {
                    if i + 1 < n, it[i + 1] == "\"" { field.append("\""); i += 2; continue }
                    inQuotes = false
                    i += 1
                    continue
                }
                field.append(ch)
                i += 1
                continue
            }
            if ch == "\"" && !fieldStarted {
                inQuotes = true
                fieldStarted = true
                i += 1
                continue
            }
            if ch == delimiter {
                row.append(field); field = ""; fieldStarted = false
                i += 1
                continue
            }
            if ch == "\n" || ch == "\r\n" || ch == "\r" {
                row.append(field); field = ""; fieldStarted = false
                rows.append(row); row = []
                i += 1
                continue
            }
            field.append(ch)
            fieldStarted = true
            i += 1
        }
        if fieldStarted || !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        // Drop fully empty trailing lines.
        while let l = rows.last, l.allSatisfy({ $0.isEmpty }) { rows.removeLast() }
        return rows
    }
}

// MARK: - JSON

public enum JSONTable {
    public static func read(_ data: Data, name: String) throws -> Sheet {
        let v = try JSONValue.parse(data)
        return Sheet(name: name, rows: table(v)).trimmed
    }

    static func cell(_ v: JSONValue) -> Cell {
        switch v {
        case .null: .empty
        case .bool(let b): .bool(b)
        case .number(let n): .number(n)
        case .string(let s): Cell.isoDate(s) ?? .string(s)
        case .array, .object: .string(v.compact)
        }
    }

    static func table(_ v: JSONValue) -> [[Cell]] {
        switch v {
        case .array(let items):
            if items.allSatisfy({ if case .object = $0 { return true }; return false }), !items.isEmpty {
                var keys: [String] = []
                var seen = Set<String>()
                for case .object(let pairs) in items { for (k, _) in pairs where seen.insert(k).inserted { keys.append(k) } }
                var rows: [[Cell]] = [keys.map(Cell.string)]
                for case .object(let pairs) in items {
                    var d: [String: JSONValue] = [:]
                    for (k, val) in pairs where d[k] == nil { d[k] = val }
                    rows.append(keys.map { d[$0].map(cell) ?? .empty })
                }
                return rows
            }
            if items.allSatisfy({ if case .array = $0 { return true }; return false }) {
                return items.map { item in
                    if case .array(let a) = item { return a.map(cell) }
                    return []
                }
            }
            return [[.string("value")]] + items.map { [cell($0)] }
        case .object(let pairs):
            // {"data": [...]} wrappers: use the first array of objects/arrays.
            for (_, val) in pairs {
                if case .array(let a) = val, let f = a.first {
                    switch f {
                    case .object, .array: return table(val)
                    default: continue
                    }
                }
            }
            // Object of objects → key column + fields.
            if !pairs.isEmpty, pairs.allSatisfy({ if case .object = $0.1 { return true }; return false }) {
                var keys: [String] = []
                var seen = Set<String>()
                for (_, val) in pairs { if case .object(let p) = val { for (k, _) in p where seen.insert(k).inserted { keys.append(k) } } }
                var rows: [[Cell]] = [[.string("key")] + keys.map(Cell.string)]
                for (k, val) in pairs {
                    guard case .object(let p) = val else { continue }
                    var d: [String: JSONValue] = [:]
                    for (kk, vv) in p where d[kk] == nil { d[kk] = vv }
                    rows.append([.string(k)] + keys.map { d[$0].map(cell) ?? .empty })
                }
                return rows
            }
            return [[.string("key"), .string("value")]] + pairs.map { [.string($0.0), cell($0.1)] }
        default:
            return [[cell(v)]]
        }
    }
}
