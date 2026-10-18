import Foundation

/// Page geometry shared by the DOCX/ODT writers and the PDF renderer.
public enum PageSize: String, Sendable {
    case a4, letter

    /// Points.
    public var size: (width: Double, height: Double) {
        switch self {
        case .a4: (595.28, 841.89)
        case .letter: (612, 792)
        }
    }

    public static func from(_ options: OptionValues) -> PageSize {
        let fallback = Locale.current.region?.identifier == "US" ? "letter" : "a4"
        return PageSize(rawValue: options.string(OptionKey.pageSize, default: fallback)) ?? (fallback == "letter" ? .letter : .a4)
    }

    /// 1-inch margins, the Word/Pages default.
    public static let margin: Double = 72
}

/// `DocModel` → DOCX (WordprocessingML), written from scratch: real heading
/// styles (with outline levels), numbering definitions for nested lists, bordered
/// tables with repeating header rows, embedded images with EMU sizing, external
/// hyperlinks and core properties. Element order follows the OOXML schema, which
/// Word enforces.
public struct DOCXWriter {
    public var pageSize: PageSize
    public var zipOptions: ZipWriter.Options

    public init(pageSize: PageSize = .letter, zipOptions: ZipWriter.Options = .init()) {
        self.pageSize = pageSize
        self.zipOptions = zipOptions
    }

    public func write(_ doc: DocModel) throws -> Data {
        let b = DocxBuilder(pageSize: pageSize)
        let body = b.blocks(doc.blocks, ctx: .init())
        var zip = ZipWriter(options: zipOptions)
        try zip.add("[Content_Types].xml", b.contentTypes())
        try zip.add("_rels/.rels", Self.packageRels)
        try zip.add("docProps/core.xml", OOXMLCommon.coreXML(doc.metadata, date: zipOptions.deterministic ? Date(timeIntervalSince1970: 0) : zipOptions.date))
        try zip.add("docProps/app.xml", OOXMLCommon.appXML)
        try zip.add("word/document.xml", b.documentXML(body))
        try zip.add("word/styles.xml", DocxBuilder.stylesXML)
        try zip.add("word/numbering.xml", b.numberingXML())
        try zip.add("word/settings.xml", DocxBuilder.settingsXML)
        try zip.add("word/_rels/document.xml.rels", b.documentRels())
        for m in b.media { try zip.add("word/media/\(m.name)", m.data, compress: false) }
        return try zip.finish()
    }

