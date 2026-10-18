import Foundation

/// HTML/XHTML → `DocModel`. Parses with HTML Tidy (`XMLDocument`, safe off the
/// main thread) and maps semantic tags. Never fetches remote resources: remote
/// images are kept as references only.
public enum HTMLReader {
    /// Resolves an `<img src>` to image bytes (data URI, local file, archive member…).
    public typealias ImageLoader = @Sendable (_ src: String) -> (data: Data, mime: String)?

    public static func read(_ html: String, baseURL: URL?, loader: ImageLoader? = nil) -> DocModel {
        let root: XNode
        do { root = try XMLTree.parseHTML(html) } catch {
            return PlainTextReader.parse(html.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression))
        }
        return read(root, baseURL: baseURL, loader: loader)
    }

    public static func read(_ root: XNode, baseURL: URL?, loader: ImageLoader? = nil) -> DocModel {
        var meta = DocMetadata()
        if let lang = root["lang"] ?? root["xml:lang"], !lang.isEmpty { meta.language = lang }
        let head = root.first("head")
        if let t = head?.first("title")?.text.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty { meta.title = t }
        for m in head?.all("meta") ?? [] {
            let name = (m["name"] ?? "").lowercased()
            if name == "author" || name == "dc.creator" || name == "dcterms.creator", let c = m["content"], !c.isEmpty { meta.author = c }
        }
        let body = root.name == "body" ? root : (root.first("body") ?? root)
        var walker = HTMLWalker(baseURL: baseURL, loader: loader)
        walker.cocoaSizes = CocoaStyleSizes(root)
        let blocks = walker.container(body)
        return DocModel(metadata: meta, blocks: blocks)
    }

    /// Parses an HTML fragment (e.g. a raw HTML block inside Markdown) into blocks.
    public static func parseFragment(_ html: String, baseURL: URL?) -> [DocBlock] {
        read("<html><body>\(html)</body></html>", baseURL: baseURL).blocks
    }
}

/// Font sizes declared by Apple's "Cocoa HTML Writer" (`p.p1 {font: 24.0px Times}`),
/// used to recover headings from TextEdit/textutil HTML, which has no <h1>.
struct CocoaStyleSizes {
    var classSize: [String: Double] = [:]
    var bodySize: Double = 0
    var enabled = false

    init() {}

    init(_ root: XNode) {
        guard root.all("h1").isEmpty, root.all("h2").isEmpty, root.all("h3").isEmpty else { return }
        let css = root.all("style").map(\.text).joined(separator: "\n")
        guard !css.isEmpty else { return }
        let pattern = #"p\.([A-Za-z0-9_-]+)\s*\{[^}]*?font:\s*(?:[a-z-]+\s+)*?([0-9.]+)px"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return }
        for m in re.matches(in: css, range: NSRange(css.startIndex..., in: css)) {
            guard let c = Range(m.range(at: 1), in: css), let s = Range(m.range(at: 2), in: css), let v = Double(css[s]) else { continue }
            classSize[String(css[c])] = v
        }
        guard !classSize.isEmpty else { return }
        // Body size = most text-weighted paragraph size.
        var weight: [Double: Int] = [:]
        for p in root.all("p") {
            guard let c = p["class"], let s = classSize[c] else { continue }
            weight[s, default: 0] += p.text.count
        }
        bodySize = weight.max { $0.value < $1.value }?.key ?? 0
        enabled = bodySize > 0
    }

    /// Heading level for a paragraph class, if its font is clearly larger than body text.
    func headingLevel(_ cls: String?) -> Int? {
        guard enabled, let cls, let s = classSize[cls], s >= bodySize * 1.2 else { return nil }
        let larger = Set(classSize.values.filter { $0 >= bodySize * 1.2 }).sorted(by: >)
        guard let idx = larger.firstIndex(of: s) else { return nil }
        return min(6, idx + 1)
    }
}

struct HTMLWalker {
    let baseURL: URL?
    let loader: HTMLReader.ImageLoader?
    var cocoaSizes = CocoaStyleSizes()

    init(baseURL: URL?, loader: HTMLReader.ImageLoader?) {
        self.baseURL = baseURL
        self.loader = loader
    }

