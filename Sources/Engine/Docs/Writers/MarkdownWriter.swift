import Foundation

/// `DocModel` → GitHub-flavoured Markdown: ATX headings, nested lists, GFM
/// tables and strikethrough, fenced code, minimal but sufficient escaping.
public struct MarkdownWriter {
    public enum Images { case embed, omit }
    public var images: Images = .embed

    public init(images: Images = .embed) { self.images = images }

    public func write(_ doc: DocModel) -> String {
        var parts: [String] = []
        if doc.metadata.title != nil || doc.metadata.author != nil {
            var fm = ["---"]
            if let t = doc.metadata.title { fm.append("title: \(Self.yaml(t))") }
            if let a = doc.metadata.author { fm.append("author: \(Self.yaml(a))") }
            if let l = doc.metadata.language { fm.append("lang: \(Self.yaml(l))") }
            fm.append("---")
            parts.append(fm.joined(separator: "\n"))
        }
        parts.append(blocks(doc.blocks))
        var out = parts.filter { !$0.isEmpty }.joined(separator: "\n\n")
        if !out.hasSuffix("\n") { out += "\n" }
        return out
    }

    static func yaml(_ s: String) -> String {
        let needsQuotes = s.contains(":") || s.contains("#") || s.hasPrefix(" ") || s.hasPrefix("\"") || s.hasPrefix("'")
        return needsQuotes ? "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\"" : s
    }

    func blocks(_ bs: [DocBlock]) -> String {
        var out: [String] = []
        var prevWasList = false
        for b in bs {
            let s = block(b)
            if s.isEmpty { continue }
            // Two adjacent lists would merge; separate them with an HTML comment like pandoc does.
            if case .list = b, prevWasList { out.append("<!-- -->") }
            out.append(s)
            if case .list = b { prevWasList = true } else { prevWasList = false }
        }
        return out.joined(separator: "\n\n")
    }

    func block(_ b: DocBlock) -> String {
        switch b {
        case .heading(let level, let inl):
            let text = inlines(inl).replacingOccurrences(of: "\n", with: " ")
            return String(repeating: "#", count: min(max(level, 1), 6)) + " " + text
        case .paragraph(let inl):
            return Self.escapeLineStarts(inlines(inl))
        case .list(let l):
            return list(l)
        case .table(let t):
            return table(t)
        case .image(let im):
            return image(im)
        case .codeBlock(let lang, let code):
            let longest = Self.longestRun(of: "`", in: code)
            let fence = String(repeating: "`", count: max(3, longest + 1))
            return "\(fence)\(lang ?? "")\n\(code)\n\(fence)"
        case .blockquote(let inner):
            let text = blocks(inner)
            return text.split(separator: "\n", omittingEmptySubsequences: false).map { $0.isEmpty ? ">" : "> " + $0 }.joined(separator: "\n")
        case .horizontalRule:
            return "---"
        case .pageBreak:
            return ""
        }
    }

    func list(_ l: DocList) -> String {
        var lines: [String] = []
        var n = l.start
        let tight = l.items.allSatisfy { item in
            if item.blocks.count <= 1 { return true }
            if item.blocks.count == 2, case .paragraph = item.blocks[0], case .list = item.blocks[1] { return true }
            return false
        }
        for item in l.items {
            let marker = l.ordered ? "\(n)." : "-"
            n += 1
            let indent = String(repeating: " ", count: marker.count + 1)
            var body = blocks(item.blocks)
            if tight {
                // Nested lists directly under a one-paragraph item stay tight.
                body = item.blocks.map(block).filter { !$0.isEmpty }.joined(separator: "\n")
            }
            if let checked = item.checked { body = (checked ? "[x] " : "[ ] ") + body }
            let itemLines = body.split(separator: "\n", omittingEmptySubsequences: false)
            for (k, line) in itemLines.enumerated() {
                if k == 0 { lines.append(marker + " " + line) } else { lines.append(line.isEmpty ? "" : indent + line) }
            }
            if itemLines.isEmpty { lines.append(marker) }
            if !tight { lines.append("") }
        }
        while lines.last == "" { lines.removeLast() }
        return lines.joined(separator: "\n")
    }

