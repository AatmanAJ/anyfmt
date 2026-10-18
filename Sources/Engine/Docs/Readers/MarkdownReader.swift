import Foundation

/// CommonMark-flavoured Markdown → `DocModel`, with the GFM extensions people
/// actually use: tables, strikethrough, task lists, bare-URL autolinks.
///
/// Two phases like the spec: block structure first (raw inline text kept),
/// then inline parsing once all link reference definitions are known. The
/// inline pass implements the delimiter-run algorithm (left/right flanking,
/// rule of three), so `***a** b*` and intraword `_` behave like CommonMark.
public enum MarkdownReader {
    /// - Parameter baseURL: directory used to resolve relative image paths.
    public static func parse(_ source: String, baseURL: URL? = nil) -> DocModel {
        var lines = normalizeLines(source)
        var meta = DocMetadata()
        stripFrontMatter(&lines, into: &meta)
        var parser = BlockParser()
        let raw = parser.parse(lines[...])
        let inline = InlineContext(refs: parser.refs, baseURL: baseURL)
        let blocks = raw.flatMap { inline.convert($0) }
        return DocModel(metadata: meta, blocks: blocks)
    }

    static func normalizeLines(_ s: String) -> [String] {
        var text = s
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        return text.split(separator: "\n", omittingEmptySubsequences: false).map { expandLeadingTabs(String($0)) }
    }

    /// Expands tabs in leading whitespace to the next multiple of 4 (indentation only).
    static func expandLeadingTabs(_ line: String) -> String {
        guard line.contains("\t") else { return line }
        var col = 0
        var out = ""
        var idx = line.startIndex
        while idx < line.endIndex {
            let c = line[idx]
            if c == " " { out.append(" "); col += 1 } else if c == "\t" {
                let n = 4 - (col % 4)
                out += String(repeating: " ", count: n)
                col += n
            } else { break }
            idx = line.index(after: idx)
        }
        return out + line[idx...]
    }

    /// YAML front matter: `---` … `---` with `key: value` lines (title, author, lang).
    static func stripFrontMatter(_ lines: inout [String], into meta: inout DocMetadata) {
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return }
        guard let end = lines.indices.dropFirst().prefix(80).first(where: {
            let t = lines[$0].trimmingCharacters(in: .whitespaces)
            return t == "---" || t == "..."
        }) else { return }
        let body = lines[1..<end]
        guard body.contains(where: { $0.contains(":") }) else { return }
        for l in body {
            guard let c = l.firstIndex(of: ":") else { continue }
            let key = l[..<c].trimmingCharacters(in: .whitespaces).lowercased()
            var value = l[l.index(after: c)...].trimmingCharacters(in: .whitespaces)
            if value.count >= 2, (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            switch key {
            case "title": meta.title = value
            case "author": meta.author = value
            case "lang", "language": meta.language = value
            default: break
            }
        }
        lines.removeSubrange(0...end)
    }
}

// MARK: - Block phase

indirect enum RawBlock {
    case heading(Int, String)
    case paragraph(String)
    case code(String?, String)
    case quote([RawBlock])
    case list(ordered: Bool, start: Int, items: [(blocks: [RawBlock], checked: Bool?)])
    case table(header: [String], aligns: [DocTable.Alignment], rows: [[String]])
    case hr
    case html(String)
}

struct LinkRef { let url: String; let title: String? }

struct ListMarker {
    let indent: Int
    let bullet: Character?     // "-", "+", "*"
    let delimiter: Character?  // "." or ")" for ordered
    let number: Int
    let contentIndent: Int
    let rest: String
    var ordered: Bool { bullet == nil }
    func sameType(_ o: ListMarker) -> Bool { bullet == o.bullet && delimiter == o.delimiter }
}

struct BlockParser {
    var refs: [String: LinkRef] = [:]

    static let htmlBlockTags: Set<String> = [
        "address", "article", "aside", "blockquote", "center", "details", "dialog", "dd", "div", "dl", "dt",
        "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3", "h4", "h5", "h6", "header",
        "hr", "li", "main", "nav", "ol", "p", "pre", "section", "table", "tbody", "td", "tfoot", "th", "thead",
        "tr", "ul", "script", "style", "iframe", "summary", "body", "html", "head",
    ]

