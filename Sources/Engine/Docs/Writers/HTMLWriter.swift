import Foundation

/// `DocModel` → HTML. Three flavours share one renderer:
/// - standalone web page (images as data URIs, light/dark CSS),
/// - print (for WebKit → PDF: page breaks, repeating table headers, no remote refs),
/// - XHTML chapters for EPUB (well-formed XML, images as package files).
public struct HTMLWriter {
    public enum ImageMode {
        /// Embed bytes as `data:` URIs. Remote references are kept as plain links.
        case dataURI
        /// Package-relative hrefs supplied by the caller (EPUB). Return nil to drop the image.
        case external(@Sendable (DocImage) -> String?)
    }

    public enum Flavor { case web, print, xhtml }

    public var flavor: Flavor
    public var imageMode: ImageMode
    /// Extra CSS appended after the built-in stylesheet.
    public var extraCSS: String = ""
    /// For `.xhtml`: stylesheet href to link instead of inline CSS.
    public var stylesheetHref: String?
    /// When set, top-level headings get `id="<prefix><block index>"` (EPUB navigation targets).
    public var headingIDPrefix: String?

    public init(flavor: Flavor = .web, imageMode: ImageMode = .dataURI) {
        self.flavor = flavor
        self.imageMode = imageMode
    }

    // MARK: Documents

    public func document(_ doc: DocModel, blocks: [DocBlock]? = nil, title: String? = nil) -> String {
        let t = esc(title ?? doc.displayTitle ?? "")
        let lang = esc(doc.metadata.language ?? "en")
        let content = topLevel(blocks ?? doc.blocks)
        let author = doc.metadata.author.map { "<meta name=\"author\" content=\"\(esc($0))\"\(selfClose)>\n" } ?? ""
        switch flavor {
        case .xhtml:
            let link = stylesheetHref.map { "<link rel=\"stylesheet\" type=\"text/css\" href=\"\(esc($0))\"/>\n" } ?? ""
            return """
            <?xml version="1.0" encoding="UTF-8"?>
            <!DOCTYPE html>
            <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" lang="\(lang)" xml:lang="\(lang)">
            <head>
            <meta charset="utf-8"/>
            <title>\(t)</title>
            \(link)</head>
            <body>
            \(content)
            </body>
            </html>

            """
        case .web, .print:
            let css = (flavor == .print ? Self.printCSS : Self.webCSS) + extraCSS
            return """
            <!DOCTYPE html>
            <html lang="\(lang)">
            <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta name="generator" content="\(esc(Brand.name))">
            \(author)<title>\(t)</title>
            <style>
            \(css)
            </style>
            </head>
            <body>
            \(content)
            </body>
            </html>

            """
        }
    }

    public static let webCSS = """
    :root { color-scheme: light dark; }
    body { font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Helvetica Neue", Helvetica, Arial, sans-serif; max-width: 46em; margin: 2.5em auto; padding: 0 1.25em; color: #1d1d1f; background: #ffffff; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.5em 0 0.5em; }
    h1 { font-size: 2em; } h2 { font-size: 1.5em; } h3 { font-size: 1.25em; } h4 { font-size: 1.1em; } h5, h6 { font-size: 1em; }
    p, ul, ol, table, pre, blockquote, figure { margin: 0 0 1em; }
    a { color: #0066cc; }
    img { max-width: 100%; height: auto; }
    figure { text-align: center; }
    table { border-collapse: collapse; }
    th, td { border: 1px solid #c7c7cc; padding: 0.35em 0.65em; vertical-align: top; text-align: left; }
    th { background: #f2f2f7; font-weight: 600; }
    caption { caption-side: top; font-style: italic; padding-bottom: 0.4em; }
    code, pre { font-family: ui-monospace, "SF Mono", SFMono-Regular, Menlo, Consolas, monospace; font-size: 0.9em; }
    code { background: rgba(127,127,127,0.12); padding: 0.1em 0.3em; border-radius: 4px; }
    pre { background: #f5f5f7; padding: 0.9em 1em; overflow-x: auto; border-radius: 8px; line-height: 1.45; }
    pre code { background: none; padding: 0; }
    blockquote { padding: 0 1em; border-left: 3px solid #d1d1d6; color: #515154; margin-left: 0; }
    hr { border: 0; border-top: 1px solid #d1d1d6; margin: 2em 0; }
    li.task { list-style: none; } li.task input { margin: 0 0.5em 0 -1.4em; }
    .page-break { height: 0; }
    @media (prefers-color-scheme: dark) {
      body { color: #f2f2f7; background: #1c1c1e; }
      a { color: #4ea1ff; }
      th { background: #2c2c2e; } th, td { border-color: #48484a; }
      pre { background: #2c2c2e; } blockquote { color: #aeaeb2; border-color: #48484a; } hr { border-color: #48484a; }
    }
    """

