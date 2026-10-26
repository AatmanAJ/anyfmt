import Foundation

/// anyfmt's format-neutral document model. Every document reader produces one
/// and every writer consumes one, so N readers + M writers give N×M routes
/// without lossy intermediate files.
public struct DocModel: Sendable, Hashable {
    public var metadata: DocMetadata
    public var blocks: [DocBlock]

    public init(metadata: DocMetadata = DocMetadata(), blocks: [DocBlock] = []) {
        self.metadata = metadata
        self.blocks = blocks
    }
}

public struct DocMetadata: Sendable, Hashable {
    public var title: String?
    public var author: String?
    /// BCP 47 tag, e.g. "en" or "de-CH".
    public var language: String?

    public init(title: String? = nil, author: String? = nil, language: String? = nil) {
        self.title = title
        self.author = author
        self.language = language
    }
}

public indirect enum DocBlock: Sendable, Hashable {
    case heading(level: Int, [DocInline])
    case paragraph([DocInline])
    case list(DocList)
    case table(DocTable)
    /// A block-level picture (figure).
    case image(DocImage)
    case codeBlock(language: String?, String)
    case blockquote([DocBlock])
    case horizontalRule
    case pageBreak
}

public struct DocList: Sendable, Hashable {
    public var ordered: Bool
    /// First number for ordered lists.
    public var start: Int
    public var items: [DocListItem]
    public init(ordered: Bool, start: Int = 1, items: [DocListItem]) {
        self.ordered = ordered
        self.start = start
        self.items = items
    }
}

public struct DocListItem: Sendable, Hashable {
    public var blocks: [DocBlock]
    /// GFM task list state, nil for ordinary items.
    public var checked: Bool?
    public init(_ blocks: [DocBlock], checked: Bool? = nil) {
        self.blocks = blocks
        self.checked = checked
    }
}

public struct DocTable: Sendable, Hashable {
    public enum Alignment: String, Sendable, Hashable { case none, left, center, right }
    public var rows: [DocTableRow]
    public var alignments: [Alignment]
    public var caption: [DocInline]

    public init(rows: [DocTableRow], alignments: [Alignment] = [], caption: [DocInline] = []) {
        self.rows = rows
        self.alignments = alignments
        self.caption = caption
    }

    public var columnCount: Int { rows.map(\.cells.count).max() ?? 0 }

    /// Header rows first, padded so every row has `columnCount` cells.
    public var normalized: DocTable {
        let n = columnCount
        var t = self
        t.rows = rows.map { r in
            var r = r
            while r.cells.count < n { r.cells.append(DocTableCell([])) }
            return r
        }
        while t.alignments.count < n { t.alignments.append(.none) }
        return t
    }
}

public struct DocTableRow: Sendable, Hashable {
    public var cells: [DocTableCell]
    public var isHeader: Bool
    public init(_ cells: [DocTableCell], isHeader: Bool = false) {
        self.cells = cells
        self.isHeader = isHeader
    }
}

public struct DocTableCell: Sendable, Hashable {
    public var blocks: [DocBlock]
    public init(_ blocks: [DocBlock]) { self.blocks = blocks }
    public init(inlines: [DocInline]) { self.blocks = inlines.isEmpty ? [] : [.paragraph(inlines)] }
}

public struct DocImage: Sendable, Hashable {
    /// Image bytes. Nil when the source referenced a remote image we must not fetch.
    public var data: Data?
    /// MIME type of `data`, e.g. "image/png".
    public var mime: String
    public var alt: String
    /// Display size in points, when the source specified one.
    public var width: Double?
    public var height: Double?
    /// Original reference (remote URL or file name), informational.
    public var source: String?

    public init(data: Data?, mime: String, alt: String = "", width: Double? = nil, height: Double? = nil, source: String? = nil) {
        self.data = data
        self.mime = mime
        self.alt = alt
        self.width = width
        self.height = height
        self.source = source
    }
}

public indirect enum DocInline: Sendable, Hashable {
    case text(String)
    case emphasis([DocInline])
    case strong([DocInline])
    case underline([DocInline])
    case strikethrough([DocInline])
    case code(String)
    case link(url: String, [DocInline])
    case image(DocImage)
    case lineBreak
}

// MARK: - Helpers shared by readers and writers

