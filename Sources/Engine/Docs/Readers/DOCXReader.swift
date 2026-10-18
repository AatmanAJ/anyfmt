import Foundation

/// DOCX → `DocModel`, our own WordprocessingML reader: heading styles (by name,
/// id or outline level, with a font-size fallback), numbering → nested lists,
/// run formatting, hyperlinks (relationships and HYPERLINK fields), tables
/// (incl. spans), embedded images, page breaks, footnotes, text boxes and
/// content controls.
public enum DOCXReader {
    public static func read(_ url: URL) throws -> DocModel {
        try read(ZipReader(url: url))
    }

    public static func read(_ zip: ZipReader) throws -> DocModel {
        var mainPath = "word/document.xml"
        if let rels = try? XMLTree.parse(zip.data("_rels/.rels")) {
            for r in rels.children("Relationship") where (r["Type"] ?? "").hasSuffix("/officeDocument") {
                if let t = r["Target"] { mainPath = OPC.resolve(t, relativeTo: "") }
            }
        }
        guard zip.contains(mainPath) else { throw ZipReader.Failure.missing(mainPath) }
        var ctx = DocxReadContext(zip: zip, partPath: mainPath)
        let root = try XMLTree.parse(zip.data(mainPath))
        guard let body = root.first("body") else { return DocModel() }
        var items = ctx.blockItems(body)
        if !ctx.footnoteOrder.isEmpty {
            items.append(.block(.horizontalRule))
            let notes = ctx.footnoteOrder.map { id -> DocListItem in
                DocListItem(ctx.footnoteBlocks[id] ?? [])
            }
            items.append(.block(.list(DocList(ordered: true, items: notes))))
        }
        var model = DocModel(metadata: OPC.coreMetadata(zip), blocks: FlowAssembler.assemble(items))
        if model.metadata.language == nil { model.metadata.language = ctx.defaultLanguage }
        return model
    }
}

/// Open Packaging Conventions helpers shared by the OOXML readers.
enum OPC {
    /// Resolves a relationship target against the directory of `partPath`.
    static func resolve(_ target: String, relativeTo partPath: String) -> String {
        if target.hasPrefix("/") { return String(target.dropFirst()) }
        var parts = partPath.split(separator: "/").map(String.init)
        if !parts.isEmpty { parts.removeLast() }
        for comp in target.split(separator: "/") {
            if comp == ".." { if !parts.isEmpty { parts.removeLast() } } else if comp != "." { parts.append(String(comp)) }
        }
        return parts.joined(separator: "/")
    }

    static func relsPath(for partPath: String) -> String {
        var parts = partPath.split(separator: "/").map(String.init)
        let name = parts.popLast() ?? ""
        return (parts + ["_rels", name + ".rels"]).joined(separator: "/")
    }

    struct Rel { let type: String; let target: String; let external: Bool }

    static func rels(_ zip: ZipReader, for partPath: String) -> [String: Rel] {
        guard let root = try? XMLTree.parse(zip.data(relsPath(for: partPath))) else { return [:] }
        var out: [String: Rel] = [:]
        for r in root.children("Relationship") {
            guard let id = r["Id"], let target = r["Target"] else { continue }
            let external = (r["TargetMode"] ?? "").lowercased() == "external"
            out[id] = Rel(type: r["Type"] ?? "", target: external ? target : resolve(target, relativeTo: partPath), external: external)
        }
        return out
    }

    static func coreMetadata(_ zip: ZipReader) -> DocMetadata {
        var m = DocMetadata()
        guard let core = try? XMLTree.parse(zip.data("docProps/core.xml")) else { return m }
        func v(_ n: String) -> String? {
            let t = core.first(n)?.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return (t?.isEmpty ?? true) ? nil : t
        }
        m.title = v("title")
        m.author = v("creator")
        m.language = v("language")
        return m
    }
}

struct DocxReadContext {
    struct Style {
        var name = "", basedOn: String?, outline: Int?, numID: String?, ilvl: Int?
        var bold: Bool?, italic: Bool?, size: Double?, mono = false
    }
    struct NumLevel { var ordered: Bool; var start: Int }
    struct RunProps { var bold = false, italic = false, underline = false, strike = false, mono = false, size: Double? }

