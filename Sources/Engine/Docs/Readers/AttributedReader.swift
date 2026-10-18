import AppKit
import Foundation

/// RTF / RTFD / DOC (Word 97) → `DocModel` through AppKit's text system, which
/// reads these formats well. Fonts give bold/italic/monospace, `NSTextList`
/// gives nested lists, `NSTextTable` gives tables and attachments give images.
/// (The HTML importer is never used: it is main-thread only and unreliable.)
public enum AttributedReader {
    public static func documentType(for format: FormatID) -> NSAttributedString.DocumentType? {
        switch format {
        case Formats.rtf: .rtf
        case Formats.rtfd: .rtfd
        case Formats.doc: .docFormat
        default: nil
        }
    }

    public static func load(_ url: URL, format: FormatID) throws -> (NSAttributedString, [NSAttributedString.DocumentAttributeKey: Any]) {
        guard let type = documentType(for: format) else { throw ConversionError.unsupported(from: format, to: Formats.txt) }
        var attrs: NSDictionary?
        do {
            let s = try NSAttributedString(url: url, options: [.documentType: type], documentAttributes: &attrs)
            var out: [NSAttributedString.DocumentAttributeKey: Any] = [:]
            if let d = attrs as? [NSAttributedString.DocumentAttributeKey: Any] { out = d }
            return (s, out)
        } catch {
            throw ConversionError.unreadable(url, detail: error.localizedDescription)
        }
    }

    public static func read(_ url: URL, format: FormatID) throws -> DocModel {
        let (s, attrs) = try load(url, format: format)
        return model(s, attributes: attrs)
    }

    public static func model(_ s: NSAttributedString, attributes: [NSAttributedString.DocumentAttributeKey: Any] = [:]) -> DocModel {
        var meta = DocMetadata()
        if let t = attributes[.title] as? String, !t.isEmpty { meta.title = t }
        if let a = attributes[.author] as? String, !a.isEmpty { meta.author = a }
        let items = flowItems(s)
        return DocModel(metadata: meta, blocks: FlowAssembler.assemble(items))
    }

    // MARK: Paragraph walk

    struct Para {
        let range: NSRange
        let style: NSParagraphStyle?
    }

