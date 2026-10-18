import AppKit
import Foundation

/// `DocModel` → NSAttributedString, then RTF or RTFD via AppKit (which writes
/// lists as real RTF list tables and tables as `\trowd` rows).
public struct AttributedWriter {
    public init() {}

    static let baseSize: CGFloat = 12
    static let headingSizes: [CGFloat] = [24, 18, 15, 13, 12, 12]

    public func attributedString(_ doc: DocModel, embedImages: Bool) -> NSAttributedString {
        let b = AttributedBuilder(embedImages: embedImages)
        b.blocks(doc.blocks, ctx: .init())
        b.trimTrailingNewline()
        return b.out
    }

    public func writeRTF(_ doc: DocModel, to url: URL) throws {
        let s = attributedString(doc, embedImages: false)
        let data = try s.data(from: NSRange(location: 0, length: s.length), documentAttributes: Self.attributes(doc, type: .rtf))
        try data.write(to: url, options: .atomic)
    }

    public func writeRTFD(_ doc: DocModel, to url: URL) throws {
        let s = attributedString(doc, embedImages: true)
        let wrapper = try s.fileWrapper(from: NSRange(location: 0, length: s.length), documentAttributes: Self.attributes(doc, type: .rtfd))
        try wrapper.write(to: url, options: .atomic, originalContentsURL: nil)
    }

    static func attributes(_ doc: DocModel, type: NSAttributedString.DocumentType) -> [NSAttributedString.DocumentAttributeKey: Any] {
        var a: [NSAttributedString.DocumentAttributeKey: Any] = [.documentType: type]
        if let t = doc.metadata.title { a[.title] = t }
        if let au = doc.metadata.author { a[.author] = au }
        return a
    }

    /// Writes an attributed string read from RTF/RTFD/DOC straight back out (no model): keeps fonts and colours.
    public static func write(_ s: NSAttributedString, attributes: [NSAttributedString.DocumentAttributeKey: Any], as format: FormatID, to url: URL) throws {
        var a: [NSAttributedString.DocumentAttributeKey: Any] = [:]
        for k in [NSAttributedString.DocumentAttributeKey.title, .author, .subject, .company, .copyright, .keywords, .comment] {
            if let v = attributes[k] { a[k] = v }
        }
        let range = NSRange(location: 0, length: s.length)
        switch format {
        case Formats.rtfd:
            a[.documentType] = NSAttributedString.DocumentType.rtfd
            try s.fileWrapper(from: range, documentAttributes: a).write(to: url, options: .atomic, originalContentsURL: nil)
        case Formats.rtf:
            a[.documentType] = NSAttributedString.DocumentType.rtf
            try s.data(from: range, documentAttributes: a).write(to: url, options: .atomic)
        default:
            throw ConversionError.unsupported(from: Formats.rtf, to: format)
        }
    }
}

final class AttributedBuilder {
    struct Ctx {
        var bold = false, italic = false, underline = false, strike = false, code = false
        var link: URL?
        var size: CGFloat = AttributedWriter.baseSize
        var lists: [NSTextList] = []
        var quote = false
        var cellBlock: NSTextTableBlock?
    }

    let out = NSMutableAttributedString()
    let embedImages: Bool
    private var imageCount = 0

    init(embedImages: Bool) { self.embedImages = embedImages }

    func font(_ c: Ctx) -> NSFont {
        if c.code { return NSFont.userFixedPitchFont(ofSize: c.size - 1) ?? NSFont.monospacedSystemFont(ofSize: c.size - 1, weight: .regular) }
        // Font descriptors (thread-safe), not NSFontManager: engines run off the main thread.
        let base = NSFont(name: "Helvetica", size: c.size) ?? NSFont.systemFont(ofSize: c.size)
        var traits: NSFontDescriptor.SymbolicTraits = []
        if c.bold { traits.insert(.bold) }
        if c.italic { traits.insert(.italic) }
        guard !traits.isEmpty else { return base }
        return NSFont(descriptor: base.fontDescriptor.withSymbolicTraits(traits), size: c.size) ?? base
    }

