import Foundation

/// ODT → `DocModel`: outline headings, nested lists with their list styles,
/// span formatting from automatic styles, links, tables, frames/images, notes.
public enum ODTReader {
    public static func read(_ url: URL) throws -> DocModel {
        try read(ZipReader(url: url))
    }

    public static func read(_ zip: ZipReader) throws -> DocModel {
        let content = try XMLTree.parse(zip.data("content.xml"))
        let stylesRoot = try? XMLTree.parse(zip.data("styles.xml"))
        var ctx = ODFStyles()
        if let stylesRoot { ctx.load(stylesRoot) }
        ctx.load(content)
        guard let text = content.first("body")?.child("text") else { return DocModel(metadata: ODFMeta.read(zip)) }
        var reader = ODTFlow(zip: zip, styles: ctx)
        var items = reader.items(text, listDepth: -1, listStyle: nil)
        if !reader.notes.isEmpty {
            items.append(.block(.horizontalRule))
            items.append(.block(.list(DocList(ordered: true, items: reader.notes.map { DocListItem($0) }))))
        }
        return DocModel(metadata: ODFMeta.read(zip), blocks: FlowAssembler.assemble(items))
    }
}

enum ODFMeta {
    static func read(_ zip: ZipReader) -> DocMetadata {
        var m = DocMetadata()
        guard let meta = try? XMLTree.parse(zip.data("meta.xml")) else { return m }
        func v(_ n: String) -> String? {
            let t = meta.first(n)?.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return (t?.isEmpty ?? true) ? nil : t
        }
        m.title = v("title")
        m.author = v("creator") ?? v("initial-creator")
        m.language = v("language")
        return m
    }
}

/// Style lookup for ODF (paragraph/text styles and list styles), with parent inheritance.
struct ODFStyles {
    struct Style {
        var parent: String?
        var bold: Bool?, italic: Bool?, underline: Bool?, strike: Bool?
        var size: Double?
        var mono = false
        var outline: Int?
        var breakBefore = false
        var listStyle: String?
        var displayName = ""
    }
    var styles: [String: Style] = [:]
    /// list style name → level (1-based) → ordered
    var lists: [String: [Int: Bool]] = [:]

    mutating func load(_ root: XNode) {
        for container in root.elements where container.name == "styles" || container.name == "automatic-styles" {
            for s in container.elements {
                if s.name == "style", let name = s["style:name"] ?? s["name"] {
                    var st = Style()
                    st.parent = s["style:parent-style-name"]
                    st.displayName = (s["style:display-name"] ?? name).lowercased()
                    st.outline = s["style:default-outline-level"].flatMap(Int.init)
                    st.listStyle = s["style:list-style-name"]
                    if let tp = s.child("text-properties") {
                        if let w = tp["fo:font-weight"] { st.bold = w == "bold" || (Int(w) ?? 400) >= 600 }
                        if let i = tp["fo:font-style"] { st.italic = i == "italic" || i == "oblique" }
                        if let u = tp["style:text-underline-style"] { st.underline = u != "none" }
                        if let l = tp["style:text-line-through-style"] { st.strike = l != "none" }
                        if let sz = tp["fo:font-size"] { st.size = ODFStyles.points(sz) }
                        let font = (tp["style:font-name"] ?? tp["fo:font-family"] ?? "").lowercased()
                        if ["courier", "mono", "consolas", "menlo", "source code"].contains(where: font.contains) || tp["style:font-family-generic"] == "modern" { st.mono = true }
                    }
                    if let pp = s.child("paragraph-properties"), pp["fo:break-before"] == "page" { st.breakBefore = true }
                    styles[name] = st
                } else if s.name == "list-style", let name = s["style:name"] ?? s["name"] {
                    var levels: [Int: Bool] = [:]
                    for l in s.elements {
                        let lv = l["text:level"].flatMap(Int.init) ?? 1
                        levels[lv] = l.name == "list-level-style-number"
                    }
                    lists[name] = levels
                }
            }
        }
    }

    func chain(_ name: String?) -> [Style] {
        var out: [Style] = []
        var cur = name
        var n = 0
        while let c = cur, let s = styles[c], n < 20 { out.append(s); cur = s.parent; n += 1 }
        return out
    }

    func names(_ name: String?) -> String {
        var out: [String] = []
        var cur = name
        var n = 0
        while let c = cur, n < 20 {
            out.append(c.lowercased().replacingOccurrences(of: "_20_", with: " "))
            if let s = styles[c] { out.append(s.displayName); cur = s.parent } else { cur = nil }
            n += 1
        }
        return out.joined(separator: "|")
    }