    let zip: ZipReader
    let partPath: String
    let rels: [String: OPC.Rel]
    var styles: [String: Style] = [:]
    var defaultParaStyle: String?
    var defaultSize: Double = 11
    var defaultLanguage: String?
    var numbering: [String: [Int: NumLevel]] = [:]
    var footnotes: [String: XNode] = [:]
    var footnoteOrder: [String] = []
    var footnoteBlocks: [String: [DocBlock]] = [:]
    var pendingExtra: [FlowItem] = []

    init(zip: ZipReader, partPath: String) {
        self.zip = zip
        self.partPath = partPath
        rels = OPC.rels(zip, for: partPath)
        loadStyles()
        loadNumbering()
        loadFootnotes()
    }

    func relTarget(type suffix: String) -> String? {
        rels.values.first { $0.type.hasSuffix("/" + suffix) && !$0.external }?.target
    }

    mutating func loadStyles() {
        guard let path = relTarget(type: "styles") ?? (zip.contains("word/styles.xml") ? "word/styles.xml" : nil),
              let root = try? XMLTree.parse(zip.data(path)) else { return }
        if let rpr = root.first("docDefaults")?.first("rPrDefault")?.first("rPr") {
            if let sz = rpr.child("sz")?["val"].flatMap(Double.init) { defaultSize = sz / 2 }
            if let lang = rpr.child("lang")?["val"], !lang.isEmpty { defaultLanguage = lang }
        }
        for s in root.children("style") {
            guard let id = s["styleId"] else { continue }
            var st = Style()
            st.name = (s.child("name")?["val"] ?? id)
            st.basedOn = s.child("basedOn")?["val"]
            if let ppr = s.child("pPr") {
                st.outline = ppr.child("outlineLvl")?["val"].flatMap(Int.init)
                if let np = ppr.child("numPr") {
                    st.numID = np.child("numId")?["val"]
                    st.ilvl = np.child("ilvl")?["val"].flatMap(Int.init)
                }
            }
            if let rpr = s.child("rPr") {
                st.bold = rpr.child("b").map(Self.on)
                st.italic = rpr.child("i").map(Self.on)
                st.size = rpr.child("sz")?["val"].flatMap(Double.init).map { $0 / 2 }
                st.mono = Self.isMono(rpr.child("rFonts"))
            }
            styles[id] = st
            if s["type"] == "paragraph", s["default"] == "1" { defaultParaStyle = id }
        }
    }

    mutating func loadNumbering() {
        guard let path = relTarget(type: "numbering") ?? (zip.contains("word/numbering.xml") ? "word/numbering.xml" : nil),
              let root = try? XMLTree.parse(zip.data(path)) else { return }
        var abstract: [String: [Int: NumLevel]] = [:]
        for a in root.children("abstractNum") {
            guard let id = a["abstractNumId"] else { continue }
            var levels: [Int: NumLevel] = [:]
            for l in a.children("lvl") {
                let il = l["ilvl"].flatMap(Int.init) ?? 0
                let fmt = l.child("numFmt")?["val"] ?? "decimal"
                levels[il] = NumLevel(ordered: fmt != "bullet" && fmt != "none", start: l.child("start")?["val"].flatMap(Int.init) ?? 1)
            }
            abstract[id] = levels
        }
        for n in root.children("num") {
            guard let id = n["numId"], let aid = n.child("abstractNumId")?["val"] else { continue }
            var levels = abstract[aid] ?? [:]
            for o in n.children("lvlOverride") {
                if let il = o["ilvl"].flatMap(Int.init), let s = o.child("startOverride")?["val"].flatMap(Int.init) {
                    var lv = levels[il] ?? NumLevel(ordered: true, start: 1)
                    lv.start = s
                    levels[il] = lv
                }
            }
            numbering[id] = levels
        }
    }

