import Foundation

// MARK: - XLSX

/// Minimal, valid SpreadsheetML workbook: shared strings, typed cells, a bold
/// header row (frozen), ISO date formats and content-based column widths.
public struct XLSXWriter {
    public var zipOptions: ZipWriter.Options
    public init(zipOptions: ZipWriter.Options = .init()) { self.zipOptions = zipOptions }

    public func write(_ wb: Workbook) throws -> Data {
        let sheets = wb.sheets.isEmpty ? [Sheet(name: "Sheet1", rows: [])] : wb.sheets
        let names = SheetNames.unique(sheets.map(\.name), maxLength: 31)
        var strings: [String] = []
        var index: [String: Int] = [:]
        func sid(_ s: String) -> Int {
            if let i = index[s] { return i }
            index[s] = strings.count
            strings.append(s)
            return strings.count - 1
        }
        var sheetXML: [String] = []
        for sh in sheets {
            let header = sh.hasHeaderRow
            var x = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<worksheet xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\">"
            let cols = sh.columnCount
            if cols > 0, !sh.rows.isEmpty { x += "<dimension ref=\"A1:\(Self.ref(col: cols - 1, row: sh.rows.count - 1))\"/>" }
            x += "<sheetViews><sheetView workbookViewId=\"0\">"
            if header { x += "<pane ySplit=\"1\" topLeftCell=\"A2\" activePane=\"bottomLeft\" state=\"frozen\"/>" }
            x += "</sheetView></sheetViews><sheetFormatPr defaultRowHeight=\"15\"/>"
            if cols > 0 {
                x += "<cols>"
                for c in 0..<cols {
                    let w = sh.rows.prefix(500).map { $0.count > c ? Self.width($0[c]) : 0 }.max() ?? 8
                    x += "<col min=\"\(c + 1)\" max=\"\(c + 1)\" width=\"\(String(format: "%.1f", min(max(Double(w) * 1.1 + 2, 8.5), 80)))\" customWidth=\"1\"/>"
                }
                x += "</cols>"
            }
            x += "<sheetData>"
            for (ri, row) in sh.rows.enumerated() {
                x += "<row r=\"\(ri + 1)\">"
                for (ci, cell) in row.enumerated() {
                    let r = Self.ref(col: ci, row: ri)
                    let bold = header && ri == 0 ? " s=\"1\"" : ""
                    switch cell {
                    case .empty: continue
                    case .string(let s): x += "<c r=\"\(r)\" t=\"s\"\(bold)><v>\(sid(s))</v></c>"
                    case .number(let d):
                        guard d.isFinite else { x += "<c r=\"\(r)\" t=\"s\"\(bold)><v>\(sid(cell.text))</v></c>"; continue }
                        x += "<c r=\"\(r)\"\(bold)><v>\(Self.number(d))</v></c>"
                    case .bool(let b): x += "<c r=\"\(r)\" t=\"b\"\(bold)><v>\(b ? 1 : 0)</v></c>"
                    case .date(let d, let t): x += "<c r=\"\(r)\" s=\"\(t ? 3 : 2)\"><v>\(Self.number(Cell.excelSerial(d)))</v></c>"
                    }
                }
                x += "</row>"
            }
            x += "</sheetData><pageMargins left=\"0.7\" right=\"0.7\" top=\"0.75\" bottom=\"0.75\" header=\"0.3\" footer=\"0.3\"/></worksheet>"
            sheetXML.append(x)
        }
        var zip = ZipWriter(options: zipOptions)
        var ct = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/xl/workbook.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml\"/>"
        for k in sheets.indices { ct += "<Override PartName=\"/xl/worksheets/sheet\(k + 1).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>" }
        ct += "<Override PartName=\"/xl/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml\"/><Override PartName=\"/xl/sharedStrings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml\"/><Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/><Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/></Types>"
        try zip.add("[Content_Types].xml", ct)
        try zip.add("_rels/.rels", """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/><Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/></Relationships>
        """)
        try zip.add("docProps/core.xml", OOXMLCommon.coreXML(DocMetadata(), date: zipOptions.deterministic ? Date(timeIntervalSince1970: 0) : zipOptions.date))
        try zip.add("docProps/app.xml", OOXMLCommon.appXML)
        var wbx = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<workbook xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><workbookPr/><bookViews><workbookView/></bookViews><sheets>"
        var rels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        for k in sheets.indices {
            wbx += "<sheet name=\"\(XMLEscape.text(names[k]))\" sheetId=\"\(k + 1)\" r:id=\"rId\(k + 1)\"/>"
            rels += "<Relationship Id=\"rId\(k + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\(k + 1).xml\"/>"
        }
        wbx += "</sheets></workbook>"
        let n = sheets.count
        rels += "<Relationship Id=\"rId\(n + 1)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/><Relationship Id=\"rId\(n + 2)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings\" Target=\"sharedStrings.xml\"/></Relationships>"
        try zip.add("xl/workbook.xml", wbx)
        try zip.add("xl/_rels/workbook.xml.rels", rels)
        for (k, x) in sheetXML.enumerated() { try zip.add("xl/worksheets/sheet\(k + 1).xml", x) }
        try zip.add("xl/styles.xml", Self.styles)
        var ss = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<sst xmlns=\"http://schemas.openxmlformats.org/spreadsheetml/2006/main\" count=\"\(strings.count)\" uniqueCount=\"\(strings.count)\">"
        for s in strings { ss += "<si><t xml:space=\"preserve\">\(XMLEscape.text(s))</t></si>" }
        ss += "</sst>"
        try zip.add("xl/sharedStrings.xml", ss)
        return try zip.finish()
    }