    static func points(_ s: String) -> Double? {
        let units: [(String, Double)] = [("pt", 1), ("cm", 28.3465), ("mm", 2.83465), ("in", 72), ("pc", 12), ("px", 0.75)]
        for (u, f) in units where s.hasSuffix(u) { return Double(s.dropLast(u.count)).map { $0 * f } }
        if s.hasSuffix("%") { return nil }
        return Double(s)
    }
}

struct ODTFlow {
    let zip: ZipReader
    let styles: ODFStyles
    var notes: [[DocBlock]] = []

    init(zip: ZipReader, styles: ODFStyles) {
        self.zip = zip
        self.styles = styles
    }

    mutating func items(_ container: XNode, listDepth: Int, listStyle: String?) -> [FlowItem] {
        var out: [FlowItem] = []
        for e in container.elements {
            switch e.name {
            case "h", "p":
                out.append(.para(paragraph(e, heading: e.name == "h")))
            case "list":
                let style = e["text:style-name"] ?? listStyle
                let depth = listDepth + 1
                for (k, li) in e.elements.enumerated() where li.name == "list-item" || li.name == "list-header" {
                    let ordered = style.flatMap { styles.lists[$0]?[min(depth + 1, 10)] } ?? false
                    var start = 1
                    if let sv = li["text:start-value"].flatMap(Int.init) { start = sv }
                    var first = true
                    for child in li.elements {
                        if child.name == "list" {
                            out.append(contentsOf: items(XNode(name: "wrapper", children: [.element(child)]), listDepth: depth, listStyle: style))
                            first = false
                            continue
                        }
                        guard child.name == "p" || child.name == "h" else { continue }
                        var p = paragraph(child, heading: false)
                        if first && li.name == "list-item" {
                            p.list = (min(depth, 8), ordered, k == 0 ? start : 1, style ?? "odf-list")
                        } else {
                            p.continuation = true
                        }
                        first = false
                        out.append(.para(p))
                    }
                }
            case "table":
                if let t = table(e) { out.append(.block(.table(t))) }
            case "section", "index-body", "table-of-content", "illustration-index", "alphabetical-index", "deletion", "change", "inserted":
                if e.name == "deletion" { continue }
                out.append(contentsOf: items(e, listDepth: listDepth, listStyle: listStyle))
            case "soft-page-break":
                break
            default:
                break
            }
        }
        return out
    }

    mutating func paragraph(_ p: XNode, heading: Bool) -> ParaItem {
        let styleName = p["text:style-name"]
        let chain = styles.chain(styleName)
        let names = styles.names(styleName)
        var item = ParaItem([])
        if heading {
            item.heading = min(max(p["text:outline-level"].flatMap(Int.init) ?? chain.compactMap(\.outline).first ?? 1, 1), 6)
        } else if let o = chain.compactMap(\.outline).first {
            item.heading = min(max(o, 1), 6)
        } else if let r = names.range(of: #"heading (\d)"#, options: .regularExpression), let l = Int(names[r].suffix(1)) {
            item.heading = min(max(l, 1), 6)
        }
        item.code = names.contains("preformatted") || names.contains("source") || chain.first?.mono == true
        item.quote = names.contains("quotation")
        item.breakBefore = chain.contains { $0.breakBefore }
        var size = 11.0
        for s in chain { if let sz = s.size { size = sz; break } }
        var c = InlineAcc(size: size)
        inline(p.children, props: Props(chain: chain), into: &c)
        item.inlines = c.out
        item.fontSize = c.maxSize ?? size
        return item
    }

    struct Props {
        var bold = false, italic = false, underline = false, strike = false, mono = false
        var size: Double?
        init() {}
        init(chain: [ODFStyles.Style]) {
            // Paragraph-level formatting only counts for heuristics (not inline marks).
            size = chain.compactMap(\.size).first
        }
    }

    struct InlineAcc {
        var out: [DocInline] = []
        var maxSize: Double?
        let size: Double
        init(size: Double) { self.size = size }
    }