    mutating func loadFootnotes() {
        guard let path = relTarget(type: "footnotes"), let root = try? XMLTree.parse(zip.data(path)) else { return }
        for f in root.children("footnote") {
            guard let id = f["id"], (f["type"] ?? "normal") == "normal" else { continue }
            footnotes[id] = f
        }
    }

    static func on(_ n: XNode) -> Bool {
        let v = (n["val"] ?? "true").lowercased()
        return v != "0" && v != "false" && v != "off" && v != "none"
    }

    static func isMono(_ fonts: XNode?) -> Bool {
        guard let f = fonts?["ascii"] ?? fonts?["hAnsi"] else { return false }
        let l = f.lowercased()
        return ["courier", "consolas", "menlo", "monaco", "mono", "source code", "lucida console", "andale"].contains { l.contains($0) }
    }

    /// Resolves an inherited style property.
    func styleChain(_ id: String?) -> [Style] {
        var out: [Style] = []
        var cur = id
        var guardCount = 0
        while let c = cur, let s = styles[c], guardCount < 20 {
            out.append(s)
            cur = s.basedOn
            guardCount += 1
        }
        return out
    }

    func headingLevel(styleID: String?) -> Int? {
        for s in styleChain(styleID) {
            let n = s.name.lowercased().replacingOccurrences(of: " ", with: "")
            if n == "title" { return 1 }
            if n.hasPrefix("heading"), let l = Int(n.dropFirst(7)), (1...9).contains(l) { return min(l, 6) }
            if let o = s.outline, o < 9 { return min(o + 1, 6) }
        }
        if let id = styleID?.lowercased(), id.hasPrefix("heading"), let l = Int(id.dropFirst(7)) { return min(max(l, 1), 6) }
        return nil
    }

    func styleName(_ id: String?) -> String { styleChain(id).map { $0.name.lowercased() }.joined(separator: "|") }

    // MARK: Block level

    mutating func blockItems(_ container: XNode) -> [FlowItem] {
        var out: [FlowItem] = []
        for e in container.elements {
            switch e.name {
            case "p":
                out.append(contentsOf: paragraph(e))
                out.append(contentsOf: pendingExtra)
                pendingExtra.removeAll()
            case "tbl":
                if let t = table(e) { out.append(.block(.table(t))) }
            case "sdt":
                if let c = e.child("sdtContent") { out.append(contentsOf: blockItems(c)) }
            case "customXml", "ins", "moveTo", "smartTag":
                out.append(contentsOf: blockItems(e))
            case "AlternateContent":
                if let alt = e.child("Fallback") ?? e.child("Choice") { out.append(contentsOf: blockItems(alt)) }
            default:
                break
            }
        }
        return out
    }

    func blocks(_ container: XNode) -> [DocBlock] {
        var copy = self
        copy.pendingExtra = []
        return FlowAssembler.assemble(copy.blockItems(container), headingHeuristic: false)
    }

    mutating func table(_ tbl: XNode) -> DocTable? {
        var rows: [DocTableRow] = []
        for tr in tbl.children("tr") {
            var cells: [DocTableCell] = []
            let header = tr.child("trPr")?.child("tblHeader").map(Self.on) ?? false
            for tc in tr.elements where tc.name == "tc" || tc.name == "sdt" {
                let cell = tc.name == "sdt" ? (tc.child("sdtContent")?.child("tc") ?? tc) : tc
                let tcPr = cell.child("tcPr")
                let span = tcPr?.child("gridSpan")?["val"].flatMap(Int.init) ?? 1
                let vmerge = tcPr?.child("vMerge")
                let continued = vmerge != nil && (vmerge?["val"] ?? "continue") == "continue"
                cells.append(continued ? DocTableCell([]) : DocTableCell(blocks(cell)))
                if span > 1 { for _ in 1..<min(span, 64) { cells.append(DocTableCell([])) } }
            }
            if !cells.isEmpty { rows.append(DocTableRow(cells, isHeader: header)) }
        }
        guard !rows.isEmpty else { return nil }
        // No explicit header: treat an all-bold first row as one.
        if !rows.contains(where: \.isHeader), rows.count > 1, Self.isAllBold(rows[0]) { rows[0].isHeader = true }
        return DocTable(rows: rows)
    }