    func paragraphStyle(_ c: Ctx, spacingAfter: CGFloat = 6, headerLevel: Int = 0) -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.paragraphSpacing = spacingAfter
        if !c.lists.isEmpty {
            let level = CGFloat(c.lists.count - 1)
            p.textLists = c.lists
            p.headIndent = 36 * (level + 1)
            p.firstLineHeadIndent = 0
            p.tabStops = [NSTextTab(textAlignment: .left, location: 36 * level + 10), NSTextTab(textAlignment: .left, location: 36 * (level + 1))]
            p.paragraphSpacing = 2
        } else if c.quote {
            p.headIndent = 36
            p.firstLineHeadIndent = 36
            p.tailIndent = -36
        }
        if let cell = c.cellBlock { p.textBlocks = [cell] }
        if headerLevel > 0 { p.headerLevel = headerLevel }
        return p
    }

    func append(_ text: String, _ c: Ctx, para: NSParagraphStyle) {
        var attrs: [NSAttributedString.Key: Any] = [.font: font(c), .paragraphStyle: para]
        if c.underline { attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue }
        if c.strike { attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        if let link = c.link {
            attrs[.link] = link
        } else if c.quote {
            attrs[.foregroundColor] = NSColor(calibratedWhite: 0.3, alpha: 1)
        }
        out.append(NSAttributedString(string: text, attributes: attrs))
    }

    func newline(_ para: NSParagraphStyle, _ c: Ctx) { append("\n", c, para: para) }

    func trimTrailingNewline() {
        while out.length > 0, out.string.hasSuffix("\n") { out.deleteCharacters(in: NSRange(location: out.length - 1, length: 1)) }
    }

    // MARK: Blocks

    func blocks(_ bs: [DocBlock], ctx: Ctx) {
        for b in bs { block(b, ctx: ctx) }
    }

    func block(_ b: DocBlock, ctx: Ctx) {
        switch b {
        case .heading(let level, let inl):
            var c = ctx
            c.bold = true
            c.size = AttributedWriter.headingSizes[min(max(level, 1), 6) - 1]
            let p = paragraphStyle(c, spacingAfter: 8, headerLevel: ctx.lists.isEmpty && ctx.cellBlock == nil ? level : 0)
            inlines(inl, ctx: c, para: p)
            newline(p, c)
        case .paragraph(let inl):
            let p = paragraphStyle(ctx)
            inlines(inl, ctx: ctx, para: p)
            newline(p, ctx)
        case .list(let l):
            list(l, ctx: ctx)
        case .table(let t):
            table(t, ctx: ctx)
        case .image(let im):
            let p = paragraphStyle(ctx)
            image(im, ctx: ctx, para: p)
            newline(p, ctx)
        case .codeBlock(_, let code):
            var c = ctx
            c.code = true
            let p = paragraphStyle(c, spacingAfter: 0)
            for line in code.split(separator: "\n", omittingEmptySubsequences: false) {
                append(String(line), c, para: p)
                newline(p, c)
            }
            let gap = paragraphStyle(ctx, spacingAfter: 4)
            newline(gap, ctx)
        case .blockquote(let inner):
            var c = ctx
            c.quote = true
            blocks(inner, ctx: c)
        case .horizontalRule:
            let p = NSMutableParagraphStyle()
            p.alignment = .center
            p.paragraphSpacing = 6
            append("* * *", ctx, para: p)
            newline(p, ctx)
        case .pageBreak:
            if ctx.cellBlock == nil, ctx.lists.isEmpty {
                let p = paragraphStyle(ctx)
                append("\u{0C}", ctx, para: p)
            }
        }
    }

    func list(_ l: DocList, ctx: Ctx) {
        let format: NSTextList.MarkerFormat
        switch (l.ordered, ctx.lists.filter { !$0.markerFormat.rawValue.contains("decimal") }.count % 3) {
        case (true, _): format = ctx.lists.count % 2 == 0 ? .decimal : .lowercaseAlpha
        case (false, 0): format = .disc
        case (false, 1): format = .circle
        default: format = .square
        }
        let list = NSTextList(markerFormat: format, options: 0)
        if l.ordered { list.startingItemNumber = l.start }
        var c = ctx
        c.lists = ctx.lists + [list]
        var n = l.start
        for item in l.items {
            let p = paragraphStyle(c)
            let marker = "\t" + list.marker(forItemNumber: n) + "\t"
            n += 1
            append(marker, c, para: p)
            var rest = item.blocks
            var prefix: [DocInline] = []
            if let checked = item.checked { prefix = [.text(checked ? "☑ " : "☐ ")] }
            if let first = rest.first, case .paragraph(let inl) = first {
                inlines(prefix + inl, ctx: c, para: p)
                rest.removeFirst()
            } else if let first = rest.first, case .heading(_, let inl) = first {
                inlines(prefix + inl, ctx: c, para: p)
                rest.removeFirst()
            } else if !prefix.isEmpty {
                inlines(prefix, ctx: c, para: p)
            }
            newline(p, c)
            for b in rest {
                if case .list = b { block(b, ctx: c); continue }
                // Continuation paragraphs: indented, no marker (drop the list from the style).
                var cc = ctx
                cc.lists = []
                let cp = NSMutableParagraphStyle()
                cp.headIndent = 36 * CGFloat(c.lists.count)
                cp.firstLineHeadIndent = cp.headIndent
                cp.paragraphSpacing = 2
                if case .paragraph(let inl) = b {
                    inlines(inl, ctx: cc, para: cp)
                    newline(cp, cc)
                } else {
                    block(b, ctx: cc)
                }
            }
        }
    }

    func table(_ table: DocTable, ctx: Ctx) {
        let t = table.normalized
        let n = t.columnCount
        guard n > 0 else { return }
        let tt = NSTextTable()
        tt.numberOfColumns = n
        tt.layoutAlgorithm = .automaticLayoutAlgorithm
        tt.collapsesBorders = true
        tt.hidesEmptyCells = false
        for (ri, r) in t.rows.enumerated() {
            for (ci, cell) in r.cells.enumerated() {
                let cellBlock = NSTextTableBlock(table: tt, startingRow: ri, rowSpan: 1, startingColumn: ci, columnSpan: 1)
                cellBlock.setWidth(0.5, type: .absoluteValueType, for: .border)
                cellBlock.setBorderColor(NSColor(calibratedWhite: 0.6, alpha: 1))
                cellBlock.setWidth(4, type: .absoluteValueType, for: .padding)
                if r.isHeader { cellBlock.backgroundColor = NSColor(calibratedWhite: 0.94, alpha: 1) }
                var c = ctx
                c.cellBlock = cellBlock
                c.lists = []
                c.bold = ctx.bold || r.isHeader
                let content = cell.blocks.isEmpty ? [DocBlock.paragraph([])] : cell.blocks
                for b in content {
                    switch b {
                    case .paragraph, .heading, .codeBlock, .image: block(b, ctx: c)
                    default:
                        // Nested structures inside cells are flattened to text (RTF can't nest them reliably).
                        let p = paragraphStyle(c)
                        append(b.plainText, c, para: p)
                        newline(p, c)
                    }
                }
            }
        }
        let after = paragraphStyle(ctx, spacingAfter: 4)
        newline(after, ctx)
    }

    // MARK: Inlines

    func inlines(_ a: [DocInline], ctx: Ctx, para: NSParagraphStyle) {
        for i in a { inline(i, ctx: ctx, para: para) }
    }

    func inline(_ i: DocInline, ctx: Ctx, para: NSParagraphStyle) {
        var c = ctx
        switch i {
        case .text(let t): append(t, ctx, para: para)
        case .emphasis(let k): c.italic = true; inlines(k, ctx: c, para: para)
        case .strong(let k): c.bold = true; inlines(k, ctx: c, para: para)
        case .underline(let k): c.underline = true; inlines(k, ctx: c, para: para)
        case .strikethrough(let k): c.strike = true; inlines(k, ctx: c, para: para)
        case .code(let t): c.code = true; append(t, c, para: para)
        case .lineBreak: append("\u{2028}", ctx, para: para)
        case .link(let url, let k):
            if let u = URL(string: url) ?? URL(string: url.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "") { c.link = u }
            inlines(k, ctx: c, para: para)
        case .image(let im): image(im, ctx: ctx, para: para)
        }
    }

    func image(_ im: DocImage, ctx: Ctx, para: NSParagraphStyle) {
        guard embedImages, let p = ImageSupport.portable(im) else {
            if !im.alt.isEmpty { append("[\(im.alt)]", ctx, para: para) }
            return
        }
        imageCount += 1
        let wrapper = FileWrapper(regularFileWithContents: p.data)
        wrapper.preferredFilename = "image\(imageCount).\(ImageSupport.fileExtension(forMIME: p.mime))"
        let att = NSTextAttachment(fileWrapper: wrapper)
        if let size = ImageSupport.displaySize(DocImage(data: p.data, mime: p.mime, width: im.width, height: im.height)) {
            let fitted = ImageSupport.fit(size, maxWidth: 468, maxHeight: 640)
            att.bounds = CGRect(x: 0, y: 0, width: fitted.width, height: fitted.height)
        }
        let s = NSMutableAttributedString(attachment: att)
        s.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: s.length))
        out.append(s)
    }
}