    static func paragraphs(_ s: NSAttributedString) -> [Para] {
        let ns = s.string as NSString
        var out: [Para] = []
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            let style = range.location < s.length ? s.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle : nil
            out.append(Para(range: range, style: style))
        }
        return out
    }

    static func flowItems(_ s: NSAttributedString) -> [FlowItem] {
        let paras = paragraphs(s)
        var items: [FlowItem] = []
        var k = 0
        while k < paras.count {
            let p = paras[k]
            if let block = p.style?.textBlocks.first(where: { $0 is NSTextTableBlock }) as? NSTextTableBlock {
                // Collect every paragraph of this table.
                let table = block.table
                var cells: [Int: [Int: [FlowItem]]] = [:]
                var maxRow = 0, maxCol = 0
                while k < paras.count, let b = paras[k].style?.textBlocks.first(where: { ($0 as? NSTextTableBlock)?.table === table }) as? NSTextTableBlock {
                    let item = paragraphItem(s, paras[k])
                    cells[b.startingRow, default: [:]][b.startingColumn, default: []].append(.para(item))
                    maxRow = max(maxRow, b.startingRow)
                    maxCol = max(maxCol, b.startingColumn + b.columnSpan - 1)
                    k += 1
                }
                var rows: [DocTableRow] = []
                for r in 0...maxRow {
                    var rowCells: [DocTableCell] = []
                    for c in 0...maxCol {
                        let blocks = FlowAssembler.assemble(cells[r]?[c] ?? [], headingHeuristic: false)
                        rowCells.append(DocTableCell(blocks))
                    }
                    rows.append(DocTableRow(rowCells))
                }
                if rows.count > 1, DocxReadContext.isAllBold(rows[0]) { rows[0].isHeader = true }
                items.append(.block(.table(FlowAssembler.plainHeaderRows(DocTable(rows: rows)))))
                continue
            }
            let text = (s.string as NSString).substring(with: p.range)
            if text == "\u{0C}" { items.append(.pageBreak); k += 1; continue }
            items.append(.para(paragraphItem(s, p)))
            k += 1
        }
        return items
    }

    static func paragraphItem(_ s: NSAttributedString, _ p: Para) -> ParaItem {
        var item = ParaItem([])
        var inl: [DocInline] = []
        var maxSize: Double = 0
        var monoChars = 0, chars = 0, boldChars = 0
        s.enumerateAttributes(in: p.range, options: []) { attrs, range, _ in
            let raw = (s.string as NSString).substring(with: range)
            if let att = attrs[.attachment] as? NSTextAttachment {
                if let im = image(att) { inl.append(.image(im)) }
                return
            }
            let font = attrs[.font] as? NSFont
            let traits = font?.fontDescriptor.symbolicTraits ?? []
            let name = font?.fontName.lowercased() ?? ""
            let bold = traits.contains(.bold) || name.contains("bold") || name.contains("black") || name.contains("heavy")
            let italic = traits.contains(.italic) || name.contains("italic") || name.contains("oblique")
            let mono = traits.contains(.monoSpace) || ["courier", "menlo", "monaco", "consolas", "mono"].contains(where: name.contains)
            let underline = (attrs[.underlineStyle] as? Int ?? 0) != 0
            let strike = (attrs[.strikethroughStyle] as? Int ?? 0) != 0
            var link: String?
            if let u = attrs[.link] as? URL { link = u.absoluteString } else if let u = attrs[.link] as? String { link = u }
            let visible = raw.filter { !$0.isWhitespace }.count
            chars += visible
            if mono { monoChars += visible }
            if bold { boldChars += visible }
            if visible > 0, let size = font?.pointSize { maxSize = max(maxSize, Double(size)) }
            // Split on line separators / form feeds.
            var pieces: [DocInline] = []
            var buf = ""
            for ch in raw {
                if ch == "\u{2028}" || ch == "\n" || ch == "\r" {
                    if !buf.isEmpty { pieces.append(.text(buf)); buf = "" }
                    pieces.append(.lineBreak)
                } else if ch == "\u{FFFC}" || ch == "\u{0C}" {
                    continue
                } else { buf.append(ch) }
            }
            if !buf.isEmpty { pieces.append(.text(buf)) }
            var wrapped: [DocInline] = pieces.map { piece in
                guard case .text(let t) = piece else { return piece }
                if mono { return .code(t) }
                var n: DocInline = .text(t)
                if strike { n = .strikethrough([n]) }
                if underline && link == nil { n = .underline([n]) }
                if italic { n = .emphasis([n]) }
                if bold { n = .strong([n]) }
                return n
            }
            if let link { wrapped = [.link(url: link, wrapped)] }
            inl.append(contentsOf: wrapped)
        }
        item.inlines = inl.compacted
        item.fontSize = maxSize > 0 ? maxSize : nil
        item.allBold = chars > 0 && boldChars == chars
        if let style = p.style {
            if style.headerLevel > 0 { item.heading = min(style.headerLevel, 6) }
            let lists = style.textLists
            if let last = lists.last {
                let ordered = !Self.isBullet(last.markerFormat)
                item.list = (min(lists.count - 1, 8), ordered, last.startingItemNumber, "\(ObjectIdentifier(lists[0]).hashValue)")
                item.heading = nil
                // AppKit keeps the rendered marker ("\t•\t") in the text; drop it.
                let text = item.inlines.plainText
                if let r = text.range(of: #"^\t?[^\t\n]{0,16}\t"#, options: .regularExpression) {
                    item.inlines = FlowAssembler.dropPrefix(item.inlines, count: text.distance(from: text.startIndex, to: r.upperBound))
                }
            } else if style.headIndent >= 28, style.firstLineHeadIndent >= 28, style.tailIndent < 0 {
                item.quote = true
            }
            item.indentLevel = max(0, Int((style.headIndent / 36).rounded()) - 1)
        }
        item.code = chars > 0 && monoChars == chars && item.list == nil
        return item
    }

    static func isBullet(_ f: NSTextList.MarkerFormat) -> Bool {
        let bullets: [NSTextList.MarkerFormat] = [.disc, .circle, .square, .hyphen, .diamond, .box, .check]
        if bullets.contains(f) { return true }
        let raw = f.rawValue
        return !(raw.contains("decimal") || raw.contains("alpha") || raw.contains("roman") || raw.contains("octal") || raw.contains("hex"))
    }

    static func image(_ att: NSTextAttachment) -> DocImage? {
        var data: Data?
        var name: String?
        if let fw = att.fileWrapper, fw.isRegularFile {
            data = fw.regularFileContents
            name = fw.preferredFilename ?? fw.filename
        }
        if data == nil, let c = att.contents { data = c }
        if data == nil, let img = att.image, let tiff = img.tiffRepresentation {
            data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        }
        guard let data, let mime = ImageSupport.sniffMIME(data, fileExtension: name.map { ($0 as NSString).pathExtension }), mime.hasPrefix("image/") else { return nil }
        let b = att.bounds
        return DocImage(data: data, mime: mime, alt: name.map { ($0 as NSString).deletingPathExtension } ?? "",
                        width: b.width > 0 ? Double(b.width) : nil, height: b.height > 0 ? Double(b.height) : nil, source: name)
    }
}