    static func isAllBold(_ r: DocTableRow) -> Bool {
        var any = false
        for c in r.cells {
            for b in c.blocks {
                guard case .paragraph(let inl) = b else { return false }
                for i in inl {
                    switch i {
                    case .strong: any = true
                    case .text(let s) where s.trimmingCharacters(in: .whitespaces).isEmpty: continue
                    default: return false
                    }
                }
            }
        }
        return any
    }

    // MARK: Paragraphs

    mutating func paragraph(_ p: XNode) -> [FlowItem] {
        let ppr = p.child("pPr")
        let styleID = ppr?.child("pStyle")?["val"] ?? defaultParaStyle
        var item = ParaItem([])
        item.heading = headingLevel(styleID: styleID)
        if let o = ppr?.child("outlineLvl")?["val"].flatMap(Int.init), o < 9, item.heading == nil { item.heading = min(o + 1, 6) }
        let chain = styleChain(styleID)
        let name = styleName(styleID)
        item.code = name.contains("code") || name.contains("verbatim") || name.contains("preformatted") || name.contains("source") || chain.contains { $0.mono }
        item.quote = name.contains("quote") || name.contains("block text")
        if let pb = ppr?.child("pageBreakBefore"), Self.on(pb) { item.breakBefore = true }
        if let left = ppr?.child("ind")?["left"] ?? ppr?.child("ind")?["start"], let tw = Double(left) { item.indentLevel = max(0, Int((tw / 720).rounded()) - 1) }

        // Numbering: direct numPr, else from the style.
        var numID = ppr?.child("numPr")?.child("numId")?["val"]
        var ilvl = ppr?.child("numPr")?.child("ilvl")?["val"].flatMap(Int.init)
        if numID == nil { for s in chain { if let n = s.numID { numID = n; ilvl = ilvl ?? s.ilvl; break } } }
        if let n = numID, n != "0", let levels = numbering[n] {
            let l = min(ilvl ?? 0, 8)
            let lv = levels[l] ?? NumLevel(ordered: false, start: 1)
            item.list = (l, lv.ordered, lv.start, n)
            item.heading = nil
        } else if name.contains("list paragraph") || name.contains("list continue") {
            item.continuation = true
        }

        // Paragraph-level defaults for heuristics.
        var paraSize = defaultSize
        for s in chain { if let sz = s.size { paraSize = sz; break } }
        if let sz = ppr?.child("rPr")?.child("sz")?["val"].flatMap(Double.init) { paraSize = sz / 2 }
        let paraBold = chain.first { $0.bold != nil }?.bold ?? false

        var collector = RunCollector(defaultSize: paraSize, paraBold: paraBold)
        collect(p.elements, into: &collector, props: RunProps(), styleChainBold: paraBold)
        item.fontSize = collector.maxSize ?? paraSize
        item.allBold = collector.boldChars > 0 && collector.boldChars >= collector.totalChars

        var out: [FlowItem] = []
        for (k, seg) in collector.segments.enumerated() {
            if k > 0 { out.append(.pageBreak) }
            var it = item
            it.inlines = seg
            if k > 0 { it.breakBefore = false }
            if k == 0 || !seg.isBlank { out.append(.para(it)) }
        }
        return out
    }

    struct RunCollector {
        var segments: [[DocInline]] = [[]]
        var maxSize: Double?
        var boldChars = 0
        var totalChars = 0
        let defaultSize: Double
        let paraBold: Bool
        /// Open complex fields; HYPERLINK fields wrap their result runs.
        var fields: [(instr: String, separated: Bool, result: [DocInline])] = []

        init(defaultSize: Double, paraBold: Bool) {
            self.defaultSize = defaultSize
            self.paraBold = paraBold
        }

        mutating func append(_ i: DocInline) {
            if !fields.isEmpty {
                if fields[fields.count - 1].separated { fields[fields.count - 1].result.append(i) }
                return
            }
            segments[segments.count - 1].append(i)
        }

        mutating func pageBreak() {
            fields.removeAll()
            segments.append([])
        }
    }