    static let styles = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><numFmts count="2"><numFmt numFmtId="164" formatCode="yyyy-mm-dd"/><numFmt numFmtId="165" formatCode="yyyy-mm-dd hh:mm:ss"/></numFmts><fonts count="2"><font><sz val="11"/><name val="Calibri"/><family val="2"/></font><font><b/><sz val="11"/><name val="Calibri"/><family val="2"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="4"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/><xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/><xf numFmtId="165" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/></cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>
    """

    static func number(_ d: Double) -> String { Cell.format(d) }

    static func width(_ c: Cell) -> Int {
        switch c {
        case .date(_, let t): t ? 19 : 10
        default: c.text.split(separator: "\n").map(\.count).max() ?? 0
        }
    }

    static func ref(col: Int, row: Int) -> String { columnName(col) + "\(row + 1)" }

    public static func columnName(_ index: Int) -> String {
        var n = index + 1
        var s = ""
        while n > 0 {
            let r = (n - 1) % 26
            s = String(UnicodeScalar(UInt8(65 + r))) + s
            n = (n - 1) / 26
        }
        return s
    }
}

enum SheetNames {
    /// Valid, unique sheet names (Excel: ≤31 chars, none of []:*?/\).
    static func unique(_ names: [String], maxLength: Int) -> [String] {
        var used = Set<String>()
        return names.enumerated().map { k, raw in
            var n = String(raw.filter { !"[]:*?/\\".contains($0) }.prefix(maxLength)).trimmingCharacters(in: .whitespaces)
            if n.isEmpty { n = "Sheet\(k + 1)" }
            var candidate = n
            var i = 2
            while used.contains(candidate.lowercased()) {
                let suffix = " (\(i))"
                candidate = String(n.prefix(maxLength - suffix.count)) + suffix
                i += 1
            }
            used.insert(candidate.lowercased())
            return candidate
        }
    }
}

// MARK: - ODS

public struct ODSWriter {
    public var zipOptions: ZipWriter.Options
    public init(zipOptions: ZipWriter.Options = .init()) { self.zipOptions = zipOptions }

    public func write(_ wb: Workbook) throws -> Data {
        let sheets = wb.sheets.isEmpty ? [Sheet(name: "Sheet1", rows: [])] : wb.sheets
        let names = SheetNames.unique(sheets.map(\.name), maxLength: 100)
        var colStyles = ""
        var body = ""
        var colStyleCount = 0
        for (k, sh) in sheets.enumerated() {
            body += "<table:table table:name=\"\(XMLEscape.text(names[k]))\">"
            let cols = max(sh.columnCount, 1)
            for c in 0..<cols {
                let w = sh.rows.prefix(500).map { $0.count > c ? XLSXWriter.width($0[c]) : 0 }.max() ?? 8
                colStyleCount += 1
                colStyles += "<style:style style:name=\"co\(colStyleCount)\" style:family=\"table-column\"><style:table-column-properties style:column-width=\"\(String(format: "%.2f", min(max(Double(w) * 0.22 + 0.4, 1.8), 15)))cm\"/></style:style>"
                body += "<table:table-column table:style-name=\"co\(colStyleCount)\"/>"
            }
            let header = sh.hasHeaderRow
            if header, let first = sh.rows.first {
                body += "<table:table-header-rows>" + row(first, bold: true) + "</table:table-header-rows>"
            }
            for r in sh.rows.dropFirst(header ? 1 : 0) { body += row(r, bold: false) }
            if sh.rows.isEmpty { body += "<table:table-row><table:table-cell/></table:table-row>" }
            body += "</table:table>"
        }
        let content = """
        <?xml version="1.0" encoding="UTF-8"?>
        <office:document-content \(ODTWriter.ns) office:version="1.2"><office:automatic-styles>\
        <number:date-style style:name="N_date"><number:year number:style="long"/><number:text>-</number:text><number:month number:style="long"/><number:text>-</number:text><number:day number:style="long"/></number:date-style>\
        <number:date-style style:name="N_datetime"><number:year number:style="long"/><number:text>-</number:text><number:month number:style="long"/><number:text>-</number:text><number:day number:style="long"/><number:text> </number:text><number:hours number:style="long"/><number:text>:</number:text><number:minutes number:style="long"/><number:text>:</number:text><number:seconds number:style="long"/></number:date-style>\
        <style:style style:name="ce_date" style:family="table-cell" style:parent-style-name="Default" style:data-style-name="N_date"/>\
        <style:style style:name="ce_datetime" style:family="table-cell" style:parent-style-name="Default" style:data-style-name="N_datetime"/>\
        <style:style style:name="ce_bold" style:family="table-cell" style:parent-style-name="Default"><style:text-properties fo:font-weight="bold" style:font-weight-asian="bold" style:font-weight-complex="bold"/></style:style>\
        \(colStyles)</office:automatic-styles><office:body><office:spreadsheet>\(body)</office:spreadsheet></office:body></office:document-content>
        """
        let styles = """
        <?xml version="1.0" encoding="UTF-8"?>
        <office:document-styles \(ODTWriter.ns) office:version="1.2"><office:styles><style:default-style style:family="table-cell"><style:text-properties fo:font-size="10pt"/></style:default-style><style:style style:name="Default" style:family="table-cell"/></office:styles></office:document-styles>
        """
        var zip = ZipWriter(options: zipOptions)
        try zip.add("mimetype", "application/vnd.oasis.opendocument.spreadsheet", compress: false)
        try zip.add("META-INF/manifest.xml", ODTWriter().manifest(media: [], type: "application/vnd.oasis.opendocument.spreadsheet"))
        try zip.add("content.xml", content)
        try zip.add("styles.xml", styles)
        try zip.add("meta.xml", ODTWriter.metaXML(DocMetadata(), date: zipOptions.deterministic ? Date(timeIntervalSince1970: 0) : zipOptions.date))
        return try zip.finish()
    }

    func row(_ r: [Cell], bold: Bool) -> String {
        var s = "<table:table-row>"
        let style = bold ? " table:style-name=\"ce_bold\"" : ""
        for c in r {
            switch c {
            case .empty: s += "<table:table-cell/>"
            case .string(let t):
                let paras = t.split(separator: "\n", omittingEmptySubsequences: false).map { "<text:p>\(ODTBuilder(textWidth: 0, textHeight: 0).text(String($0)))</text:p>" }.joined()
                s += "<table:table-cell office:value-type=\"string\"\(style)>\(paras)</table:table-cell>"
            case .number(let d):
                if d.isFinite {
                    s += "<table:table-cell office:value-type=\"float\" office:value=\"\(Cell.format(d))\"\(style)><text:p>\(Cell.format(d))</text:p></table:table-cell>"
                } else {
                    s += "<table:table-cell office:value-type=\"string\"\(style)><text:p>\(c.text)</text:p></table:table-cell>"
                }
            case .bool(let b):
                s += "<table:table-cell office:value-type=\"boolean\" office:boolean-value=\"\(b ? "true" : "false")\"\(style)><text:p>\(b ? "TRUE" : "FALSE")</text:p></table:table-cell>"
            case .date(let d, let t):
                let iso = Cell.isoString(d, time: t).replacingOccurrences(of: " ", with: "T")
                s += "<table:table-cell table:style-name=\"\(t ? "ce_datetime" : "ce_date")\" office:value-type=\"date\" office:date-value=\"\(iso)\"><text:p>\(c.text)</text:p></table:table-cell>"
            }
        }
        return s + "</table:table-row>"
    }
}

// MARK: - CSV / TSV / JSON / HTML

public enum DelimitedWriter {
    /// RFC 4180: CRLF line ends, quotes doubled, fields quoted when needed.
    public static func write(_ sheet: Sheet, delimiter: Character, bom: Bool = false) -> Data {
        var out = ""
        for row in sheet.rows {
            out += row.map { field($0.text, delimiter: delimiter) }.joined(separator: String(delimiter))
            out += "\r\n"
        }
        var d = Data()
        if bom { d.append(contentsOf: [0xEF, 0xBB, 0xBF]) }
        d.append(Data(out.utf8))
        return d
    }

    static func field(_ s: String, delimiter: Character) -> String {
        let needs = s.contains(delimiter) || s.contains("\"") || s.contains("\n") || s.contains("\r") || s.hasPrefix(" ") || s.hasSuffix(" ")
        guard needs else { return s }
        if delimiter == "\t" && !s.contains("\t") && !s.contains("\n") && !s.contains("\r") && !s.contains("\"") { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

public enum JSONTableWriter {
    /// Array of objects keyed by the header row when there is one, else array of arrays.
    public static func write(_ sheet: Sheet) -> Data {
        var out = ""
        if sheet.hasHeaderRow, let header = sheet.rows.first {
            let keys = header.map(\.text)
            let rows = sheet.rows.dropFirst()
            out = "[\n" + rows.map { r in
                "  {" + keys.enumerated().map { k, key in
                    JSONValue.quote(key) + ": " + value(k < r.count ? r[k] : .empty)
                }.joined(separator: ", ") + "}"
            }.joined(separator: ",\n") + "\n]\n"
        } else {
            out = "[\n" + sheet.rows.map { r in "  [" + r.map(value).joined(separator: ", ") + "]" }.joined(separator: ",\n") + "\n]\n"
        }
        if sheet.rows.isEmpty { out = "[]\n" }
        return Data(out.utf8)
    }

    static func value(_ c: Cell) -> String {
        switch c {
        case .empty: "null"
        case .string(let s): JSONValue.quote(s)
        case .number(let d): d.isFinite ? Cell.format(d) : "null"
        case .bool(let b): b ? "true" : "false"
        case .date: JSONValue.quote(c.text)
        }
    }
}

public enum SheetHTMLWriter {
    public static func html(_ wb: Workbook, print: Bool) -> String {
        var body = ""
        let multi = wb.sheets.count > 1
        for (k, sh) in wb.sheets.enumerated() {
            if multi {
                body += "<h2\(print && k > 0 ? " class=\"sheet-break\"" : "")>\(XMLEscape.text(sh.name))</h2>\n"
            }
            body += table(sh)
        }
        let css = print ? HTMLWriter.printCSS + sheetCSS(print: true) : HTMLWriter.webCSS + sheetCSS(print: false)
        let title = wb.sheets.first?.name ?? ""
        return """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="generator" content="\(XMLEscape.text(Brand.name))">
        <title>\(XMLEscape.text(title))</title>
        <style>
        \(css)
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>

