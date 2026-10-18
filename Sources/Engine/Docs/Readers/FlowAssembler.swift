import Foundation

/// One paragraph as word processors store it (flat), before we rebuild
/// structure: nested lists, code blocks, quotes, heuristic headings.
struct ParaItem {
    var inlines: [DocInline]
    var heading: Int?
    /// List membership: level 0…8, ordered flag, first number, and a key that
    /// identifies the list instance (numId / list style).
    var list: (level: Int, ordered: Bool, start: Int, key: String)?
    /// A list paragraph without its own number (2nd paragraph of an item).
    var continuation = false
    var code = false
    var quote = false
    var breakBefore = false
    /// Largest font size in the paragraph, points.
    var fontSize: Double?
    var allBold = false
    /// Left indent level (720 twips per level), for marker-text lists.
    var indentLevel = 0

    init(_ inlines: [DocInline]) { self.inlines = inlines }
}

enum FlowItem {
    case para(ParaItem)
    case block(DocBlock)
    case pageBreak
}

enum FlowAssembler {
    /// - Parameter headingHeuristic: infer headings from font size when no
    ///   paragraph uses a heading style (textutil/TextEdit/Pages exports).
    static func assemble(_ input: [FlowItem], headingHeuristic: Bool = true) -> [DocBlock] {
        var items = input
        if headingHeuristic { inferHeadings(&items) }
        detectMarkerLists(&items)
        return build(items)
    }

    // MARK: Heuristics

    static func inferHeadings(_ items: inout [FlowItem]) {
        let paras = items.compactMap { if case .para(let p) = $0 { return p }; return nil }
        guard !paras.contains(where: { $0.heading != nil }) else { return }
        var weight: [Double: Int] = [:]
        for p in paras { if let s = p.fontSize { weight[(s * 2).rounded() / 2, default: 0] += p.inlines.plainText.count } }
        guard let body = weight.max(by: { $0.value < $1.value })?.key, body > 0 else { return }
        func candidate(_ p: ParaItem) -> Double? {
            guard p.list == nil, !p.code, let s = p.fontSize, s >= body * 1.15 else { return nil }
            let text = p.inlines.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, text.count <= 160, !text.hasSuffix(".") || text.count < 40 else { return nil }
            return (s * 2).rounded() / 2
        }
        let sizes = Set(paras.compactMap(candidate)).sorted(by: >)
        guard !sizes.isEmpty else { return }
        for k in items.indices {
            guard case .para(var p) = items[k], let s = candidate(p), let rank = sizes.firstIndex(of: s) else { continue }
            p.heading = min(6, rank + 1)
            p.inlines = unwrapBold(p.inlines)
            items[k] = .para(p)
        }
    }

    /// Bullets typed as text ("\t•\tItem", "1.\tItem"), which is how textutil and
    /// many converters write lists.
    static func detectMarkerLists(_ items: inout [FlowItem]) {
        let pattern = #"^\t?([•◦▪‣⁃·○■□–\-\*]|\(?\d{1,3}[.)]|[a-zA-Z][.)]|[ivxIVX]{1,4}[.)])\t"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return }
        for k in items.indices {
            guard case .para(var p) = items[k], p.list == nil, p.heading == nil, !p.code else { continue }
            let text = p.inlines.plainText
            guard let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let whole = Range(m.range, in: text), let mr = Range(m.range(at: 1), in: text) else { continue }
            let marker = String(text[mr])
            let ordered = marker.first.map { $0.isNumber || $0.isLetter || $0 == "(" } ?? false
            var start = 1
            if ordered, let n = Int(marker.filter(\.isNumber)) { start = n }
            p.inlines = dropPrefix(p.inlines, count: text.distance(from: text.startIndex, to: whole.upperBound))
            p.list = (min(p.indentLevel, 8), ordered, start, ordered ? "marker-ol" : "marker-ul")
            items[k] = .para(p)
        }
    }

    static func unwrapBold(_ a: [DocInline]) -> [DocInline] {
        a.flatMap { i -> [DocInline] in
            if case .strong(let c) = i { return c }
            return [i]
        }.compacted
    }