    func table(_ table: DocTable) -> String {
        let t = table.normalized
        guard t.columnCount > 0, !t.rows.isEmpty else { return "" }
        let rendered = t.rows.map { r in r.cells.map(cell) }
        // GFM needs a header row; use the first row.
        let n = t.columnCount
        var widths = [Int](repeating: 3, count: n)
        for r in rendered { for (k, c) in r.enumerated() { widths[k] = max(widths[k], min(c.count, 40)) } }
        func line(_ cells: [String]) -> String {
            "| " + cells.enumerated().map { k, c in c.padding(toLength: max(c.count, widths[k]), withPad: " ", startingAt: 0) }.joined(separator: " | ") + " |"
        }
        var out: [String] = []
        if !t.caption.isEmpty { out.append("*" + inlines(t.caption) + "*"); out.append("") }
        out.append(line(rendered[0]))
        let sep = (0..<n).map { k -> String in
            let w = widths[k]
            switch t.alignments[k] {
            case .left: return ":" + String(repeating: "-", count: w - 1)
            case .right: return String(repeating: "-", count: w - 1) + ":"
            case .center: return ":" + String(repeating: "-", count: max(1, w - 2)) + ":"
            case .none: return String(repeating: "-", count: w)
            }
        }
        out.append("| " + sep.joined(separator: " | ") + " |")
        for r in rendered.dropFirst() { out.append(line(r)) }
        return out.joined(separator: "\n")
    }

    func cell(_ c: DocTableCell) -> String {
        let parts: [String] = c.blocks.map { b in
            switch b {
            case .paragraph(let inl), .heading(_, let inl): return inlines(inl)
            case .image(let im): return image(im)
            case .list(let l): return l.items.map { "• " + $0.blocks.map(\.plainText).joined(separator: " ") }.joined(separator: "<br>")
            default: return Self.escapeText(b.plainText)
            }
        }
        // Text is already escaped (including "|"); hard breaks become <br>.
        return parts.joined(separator: "<br>")
            .replacingOccurrences(of: "\\\n", with: "<br>")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    func image(_ im: DocImage) -> String {
        let alt = Self.escapeText(im.alt)
        switch images {
        case .omit:
            return im.alt.isEmpty ? "" : "*[\(alt)]*"
        case .embed:
            if let data = im.data {
                return "![\(alt)](\(ImageSupport.dataURI(data, mime: im.mime.isEmpty ? "image/png" : im.mime)))"
            }
            if let s = im.source { return "![\(alt)](\(Self.destination(s)))" }
            return im.alt.isEmpty ? "" : "*[\(alt)]*"
        }
    }

    func inlines(_ a: [DocInline]) -> String {
        var s = ""
        for i in a { s += inline(i) }
        return s
    }

    func inline(_ i: DocInline) -> String {
        switch i {
        case .text(let t): return Self.escapeText(t)
        case .emphasis(let c): return wrap(c, "*")
        case .strong(let c): return wrap(c, "**")
        case .underline(let c): return "<u>" + inlines(c) + "</u>"
        case .strikethrough(let c): return wrap(c, "~~")
        case .code(let t):
            let run = Self.longestRun(of: "`", in: t)
            let fence = String(repeating: "`", count: run + 1)
            let pad = t.hasPrefix("`") || t.hasSuffix("`") || (t.hasPrefix(" ") && t.hasSuffix(" ") && !t.allSatisfy { $0 == " " }) ? " " : ""
            return fence + pad + t + pad + fence
        case .link(let url, let c):
            let text = inlines(c)
            if c.plainText == url, url.lowercased().hasPrefix("http") { return "<\(url)>" }
            return "[\(text)](\(Self.destination(url)))"
        case .image(let im): return image(im)
        case .lineBreak: return "\\\n"
        }
    }

    /// Emphasis markers must hug non-space text: move surrounding spaces outside.
    func wrap(_ c: [DocInline], _ marker: String) -> String {
        let inner = inlines(c)
        let trimmed = inner.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return inner }
        let lead = inner.prefix { $0 == " " }
        let trail = String(inner.reversed().prefix { $0 == " " })
        return lead + marker + trimmed + marker + trail
    }