    static let skip: Set<String> = ["head", "script", "style", "noscript", "template", "title", "meta", "link", "iframe",
                                    "object", "embed", "canvas", "button", "input", "select", "textarea", "svg", "math", "map", "audio", "video"]
    static let blockContainers: Set<String> = ["div", "section", "article", "main", "header", "footer", "nav", "aside", "body",
                                               "html", "center", "form", "fieldset", "details", "summary", "figure", "address",
                                               "hgroup", "legend", "noframes", "frameset", "picture"]
    static let blockTags: Set<String> = blockContainers.union(["p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "dl", "dt", "dd",
                                                                "table", "pre", "blockquote", "hr", "li", "figcaption", "caption", "tr", "td", "th",
                                                                "thead", "tbody", "tfoot"])

    /// Blocks for a container: inline runs become paragraphs, block children recurse.
    func container(_ node: XNode) -> [DocBlock] {
        var out: [DocBlock] = []
        var pending: [DocInline] = []
        func flush() {
            let inl = pending.trimmed
            pending.removeAll()
            guard !inl.isBlank || inl.contains(where: { if case .image = $0 { return true }; return false }) else { return }
            if inl.count == 1, case .image(let im) = inl[0] { out.append(.image(im)) } else { out.append(.paragraph(inl)) }
        }
        for c in node.children {
            switch c {
            case .text(let t):
                pending.append(.text(Self.collapse(t)))
            case .element(let e):
                if Self.skip.contains(e.name) { continue }
                if Self.blockTags.contains(e.name) {
                    flush()
                    if Self.breakBefore(e) { out.append(.pageBreak) }
                    out.append(contentsOf: block(e))
                    if Self.breakAfter(e) { out.append(.pageBreak) }
                } else {
                    pending.append(contentsOf: inlines(e))
                }
            }
        }
        flush()
        return out
    }

    func block(_ e: XNode) -> [DocBlock] {
        switch e.name {
        case "h1", "h2", "h3", "h4", "h5", "h6":
            let level = Int(String(e.name.dropFirst())) ?? 1
            let inl = inlineContent(e).trimmed
            return inl.isEmpty ? [] : [.heading(level: level, inl)]
        case "p":
            if let level = cocoaSizes.headingLevel(e["class"]) {
                let inl = Self.unwrapStrong(inlineContent(e).trimmed)
                if !inl.isEmpty, inl.plainText.count < 200 { return [.heading(level: level, inl)] }
            }
            return container(e)
        case "ul", "ol":
            return [.list(list(e))]
        case "table":
            return table(e)
        case "pre":
            var text = e.text
            if text.hasPrefix("\n") { text.removeFirst() }
            while text.hasSuffix("\n") { text.removeLast() }
            let cls = (e["class"] ?? "") + " " + (e.first("code")?["class"] ?? "")
            var lang: String?
            if let r = cls.range(of: #"(?:language|lang)-([A-Za-z0-9_+#-]+)"#, options: .regularExpression) {
                lang = String(cls[r].split(separator: "-", maxSplits: 1).last ?? "")
            }
            return [.codeBlock(language: lang, text)]
        case "blockquote":
            let inner = container(e)
            return inner.isEmpty ? [] : [.blockquote(inner)]
        case "hr":
            return [.horizontalRule]
        case "dl":
            var out: [DocBlock] = []
            for c in e.elements {
                if c.name == "dt" {
                    let inl = inlineContent(c).trimmed
                    if !inl.isEmpty { out.append(.paragraph([.strong(inl)])) }
                } else if c.name == "dd" {
                    let inner = container(c)
                    if !inner.isEmpty { out.append(.blockquote(inner)) }
                }
            }
            return out
        case "figcaption", "caption":
            let inl = inlineContent(e).trimmed
            return inl.isEmpty ? [] : [.paragraph([.emphasis(inl)])]
        case "li", "dt", "dd", "tr", "td", "th", "thead", "tbody", "tfoot":
            return container(e)
        default:
            return container(e)
        }
    }