    mutating func inline(_ nodes: [XContent], props: Props, into c: inout InlineAcc) {
        for n in nodes {
            switch n {
            case .text(let t):
                let collapsed = HTMLWalker.collapse(t)
                guard !collapsed.isEmpty else { continue }
                if !collapsed.trimmingCharacters(in: .whitespaces).isEmpty { c.maxSize = max(c.maxSize ?? 0, props.size ?? c.size) }
                c.out.append(Self.wrap(collapsed, props))
            case .element(let e):
                switch e.name {
                case "span":
                    var p = props
                    for s in styles.chain(e["text:style-name"]).reversed() {
                        if let b = s.bold { p.bold = b }
                        if let i = s.italic { p.italic = i }
                        if let u = s.underline { p.underline = u }
                        if let st = s.strike { p.strike = st }
                        if s.mono { p.mono = true }
                        if let sz = s.size { p.size = sz }
                    }
                    inline(e.children, props: p, into: &c)
                case "a":
                    var inner = InlineAcc(size: c.size)
                    inline(e.children, props: props, into: &inner)
                    c.maxSize = max(c.maxSize ?? 0, inner.maxSize ?? 0)
                    if let href = e["xlink:href"], !href.isEmpty { c.out.append(.link(url: href, inner.out)) } else { c.out.append(contentsOf: inner.out) }
                case "s":
                    let n = max(1, e["text:c"].flatMap(Int.init) ?? 1)
                    c.out.append(.text(String(repeating: " ", count: min(n, 200))))
                case "tab": c.out.append(.text("\t"))
                case "line-break": c.out.append(.lineBreak)
                case "frame":
                    if let im = image(e) { c.out.append(.image(im)) }
                case "note":
                    let body = e.child("note-body")
                    var nested = ODTFlow(zip: zip, styles: styles)
                    let blocks = body.map { FlowAssembler.assemble(nested.items($0, listDepth: -1, listStyle: nil), headingHeuristic: false) } ?? []
                    notes.append(blocks)
                    c.out.append(.text("[\(notes.count)]"))
                case "annotation", "bookmark", "bookmark-start", "bookmark-end", "change-start", "change-end", "change", "reference-mark", "soft-page-break", "sequence-decls":
                    break
                default:
                    inline(e.children, props: props, into: &c)
                }
            }
        }
    }

    static func wrap(_ t: String, _ p: Props) -> DocInline {
        if p.mono { return .code(t) }
        var node: DocInline = .text(t)
        if p.strike { node = .strikethrough([node]) }
        if p.underline { node = .underline([node]) }
        if p.italic { node = .emphasis([node]) }
        if p.bold { node = .strong([node]) }
        return node
    }

    func image(_ frame: XNode) -> DocImage? {
        guard let img = frame.first("image"), let href = img["xlink:href"], !href.hasPrefix("http"),
              let data = try? zip.data(href) else { return nil }
        let w = frame["svg:width"].flatMap(ODFStyles.points)
        let h = frame["svg:height"].flatMap(ODFStyles.points)
        let alt = frame.child("desc")?.text ?? frame.child("title")?.text ?? frame["draw:name"] ?? ""
        let mime = ImageSupport.sniffMIME(data, fileExtension: (href as NSString).pathExtension) ?? "image/png"
        return DocImage(data: data, mime: mime, alt: alt, width: w, height: h, source: (href as NSString).lastPathComponent)
    }

    mutating func table(_ t: XNode) -> DocTable? {
        var rows: [DocTableRow] = []
        func addRows(_ container: XNode, header: Bool) {
            for r in container.elements {
                if r.name == "table-row" {
                    let repeatCount = min(r["table:number-rows-repeated"].flatMap(Int.init) ?? 1, 1000)
                    var cells: [DocTableCell] = []
                    for cnode in r.elements where cnode.name == "table-cell" || cnode.name == "covered-table-cell" {
                        let rep = min(cnode["table:number-columns-repeated"].flatMap(Int.init) ?? 1, 64)
                        var blocks: [DocBlock] = []
                        if cnode.name == "table-cell" {
                            var nested = ODTFlow(zip: zip, styles: styles)
                            blocks = FlowAssembler.assemble(nested.items(cnode, listDepth: -1, listStyle: nil), headingHeuristic: false)
                        }
                        for _ in 0..<rep { cells.append(DocTableCell(blocks)) }
                    }
                    // Trim trailing empty cells (spreadsheet-style padding).
                    while let last = cells.last, last.blocks.isEmpty, cells.count > 1 { cells.removeLast() }
                    for _ in 0..<repeatCount { rows.append(DocTableRow(cells, isHeader: header)) }
                } else if r.name == "table-header-rows" {
                    addRows(r, header: true)
                } else if r.name == "table-rows" || r.name == "table-row-group" {
                    addRows(r, header: header)
                }
            }
        }
        addRows(t, header: false)
        while let last = rows.last, last.cells.allSatisfy({ $0.blocks.isEmpty }) { rows.removeLast() }
        return rows.isEmpty ? nil : DocTable(rows: rows)
    }
}