    mutating func parse(_ lines: ArraySlice<String>) -> [RawBlock] {
        var out: [RawBlock] = []
        var para: [String] = []
        var i = lines.startIndex
        let end = lines.endIndex

        func flush() {
            if !para.isEmpty {
                out.append(.paragraph(para.map(Self.trimLeading).joined(separator: "\n")))
                para.removeAll()
            }
        }

        while i < end {
            let line = lines[i]
            if Self.isBlank(line) { flush(); i += 1; continue }
            let indent = Self.indent(line)

            // Indented code (can't interrupt a paragraph).
            if indent >= 4 && para.isEmpty {
                var code: [String] = []
                while i < end, Self.isBlank(lines[i]) || Self.indent(lines[i]) >= 4 {
                    code.append(Self.isBlank(lines[i]) ? "" : Self.dropIndent(lines[i], 4))
                    i += 1
                }
                while code.last == "" { code.removeLast() }
                out.append(.code(nil, code.joined(separator: "\n")))
                continue
            }
            let t = Self.dropIndent(line, min(indent, 3))

            if let fence = Self.fence(t) {
                flush()
                let fenceIndent = min(indent, 3)
                let lang = fence.info.split(separator: " ").first.map(String.init)
                var code: [String] = []
                i += 1
                while i < end {
                    let l = lines[i]
                    let ct = Self.dropIndent(l, min(Self.indent(l), 3))
                    if Self.indent(l) < 4, ct.hasPrefix(String(repeating: fence.char, count: fence.count)),
                       ct.trimmingCharacters(in: .whitespaces).allSatisfy({ $0 == fence.char }) {
                        i += 1
                        break
                    }
                    code.append(Self.dropIndent(l, min(fenceIndent, Self.indent(l))))
                    i += 1
                }
                out.append(.code(lang.flatMap { $0.isEmpty ? nil : MarkdownReader.unescape($0) }, code.joined(separator: "\n")))
                continue
            }
            if let h = Self.atxHeading(t) { flush(); out.append(.heading(h.0, h.1)); i += 1; continue }
            if !para.isEmpty, let level = Self.setextLevel(t) {
                out.append(.heading(level, para.map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")))
                para.removeAll()
                i += 1
                continue
            }
            if Self.isThematicBreak(t) { flush(); out.append(.hr); i += 1; continue }

            if t.hasPrefix(">") {
                flush()
                var inner: [String] = []
                while i < end {
                    let l = lines[i]
                    let li = Self.indent(l)
                    let lt = Self.dropIndent(l, min(li, 3))
                    if li < 4, lt.hasPrefix(">") {
                        var rest = String(lt.dropFirst())
                        if rest.hasPrefix(" ") { rest.removeFirst() }
                        inner.append(rest)
                    } else if !Self.isBlank(l), let last = inner.last, !Self.isBlank(last), !Self.startsBlock(lt) {
                        inner.append(l) // lazy continuation
                    } else {
                        break
                    }
                    i += 1
                }
                var sub = BlockParser()
                let blocks = sub.parse(inner[...])
                refs.merge(sub.refs) { a, _ in a }
                out.append(.quote(blocks))
                continue
            }

            if let m = Self.listMarker(line), indent < 4, para.isEmpty || !m.ordered || m.number == 1 {
                if !para.isEmpty, m.rest.trimmingCharacters(in: .whitespaces).isEmpty {
                    // An empty item can't interrupt a paragraph.
                } else {
                    flush()
                    let (block, next) = parseList(lines, from: i, first: m)
                    out.append(block)
                    i = next
                    continue
                }
            }

            if i + 1 < end, t.contains("|"), let table = Self.tableStart(t, lines[i + 1]) {
                flush()
                var rows: [[String]] = []
                i += 2
                while i < end, !Self.isBlank(lines[i]) {
                    let rt = lines[i].trimmingCharacters(in: .whitespaces)
                    if Self.startsBlock(rt) && !rt.contains("|") { break }
                    if !rt.contains("|") { break }
                    rows.append(Self.splitRow(rt))
                    i += 1
                }
                out.append(.table(header: table.header, aligns: table.aligns, rows: rows))
                continue
            }

            if Self.isHTMLBlockStart(t) {
                flush()
                var html: [String] = []
                let isComment = t.hasPrefix("<!--")
                while i < end {
                    if !isComment && Self.isBlank(lines[i]) { break }
                    html.append(lines[i])
                    i += 1
                    if isComment, html.last?.contains("-->") == true { break }
                }
                out.append(.html(html.joined(separator: "\n")))
                continue
            }

            if para.isEmpty, let (label, ref) = Self.linkReferenceDefinition(t) {
                if refs[label] == nil { refs[label] = ref }
                i += 1
                continue
            }

            para.append(line)
            i += 1
        }
        flush()
        return out
    }

    mutating func parseList(_ lines: ArraySlice<String>, from start: Int, first: ListMarker) -> (RawBlock, Int) {
        var items: [(blocks: [RawBlock], checked: Bool?)] = []
        var i = start
        let end = lines.endIndex
        var marker: ListMarker? = first
        while let m = marker {
            var content: [String] = [m.rest]
            i += 1
            var sawBlank = false
            while i < end {
                let l = lines[i]
                if Self.isBlank(l) { content.append(""); sawBlank = true; i += 1; continue }
                let ind = Self.indent(l)
                if ind >= m.contentIndent {
                    content.append(Self.dropIndent(l, m.contentIndent))
                    sawBlank = false
                    i += 1
                    continue
                }
                if Self.listMarker(l) != nil { break }
                let lt = Self.dropIndent(l, min(ind, 3))
                if !sawBlank, !Self.startsBlock(lt) {
                    content.append(lt) // lazy paragraph continuation
                    i += 1
                    continue
                }
                break
            }
            // Trailing blank lines belong between items, not inside.
            while content.last == "" { content.removeLast() }
            var checked: Bool?
            if let f = content.first {
                let lower = f.lowercased()
                if lower.hasPrefix("[ ] ") || lower == "[ ]" { checked = false; content[0] = String(f.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
                else if lower.hasPrefix("[x] ") || lower == "[x]" { checked = true; content[0] = String(f.dropFirst(3)).trimmingCharacters(in: .whitespaces) }
            }
            var sub = BlockParser()
            let blocks = sub.parse(content[...])
            refs.merge(sub.refs) { a, _ in a }
            items.append((blocks, checked))
            // Next item of the same list?
            var j = i
            while j < end, Self.isBlank(lines[j]) { j += 1 }
            if j < end, let next = Self.listMarker(lines[j]), next.sameType(first), Self.indent(lines[j]) < first.contentIndent + 1, Self.indent(lines[j]) < 4 {
                i = j
                marker = next
            } else {
                marker = nil
            }
        }
        return (.list(ordered: first.ordered, start: first.number, items: items), i)
    }

    // MARK: line predicates

    static func isBlank(_ s: String) -> Bool { s.allSatisfy { $0 == " " || $0 == "\t" } }

    static func trimLeading(_ s: String) -> String { String(s.drop { $0 == " " || $0 == "\t" }) }

    static func indent(_ s: String) -> Int {
        var n = 0
        for c in s { if c == " " { n += 1 } else { break } }
        return n
    }

    static func dropIndent(_ s: String, _ n: Int) -> String {
        var k = 0
        var idx = s.startIndex
        while k < n, idx < s.endIndex, s[idx] == " " { idx = s.index(after: idx); k += 1 }
        return String(s[idx...])
    }

    static func fence(_ t: String) -> (char: Character, count: Int, info: String)? {
        guard let c = t.first, c == "`" || c == "~" else { return nil }
        let run = t.prefix { $0 == c }.count
        guard run >= 3 else { return nil }
        let info = String(t.dropFirst(run)).trimmingCharacters(in: .whitespaces)
        if c == "`" && info.contains("`") { return nil }
        return (c, run, info)
    }

    static func atxHeading(_ t: String) -> (Int, String)? {
        let hashes = t.prefix { $0 == "#" }.count
        guard (1...6).contains(hashes) else { return nil }
        let rest = t.dropFirst(hashes)
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" else { return nil }
        var content = rest.trimmingCharacters(in: .whitespaces)
        // Optional closing sequence: " ###"
        if let r = content.range(of: #"(^|\s)#+\s*$"#, options: .regularExpression) {
            content = String(content[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
        return (hashes, content)
    }

    static func setextLevel(_ t: String) -> Int? {
        let s = t.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        if s.allSatisfy({ $0 == "=" }) { return 1 }
        if s.allSatisfy({ $0 == "-" }) { return 2 }
        return nil
    }

    static func isThematicBreak(_ t: String) -> Bool {
        let s = t.filter { $0 != " " && $0 != "\t" }
        guard s.count >= 3, let c = s.first, c == "-" || c == "*" || c == "_" else { return false }
        return s.allSatisfy { $0 == c }
    }

    static func listMarker(_ line: String) -> ListMarker? {
        let ind = indent(line)
        let t = Array(line.dropFirst(ind))
        guard let c = t.first else { return nil }
        var markerLen = 0
        var bullet: Character?
        var delim: Character?
        var number = 1
        if c == "-" || c == "+" || c == "*" {
            bullet = c
            markerLen = 1
        } else if c.isASCII, c.isNumber {
            var digits = ""
            var k = 0
            while k < t.count, k < 9, t[k].isASCII, t[k].isNumber { digits.append(t[k]); k += 1 }
            guard k < t.count, t[k] == "." || t[k] == ")" else { return nil }
            delim = t[k]
            number = Int(digits) ?? 1
            markerLen = k + 1
        } else {
            return nil
        }
        // Marker must be followed by a space/tab or end of line.
        if markerLen < t.count, t[markerLen] != " " && t[markerLen] != "\t" { return nil }
        if bullet != nil {
            let s = String(t)
            if isThematicBreak(s) { return nil }
        }
        var spaces = 0
        while markerLen + spaces < t.count, t[markerLen + spaces] == " " { spaces += 1 }
        let restAll = String(t.dropFirst(markerLen))
        if markerLen + spaces >= t.count {
            return ListMarker(indent: ind, bullet: bullet, delimiter: delim, number: number, contentIndent: ind + markerLen + 1, rest: "")
        }
        if spaces > 4 { spaces = 1 } // content is indented code; keep one space
        let rest = String(restAll.dropFirst(spaces))
        return ListMarker(indent: ind, bullet: bullet, delimiter: delim, number: number, contentIndent: ind + markerLen + spaces, rest: rest)
    }

    static func startsBlock(_ t: String) -> Bool {
        if t.hasPrefix(">") || atxHeading(t) != nil || isThematicBreak(t) || fence(t) != nil { return true }
        if listMarker(t) != nil { return true }
        return isHTMLBlockStart(t)
    }

    static func isHTMLBlockStart(_ t: String) -> Bool {
        guard t.hasPrefix("<") else { return false }
        if t.hasPrefix("<!--") { return true }
        var name = ""
        for c in t.dropFirst().drop(while: { $0 == "/" }) {
            if c.isLetter || c.isNumber { name.append(c) } else { break }
        }
        return htmlBlockTags.contains(name.lowercased())
    }

    static func tableStart(_ header: String, _ delimiter: String) -> (header: [String], aligns: [DocTable.Alignment])? {
        let d = delimiter.trimmingCharacters(in: .whitespaces)
        guard d.contains("-"), d.allSatisfy({ "|:- \t".contains($0) }) else { return nil }
        let dcells = splitRow(d)
        guard !dcells.isEmpty, dcells.allSatisfy({ c in
            let s = c.trimmingCharacters(in: .whitespaces)
            return !s.isEmpty && s.contains("-") && s.allSatisfy { $0 == "-" || $0 == ":" } && !s.dropFirst().dropLast().contains(":")
        }) else { return nil }
        let h = splitRow(header.trimmingCharacters(in: .whitespaces))
        guard h.count == dcells.count else { return nil }
        let aligns: [DocTable.Alignment] = dcells.map { c in
            let s = c.trimmingCharacters(in: .whitespaces)
            switch (s.hasPrefix(":"), s.hasSuffix(":")) {
            case (true, true): return .center
            case (false, true): return .right
            case (true, false): return .left
            default: return .none
            }
        }
        return (h, aligns)
    }

    /// Splits a table row on unescaped pipes outside code spans.
    static func splitRow(_ row: String) -> [String] {
        var s = Array(row.trimmingCharacters(in: .whitespaces))
        if s.first == "|" { s.removeFirst() }
        if s.last == "|", !(s.count >= 2 && s[s.count - 2] == "\\") { s.removeLast() }
        var cells: [String] = []
        var cur = ""
        var i = 0
        var inCode = 0
        while i < s.count {
            let c = s[i]
            if c == "\\", i + 1 < s.count, s[i + 1] == "|" { cur.append("|"); i += 2; continue }
            if c == "`" {
                let run = s[i...].prefix { $0 == "`" }.count
                if inCode == 0 { inCode = run } else if inCode == run { inCode = 0 }
                cur += String(repeating: "`", count: run)
                i += run
                continue
            }
            if c == "|" && inCode == 0 { cells.append(cur.trimmingCharacters(in: .whitespaces)); cur = ""; i += 1; continue }
            cur.append(c)
            i += 1
        }
        cells.append(cur.trimmingCharacters(in: .whitespaces))
        return cells
    }

    static func linkReferenceDefinition(_ t: String) -> (String, LinkRef)? {
        guard t.hasPrefix("[") else { return nil }
        let pattern = #"^\[((?:[^\]\\]|\\.)+)\]:\s*(<[^>\n]*>|\S+)(?:\s+("(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|\((?:[^)\\]|\\.)*\)))?\s*$"#
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)),
              let lr = Range(m.range(at: 1), in: t), let ur = Range(m.range(at: 2), in: t) else { return nil }
        var url = String(t[ur])
        if url.hasPrefix("<") && url.hasSuffix(">") { url = String(url.dropFirst().dropLast()) }
        var title: String?
        if let tr = Range(m.range(at: 3), in: t) { title = String(t[tr].dropFirst().dropLast()) }
        return (normalizeLabel(String(t[lr])), LinkRef(url: MarkdownReader.unescape(url), title: title.map(MarkdownReader.unescape)))
    }

    static func normalizeLabel(_ s: String) -> String {
        s.lowercased().split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }
}

// MARK: - Inline phase

struct InlineContext {
    let refs: [String: LinkRef]
    let baseURL: URL?

    func convert(_ b: RawBlock) -> [DocBlock] {
        switch b {
        case .heading(let l, let s): return [.heading(level: l, parse(s).trimmed)]
        case .paragraph(let s):
            let inl = parse(s).trimmed
            if inl.isEmpty { return [] }
            if inl.count == 1, case .image(let im) = inl[0] { return [.image(im)] }
            return [.paragraph(inl)]
        case .code(let lang, let s): return [.codeBlock(language: lang, s)]
        case .quote(let bs): return [.blockquote(bs.flatMap(convert))]
        case .list(let ordered, let start, let items):
            return [.list(DocList(ordered: ordered, start: start, items: items.map { DocListItem($0.blocks.flatMap(convert), checked: $0.checked) }))]
        case .table(let header, let aligns, let rows):
            let n = header.count
            let head = DocTableRow(header.map { DocTableCell(inlines: parse($0).trimmed) }, isHeader: true)
            let body = rows.map { r -> DocTableRow in
                var cells = r.prefix(n).map { DocTableCell(inlines: parse($0).trimmed) }
                while cells.count < n { cells.append(DocTableCell([])) }
                return DocTableRow(cells)
            }
            return [.table(DocTable(rows: [head] + body, alignments: aligns))]
        case .hr: return [.horizontalRule]
        case .html(let h):
            return HTMLReader.parseFragment(h, baseURL: baseURL)
        }
    }

    func parse(_ s: String) -> [DocInline] {
        var p = InlineParser(chars: Array(s), ctx: self)
        return p.run()
    }

    func image(src: String, alt: String) -> DocImage {
        if src.hasPrefix("data:"), let d = ImageSupport.decodeDataURI(src) {
            return DocImage(data: d.data, mime: ImageSupport.sniffMIME(d.data) ?? d.mime, alt: alt)
        }
        if let local = LocalResource.resolve(src, baseURL: baseURL), let data = try? Data(contentsOf: local) {
            return DocImage(data: data, mime: ImageSupport.sniffMIME(data, fileExtension: local.pathExtension) ?? "application/octet-stream", alt: alt, source: src)
        }
        return DocImage(data: nil, mime: "", alt: alt, source: src)
    }
}

/// Resolves a relative or file: reference against a base directory. Never resolves network URLs.
enum LocalResource {
    static func resolve(_ ref: String, baseURL: URL?) -> URL? {
        let r = ref.trimmingCharacters(in: .whitespaces)
        if r.isEmpty { return nil }
        if let u = URL(string: r), let scheme = u.scheme?.lowercased() {
            guard scheme == "file" else { return nil }
            return u
        }
        guard let baseURL else { return nil }
        let decoded = r.removingPercentEncoding ?? r
        let path = decoded.split(separator: "#").first.map(String.init) ?? decoded
        let u = path.hasPrefix("/") ? URL(fileURLWithPath: path) : baseURL.appendingPathComponent(path)
        return FileManager.default.fileExists(atPath: u.path) ? u : nil
    }
}

private struct Delim {
    var char: Character
    var count: Int
    let orig: Int
    let canOpen: Bool
    let canClose: Bool
}

private struct Bracket {
    let isImage: Bool
    var active: Bool
    /// Index in `chars` just after "[".
    let start: Int
}

private enum Tok {
    case text(String)
    case node(DocInline)
    case delim(Delim)
    case bracket(Bracket)
}

private struct InlineParser {
    let chars: [Character]
    let ctx: InlineContext
    var toks: [Tok] = []
    var buf = ""
    var i = 0

    init(chars: [Character], ctx: InlineContext) {
        self.chars = chars
        self.ctx = ctx
    }

    static let asciiPunct: Set<Character> = Set("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~")

    static func isPunct(_ c: Character?) -> Bool {
        guard let c else { return false }
        if asciiPunct.contains(c) { return true }
        return c.unicodeScalars.first.map { CharacterSet.punctuationCharacters.contains($0) || CharacterSet.symbols.contains($0) } ?? false
    }

    static func isSpace(_ c: Character?) -> Bool {
        guard let c else { return true }
        return c.isWhitespace
    }

    mutating func flushText() {
        if !buf.isEmpty { toks.append(.text(buf)); buf = "" }
    }

    mutating func run() -> [DocInline] {
        while i < chars.count {
            let c = chars[i]
            switch c {
            case "\\":
                if i + 1 < chars.count, chars[i + 1] == "\n" {
                    flushText(); toks.append(.node(.lineBreak)); i += 2
                    skipLeadingSpaces()
                } else if i + 1 < chars.count, Self.asciiPunct.contains(chars[i + 1]) {
                    buf.append(chars[i + 1]); i += 2
                } else { buf.append(c); i += 1 }
            case "`":
                codeSpan()
            case "*", "_", "~":
                delimiterRun(c)
            case "!":
                if i + 1 < chars.count, chars[i + 1] == "[" {
                    flushText(); toks.append(.bracket(Bracket(isImage: true, active: true, start: i + 2))); i += 2
                } else { buf.append(c); i += 1 }
            case "[":
                flushText(); toks.append(.bracket(Bracket(isImage: false, active: true, start: i + 1))); i += 1
            case "]":
                closeBracket()
            case "<":
                angle()
            case "&":
                entity()
            case "\n":
                // Hard break when the line ended with 2+ spaces; otherwise a soft break (space).
                var trailing = 0
                while buf.hasSuffix(" ") { buf.removeLast(); trailing += 1 }
                if trailing >= 2 { flushText(); toks.append(.node(.lineBreak)) } else { buf.append(" ") }
                i += 1
                skipLeadingSpaces()
            case "h", "w", "H", "W":
                if !bareAutolink() { buf.append(c); i += 1 }
            default:
                buf.append(c)
                i += 1
            }
        }
        flushText()
        Self.processEmphasis(&toks)
        return Self.inlines(toks).compacted
    }

    mutating func skipLeadingSpaces() {
        while i < chars.count, chars[i] == " " { i += 1 }
    }

    mutating func codeSpan() {
        let run = chars[i...].prefix { $0 == "`" }.count
        var j = i + run
        while j < chars.count {
            if chars[j] == "`" {
                let r = chars[j...].prefix { $0 == "`" }.count
                if r == run {
                    var content = String(chars[(i + run)..<j]).replacingOccurrences(of: "\n", with: " ")
                    if content.count >= 2, content.hasPrefix(" "), content.hasSuffix(" "), !content.allSatisfy({ $0 == " " }) {
                        content = String(content.dropFirst().dropLast())
                    }
                    flushText()
                    toks.append(.node(.code(content)))
                    i = j + run
                    return
                }
                j += r
            } else { j += 1 }
        }
        buf += String(repeating: "`", count: run)
        i += run
    }

    mutating func delimiterRun(_ c: Character) {
        let run = chars[i...].prefix { $0 == c }.count
        let before: Character? = i > 0 ? chars[i - 1] : nil
        let after: Character? = i + run < chars.count ? chars[i + run] : nil
        let left = !Self.isSpace(after) && (!Self.isPunct(after) || Self.isSpace(before) || Self.isPunct(before))
        let right = !Self.isSpace(before) && (!Self.isPunct(before) || Self.isSpace(after) || Self.isPunct(after))
        var canOpen = left, canClose = right
        if c == "_" {
            canOpen = left && (!right || Self.isPunct(before))
            canClose = right && (!left || Self.isPunct(after))
        }
        if c == "~" && run > 2 {
            buf += String(repeating: "~", count: run)
            i += run
            return
        }
        flushText()
        toks.append(.delim(Delim(char: c, count: run, orig: run, canOpen: canOpen, canClose: canClose)))
        i += run
    }

    mutating func closeBracket() {
        flushText()
        guard let b = toks.lastIndex(where: { if case .bracket = $0 { return true }; return false }),
              case .bracket(let br) = toks[b] else {
            buf.append("]"); i += 1
            return
        }
        if !br.active {
            toks[b] = .text(br.isImage ? "![" : "[")
            buf.append("]"); i += 1
            return
        }
        let labelText = String(chars[br.start..<i])
        var j = i + 1
        var dest: String?
        if j < chars.count, chars[j] == "(", let parsed = parseInlineLink(from: j) {
            dest = parsed.dest
            j = parsed.end
        } else if j < chars.count, chars[j] == "[", let close = chars[(j + 1)...].firstIndex(of: "]") {
            let label = String(chars[(j + 1)..<close])
            let key = BlockParser.normalizeLabel(label.isEmpty ? labelText : label)
            if let r = ctx.refs[key] { dest = r.url; j = close + 1 }
        }
        if dest == nil, let r = ctx.refs[BlockParser.normalizeLabel(labelText)] {
            dest = r.url
            j = i + 1
            // Collapsed reference "[foo][]"
            if j + 1 < chars.count, chars[j] == "[", chars[j + 1] == "]" { j += 2 }
        }
        guard let url = dest else {
            toks[b] = .text(br.isImage ? "![" : "[")
            buf.append("]"); i += 1
            return
        }
        var inner = Array(toks[(b + 1)...])
        Self.processEmphasis(&inner)
        let content = Self.inlines(inner).compacted
        toks.removeSubrange(b...)
        if br.isImage {
            toks.append(.node(.image(ctx.image(src: url, alt: content.plainText))))
        } else {
            toks.append(.node(.link(url: url, content)))
            // Links can't contain links: deactivate earlier openers.
            for k in toks.indices { if case .bracket(var o) = toks[k], !o.isImage { o.active = false; toks[k] = .bracket(o) } }
        }
        i = j
    }

    /// `(dest "title")` starting at "(". Returns destination and index after ")".
    func parseInlineLink(from start: Int) -> (dest: String, end: Int)? {
        var j = start + 1
        func skipWS() { while j < chars.count, chars[j].isWhitespace { j += 1 } }
        skipWS()
        var dest = ""
        if j < chars.count, chars[j] == "<" {
            j += 1
            while j < chars.count, chars[j] != ">" {
                if chars[j] == "\n" || chars[j] == "<" { return nil }
                if chars[j] == "\\", j + 1 < chars.count { dest.append(chars[j + 1]); j += 2; continue }
                dest.append(chars[j]); j += 1
            }
            guard j < chars.count else { return nil }
            j += 1
        } else {
            var depth = 0
            while j < chars.count {
                let c = chars[j]
                if c.isWhitespace { break }
                if c == "\\", j + 1 < chars.count, Self.asciiPunct.contains(chars[j + 1]) { dest.append(chars[j + 1]); j += 2; continue }
                if c == "(" { depth += 1 }
                if c == ")" { if depth == 0 { break }; depth -= 1 }
                dest.append(c)
                j += 1
            }
        }
        skipWS()
        if j < chars.count, chars[j] == "\"" || chars[j] == "'" || chars[j] == "(" {
            let close: Character = chars[j] == "(" ? ")" : chars[j]
            j += 1
            while j < chars.count, chars[j] != close {
                if chars[j] == "\\" { j += 1 }
                j += 1
            }
            guard j < chars.count else { return nil }
            j += 1
            skipWS()
        }
        guard j < chars.count, chars[j] == ")" else { return nil }
        return (MarkdownReader.decodeEntities(dest), j + 1)
    }

    mutating func angle() {
        guard let close = chars[(i + 1)...].firstIndex(of: ">") else { buf.append("<"); i += 1; return }
        let inner = String(chars[(i + 1)..<close])
        if inner.hasPrefix("!--") {
            // HTML comment: skip to "-->".
            let s = String(chars[i...])
            if let r = s.range(of: "-->") { i += s.distance(from: s.startIndex, to: r.upperBound); return }
        }
        if !inner.contains(" "), !inner.contains("<") {
            if inner.range(of: #"^[A-Za-z][A-Za-z0-9+.\-]{1,31}:[^\s<>]*$"#, options: .regularExpression) != nil {
                flushText(); toks.append(.node(.link(url: inner, [.text(inner)]))); i = close + 1; return
            }
            if inner.range(of: #"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$"#, options: .regularExpression) != nil {
                flushText(); toks.append(.node(.link(url: "mailto:" + inner, [.text(inner)]))); i = close + 1; return
            }
        }
        // Inline HTML tags: <br> becomes a line break, other tags are dropped (their text stays).
        if inner.range(of: #"^/?[A-Za-z][A-Za-z0-9-]*(\s[^<>]*)?/?$"#, options: .regularExpression) != nil {
            let name = inner.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/ ")).split(separator: " ").first.map(String.init) ?? ""
            if name == "br" { flushText(); toks.append(.node(.lineBreak)) }
            i = close + 1
            return
        }
        buf.append("<")
        i += 1
    }

    mutating func entity() {
        let s = chars[i...].prefix(34)
        guard let semi = s.firstIndex(of: ";") else { buf.append("&"); i += 1; return }
        let name = String(chars[(i + 1)..<semi])
        if let decoded = MarkdownReader.entity(name) {
            buf += decoded
            i = semi + 1
        } else {
            buf.append("&")
            i += 1
        }
    }

    /// GFM extended autolinks: http://, https://, www.
    mutating func bareAutolink() -> Bool {
        let prev: Character? = i > 0 ? chars[i - 1] : nil
        if let prev, !prev.isWhitespace, !"*_~(".contains(prev) { return false }
        let rest = String(chars[i...].prefix(8)).lowercased()
        guard rest.hasPrefix("http://") || rest.hasPrefix("https://") || rest.hasPrefix("www.") else { return false }
        var j = i
        while j < chars.count, !chars[j].isWhitespace, chars[j] != "<" { j += 1 }
        var end = j
        // Trim trailing punctuation and unbalanced parentheses.
        while end > i, "?!.,:*_~'\"".contains(chars[end - 1]) { end -= 1 }
        while end > i, chars[end - 1] == ")" {
            let seg = chars[i..<end]
            if seg.filter({ $0 == "(" }).count < seg.filter({ $0 == ")" }).count { end -= 1 } else { break }
        }
        let text = String(chars[i..<end])
        guard text.contains(".") else { return false }
        let url = text.lowercased().hasPrefix("www.") ? "http://" + text : text
        flushText()
        toks.append(.node(.link(url: url, [.text(text)])))
        i = end
        return true
    }

    // MARK: emphasis

    static func processEmphasis(_ toks: inout [Tok]) {
        var i = 0
        while i < toks.count {
            guard case .delim(var closer) = toks[i], closer.canClose, closer.count > 0 else { i += 1; continue }
            var found = -1
            var j = i - 1
            while j >= 0 {
                if case .delim(let op) = toks[j], op.char == closer.char, op.canOpen, op.count > 0 {
                    if closer.char == "~" {
                        if op.count == closer.count { found = j; break }
                    } else {
                        let odd = (op.canClose || closer.canOpen) && (op.orig + closer.orig) % 3 == 0 && !(op.orig % 3 == 0 && closer.orig % 3 == 0)
                        if !odd { found = j; break }
                    }
                }
                j -= 1
            }
            guard found >= 0, case .delim(var op) = toks[found] else { i += 1; continue }
            let use = closer.char == "~" ? closer.count : ((op.count >= 2 && closer.count >= 2) ? 2 : 1)
            let content = Self.inlines(Array(toks[(found + 1)..<i])).compacted
            let node: DocInline = closer.char == "~" ? .strikethrough(content) : (use == 2 ? .strong(content) : .emphasis(content))
            op.count -= use
            closer.count -= use
            var rebuilt = Array(toks[..<found])
            if op.count > 0 { rebuilt.append(.delim(op)) }
            rebuilt.append(.node(node))
            let next = rebuilt.count
            if closer.count > 0 { rebuilt.append(.delim(closer)) }
            rebuilt.append(contentsOf: toks[(i + 1)...])
            toks = rebuilt
            i = next
        }
    }

    static func inlines(_ toks: [Tok]) -> [DocInline] {
        toks.map { t -> DocInline in
            switch t {
            case .text(let s): .text(s)
            case .node(let n): n
            case .delim(let d): .text(String(repeating: d.char, count: d.count))
            case .bracket(let b): .text(b.isImage ? "![" : "[")
            }
        }
    }
}

extension MarkdownReader {
    static func unescape(_ s: String) -> String {
        var out = ""
        var it = s.makeIterator()
        while let c = it.next() {
            if c == "\\", let n = it.next() {
                if InlineParser.asciiPunct.contains(n) { out.append(n) } else { out.append(c); out.append(n) }
            } else { out.append(c) }
        }
        return decodeEntities(out)
    }

    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = ""
        var rest = Substring(s)
        while let amp = rest.firstIndex(of: "&") {
            out += rest[..<amp]
            let after = rest[rest.index(after: amp)...]
            if let semi = after.prefix(33).firstIndex(of: ";"), let d = entity(String(after[..<semi])) {
                out += d
                rest = after[after.index(after: semi)...]
            } else {
                out.append("&")
                rest = after
            }
        }
        return out + rest
    }

    static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{00A0}", "copy": "©", "reg": "®",
        "trade": "™", "hellip": "…", "mdash": "—", "ndash": "–", "lsquo": "‘", "rsquo": "’", "ldquo": "“",
        "rdquo": "”", "bull": "•", "middot": "·", "deg": "°", "plusmn": "±", "times": "×", "divide": "÷",
        "euro": "€", "pound": "£", "yen": "¥", "cent": "¢", "sect": "§", "para": "¶", "laquo": "«", "raquo": "»",
        "larr": "←", "rarr": "→", "uarr": "↑", "darr": "↓", "harr": "↔", "frac12": "½", "frac14": "¼",
        "frac34": "¾", "sup2": "²", "sup3": "³", "iexcl": "¡", "iquest": "¿", "shy": "\u{00AD}", "ensp": "\u{2002}",
        "emsp": "\u{2003}", "thinsp": "\u{2009}", "zwj": "\u{200D}", "zwnj": "\u{200C}", "check": "✓",
    ]

    static func entity(_ name: String) -> String? {
        if name.hasPrefix("#x") || name.hasPrefix("#X") {
            guard let v = UInt32(name.dropFirst(2), radix: 16), let u = Unicode.Scalar(v), v != 0 else { return nil }
            return String(Character(u))
        }
        if name.hasPrefix("#") {
            guard let v = UInt32(name.dropFirst()), let u = Unicode.Scalar(v), v != 0 else { return nil }
            return String(Character(u))
        }
        return namedEntities[name]
    }
}
