import Foundation

/// `DocModel` → ODT (OpenDocument Text 1.2): outline headings, list styles for
/// bullets and numbers, tables with header rows, embedded pictures, links.
public struct ODTWriter {
    public var pageSize: PageSize
    public var zipOptions: ZipWriter.Options

    public init(pageSize: PageSize = .a4, zipOptions: ZipWriter.Options = .init()) {
        self.pageSize = pageSize
        self.zipOptions = zipOptions
    }

    static let ns = """
    xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0" xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0" xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0" xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0" xmlns:xlink="http://www.w3.org/1999/xlink" xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0" xmlns:number="urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0" xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"
    """

    public func write(_ doc: DocModel) throws -> Data {
        let b = ODTBuilder(textWidth: pageSize.size.width - 2 * PageSize.margin, textHeight: pageSize.size.height - 2 * PageSize.margin)
        let body = b.blocks(doc.blocks, ctx: .init())
        var zip = ZipWriter(options: zipOptions)
        try zip.add("mimetype", "application/vnd.oasis.opendocument.text", compress: false)
        try zip.add("META-INF/manifest.xml", manifest(media: b.media.map { ($0.name, $0.mime) }, type: "application/vnd.oasis.opendocument.text"))
        try zip.add("content.xml", contentXML(body))
        try zip.add("styles.xml", stylesXML())
        try zip.add("meta.xml", Self.metaXML(doc.metadata, date: zipOptions.deterministic ? Date(timeIntervalSince1970: 0) : zipOptions.date))
        for m in b.media { try zip.add("Pictures/\(m.name)", m.data, compress: false) }
        return try zip.finish()
    }

    func manifest(media: [(String, String)], type: String) -> String {
        var s = """
        <?xml version="1.0" encoding="UTF-8"?>
        <manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.2">
         <manifest:file-entry manifest:full-path="/" manifest:version="1.2" manifest:media-type="\(type)"/>
         <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
         <manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>
         <manifest:file-entry manifest:full-path="meta.xml" manifest:media-type="text/xml"/>

        """
        for (name, mime) in media { s += " <manifest:file-entry manifest:full-path=\"Pictures/\(name)\" manifest:media-type=\"\(mime)\"/>\n" }
        return s + "</manifest:manifest>"
    }

    static func metaXML(_ m: DocMetadata, date: Date) -> String {
        var s = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<office:document-meta \(ns) office:version=\"1.2\"><office:meta><meta:generator>\(XMLEscape.text(Brand.name))</meta:generator>"
        if let t = m.title { s += "<dc:title>\(XMLEscape.text(t))</dc:title>" }
        if let a = m.author { s += "<meta:initial-creator>\(XMLEscape.text(a))</meta:initial-creator><dc:creator>\(XMLEscape.text(a))</dc:creator>" }
        if let l = m.language { s += "<dc:language>\(XMLEscape.text(l))</dc:language>" }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        s += "<meta:creation-date>\(f.string(from: date).replacingOccurrences(of: "Z", with: ""))</meta:creation-date>"
        return s + "</office:meta></office:document-meta>"
    }