    func list(_ e: XNode) -> DocList {
        let ordered = e.name == "ol"
        let start = Int(e["start"] ?? "") ?? 1
        var items: [DocListItem] = []
        for c in e.elements {
            if c.name == "li" {
                var blocks = container(c)
                var checked: Bool?
                if let box = c.first("input"), (box["type"] ?? "").lowercased() == "checkbox" {
                    checked = box["checked"] != nil
                }
                if blocks.isEmpty { blocks = [] }
                items.append(DocListItem(blocks, checked: checked))
            } else if c.name == "ul" || c.name == "ol" {
                // Nested list placed directly in the list (common sloppy HTML): attach to the previous item.
                let nested = DocBlock.list(list(c))
                if items.isEmpty { items.append(DocListItem([nested])) } else { items[items.count - 1].blocks.append(nested) }
            }
        }
        return DocList(ordered: ordered, start: start, items: items)
    }

    func table(_ e: XNode) -> [DocBlock] {
        var rows: [DocTableRow] = []
        var caption: [DocInline] = []
        func addRow(_ tr: XNode, header: Bool) {
            var cells: [DocTableCell] = []
            var allTH = true
            for c in tr.elements where c.name == "td" || c.name == "th" {
                if c.name != "th" { allTH = false }
                cells.append(DocTableCell(container(c)))
                let span = min(Int(c["colspan"] ?? "") ?? 1, 64)
                if span > 1 { for _ in 1..<span { cells.append(DocTableCell([])) } }
            }
            if !cells.isEmpty { rows.append(DocTableRow(cells, isHeader: header || allTH)) }
        }
        for c in e.elements {
            switch c.name {
            case "caption": caption = inlineContent(c).trimmed
            case "thead": c.children("tr").forEach { addRow($0, header: true) }
            case "tbody", "tfoot": c.children("tr").forEach { addRow($0, header: false) }
            case "tr": addRow(c, header: false)
            default: break
            }
        }
        guard !rows.isEmpty else { return [] }
        return [.table(DocTable(rows: rows, caption: caption))]
    }

    /// Inline content of an element's children.
    func inlineContent(_ e: XNode) -> [DocInline] {
        var out: [DocInline] = []
        for c in e.children {
            switch c {
            case .text(let t): out.append(.text(Self.collapse(t)))
            case .element(let ce):
                if Self.skip.contains(ce.name) { continue }
                if Self.blockTags.contains(ce.name) {
                    // Block inside an inline context (headings with <p>, cells…): keep its text with a break.
                    let inner = inlineContent(ce)
                    if !out.isEmpty, !inner.isBlank { out.append(.lineBreak) }
                    out.append(contentsOf: inner)
                } else {
                    out.append(contentsOf: inlines(ce))
                }
            }
        }
        return out
    }

    func inlines(_ e: XNode) -> [DocInline] {
        let kids = { inlineContent(e) }
        switch e.name {
        case "strong", "b": return [.strong(kids())]
        case "em", "i", "cite", "dfn", "var": return [.emphasis(kids())]
        case "u", "ins": return [.underline(kids())]
        case "s", "strike", "del": return [.strikethrough(kids())]
        case "code", "kbd", "samp", "tt": return [.code(e.text)]
        case "br": return [.lineBreak]
        case "wbr": return []
        case "q": return [.text("“")] + kids() + [.text("”")]
        case "img": return image(e).map { [.image($0)] } ?? []
        case "a":
            let href = (e["href"] ?? "").trimmingCharacters(in: .whitespaces)
            let content = kids()
            if href.isEmpty || href.lowercased().hasPrefix("javascript:") { return content }
            return [.link(url: href, content)]
        case "span", "font":
            var content = kids()
            let style = (e["style"] ?? "").lowercased().replacingOccurrences(of: " ", with: "")
            if style.contains("font-weight:bold") || style.contains("font-weight:700") || style.contains("font-weight:600") || style.contains("font-weight:800") { content = [.strong(content)] }
            if style.contains("font-style:italic") { content = [.emphasis(content)] }
            if style.contains("line-through") { content = [.strikethrough(content)] }
            if style.contains("text-decoration:underline") { content = [.underline(content)] }
            return content
        default:
            return kids()
        }
    }