    mutating func collect(_ nodes: [XNode], into c: inout RunCollector, props: RunProps, styleChainBold: Bool) {
        for n in nodes {
            switch n.name {
            case "r":
                run(n, into: &c, base: props)
            case "hyperlink":
                var url: String?
                if let id = n["r:id"] ?? n["id"], let r = rels[id] { url = r.target }
                if let anchor = n["anchor"] { url = (url ?? "") + "#" + anchor }
                var inner = RunCollector(defaultSize: c.defaultSize, paraBold: c.paraBold)
                collect(n.elements, into: &inner, props: props, styleChainBold: styleChainBold)
                let content = inner.segments.flatMap { $0 }
                c.maxSize = max(c.maxSize ?? 0, inner.maxSize ?? 0)
                c.totalChars += inner.totalChars
                c.boldChars += inner.boldChars
                if let url, !url.isEmpty { c.append(.link(url: url, content)) } else { content.forEach { c.append($0) } }
            case "fldSimple":
                var inner = RunCollector(defaultSize: c.defaultSize, paraBold: c.paraBold)
                collect(n.elements, into: &inner, props: props, styleChainBold: styleChainBold)
                let content = inner.segments.flatMap { $0 }
                if let url = Self.hyperlinkTarget(n["instr"] ?? "") { c.append(.link(url: url, content)) } else { content.forEach { c.append($0) } }
            case "ins", "moveTo", "smartTag", "customXml", "sdtContent", "dir", "bdo":
                collect(n.elements, into: &c, props: props, styleChainBold: styleChainBold)
            case "sdt":
                if let content = n.child("sdtContent") { collect(content.elements, into: &c, props: props, styleChainBold: styleChainBold) }
            case "AlternateContent":
                if let alt = n.child("Choice") ?? n.child("Fallback") { collect(alt.elements, into: &c, props: props, styleChainBold: styleChainBold) }
            default:
                break // del, moveFrom, bookmarks, proofErr, pPr…
            }
        }
    }

    mutating func run(_ r: XNode, into c: inout RunCollector, base: RunProps) {
        var p = base
        if let rpr = r.child("rPr") {
            if let st = rpr.child("rStyle")?["val"] {
                for s in styleChain(st) {
                    if let b = s.bold { p.bold = b }
                    if let i = s.italic { p.italic = i }
                    if s.mono { p.mono = true }
                    if let sz = s.size { p.size = sz }
                }
            }
            if let b = rpr.child("b") { p.bold = Self.on(b) }
            if let i = rpr.child("i") { p.italic = Self.on(i) }
            if let u = rpr.child("u") { p.underline = Self.on(u) }
            if let s = rpr.child("strike") { p.strike = Self.on(s) }
            if let s = rpr.child("dstrike"), Self.on(s) { p.strike = true }
            if Self.isMono(rpr.child("rFonts")) { p.mono = true }
            if let sz = rpr.child("sz")?["val"].flatMap(Double.init) { p.size = sz / 2 }
            if let v = rpr.child("vanish"), Self.on(v) { return }
        }
        let size = p.size ?? c.defaultSize
        var text = ""
        func emitText() {
            guard !text.isEmpty else { return }
            let visible = text.filter { !$0.isWhitespace }.count
            c.totalChars += visible
            if p.bold || c.paraBold { c.boldChars += visible }
            if visible > 0 { c.maxSize = max(c.maxSize ?? 0, size) }
            var node: DocInline = p.mono ? .code(text) : .text(text)
            if !p.mono {
                if p.strike { node = .strikethrough([node]) }
                if p.underline { node = .underline([node]) }
                if p.italic { node = .emphasis([node]) }
                if p.bold { node = .strong([node]) }
            }
            c.append(node)
            text = ""
        }
        for e in r.elements {
            switch e.name {
            case "t": text += e.text
            case "tab", "ptab": text += "\t"
            case "noBreakHyphen": text += "\u{2011}"
            case "sym":
                if let ch = e["char"], let v = UInt32(ch, radix: 16), v < 0xF000, let u = Unicode.Scalar(v) { text.append(Character(u)) }
            case "br", "cr":
                emitText()
                if e["type"] == "page" { c.pageBreak() } else { c.append(.lineBreak) }
            case "drawing", "pict", "object":
                emitText()
                if let im = image(e) { c.append(.image(im)) }
                for tb in e.all("txbxContent") { pendingExtra.append(contentsOf: blockItems(tb)) }
            case "AlternateContent":
                emitText()
                let alt = e.child("Choice") ?? e.child("Fallback")
                if let alt, let im = image(alt) { c.append(.image(im)) }
                for tb in (alt ?? e).all("txbxContent") { pendingExtra.append(contentsOf: blockItems(tb)) }
            case "fldChar":
                emitText()
                switch e["fldCharType"] {
                case "begin": c.fields.append(("", false, []))
                case "separate": if !c.fields.isEmpty { c.fields[c.fields.count - 1].separated = true }
                case "end":
                    if let f = c.fields.popLast() {
                        if let url = Self.hyperlinkTarget(f.instr) { c.append(.link(url: url, f.result)) } else { f.result.forEach { c.append($0) } }
                    }
                default: break
                }
            case "instrText":
                if !c.fields.isEmpty { c.fields[c.fields.count - 1].instr += e.text }
            case "footnoteReference", "endnoteReference":
                emitText()
                if let id = e["id"], let note = footnotes[id] {
                    if footnoteBlocks[id] == nil {
                        footnoteOrder.append(id)
                        footnoteBlocks[id] = blocks(note)
                    }
                    let n = (footnoteOrder.firstIndex(of: id) ?? 0) + 1
                    c.append(.text("[\(n)]"))
                }
            default:
                break
            }
        }
        emitText()
    }