    func contentXML(_ body: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <office:document-content \(Self.ns) office:version="1.2"><office:automatic-styles>\
        <style:style style:name="T_b" style:family="text"><style:text-properties fo:font-weight="bold" style:font-weight-asian="bold" style:font-weight-complex="bold"/></style:style>\
        <style:style style:name="T_i" style:family="text"><style:text-properties fo:font-style="italic" style:font-style-asian="italic" style:font-style-complex="italic"/></style:style>\
        <style:style style:name="T_u" style:family="text"><style:text-properties style:text-underline-style="solid" style:text-underline-width="auto" style:text-underline-color="font-color"/></style:style>\
        <style:style style:name="T_s" style:family="text"><style:text-properties style:text-line-through-style="solid"/></style:style>\
        <style:style style:name="P_Break" style:family="paragraph" style:parent-style-name="Standard"><style:paragraph-properties fo:break-before="page"/></style:style>\
        <style:style style:name="P_Figure" style:family="paragraph" style:parent-style-name="Standard"><style:paragraph-properties fo:text-align="center" fo:margin-bottom="0.2cm"/></style:style>\
        <style:style style:name="Tbl" style:family="table"><style:table-properties style:width="\(fmt(pageSize.size.width - 2 * PageSize.margin))pt" table:align="margins" fo:margin-top="0.1cm" fo:margin-bottom="0.3cm"/></style:style>\
        <style:style style:name="TC" style:family="table-cell"><style:table-cell-properties fo:padding="0.1cm" fo:border="0.5pt solid #a6a6a6"/></style:style>\
        <style:style style:name="TCH" style:family="table-cell"><style:table-cell-properties fo:background-color="#f2f2f2" fo:padding="0.1cm" fo:border="0.5pt solid #a6a6a6"/></style:style>\
        <style:style style:name="fr1" style:family="graphic" style:parent-style-name="Graphics"><style:graphic-properties style:vertical-pos="top" style:vertical-rel="baseline"/></style:style>\
        </office:automatic-styles><office:body><office:text>\(body)</office:text></office:body></office:document-content>
        """
    }

    func fmt(_ v: Double) -> String { String(format: "%.2f", v) }

    func stylesXML() -> String {
        let (w, h) = pageSize.size
        var s = """
        <?xml version="1.0" encoding="UTF-8"?>
        <office:document-styles \(Self.ns) office:version="1.2"><office:styles>\
        <style:default-style style:family="paragraph"><style:paragraph-properties style:writing-mode="page"/><style:text-properties fo:font-family="Helvetica, Arial, sans-serif" fo:font-size="11pt" fo:language="en" fo:country="US"/></style:default-style>\
        <style:style style:name="Standard" style:family="paragraph" style:class="text"/>\
        <style:style style:name="Text_20_body" style:display-name="Text body" style:family="paragraph" style:parent-style-name="Standard" style:class="text"><style:paragraph-properties fo:margin-top="0cm" fo:margin-bottom="0.25cm" fo:line-height="120%"/></style:style>\
        <style:style style:name="List_20_Paragraph" style:display-name="List Paragraph" style:family="paragraph" style:parent-style-name="Standard" style:class="list"><style:paragraph-properties fo:margin-top="0cm" fo:margin-bottom="0.1cm"/></style:style>\
        <style:style style:name="Heading" style:family="paragraph" style:parent-style-name="Standard" style:next-style-name="Text_20_body" style:class="text"><style:paragraph-properties fo:margin-top="0.42cm" fo:margin-bottom="0.21cm" fo:keep-with-next="always"/><style:text-properties fo:font-weight="bold" style:font-weight-asian="bold" style:font-weight-complex="bold"/></style:style>
        """
        let sizes = [20, 16, 14, 12, 11, 11]
        for l in 1...6 {
            s += "<style:style style:name=\"Heading_20_\(l)\" style:display-name=\"Heading \(l)\" style:family=\"paragraph\" style:parent-style-name=\"Heading\" style:next-style-name=\"Text_20_body\" style:default-outline-level=\"\(l)\" style:class=\"text\"><style:text-properties fo:font-size=\"\(sizes[l - 1])pt\"\(l >= 5 ? " fo:font-style=\"italic\"" : "")/></style:style>"
        }
        s += """
        <style:style style:name="Quotations" style:family="paragraph" style:parent-style-name="Standard" style:class="html"><style:paragraph-properties fo:margin-left="1cm" fo:margin-right="1cm" fo:margin-top="0cm" fo:margin-bottom="0.25cm" fo:padding-left="0.2cm" fo:border-left="1.5pt solid #bfbfbf" fo:border-right="none" fo:border-top="none" fo:border-bottom="none"/><style:text-properties fo:font-style="italic" fo:color="#404040"/></style:style>\
        <style:style style:name="Preformatted_20_Text" style:display-name="Preformatted Text" style:family="paragraph" style:parent-style-name="Standard" style:class="html"><style:paragraph-properties fo:margin-top="0cm" fo:margin-bottom="0cm" fo:background-color="#f4f4f6"/><style:text-properties fo:font-family="'Courier New', monospace" style:font-family-generic="modern" fo:font-size="9.5pt"/></style:style>\
        <style:style style:name="Table_20_Contents" style:display-name="Table Contents" style:family="paragraph" style:parent-style-name="Standard" style:class="extra"/>\
        <style:style style:name="Table_20_Heading" style:display-name="Table Heading" style:family="paragraph" style:parent-style-name="Table_20_Contents" style:class="extra"><style:text-properties fo:font-weight="bold"/></style:style>\
        <style:style style:name="Caption" style:family="paragraph" style:parent-style-name="Standard" style:class="extra"><style:paragraph-properties fo:text-align="center" fo:margin-bottom="0.25cm"/><style:text-properties fo:font-size="9pt" fo:font-style="italic"/></style:style>\
        <style:style style:name="Horizontal_20_Line" style:display-name="Horizontal Line" style:family="paragraph" style:parent-style-name="Standard" style:class="html"><style:paragraph-properties fo:margin-top="0cm" fo:margin-bottom="0.3cm" fo:padding="0cm" fo:border-left="none" fo:border-right="none" fo:border-top="none" fo:border-bottom="0.75pt solid #a6a6a6"/></style:style>\
        <style:style style:name="Internet_20_link" style:display-name="Internet link" style:family="text"><style:text-properties fo:color="#0563c1" style:text-underline-style="solid" style:text-underline-width="auto" style:text-underline-color="font-color"/></style:style>\
        <style:style style:name="Source_20_Text" style:display-name="Source Text" style:family="text"><style:text-properties fo:font-family="'Courier New', monospace" style:font-family-generic="modern"/></style:style>\
        <style:style style:name="Graphics" style:family="graphic"><style:graphic-properties text:anchor-type="as-char" svg:y="0cm" style:vertical-pos="top" style:vertical-rel="baseline"/></style:style>
        """
        s += listStyle("L_bullet", ordered: false) + listStyle("L_number", ordered: true)
        s += """
        </office:styles><office:automatic-styles><style:page-layout style:name="pm1"><style:page-layout-properties fo:page-width="\(fmt(w))pt" fo:page-height="\(fmt(h))pt" style:print-orientation="portrait" fo:margin-top="72pt" fo:margin-bottom="72pt" fo:margin-left="72pt" fo:margin-right="72pt"/></style:page-layout></office:automatic-styles><office:master-styles><style:master-page style:name="Standard" style:page-layout-name="pm1"/></office:master-styles></office:document-styles>
        """
        return s
    }

    func listStyle(_ name: String, ordered: Bool) -> String {
        var s = "<text:list-style style:name=\"\(name)\">"
        let bullets = ["•", "◦", "▪"]
        let formats = ["1", "a", "i"]
        for l in 1...10 {
            let props = "<style:list-level-properties text:list-level-position-and-space-mode=\"label-alignment\"><style:list-level-label-alignment text:label-followed-by=\"listtab\" text:list-tab-stop-position=\"\(fmt(Double(l) * 0.635 + 0.635))cm\" fo:text-indent=\"-0.635cm\" fo:margin-left=\"\(fmt(Double(l) * 0.635 + 0.635))cm\"/></style:list-level-properties>"
            if ordered {
                s += "<text:list-level-style-number text:level=\"\(l)\" style:num-suffix=\".\" style:num-format=\"\(formats[(l - 1) % 3])\">\(props)</text:list-level-style-number>"
            } else {
                s += "<text:list-level-style-bullet text:level=\"\(l)\" text:bullet-char=\"\(bullets[(l - 1) % 3])\">\(props)</text:list-level-style-bullet>"
            }
        }
        return s + "</text:list-style>"
    }
}

final class ODTBuilder {
    struct Media { let name: String; let data: Data; let mime: String }
    struct Ctx {
        var paraStyle = "Text_20_body"
        var inList = false
        var header = false
    }

    let textWidth: Double
    let textHeight: Double
    private(set) var media: [Media] = []
    private var mediaByKey: [String: String] = [:]
    private var frameCount = 0
    private var tableCount = 0

    init(textWidth: Double, textHeight: Double) {
        self.textWidth = textWidth
        self.textHeight = textHeight
    }

    func blocks(_ bs: [DocBlock], ctx: Ctx) -> String { bs.map { block($0, ctx: ctx) }.joined() }

    func block(_ b: DocBlock, ctx: Ctx) -> String {
        switch b {
        case .heading(let level, let inl):
            if ctx.inList || ctx.paraStyle == "Quotations" { return "<text:p text:style-name=\"\(ctx.paraStyle)\">\(inlines(inl))</text:p>" }
            let l = min(max(level, 1), 6)
            return "<text:h text:style-name=\"Heading_20_\(l)\" text:outline-level=\"\(l)\">\(inlines(inl))</text:h>"
        case .paragraph(let inl):
            return "<text:p text:style-name=\"\(ctx.paraStyle)\">\(inlines(inl))</text:p>"
        case .list(let l):
            return list(l, ctx: ctx)
        case .table(let t):
            return table(t)
        case .image(let im):
            guard let frame = frame(im) else { return im.alt.isEmpty ? "" : "<text:p text:style-name=\"\(ctx.paraStyle)\">\(esc(im.alt))</text:p>" }
            return "<text:p text:style-name=\"P_Figure\">\(frame)</text:p>"
        case .codeBlock(_, let code):
            return code.split(separator: "\n", omittingEmptySubsequences: false).map { "<text:p text:style-name=\"Preformatted_20_Text\">\(text(String($0)))</text:p>" }.joined()
        case .blockquote(let inner):
            var c = ctx
            c.paraStyle = "Quotations"
            return blocks(inner, ctx: c)
        case .horizontalRule:
            return "<text:p text:style-name=\"Horizontal_20_Line\"/>"
        case .pageBreak:
            return "<text:p text:style-name=\"P_Break\"/>"
        }
    }

    func list(_ l: DocList, ctx: Ctx) -> String {
        var c = ctx
        c.inList = true
        if c.paraStyle == "Text_20_body" { c.paraStyle = "List_20_Paragraph" }
        var s = "<text:list text:style-name=\"\(l.ordered ? "L_number" : "L_bullet")\">"
        for (k, item) in l.items.enumerated() {
            let start = l.ordered && k == 0 && l.start != 1 ? " text:start-value=\"\(l.start)\"" : ""
            s += "<text:list-item\(start)>"
            var blocks = item.blocks
            if let checked = item.checked {
                let box: DocInline = .text(checked ? "☑ " : "☐ ")
                if let f = blocks.first, case .paragraph(let inl) = f { blocks[0] = .paragraph([box] + inl) } else { blocks.insert(.paragraph([box]), at: 0) }
            }
            if blocks.isEmpty { s += "<text:p text:style-name=\"\(c.paraStyle)\"/>" }
            for b in blocks {
                // A list item may only contain paragraphs, headings and lists.
                switch b {
                case .paragraph, .heading, .list: s += block(b, ctx: c)
                case .table(let t): s += "<text:p text:style-name=\"\(c.paraStyle)\">\(esc(DocBlock.table(t).plainText.replacingOccurrences(of: "\n", with: "; ")))</text:p>"
                default: s += block(b, ctx: c)
                }
            }
            s += "</text:list-item>"
        }
        return s + "</text:list>"
    }

    func table(_ table: DocTable) -> String {
        let t = table.normalized
        let n = t.columnCount
        guard n > 0 else { return "" }
        tableCount += 1
        var s = ""
        if !t.caption.isEmpty { s += "<text:p text:style-name=\"Caption\">\(inlines(t.caption))</text:p>" }
        s += "<table:table table:name=\"Table\(tableCount)\" table:style-name=\"Tbl\"><table:table-column table:number-columns-repeated=\"\(n)\"/>"
        let headCount = t.rows.prefix { $0.isHeader }.count
        func row(_ r: DocTableRow, header: Bool) -> String {
            var out = "<table:table-row>"
            for c in r.cells {
                out += "<table:table-cell table:style-name=\"\(header ? "TCH" : "TC")\" office:value-type=\"string\">"
                var cc = Ctx()
                cc.paraStyle = header ? "Table_20_Heading" : "Table_20_Contents"
                var inner = ""
                for b in c.blocks {
                    switch b {
                    case .table(let nested): inner += "<text:p text:style-name=\"\(cc.paraStyle)\">\(esc(DocBlock.table(nested).plainText))</text:p>"
                    default: inner += block(b, ctx: cc)
                    }
                }
                if inner.isEmpty { inner = "<text:p text:style-name=\"\(cc.paraStyle)\"/>" }
                out += inner + "</table:table-cell>"
            }
            return out + "</table:table-row>"
        }
        if headCount > 0 {
            s += "<table:table-header-rows>" + t.rows.prefix(headCount).map { row($0, header: true) }.joined() + "</table:table-header-rows>"
        }
        s += t.rows.dropFirst(headCount).map { row($0, header: $0.isHeader) }.joined()
        return s + "</table:table>"
    }

    func inlines(_ a: [DocInline]) -> String { a.map(inline).joined() }

    func inline(_ i: DocInline) -> String {
        switch i {
        case .text(let t): return text(t)
        case .strong(let c): return "<text:span text:style-name=\"T_b\">\(inlines(c))</text:span>"
        case .emphasis(let c): return "<text:span text:style-name=\"T_i\">\(inlines(c))</text:span>"
        case .underline(let c): return "<text:span text:style-name=\"T_u\">\(inlines(c))</text:span>"
        case .strikethrough(let c): return "<text:span text:style-name=\"T_s\">\(inlines(c))</text:span>"
        case .code(let t): return "<text:span text:style-name=\"Source_20_Text\">\(text(t))</text:span>"
        case .lineBreak: return "<text:line-break/>"
        case .image(let im): return frame(im) ?? text(im.alt)
        case .link(let url, let c):
            guard let safe = HTMLWriter.safeHref(url) else { return inlines(c) }
            return "<text:a xlink:type=\"simple\" xlink:href=\"\(esc(safe))\" text:style-name=\"Internet_20_link\">\(inlines(c))</text:a>"
        }
    }

    /// Text with ODF whitespace rules: runs of spaces → `<text:s/>`, tabs, newlines.
    func text(_ s: String) -> String {
        var out = ""
        var spaces = 0
        var atStart = true
        func flushSpaces() {
            guard spaces > 0 else { return }
            if atStart || spaces > 1 {
                let literal = atStart ? 0 : 1
                if literal == 1 { out += " " }
                let rest = spaces - literal
                if rest > 0 { out += rest == 1 ? "<text:s/>" : "<text:s text:c=\"\(rest)\"/>" }
            } else { out += " " }
            spaces = 0
        }
        for ch in s {
            switch ch {
            case " ": spaces += 1
            case "\t": flushSpaces(); out += "<text:tab/>"; atStart = false
            case "\n": flushSpaces(); out += "<text:line-break/>"; atStart = false
            default:
                flushSpaces()
                out += XMLEscape.text(String(ch))
                atStart = false
            }
        }
        flushSpaces()
        return out
    }

    func frame(_ im: DocImage) -> String? {
        guard let p = ImageSupport.portable(im) else { return nil }
        let key = "\(CRC32.checksum(p.data))-\(p.data.count)"
        let name: String
        if let n = mediaByKey[key] { name = n } else {
            name = "image\(media.count + 1).\(ImageSupport.fileExtension(forMIME: p.mime))"
            media.append(Media(name: name, data: p.data, mime: p.mime))
            mediaByKey[key] = name
        }
        var size = ImageSupport.displaySize(DocImage(data: p.data, mime: p.mime, width: im.width, height: im.height)) ?? (200, 150)
        size = ImageSupport.fit(size, maxWidth: textWidth, maxHeight: textHeight * 0.9)
        frameCount += 1
        let desc = im.alt.isEmpty ? "" : "<svg:desc>\(esc(im.alt))</svg:desc>"
        return "<draw:frame draw:style-name=\"fr1\" draw:name=\"Image\(frameCount)\" text:anchor-type=\"as-char\" svg:width=\"\(String(format: "%.2f", size.width))pt\" svg:height=\"\(String(format: "%.2f", size.height))pt\" draw:z-index=\"0\"><draw:image xlink:href=\"Pictures/\(name)\" xlink:type=\"simple\" xlink:show=\"embed\" xlink:actuate=\"onLoad\"/>\(desc)</draw:frame>"
    }

    func esc(_ s: String) -> String { XMLEscape.text(s) }
}