    static func destination(_ url: String) -> String {
        if url.contains(" ") || url.contains("(") || url.contains(")") || url.contains("<") {
            return "<" + url.replacingOccurrences(of: ">", with: "%3E").replacingOccurrences(of: "<", with: "%3C") + ">"
        }
        return url
    }

    static func escapeText(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for c in s {
            switch c {
            case "\\", "`", "*", "_", "[", "]", "<", ">", "~", "|": out.append("\\"); out.append(c)
            case "\u{00A0}": out += "&nbsp;"
            default: out.append(c)
            }
        }
        return out
    }

    /// Escapes characters that would turn a paragraph line into another block.
    static func escapeLineStarts(_ s: String) -> String {
        s.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
            var l = String(line)
            if l.hasPrefix("#") || l.hasPrefix("+ ") || l.hasPrefix("- ") || l.hasPrefix("=") { l = "\\" + l }
            if let r = l.range(of: #"^\d+[.)] "#, options: .regularExpression) {
                let digits = l[r].dropLast(2)
                l = digits + "\\" + l[l.index(r.upperBound, offsetBy: -2)...]
            }
            return l
        }.joined(separator: "\n")
    }

    static func longestRun(of ch: Character, in s: String) -> Int {
        var best = 0, cur = 0
        for c in s { if c == ch { cur += 1; best = max(best, cur) } else { cur = 0 } }
        return best
    }
}

/// `DocModel` → plain text: no wrapping, bullets for lists, tabs between table cells.
public struct PlainTextWriter {
    public init() {}

    public func write(_ doc: DocModel) -> String {
        var out = blocks(doc.blocks, indent: "")
        if !out.hasSuffix("\n") { out += "\n" }
        return out
    }

    func blocks(_ bs: [DocBlock], indent: String) -> String {
        bs.map { block($0, indent: indent) }.filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    func block(_ b: DocBlock, indent: String) -> String {
        switch b {
        case .heading(_, let inl), .paragraph(let inl):
            return prefixLines(text(inl), indent)
        case .list(let l):
            var n = l.start
            var lines: [String] = []
            for item in l.items {
                let marker = l.ordered ? "\(n). " : "• "
                n += 1
                let box = item.checked.map { $0 ? "[x] " : "[ ] " } ?? ""
                let body = item.blocks.map { block($0, indent: "") }.filter { !$0.isEmpty }.joined(separator: "\n")
                let pad = String(repeating: " ", count: marker.count)
                for (k, line) in body.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    lines.append(indent + (k == 0 ? marker + box : pad) + line)
                }
            }
            return lines.joined(separator: "\n")
        case .table(let t):
            return t.normalized.rows.map { r in
                indent + r.cells.map { c in c.blocks.map(\.plainText).joined(separator: " ").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\t", with: " ") }.joined(separator: "\t")
            }.joined(separator: "\n")
        case .image(let im):
            return im.alt.isEmpty ? "" : indent + "[\(im.alt)]"
        case .codeBlock(_, let code):
            return prefixLines(code, indent + "    ")
        case .blockquote(let inner):
            return blocks(inner, indent: indent + "    ")
        case .horizontalRule:
            return indent + "* * *"
        case .pageBreak:
            return "\u{0C}"
        }
    }

    func text(_ inl: [DocInline]) -> String {
        inl.map { i -> String in
            switch i {
            case .link(let url, let c):
                let t = c.plainText
                return t == url || url.hasPrefix("#") ? t : "\(t) <\(url)>"
            case .image(let im): return im.alt.isEmpty ? "" : "[\(im.alt)]"
            default: return i.plainText
            }
        }.joined()
    }

    func prefixLines(_ s: String, _ indent: String) -> String {
        guard !indent.isEmpty else { return s }
        return s.split(separator: "\n", omittingEmptySubsequences: false).map { indent + $0 }.joined(separator: "\n")
    }
}