        """
    }

    static func sheetCSS(print: Bool) -> String {
        """

        body { \(print ? "" : "max-width: none; margin: 1.5em; ") }
        table.sheet { border-collapse: collapse; font-variant-numeric: tabular-nums; \(print ? "font-size: 8.5pt;" : "font-size: 0.92em;") }
        table.sheet td.n { text-align: right; white-space: nowrap; }
        table.sheet td, table.sheet th { white-space: pre-wrap; }
        h2.sheet-break { break-before: page; page-break-before: always; }
        """
    }

    static func table(_ sh: Sheet) -> String {
        guard !sh.rows.isEmpty else { return "<p></p>\n" }
        let n = sh.columnCount
        var s = "<table class=\"sheet\">\n"
        let header = sh.hasHeaderRow
        func cells(_ r: [Cell], tag: String) -> String {
            var out = "<tr>"
            for k in 0..<n {
                let c = k < r.count ? r[k] : .empty
                let cls: String
                switch c {
                case .number, .date: cls = tag == "td" ? " class=\"n\"" : ""
                default: cls = ""
                }
                out += "<\(tag)\(cls)>\(XMLEscape.text(c.text))</\(tag)>"
            }
            return out + "</tr>\n"
        }
        if header, let first = sh.rows.first { s += "<thead>\n" + cells(first, tag: "th") + "</thead>\n" }
        s += "<tbody>\n"
        for r in sh.rows.dropFirst(header ? 1 : 0) { s += cells(r, tag: "td") }
        return s + "</tbody>\n</table>\n"
    }

    /// Landscape when the widest sheet won't fit a portrait page comfortably.
    static func needsLandscape(_ wb: Workbook) -> Bool {
        for sh in wb.sheets {
            let n = sh.columnCount
            if n > 7 { return true }
            var total = 0
            for c in 0..<n { total += min(sh.rows.prefix(200).map { $0.count > c ? XLSXWriter.width($0[c]) : 0 }.max() ?? 0, 40) }
            if total > 90 { return true }
        }
        return false
    }
}