    public static let printCSS = """
    html { -webkit-print-color-adjust: exact; }
    body { font: 11pt/1.45 "Helvetica Neue", Helvetica, Arial, sans-serif; color: #000; margin: 0; padding: 0; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.2em 0 0.4em; break-after: avoid; page-break-after: avoid; }
    h1 { font-size: 20pt; } h2 { font-size: 16pt; } h3 { font-size: 13.5pt; } h4 { font-size: 12pt; } h5, h6 { font-size: 11pt; }
    body > :first-child { margin-top: 0; }
    p, ul, ol, table, pre, blockquote, figure { margin: 0 0 0.75em; }
    p { orphans: 3; widows: 3; }
    a { color: #0645ad; text-decoration: none; }
    img { max-width: 100%; height: auto; break-inside: avoid; page-break-inside: avoid; }
    figure { text-align: center; margin-left: 0; margin-right: 0; }
    table { border-collapse: collapse; width: auto; max-width: 100%; }
    thead { display: table-header-group; }
    tr { break-inside: avoid; page-break-inside: avoid; }
    th, td { border: 0.75pt solid #8e8e93; padding: 3pt 6pt; vertical-align: top; text-align: left; }
    th { background: #ececf0; font-weight: 600; }
    caption { caption-side: top; font-style: italic; padding-bottom: 4pt; }
    code, pre { font-family: "SF Mono", Menlo, Consolas, monospace; font-size: 9pt; }
    pre { background: #f4f4f6; padding: 6pt 8pt; white-space: pre-wrap; word-wrap: break-word; break-inside: avoid; page-break-inside: avoid; }
    blockquote { padding: 0 0 0 10pt; border-left: 2pt solid #c7c7cc; color: #333; margin-left: 0; }
    hr { border: 0; border-top: 0.75pt solid #aeaeb2; margin: 1.5em 0; }
    li.task { list-style: none; }
    /* Bullets as real text: WebKit paints disc markers as shapes, which leaves PDFs with no bullet characters to copy or re-read. */
    ul { list-style: none; padding-left: 1.5em; }
    ul > li:not(.task)::before { content: "•"; display: inline-block; width: 1.1em; margin-left: -1.1em; }
    ul ul > li:not(.task)::before { content: "◦"; }
    ul ul ul > li:not(.task)::before { content: "▪"; }
    .page-break { break-after: page; page-break-after: always; height: 0; margin: 0; }
    """

    public static let epubCSS = """
    body { font-family: serif; line-height: 1.5; margin: 0 0.5em; }
    h1, h2, h3, h4, h5, h6 { font-family: sans-serif; line-height: 1.25; page-break-after: avoid; }
    h1 { font-size: 1.6em; margin: 1em 0 0.6em; } h2 { font-size: 1.35em; } h3 { font-size: 1.15em; }
    p { margin: 0 0 0.8em; }
    img { max-width: 100%; height: auto; }
    figure { margin: 1em 0; text-align: center; }
    table { border-collapse: collapse; margin: 1em 0; }
    th, td { border: 1px solid #999; padding: 0.25em 0.5em; vertical-align: top; }
    th { font-weight: bold; }
    pre { font-family: monospace; font-size: 0.85em; white-space: pre-wrap; background: #f4f4f4; padding: 0.5em; }
    code { font-family: monospace; }
    blockquote { margin: 1em 1.5em; font-style: italic; }
    hr { border: 0; border-top: 1px solid #999; margin: 1.5em 0; }
    li.task { list-style: none; }
    """

    // MARK: Blocks

    var selfClose: String { flavor == .xhtml ? "/" : "" }