    static let packageRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
    <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/extended-properties" Target="docProps/app.xml"/>
    </Relationships>
    """
}

/// Shared OOXML package bits (core/app properties).
enum OOXMLCommon {
    static func iso(_ d: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: d)
    }

    static func coreXML(_ m: DocMetadata, date: Date) -> String {
        var s = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:dcmitype="http://purl.org/dc/dcmitype/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

        """
        if let t = m.title { s += "<dc:title>\(XMLEscape.text(t))</dc:title>\n" }
        if let a = m.author { s += "<dc:creator>\(XMLEscape.text(a))</dc:creator>\n" }
        if let l = m.language { s += "<dc:language>\(XMLEscape.text(l))</dc:language>\n" }
        let d = iso(date)
        s += "<dcterms:created xsi:type=\"dcterms:W3CDTF\">\(d)</dcterms:created>\n"
        s += "<dcterms:modified xsi:type=\"dcterms:W3CDTF\">\(d)</dcterms:modified>\n"
        return s + "</cp:coreProperties>"
    }

    static var appXML: String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Properties xmlns="http://schemas.openxmlformats.org/officeDocument/2006/extended-properties" xmlns:vt="http://schemas.openxmlformats.org/officeDocument/2006/docPropsVTypes"><Application>\(XMLEscape.text(Brand.name))</Application></Properties>
        """
    }

    /// 1 pt = 12700 EMU, 1 pt = 20 twips.
    static func emu(_ points: Double) -> Int { Int((points * 12700).rounded()) }
}

/// Mutable state while emitting one document (relationships, media, numbering).
final class DocxBuilder {
    struct Media { let name: String; let data: Data; let mime: String }
    struct Ctx {
        var bold = false, italic = false, underline = false, strike = false, code = false, link = false
        var paragraphStyle: String?
        var listLevel = -1
        var cellHeader = false
        /// Heading runs also carry direct bold + size (half-points): AppKit's DOCX
        /// importer (TextEdit, textutil) ignores styles.xml entirely.
        var headingHalfPoints: Int?
    }

    let pageSize: PageSize
    private(set) var rels: [(id: String, type: String, target: String, external: Bool)] = []
    private(set) var media: [Media] = []
    private var nums: [(id: Int, abstract: Int, start: Int)] = []
    private var drawingID = 0
    private var mediaByHash: [String: (rid: String, name: String)] = [:]

    init(pageSize: PageSize) {
        self.pageSize = pageSize
        rels = [
            ("rId1", "styles", "styles.xml", false),
            ("rId2", "numbering", "numbering.xml", false),
            ("rId3", "settings", "settings.xml", false),
        ]
    }

    var textWidthPt: Double { pageSize.size.width - 2 * PageSize.margin }
    var textHeightPt: Double { pageSize.size.height - 2 * PageSize.margin }

    func addRel(type: String, target: String, external: Bool = false) -> String {
        let id = "rId\(rels.count + 1)"
        rels.append((id, type, target, external))
        return id
    }

    // MARK: Package parts

    func documentXML(_ body: String) -> String {
        let (w, h) = pageSize.size
        let tw = Int(w * 20), th = Int(h * 20)
        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><w:body>\(body)<w:sectPr><w:pgSz w:w="\(tw)" w:h="\(th)"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440" w:header="720" w:footer="720" w:gutter="0"/><w:cols w:space="720"/></w:sectPr></w:body></w:document>
        """
    }

    func documentRels() -> String {
        var s = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">"
        for r in rels {
            let mode = r.external ? " TargetMode=\"External\"" : ""
            s += "<Relationship Id=\"\(r.id)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/\(r.type)\" Target=\"\(XMLEscape.text(r.target))\"\(mode)/>"
        }
        return s + "</Relationships>"
    }

    func contentTypes() -> String {
        var s = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Default Extension="png" ContentType="image/png"/><Default Extension="jpeg" ContentType="image/jpeg"/><Default Extension="jpg" ContentType="image/jpeg"/><Default Extension="gif" ContentType="image/gif"/>
        """
        s += "<Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/>"
        s += "<Override PartName=\"/word/styles.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml\"/>"
        s += "<Override PartName=\"/word/numbering.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml\"/>"
        s += "<Override PartName=\"/word/settings.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml\"/>"
        s += "<Override PartName=\"/docProps/core.xml\" ContentType=\"application/vnd.openxmlformats-package.core-properties+xml\"/>"
        s += "<Override PartName=\"/docProps/app.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.extended-properties+xml\"/>"
        return s + "</Types>"
    }

    func numberingXML() -> String {
        var s = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<w:numbering xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">"
        // abstractNum 0: bullets, 1: decimal/letters/roman.
        let bullets = ["•", "◦", "▪"]
        s += "<w:abstractNum w:abstractNumId=\"0\"><w:multiLevelType w:val=\"hybridMultilevel\"/>"
        for l in 0..<9 {
            s += "<w:lvl w:ilvl=\"\(l)\"><w:start w:val=\"1\"/><w:numFmt w:val=\"bullet\"/><w:lvlText w:val=\"\(bullets[l % 3])\"/><w:lvlJc w:val=\"left\"/><w:pPr><w:ind w:left=\"\(720 * (l + 1))\" w:hanging=\"360\"/></w:pPr><w:rPr><w:rFonts w:ascii=\"Arial\" w:hAnsi=\"Arial\" w:cs=\"Arial\"/></w:rPr></w:lvl>"
        }
        s += "</w:abstractNum>"
        let fmts = ["decimal", "lowerLetter", "lowerRoman"]
        s += "<w:abstractNum w:abstractNumId=\"1\"><w:multiLevelType w:val=\"hybridMultilevel\"/>"
        for l in 0..<9 {
            s += "<w:lvl w:ilvl=\"\(l)\"><w:start w:val=\"1\"/><w:numFmt w:val=\"\(fmts[l % 3])\"/><w:lvlText w:val=\"%\(l + 1).\"/><w:lvlJc w:val=\"left\"/><w:pPr><w:ind w:left=\"\(720 * (l + 1))\" w:hanging=\"360\"/></w:pPr></w:lvl>"
        }
        s += "</w:abstractNum>"
        for n in nums {
            s += "<w:num w:numId=\"\(n.id)\"><w:abstractNumId w:val=\"\(n.abstract)\"/>"
            if n.abstract == 1 {
                // Restart every ordered list at its own start value, at every level.
                for l in 0..<9 { s += "<w:lvlOverride w:ilvl=\"\(l)\"><w:startOverride w:val=\"\(l == 0 ? n.start : 1)\"/></w:lvlOverride>" }
            }
            s += "</w:num>"
        }
        if nums.isEmpty { s += "<w:num w:numId=\"1\"><w:abstractNumId w:val=\"0\"/></w:num>" }
        return s + "</w:numbering>"
    }

    static let settingsXML = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:defaultTabStop w:val="720"/><w:characterSpacingControl w:val="doNotCompress"/><w:compat><w:compatSetting w:name="compatibilityMode" w:uri="http://schemas.microsoft.com/office/word" w:val="15"/></w:compat></w:settings>
    """

    static let headingSizes = [40, 32, 28, 24, 22, 22]

    static let stylesXML: String = {
        let font = "<w:rFonts w:ascii=\"Calibri\" w:hAnsi=\"Calibri\" w:eastAsia=\"Calibri\" w:cs=\"Calibri\"/>"
        let mono = "<w:rFonts w:ascii=\"Courier New\" w:hAnsi=\"Courier New\" w:eastAsia=\"Courier New\" w:cs=\"Courier New\"/>"
        var s = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:docDefaults><w:rPrDefault><w:rPr>\(font)<w:sz w:val="22"/><w:szCs w:val="22"/><w:lang w:val="en-US" w:eastAsia="en-US" w:bidi="ar-SA"/></w:rPr></w:rPrDefault><w:pPrDefault><w:pPr><w:spacing w:after="160" w:line="264" w:lineRule="auto"/></w:pPr></w:pPrDefault></w:docDefaults>
        <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:qFormat/></w:style>
        <w:style w:type="character" w:default="1" w:styleId="DefaultParagraphFont"><w:name w:val="Default Paragraph Font"/><w:uiPriority w:val="1"/><w:semiHidden/><w:unhideWhenUsed/></w:style>
        <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:after="240"/></w:pPr><w:rPr><w:b/><w:sz w:val="52"/><w:szCs w:val="52"/></w:rPr></w:style>

        """
        let sizes = headingSizes
        let before = [360, 320, 280, 240, 240, 200]
        for l in 1...6 {
            let italic = l >= 5 ? "<w:i/><w:iCs/>" : ""
            s += "<w:style w:type=\"paragraph\" w:styleId=\"Heading\(l)\"><w:name w:val=\"heading \(l)\"/><w:basedOn w:val=\"Normal\"/><w:next w:val=\"Normal\"/><w:uiPriority w:val=\"9\"/><w:qFormat/><w:pPr><w:keepNext/><w:keepLines/><w:spacing w:before=\"\(before[l - 1])\" w:after=\"120\"/><w:outlineLvl w:val=\"\(l - 1)\"/></w:pPr><w:rPr><w:b/><w:bCs/>\(italic)<w:color w:val=\"1A1A1A\"/><w:sz w:val=\"\(sizes[l - 1])\"/><w:szCs w:val=\"\(sizes[l - 1])\"/></w:rPr></w:style>\n"
        }
        s += """
        <w:style w:type="paragraph" w:styleId="Quote"><w:name w:val="Quote"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:pBdr><w:left w:val="single" w:sz="12" w:space="8" w:color="BFBFBF"/></w:pBdr><w:ind w:left="720" w:right="720"/></w:pPr><w:rPr><w:i/><w:iCs/><w:color w:val="404040"/></w:rPr></w:style>
        <w:style w:type="paragraph" w:styleId="SourceCode"><w:name w:val="Source Code"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:shd w:val="clear" w:color="auto" w:fill="F4F4F6"/><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr><w:rPr>\(mono)<w:sz w:val="19"/><w:szCs w:val="19"/></w:rPr></w:style>
        <w:style w:type="paragraph" w:styleId="ListParagraph"><w:name w:val="List Paragraph"/><w:basedOn w:val="Normal"/><w:uiPriority w:val="34"/><w:qFormat/><w:pPr><w:spacing w:after="60"/><w:ind w:left="720"/><w:contextualSpacing/></w:pPr></w:style>
        <w:style w:type="paragraph" w:styleId="Caption"><w:name w:val="caption"/><w:basedOn w:val="Normal"/><w:next w:val="Normal"/><w:qFormat/><w:pPr><w:spacing w:after="200"/></w:pPr><w:rPr><w:i/><w:iCs/><w:sz w:val="18"/><w:szCs w:val="18"/></w:rPr></w:style>
        <w:style w:type="paragraph" w:styleId="Figure"><w:name w:val="Figure"/><w:basedOn w:val="Normal"/><w:qFormat/><w:pPr><w:keepNext/><w:jc w:val="center"/></w:pPr></w:style>
        <w:style w:type="character" w:styleId="VerbatimChar"><w:name w:val="Verbatim Char"/><w:rPr>\(mono)<w:sz w:val="20"/><w:szCs w:val="20"/></w:rPr></w:style>
        <w:style w:type="character" w:styleId="Hyperlink"><w:name w:val="Hyperlink"/><w:basedOn w:val="DefaultParagraphFont"/><w:uiPriority w:val="99"/><w:unhideWhenUsed/><w:rPr><w:color w:val="0563C1"/><w:u w:val="single"/></w:rPr></w:style>
        <w:style w:type="table" w:default="1" w:styleId="TableNormal"><w:name w:val="Normal Table"/><w:uiPriority w:val="99"/><w:semiHidden/><w:unhideWhenUsed/><w:tblPr><w:tblInd w:w="0" w:type="dxa"/><w:tblCellMar><w:top w:w="0" w:type="dxa"/><w:left w:w="108" w:type="dxa"/><w:bottom w:w="0" w:type="dxa"/><w:right w:w="108" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>
        <w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:basedOn w:val="TableNormal"/><w:uiPriority w:val="39"/><w:pPr><w:spacing w:after="0" w:line="240" w:lineRule="auto"/></w:pPr><w:tblPr><w:tblBorders><w:top w:val="single" w:sz="4" w:space="0" w:color="A6A6A6"/><w:left w:val="single" w:sz="4" w:space="0" w:color="A6A6A6"/><w:bottom w:val="single" w:sz="4" w:space="0" w:color="A6A6A6"/><w:right w:val="single" w:sz="4" w:space="0" w:color="A6A6A6"/><w:insideH w:val="single" w:sz="4" w:space="0" w:color="A6A6A6"/><w:insideV w:val="single" w:sz="4" w:space="0" w:color="A6A6A6"/></w:tblBorders><w:tblCellMar><w:top w:w="40" w:type="dxa"/><w:left w:w="100" w:type="dxa"/><w:bottom w:w="40" w:type="dxa"/><w:right w:w="100" w:type="dxa"/></w:tblCellMar></w:tblPr></w:style>
        </w:styles>
        """
        return s
    }()

    // MARK: Blocks

    func blocks(_ bs: [DocBlock], ctx: Ctx) -> String {
        var s = ""
        for b in bs { s += block(b, ctx: ctx) }
        return s
    }

    func block(_ b: DocBlock, ctx: Ctx) -> String {
        switch b {
        case .heading(let level, let inl):
            if ctx.paragraphStyle == "Quote" { return paragraph(inl, style: "Quote", ctx: ctx) }
            let l = min(max(level, 1), 6)
            var c = ctx
            c.bold = true
            c.headingHalfPoints = Self.headingSizes[l - 1]
            return paragraph(inl, style: "Heading\(l)", ctx: c)
        case .paragraph(let inl):
            return paragraph(inl, style: ctx.paragraphStyle, ctx: ctx)
        case .list(let l):
            return list(l, ctx: ctx)
        case .table(let t):
            return table(t, ctx: ctx) + "<w:p><w:pPr><w:spacing w:after=\"0\"/></w:pPr></w:p>"
        case .image(let im):
            guard let run = drawing(im) else { return im.alt.isEmpty ? "" : paragraph([.text(im.alt)], style: nil, ctx: ctx) }
            var s = "<w:p><w:pPr><w:pStyle w:val=\"Figure\"/></w:pPr>\(run)</w:p>"
            if !im.alt.isEmpty, im.alt.count > 3 { s += paragraph([.text(im.alt)], style: "Caption", ctx: ctx, jc: "center") }
            return s
        case .codeBlock(_, let code):
            let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
            var runs = ""
            for (k, line) in lines.enumerated() {
                if k > 0 { runs += "<w:r><w:br/></w:r>" }
                runs += textRun(String(line), rPr: "")
            }
            return "<w:p><w:pPr><w:pStyle w:val=\"SourceCode\"/></w:pPr>\(runs)</w:p><w:p><w:pPr><w:spacing w:after=\"0\"/></w:pPr></w:p>"
        case .blockquote(let inner):
            var c = ctx
            c.paragraphStyle = "Quote"
            return blocks(inner, ctx: c)
        case .horizontalRule:
            return "<w:p><w:pPr><w:pBdr><w:bottom w:val=\"single\" w:sz=\"6\" w:space=\"1\" w:color=\"A6A6A6\"/></w:pBdr></w:pPr></w:p>"
        case .pageBreak:
            return "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
        }
    }

    func paragraph(_ inl: [DocInline], style: String?, ctx: Ctx, numPr: (num: Int, level: Int)? = nil, indentLevel: Int? = nil, jc: String? = nil) -> String {
        var pPr = ""
        if let style { pPr += "<w:pStyle w:val=\"\(style)\"/>" }
        if let numPr { pPr += "<w:numPr><w:ilvl w:val=\"\(numPr.level)\"/><w:numId w:val=\"\(numPr.num)\"/></w:numPr>" }
        if let indentLevel { pPr += "<w:ind w:left=\"\(720 * (indentLevel + 1))\"/>" }
        if let jc { pPr += "<w:jc w:val=\"\(jc)\"/>" }
        let runs = inlines(inl, ctx: ctx)
        return "<w:p>" + (pPr.isEmpty ? "" : "<w:pPr>\(pPr)</w:pPr>") + runs + "</w:p>"
    }

    func list(_ l: DocList, ctx: Ctx) -> String {
        let numID = nums.count + 1
        nums.append((numID, l.ordered ? 1 : 0, l.start))
        let level = min(ctx.listLevel + 1, 8)
        var c = ctx
        c.listLevel = level
        var s = ""
        for item in l.items {
            var first = true
            var prefix: [DocInline] = []
            if let checked = item.checked { prefix = [.text(checked ? "☑ " : "☐ ")] }
            if item.blocks.isEmpty {
                s += paragraph(prefix, style: "ListParagraph", ctx: c, numPr: (numID, level))
                continue
            }
            for b in item.blocks {
                switch b {
                case .paragraph(let inl) where first, .heading(_, let inl) where first:
                    s += paragraph(prefix + inl, style: "ListParagraph", ctx: c, numPr: (numID, level))
                case .paragraph(let inl):
                    s += paragraph(inl, style: "ListParagraph", ctx: c, indentLevel: level)
                case .list(let nested):
                    if first { s += paragraph(prefix, style: "ListParagraph", ctx: c, numPr: (numID, level)) }
                    s += list(nested, ctx: c)
                default:
                    if first { s += paragraph(prefix, style: "ListParagraph", ctx: c, numPr: (numID, level)) }
                    s += block(b, ctx: c)
                }
                first = false
            }
        }
        return s
    }

    func table(_ table: DocTable, ctx: Ctx) -> String {
        let t = table.normalized
        guard t.columnCount > 0 else { return "" }
        let n = t.columnCount
        let totalTwips = Int(textWidthPt * 20)
        // Column widths proportional to content length, clamped so no column vanishes.
        var weights = [Double](repeating: 1, count: n)
        for r in t.rows {
            for (k, c) in r.cells.enumerated() {
                let len = Double(c.blocks.map(\.plainText).joined(separator: " ").count)
                weights[k] = max(weights[k], min(len, 60))
            }
        }
        let sum = weights.reduce(0, +)
        let widths = weights.map { max(Int(Double(totalTwips) * $0 / sum), 600) }
        var s = "<w:tbl><w:tblPr><w:tblStyle w:val=\"TableGrid\"/><w:tblW w:w=\"5000\" w:type=\"pct\"/><w:tblLook w:val=\"04A0\" w:firstRow=\"1\" w:lastRow=\"0\" w:firstColumn=\"0\" w:lastColumn=\"0\" w:noHBand=\"0\" w:noVBand=\"1\"/></w:tblPr><w:tblGrid>"
        for w in widths { s += "<w:gridCol w:w=\"\(w)\"/>" }
        s += "</w:tblGrid>"
        var c = ctx
        c.paragraphStyle = nil
        c.listLevel = -1
        for (ri, r) in t.rows.enumerated() {
            let header = r.isHeader && t.rows.prefix(ri + 1).allSatisfy(\.isHeader)
            s += "<w:tr>"
            if header { s += "<w:trPr><w:cantSplit/><w:tblHeader/></w:trPr>" } else { s += "<w:trPr><w:cantSplit/></w:trPr>" }
            for (k, cell) in r.cells.enumerated() {
                s += "<w:tc><w:tcPr><w:tcW w:w=\"\(widths[min(k, widths.count - 1)])\" w:type=\"dxa\"/>"
                if r.isHeader { s += "<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"F2F2F2\"/>" }
                s += "</w:tcPr>"
                var cc = c
                cc.bold = c.bold || r.isHeader
                let align = k < t.alignments.count ? t.alignments[k] : .none
                let jc: String? = align == .center ? "center" : (align == .right ? "right" : nil)
                var inner = ""
                for b in cell.blocks {
                    if case .paragraph(let inl) = b { inner += paragraph(inl, style: nil, ctx: cc, jc: jc) } else { inner += block(b, ctx: cc) }
                }
                // A cell must end with a paragraph.
                if inner.isEmpty || !inner.hasSuffix("</w:p>") { inner += "<w:p/>" }
                s += inner + "</w:tc>"
            }
            s += "</w:tr>"
        }
        s += "</w:tbl>"
        if !t.caption.isEmpty { s = paragraph(t.caption, style: "Caption", ctx: ctx) + s }
        return s
    }

    // MARK: Inlines

    func inlines(_ a: [DocInline], ctx: Ctx) -> String {
        var s = ""
        for i in a { s += inline(i, ctx: ctx) }
        return s
    }

    func inline(_ i: DocInline, ctx: Ctx) -> String {
        var c = ctx
        switch i {
        case .text(let t): return textRun(t, rPr: rPr(ctx))
        case .emphasis(let k): c.italic = true; return inlines(k, ctx: c)
        case .strong(let k): c.bold = true; return inlines(k, ctx: c)
        case .underline(let k): c.underline = true; return inlines(k, ctx: c)
        case .strikethrough(let k): c.strike = true; return inlines(k, ctx: c)
        case .code(let t): c.code = true; return textRun(t, rPr: rPr(c))
        case .lineBreak: return "<w:r><w:br/></w:r>"
        case .image(let im): return drawing(im) ?? textRun(im.alt, rPr: rPr(ctx))
        case .link(let url, let k):
            c.link = true
            let content = inlines(k, ctx: c)
            if url.hasPrefix("#") {
                return "<w:hyperlink w:anchor=\"\(XMLEscape.text(String(url.dropFirst())))\" w:history=\"1\">\(content)</w:hyperlink>"
            }
            guard let safe = HTMLWriter.safeHref(url), !safe.isEmpty else { return inlines(k, ctx: ctx) }
            let rid = addRel(type: "hyperlink", target: safe, external: true)
            return "<w:hyperlink r:id=\"\(rid)\" w:history=\"1\">\(content)</w:hyperlink>"
        }
    }

    func rPr(_ c: Ctx) -> String {
        var s = ""
        if c.code { s += "<w:rStyle w:val=\"VerbatimChar\"/>" } else if c.link { s += "<w:rStyle w:val=\"Hyperlink\"/>" }
        if c.bold { s += "<w:b/><w:bCs/>" }
        if c.italic { s += "<w:i/><w:iCs/>" }
        if c.strike { s += "<w:strike/>" }
        if let hp = c.headingHalfPoints { s += "<w:sz w:val=\"\(hp)\"/><w:szCs w:val=\"\(hp)\"/>" }
        if c.underline && !c.link { s += "<w:u w:val=\"single\"/>" }
        return s
    }

    func textRun(_ text: String, rPr: String) -> String {
        guard !text.isEmpty else { return "" }
        let props = rPr.isEmpty ? "" : "<w:rPr>\(rPr)</w:rPr>"
        var s = "<w:r>\(props)"
        var buf = ""
        func flush() {
            if !buf.isEmpty { s += "<w:t xml:space=\"preserve\">\(XMLEscape.text(buf))</w:t>"; buf = "" }
        }
        for ch in text {
            switch ch {
            case "\t": flush(); s += "<w:tab/>"
            case "\n", "\u{2028}": flush(); s += "<w:br/>"
            default: buf.append(ch)
            }
        }
        flush()
        return s + "</w:r>"
    }

    /// Inline picture run (`w:drawing`), or nil when there's nothing embeddable.
    func drawing(_ im: DocImage) -> String? {
        guard let portable = ImageSupport.portable(im) else { return nil }
        let key = "\(CRC32.checksum(portable.data))-\(portable.data.count)"
        let rid: String, name: String
        if let existing = mediaByHash[key] {
            (rid, name) = existing
        } else {
            let ext = ImageSupport.fileExtension(forMIME: portable.mime)
            name = "image\(media.count + 1).\(ext == "jpg" ? "jpeg" : ext)"
            media.append(Media(name: name, data: portable.data, mime: portable.mime))
            rid = addRel(type: "image", target: "media/\(name)")
            mediaByHash[key] = (rid, name)
        }
        var size = ImageSupport.displaySize(DocImage(data: portable.data, mime: portable.mime, alt: im.alt, width: im.width, height: im.height)) ?? (200, 150)
        size = ImageSupport.fit(size, maxWidth: textWidthPt, maxHeight: textHeightPt * 0.9)
        let cx = OOXMLCommon.emu(size.width), cy = OOXMLCommon.emu(size.height)
        drawingID += 1
        let id = drawingID
        let alt = XMLEscape.text(im.alt)
        return """
        <w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="\(cx)" cy="\(cy)"/><wp:effectExtent l="0" t="0" r="0" b="0"/><wp:docPr id="\(id)" name="Picture \(id)" descr="\(alt)"/><wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr><a:graphic><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic><pic:nvPicPr><pic:cNvPr id="\(id)" name="\(name)" descr="\(alt)"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip r:embed="\(rid)"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>
        """
    }
}