    func image(_ e: XNode) -> DocImage? {
        let src = (e["src"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let alt = e["alt"] ?? e["title"] ?? ""
        var w = Self.pixels(e["width"]), h = Self.pixels(e["height"])
        if let style = e["style"] {
            if w == nil { w = Self.cssLength(style, "width") }
            if h == nil { h = Self.cssLength(style, "height") }
        }
        guard !src.isEmpty else { return nil }
        // CSS px → points.
        let wp = w.map { $0 * 0.75 }, hp = h.map { $0 * 0.75 }
        if src.hasPrefix("data:"), let d = ImageSupport.decodeDataURI(src) {
            return DocImage(data: d.data, mime: ImageSupport.sniffMIME(d.data) ?? d.mime, alt: alt, width: wp, height: hp)
        }
        if let loader, let d = loader(src) {
            return DocImage(data: d.data, mime: ImageSupport.sniffMIME(d.data) ?? d.mime, alt: alt, width: wp, height: hp, source: src)
        }
        if let local = LocalResource.resolve(src, baseURL: baseURL), let data = try? Data(contentsOf: local),
           let mime = ImageSupport.sniffMIME(data, fileExtension: local.pathExtension), mime.hasPrefix("image/") {
            return DocImage(data: data, mime: mime, alt: alt, width: wp, height: hp, source: src)
        }
        return DocImage(data: nil, mime: "", alt: alt, width: wp, height: hp, source: src)
    }

    static func pixels(_ s: String?) -> Double? {
        guard let s = s?.trimmingCharacters(in: .whitespaces), !s.hasSuffix("%") else { return nil }
        return Double(s.replacingOccurrences(of: "px", with: ""))
    }

    static func cssLength(_ style: String, _ prop: String) -> Double? {
        let pattern = "(?:^|;)\\s*\(prop)\\s*:\\s*([0-9.]+)(px|pt)?"
        guard let r = style.range(of: pattern, options: [.regularExpression, .caseInsensitive]) else { return nil }
        let m = String(style[r])
        guard let num = m.range(of: #"[0-9.]+"#, options: .regularExpression), let v = Double(m[num]) else { return nil }
        return m.lowercased().hasSuffix("pt") ? v / 0.75 : v
    }

    static func breakBefore(_ e: XNode) -> Bool {
        let s = (e["style"] ?? "").lowercased().replacingOccurrences(of: " ", with: "")
        return s.contains("page-break-before:always") || s.contains("break-before:page")
    }

    static func breakAfter(_ e: XNode) -> Bool {
        let s = (e["style"] ?? "").lowercased().replacingOccurrences(of: " ", with: "")
        return s.contains("page-break-after:always") || s.contains("break-after:page")
    }

    /// Collapses HTML whitespace (not NBSP) to single spaces.
    static func collapse(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        var lastSpace = false
        for c in s {
            if c == " " || c == "\n" || c == "\t" || c == "\r" || c == "\u{0C}" {
                if !lastSpace { out.append(" ") }
                lastSpace = true
            } else {
                out.append(c)
                lastSpace = false
            }
        }
        return out
    }

    /// A heading made of one bold run doesn't need the bold.
    static func unwrapStrong(_ inl: [DocInline]) -> [DocInline] {
        if inl.count == 1, case .strong(let c) = inl[0] { return c }
        return inl
    }
}

/// Plain text → paragraphs (blank lines separate paragraphs; single newlines are line breaks).
public enum PlainTextReader {
    public static func parse(_ text: String) -> DocModel {
        var t = text
        if t.hasPrefix("\u{FEFF}") { t.removeFirst() }
        t = t.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var blocks: [DocBlock] = []
        for chunk in t.components(separatedBy: "\n\n") {
            let lines = chunk.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
            let content = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard !content.isEmpty else { continue }
            if content.contains(where: { $0.contains("\u{0C}") }) {
                // Form feed = page break (common in plain-text exports).
                blocks.append(.pageBreak)
            }
            var inl: [DocInline] = []
            for (k, l) in content.enumerated() {
                if k > 0 { inl.append(.lineBreak) }
                inl.append(.text(l.replacingOccurrences(of: "\u{0C}", with: "")))
            }
            blocks.append(.paragraph(inl))
        }
        return DocModel(blocks: blocks)
    }
}