    public func body(_ blocks: [DocBlock]) -> String {
        blocks.map(block).filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// Body for a document's top level: like `body`, plus heading ids when requested.
    func topLevel(_ blocks: [DocBlock]) -> String {
        guard let prefix = headingIDPrefix else { return body(blocks) }
        return blocks.enumerated().map { i, b -> String in
            if case .heading(let level, let inl) = b {
                let l = min(max(level, 1), 6)
                return "<h\(l) id=\"\(esc(prefix))\(i)\">\(inlines(inl))</h\(l)>"
            }
            return block(b)
        }.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    func block(_ b: DocBlock) -> String {
        switch b {
        case .heading(let level, let inl):
            let l = min(max(level, 1), 6)
            return "<h\(l)>\(inlines(inl))</h\(l)>"
        case .paragraph(let inl):
            return "<p>\(inlines(inl))</p>"
        case .list(let list):
            return listHTML(list)
        case .table(let t):
            return tableHTML(t)
        case .image(let im):
            guard let tag = imageTag(im) else { return im.alt.isEmpty ? "" : "<p>\(esc(im.alt))</p>" }
            return "<figure>\(tag)</figure>"
        case .codeBlock(let lang, let code):
            let cls = lang.map { " class=\"language-\(esc($0))\"" } ?? ""
            return "<pre><code\(cls)>\(esc(code))</code></pre>"
        case .blockquote(let inner):
            return "<blockquote>\n\(body(inner))\n</blockquote>"
        case .horizontalRule:
            return "<hr\(selfClose)>"
        case .pageBreak:
            return flavor == .xhtml ? "" : "<div class=\"page-break\"></div>"
        }
    }

    func listHTML(_ list: DocList) -> String {
        let tag = list.ordered ? "ol" : "ul"
        let start = list.ordered && list.start != 1 ? " start=\"\(list.start)\"" : ""
        var s = "<\(tag)\(start)>\n"
        for item in list.items {
            var box = ""
            var cls = ""
            if let checked = item.checked {
                cls = " class=\"task\""
                box = "<input type=\"checkbox\" disabled=\"disabled\"\(checked ? " checked=\"checked\"" : "")\(selfClose)> "
            }
            if item.blocks.count == 1, case .paragraph(let inl) = item.blocks[0] {
                s += "<li\(cls)>\(box)\(inlines(inl))</li>\n"
            } else if let first = item.blocks.first, case .paragraph(let inl) = first {
                s += "<li\(cls)>\(box)\(inlines(inl))\n\(body(Array(item.blocks.dropFirst())))</li>\n"
            } else {
                s += "<li\(cls)>\(box)\(body(item.blocks))</li>\n"
            }
        }
        return s + "</\(tag)>"
    }

    func tableHTML(_ table: DocTable) -> String {
        let t = table.normalized
        guard !t.rows.isEmpty else { return "" }
        var s = "<table>\n"
        if !t.caption.isEmpty { s += "<caption>\(inlines(t.caption))</caption>\n" }
        let headCount = t.rows.prefix { $0.isHeader }.count
        func row(_ r: DocTableRow, header: Bool) -> String {
            var out = "<tr>"
            for (k, c) in r.cells.enumerated() {
                let tag = header ? "th" : "td"
                let align = k < t.alignments.count && t.alignments[k] != .none ? " style=\"text-align: \(t.alignments[k].rawValue)\"" : ""
                out += "<\(tag)\(align)>\(cell(c))</\(tag)>"
            }
            return out + "</tr>\n"
        }
        if headCount > 0 {
            s += "<thead>\n" + t.rows.prefix(headCount).map { row($0, header: true) }.joined() + "</thead>\n"
        }
        let bodyRows = t.rows.dropFirst(headCount)
        if !bodyRows.isEmpty {
            s += "<tbody>\n" + bodyRows.map { row($0, header: $0.isHeader) }.joined() + "</tbody>\n"
        }
        return s + "</table>"
    }

    func cell(_ c: DocTableCell) -> String {
        if c.blocks.count == 1, case .paragraph(let inl) = c.blocks[0] { return inlines(inl) }
        return body(c.blocks)
    }

    // MARK: Inlines

    public func inlines(_ a: [DocInline]) -> String {
        a.map(inline).joined()
    }

    func inline(_ i: DocInline) -> String {
        switch i {
        case .text(let s): return esc(s)
        case .emphasis(let c): return "<em>\(inlines(c))</em>"
        case .strong(let c): return "<strong>\(inlines(c))</strong>"
        case .underline(let c): return "<u>\(inlines(c))</u>"
        case .strikethrough(let c): return "<del>\(inlines(c))</del>"
        case .code(let s): return "<code>\(esc(s))</code>"
        case .lineBreak: return "<br\(selfClose)>"
        case .link(let url, let c):
            let safe = Self.safeHref(url)
            guard let safe else { return inlines(c) }
            return "<a href=\"\(esc(safe))\">\(inlines(c))</a>"
        case .image(let im):
            return imageTag(im) ?? esc(im.alt)
        }
    }

    func imageTag(_ im: DocImage) -> String? {
        var src: String?
        switch imageMode {
        case .dataURI:
            if let data = im.data {
                src = ImageSupport.dataURI(data, mime: im.mime.isEmpty ? (ImageSupport.sniffMIME(data) ?? "image/png") : im.mime)
            } else if flavor == .web, let s = im.source, s.lowercased().hasPrefix("http") {
                // Web pages may keep remote references; print/XHTML never load remote content.
                src = s
            }
        case .external(let resolver):
            src = resolver(im)
        }
        guard let src else { return nil }
        var size = ""
        if let w = im.width, w > 0 { size += " width=\"\(Int((w / 0.75).rounded()))\"" }
        if let h = im.height, h > 0 { size += " height=\"\(Int((h / 0.75).rounded()))\"" }
        return "<img src=\"\(esc(src))\" alt=\"\(esc(im.alt))\"\(size)\(selfClose)>"
    }

    /// Drops script URLs; keeps http(s), mailto, tel, fragment and relative links.
    static func safeHref(_ url: String) -> String? {
        let u = url.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = u.lowercased()
        if lower.hasPrefix("javascript:") || lower.hasPrefix("vbscript:") || lower.hasPrefix("data:") { return nil }
        return u
    }

    func esc(_ s: String) -> String { XMLEscape.text(s) }
}