/// Safari `.webarchive` (a property list of HTML + subresources) → `DocModel`
/// through our own HTML reader; images come from the archived subresources.
public enum WebArchiveReader {
    public static func read(_ url: URL) throws -> DocModel {
        let data = try Data(contentsOf: url)
        guard let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let main = plist["WebMainResource"] as? [String: Any],
              let html = main["WebResourceData"] as? Data else {
            throw ConversionError.unreadable(url, detail: "not a web archive")
        }
        var resources: [String: (Data, String)] = [:]
        for r in plist["WebSubresources"] as? [[String: Any]] ?? [] {
            guard let u = r["WebResourceURL"] as? String, let d = r["WebResourceData"] as? Data else { continue }
            let mime = r["WebResourceMIMEType"] as? String ?? ImageSupport.sniffMIME(d) ?? "application/octet-stream"
            resources[u] = (d, mime)
            if let last = URL(string: u)?.lastPathComponent, resources[last] == nil { resources[last] = (d, mime) }
        }
        let base = (main["WebResourceURL"] as? String).flatMap(URL.init(string:))
        let encodingName = main["WebResourceTextEncodingName"] as? String
        var text = TextDecoding.decode(html)
        if let enc = encodingName?.lowercased(), enc.contains("utf-16"), let s = String(data: html, encoding: .utf16) { text = s }
        let lookup = resources
        let loader: HTMLReader.ImageLoader = { src in
            if let r = lookup[src] { return (r.0, r.1) }
            if let base, let abs = URL(string: src, relativeTo: base)?.absoluteString, let r = lookup[abs] { return (r.0, r.1) }
            if let last = URL(string: src)?.lastPathComponent, let r = lookup[last] { return (r.0, r.1) }
            return nil
        }
        return HTMLReader.read(text, baseURL: nil, loader: loader)
    }
}

/// Finder text clippings: a property list with a "UTI-Data" dictionary (macOS
/// 10.12+), or classic resource-fork clippings ('utf8'/'utxt'/'TEXT').
public enum TextClippingReader {
    public enum Content {
        case attributed(NSAttributedString)
        case html(String)
        case text(String)
    }

    public static func content(_ url: URL) throws -> Content {
        let data = (try? Data(contentsOf: url)) ?? Data()
        if !data.isEmpty, let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let uti = plist["UTI-Data"] as? [String: Any] {
            func bytes(_ key: String) -> Data? {
                if let d = uti[key] as? Data { return d }
                if let s = uti[key] as? String { return Data(s.utf8) }
                return nil
            }
            if let rtfd = bytes("com.apple.flat-rtfd"), let s = NSAttributedString(rtfd: rtfd, documentAttributes: nil) { return .attributed(s) }
            if let rtf = bytes("public.rtf"), let s = NSAttributedString(rtf: rtf, documentAttributes: nil) { return .attributed(s) }
            if let t = uti["public.utf8-plain-text"] as? String { return .text(t) }
            if let d = uti["public.utf8-plain-text"] as? Data { return .text(String(decoding: d, as: UTF8.self)) }
            if let d = uti["public.utf16-plain-text"] as? Data, let s = String(data: d, encoding: .utf16) { return .text(s) }
            if let t = uti["public.plain-text"] as? String { return .text(t) }
            if let h = bytes("public.html") { return .html(TextDecoding.decode(h)) }
            if let u = uti["public.url"] as? String ?? (uti["public.url"] as? Data).map({ String(decoding: $0, as: UTF8.self) }) { return .text(u) }
        }
        if let text = resourceForkText(url) { return .text(text) }
        throw ConversionError.unreadable(url, detail: "no text in clipping")
    }

    public static func read(_ url: URL) throws -> DocModel {
        switch try content(url) {
        case .attributed(let s): return AttributedReader.model(s)
        case .html(let h): return HTMLReader.read(h, baseURL: nil)
        case .text(let t): return PlainTextReader.parse(t)
        }
    }

    /// Minimal resource-fork reader for pre-10.12 clippings.
    static func resourceForkText(_ url: URL) -> String? {
        let fork = url.appendingPathComponent("..namedfork/rsrc")
        guard let d = try? Data(contentsOf: fork), d.count > 16 else { return nil }
        let b = [UInt8](d)
        func u32(_ i: Int) -> Int { i + 4 <= b.count ? Int(b[i]) << 24 | Int(b[i + 1]) << 16 | Int(b[i + 2]) << 8 | Int(b[i + 3]) : 0 }
        func u16(_ i: Int) -> Int { i + 2 <= b.count ? Int(b[i]) << 8 | Int(b[i + 1]) : 0 }
        let dataOff = u32(0), mapOff = u32(4)
        guard mapOff + 30 <= b.count else { return nil }
        let typeListOff = mapOff + u16(mapOff + 24)
        let nTypes = u16(typeListOff) + 1
        var found: [String: Data] = [:]
        for t in 0..<min(nTypes, 64) {
            let e = typeListOff + 2 + t * 8
            guard e + 8 <= b.count else { break }
            let type = String(bytes: b[e..<e + 4], encoding: .macOSRoman) ?? ""
            let refOff = typeListOff + u16(e + 6)
            guard refOff + 12 <= b.count else { continue }
            let off = (Int(b[refOff + 5]) << 16) | (Int(b[refOff + 6]) << 8) | Int(b[refOff + 7])
            let start = dataOff + off
            let len = u32(start)
            guard start + 4 + len <= b.count else { continue }
            found[type] = Data(b[(start + 4)..<(start + 4 + len)])
        }
        if let d = found["utf8"] { return String(decoding: d, as: UTF8.self) }
        if let d = found["utxt"] { return String(data: d, encoding: .utf16BigEndian) }
        if let d = found["TEXT"] { return String(data: d, encoding: .macOSRoman) }
        return nil
    }
}