public extension DocInline {
    /// Visible text (images contribute their alt text).
    var plainText: String {
        switch self {
        case .text(let s), .code(let s): s
        case .emphasis(let c), .strong(let c), .underline(let c), .strikethrough(let c), .link(_, let c): c.plainText
        case .image(let i): i.alt
        case .lineBreak: "\n"
        }
    }
}

public extension Array where Element == DocInline {
    var plainText: String { map(\.plainText).joined() }

    /// Merges adjacent text runs and identical wrappers, drops empty text.
    var compacted: [DocInline] {
        var out: [DocInline] = []
        for i in self {
            switch i {
            case .text(let s):
                if s.isEmpty { continue }
                if case .text(let prev)? = out.last { out[out.count - 1] = .text(prev + s) } else { out.append(i) }
            case .strong(let c):
                let c = c.compacted
                if c.isEmpty { continue }
                if case .strong(let p)? = out.last { out[out.count - 1] = .strong((p + c).compacted) } else { out.append(.strong(c)) }
            case .emphasis(let c):
                let c = c.compacted
                if c.isEmpty { continue }
                if case .emphasis(let p)? = out.last { out[out.count - 1] = .emphasis((p + c).compacted) } else { out.append(.emphasis(c)) }
            case .underline(let c):
                let c = c.compacted
                if !c.isEmpty { out.append(.underline(c)) }
            case .strikethrough(let c):
                let c = c.compacted
                if !c.isEmpty { out.append(.strikethrough(c)) }
            case .link(let u, let c):
                let c = c.compacted
                if case .link(let pu, let p)? = out.last, pu == u { out[out.count - 1] = .link(url: u, (p + c).compacted) } else { out.append(.link(url: u, c)) }
            default:
                out.append(i)
            }
        }
        return out
    }

    /// Trims leading/trailing whitespace of the outermost text runs.
    var trimmed: [DocInline] {
        var a = self.compacted
        while let f = a.first, case .text(let s) = f {
            let t = String(s.drop { $0 == " " || $0 == "\t" || $0 == "\n" })
            if t.isEmpty { a.removeFirst() } else { a[0] = .text(t); break }
        }
        while let l = a.last, case .text(let s) = l {
            var t = s
            while let c = t.last, c == " " || c == "\t" || c == "\n" { t.removeLast() }
            if t.isEmpty { a.removeLast() } else { a[a.count - 1] = .text(t); break }
        }
        while case .lineBreak? = a.last { a.removeLast() }
        return a
    }

    var isBlank: Bool {
        allSatisfy { i in
            switch i {
            case .text(let s): s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .lineBreak: true
            default: false
            }
        }
    }
}

public extension DocBlock {
    var plainText: String {
        switch self {
        case .heading(_, let i), .paragraph(let i): i.plainText
        case .list(let l): l.items.map { $0.blocks.map(\.plainText).joined(separator: "\n") }.joined(separator: "\n")
        case .table(let t): t.rows.map { $0.cells.map { $0.blocks.map(\.plainText).joined(separator: " ") }.joined(separator: "\t") }.joined(separator: "\n")
        case .image(let i): i.alt
        case .codeBlock(_, let s): s
        case .blockquote(let b): b.map(\.plainText).joined(separator: "\n")
        case .horizontalRule, .pageBreak: ""
        }
    }
}

public extension DocModel {
    /// Title from metadata, else the first heading's text.
    var displayTitle: String? {
        if let t = metadata.title, !t.trimmingCharacters(in: .whitespaces).isEmpty { return t }
        for b in blocks { if case .heading(_, let i) = b { return i.plainText.trimmingCharacters(in: .whitespacesAndNewlines) } }
        return nil
    }

    /// Every image in document order (blocks, inlines, nested containers).
    var allImages: [DocImage] {
        var out: [DocImage] = []
        func inl(_ a: [DocInline]) {
            for i in a {
                switch i {
                case .image(let im): out.append(im)
                case .emphasis(let c), .strong(let c), .underline(let c), .strikethrough(let c), .link(_, let c): inl(c)
                default: break
                }
            }
        }
        func blk(_ a: [DocBlock]) {
            for b in a {
                switch b {
                case .heading(_, let i), .paragraph(let i): inl(i)
                case .list(let l): l.items.forEach { blk($0.blocks) }
                case .table(let t): t.rows.forEach { $0.cells.forEach { blk($0.blocks) } }
                case .image(let im): out.append(im)
                case .blockquote(let c): blk(c)
                default: break
                }
            }
        }
        blk(blocks)
        return out
    }
}