    /// `HYPERLINK "https://…" \l "anchor"` → URL (or "#anchor").
    static func hyperlinkTarget(_ instr: String) -> String? {
        let t = instr.trimmingCharacters(in: .whitespaces)
        guard t.uppercased().hasPrefix("HYPERLINK") else { return nil }
        var rest = Substring(t.dropFirst(9))
        var url = ""
        var anchor: String?
        var expectAnchor = false
        while true {
            rest = rest.drop { $0 == " " }
            guard let first = rest.first else { break }
            if first == "\\" {
                expectAnchor = rest.dropFirst().first == "l"
                rest = rest.dropFirst(2)
                continue
            }
            let token: String
            if first == "\"" {
                rest = rest.dropFirst()
                let end = rest.firstIndex(of: "\"") ?? rest.endIndex
                token = String(rest[..<end])
                rest = end < rest.endIndex ? rest[rest.index(after: end)...] : ""
            } else {
                let end = rest.firstIndex(of: " ") ?? rest.endIndex
                token = String(rest[..<end])
                rest = rest[end...]
            }
            if expectAnchor { anchor = token; expectAnchor = false } else if url.isEmpty { url = token }
        }
        if let anchor, !anchor.isEmpty { url += "#" + anchor }
        return url.isEmpty ? nil : url
    }

    func image(_ n: XNode) -> DocImage? {
        var rid: String?
        if let blip = n.first("blip") { rid = blip["r:embed"] ?? blip["embed"] }
        if rid == nil, let im = n.first("imagedata") { rid = im["r:id"] ?? im["id"] }
        guard let id = rid, let rel = rels[id], !rel.external, let data = try? zip.data(rel.target) else { return nil }
        var w: Double?, h: Double?
        if let ext = n.first("extent"), let cx = ext["cx"].flatMap(Double.init), let cy = ext["cy"].flatMap(Double.init) {
            w = cx / 12700
            h = cy / 12700
        }
        let docPr = n.first("docPr")
        let alt = docPr?["descr"] ?? docPr?["title"] ?? ""
        let mime = ImageSupport.sniffMIME(data, fileExtension: (rel.target as NSString).pathExtension) ?? "image/png"
        return DocImage(data: data, mime: mime, alt: alt, width: w, height: h, source: (rel.target as NSString).lastPathComponent)
    }
}