    /// Removes the first `count` visible characters from an inline list.
    static func dropPrefix(_ a: [DocInline], count: Int) -> [DocInline] {
        var remaining = count
        var out: [DocInline] = []
        func drop(_ i: DocInline) -> DocInline? {
            guard remaining > 0 else { return i }
            switch i {
            case .text(let s):
                if s.count <= remaining { remaining -= s.count; return nil }
                let r = String(s.dropFirst(remaining)); remaining = 0; return .text(r)
            case .lineBreak:
                remaining -= 1; return nil
            case .strong(let c): let r = c.compactMap(drop); return r.isEmpty ? nil : .strong(r)
            case .emphasis(let c): let r = c.compactMap(drop); return r.isEmpty ? nil : .emphasis(r)
            case .underline(let c): let r = c.compactMap(drop); return r.isEmpty ? nil : .underline(r)
            case .strikethrough(let c): let r = c.compactMap(drop); return r.isEmpty ? nil : .strikethrough(r)
            case .link(let u, let c): let r = c.compactMap(drop); return r.isEmpty ? nil : .link(url: u, r)
            case .code(let s):
                if s.count <= remaining { remaining -= s.count; return nil }
                let r = String(s.dropFirst(remaining)); remaining = 0; return .code(r)
            case .image(let im):
                let n = im.alt.count
                if n <= remaining { remaining -= n; return nil }
                return i
            }
        }
        for i in a { if let r = drop(i) { out.append(r) } }
        return out.compacted
    }

    // MARK: Structure

    private struct OpenList { var level: Int; var list: DocList; var key: String }

    static func build(_ items: [FlowItem]) -> [DocBlock] {
        var out: [DocBlock] = []
        var stack: [OpenList] = []
        var code: [String] = []
        var quote: [DocBlock] = []

        func attach(_ b: DocBlock) {
            guard !stack.isEmpty else { out.append(b); return }
            if stack[stack.count - 1].list.items.isEmpty { stack[stack.count - 1].list.items.append(DocListItem([])) }
            let li = stack[stack.count - 1].list.items.count - 1
            stack[stack.count - 1].list.items[li].blocks.append(b)
        }
        func closeLists() {
            while let top = stack.popLast() {
                if stack.isEmpty { out.append(.list(top.list)) } else { attach(.list(top.list)) }
            }
        }
        func flushCode() {
            if !code.isEmpty { out.append(.codeBlock(language: nil, code.joined(separator: "\n"))); code.removeAll() }
        }
        func flushQuote() {
            if !quote.isEmpty { out.append(.blockquote(quote)); quote.removeAll() }
        }
        func paragraphBlock(_ p: ParaItem) -> DocBlock? {
            let inl = p.inlines.trimmed
            if let h = p.heading { return inl.isEmpty ? nil : .heading(level: h, inl) }
            if inl.isEmpty { return nil }
            if inl.count == 1, case .image(let im) = inl[0] { return .image(im) }
            return .paragraph(inl)
        }

        for item in items {
            switch item {
            case .pageBreak:
                flushCode(); flushQuote(); closeLists()
                if let last = out.last, case .pageBreak = last { continue }
                if !out.isEmpty { out.append(.pageBreak) }
            case .block(let b):
                flushCode(); flushQuote(); closeLists()
                out.append(b)
            case .para(let p):
                if p.breakBefore, !out.isEmpty {
                    flushCode(); flushQuote(); closeLists()
                    if case .pageBreak? = out.last {} else { out.append(.pageBreak) }
                }
                if p.code {
                    flushQuote(); closeLists()
                    code.append(p.inlines.plainText)
                    continue
                }
                flushCode()
                if let l = p.list {
                    flushQuote()
                    while let top = stack.last, top.level > l.level {
                        stack.removeLast()
                        if stack.isEmpty { out.append(.list(top.list)) } else { attach(.list(top.list)) }
                    }
                    if let top = stack.last, top.level == l.level, top.list.ordered != l.ordered {
                        stack.removeLast()
                        if stack.isEmpty { out.append(.list(top.list)) } else { attach(.list(top.list)) }
                    }
                    if stack.last?.level != l.level {
                        stack.append(OpenList(level: l.level, list: DocList(ordered: l.ordered, start: l.start, items: []), key: l.key))
                    }
                    let blocks = paragraphBlock(p).map { [$0] } ?? []
                    stack[stack.count - 1].list.items.append(DocListItem(blocks))
                    continue
                }
                if p.continuation, !stack.isEmpty {
                    if let b = paragraphBlock(p) { attach(b) }
                    continue
                }
                closeLists()
                if p.quote {
                    if let b = paragraphBlock(p) { quote.append(b) }
                    continue
                }
                flushQuote()
                if let b = paragraphBlock(p) { out.append(b) }
            }
        }
        flushCode(); flushQuote(); closeLists()
        while case .pageBreak? = out.last { out.removeLast() }
        return out
    }
}
