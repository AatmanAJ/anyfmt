import AppKit
import CoreGraphics
import Foundation
import PDFKit

/// PDF → `DocModel` reconstruction. PDFs have no structure, so this infers it:
/// lines (PDFKit text + geometry) are grouped into paragraphs by spacing,
/// headings come from relative font size (and bold short lines), bullets and
/// numbers become lists, repeated headers/footers and page numbers are dropped,
/// paragraphs split by a page break are rejoined, and embedded raster images are
/// extracted and placed where they sit on the page.
public enum PDFDocReader {
    public struct Options: Sendable {
        public var pageBreaks = true
        public var images = true
        public init() {}
    }

    struct Line {
        var text: String
        var rect: CGRect
        var size: Double
        var bold: Bool
        var runs: [DocInline]
        var page: Int
    }

    enum Element {
        case line(Line)
        case image(DocImage, y: CGFloat)
    }

    public static func read(_ url: URL, options: Options = Options()) throws -> DocModel {
        guard let doc = PDFDocument(url: url) else { throw ConversionError.unreadable(url, detail: "PDFKit could not open the file") }
        if doc.isLocked { throw ConversionError.other(L("This PDF is password-protected."), detail: url.path) }
        var meta = DocMetadata()
        if let attrs = doc.documentAttributes {
            if let t = attrs[PDFDocumentAttribute.titleAttribute] as? String, !t.trimmingCharacters(in: .whitespaces).isEmpty { meta.title = t }
            if let a = attrs[PDFDocumentAttribute.authorAttribute] as? String, !a.trimmingCharacters(in: .whitespaces).isEmpty { meta.author = a }
        }
        var pages: [[Element]] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            var elements = lines(page, index: i).map(Element.line)
            if options.images {
                let imgs = PDFImageExtractor.images(page)
                elements = merge(elements, images: imgs, pageHeight: page.bounds(for: .mediaBox).height)
            }
            pages.append(elements)
        }
        stripRunningHeaders(&pages, doc: doc)
        let blocks = assemble(pages, pageBreaks: options.pageBreaks)
        return DocModel(metadata: meta, blocks: blocks)
    }

    // MARK: Lines

    static func lines(_ page: PDFPage, index: Int) -> [Line] {
        guard let attr = page.attributedString, attr.length > 0 else { return [] }
        let ns = attr.string as NSString
        var out: [Line] = []
        let links = linkAnnotations(page)
        ns.enumerateSubstrings(in: NSRange(location: 0, length: ns.length), options: [.byLines]) { sub, range, _, _ in
            guard let sub, !sub.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            guard let sel = page.selection(for: range) else { return }
            let rect = sel.bounds(for: page)
            var runs: [DocInline] = []
            var sizeWeight: [Double: Int] = [:]
            var boldChars = 0, chars = 0
            attr.enumerateAttributes(in: range, options: []) { a, r, _ in
                let t = ns.substring(with: r)
                let font = a[.font] as? NSFont
                let name = font?.fontName.lowercased() ?? ""
                let traits = font?.fontDescriptor.symbolicTraits ?? []
                let bold = traits.contains(.bold) || name.contains("bold") || name.contains("black") || name.contains("heavy") || name.contains("semibold")
                let italic = traits.contains(.italic) || name.contains("italic") || name.contains("oblique")
                let mono = traits.contains(.monoSpace) || name.contains("courier") || name.contains("mono") || name.contains("menlo") || name.contains("consolas")
                let visible = t.filter { !$0.isWhitespace }.count
                chars += visible
                if bold { boldChars += visible }
                if let s = font?.pointSize { sizeWeight[(Double(s) * 2).rounded() / 2, default: 0] += max(visible, 1) }
                var node: DocInline = mono ? .code(t) : .text(t)
                if !mono {
                    if italic { node = .emphasis([node]) }
                    if bold { node = .strong([node]) }
                }
                runs.append(node)
            }
            let size = sizeWeight.max { $0.value < $1.value }?.key ?? Double(rect.height * 0.8)
            var line = Line(text: sub, rect: rect, size: size, bold: chars > 0 && boldChars * 10 >= chars * 8, runs: runs.compacted, page: index)
            for (bounds, url) in links where bounds.intersects(rect) {
                if let s = page.selection(for: bounds)?.string?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty, sub.contains(s) {
                    line.runs = linkify(line.runs, text: s, url: url)
                }
            }
            out.append(line)
        }
        return out
    }

    static func linkAnnotations(_ page: PDFPage) -> [(CGRect, String)] {
        page.annotations.compactMap { a in
            guard let u = a.url?.absoluteString ?? (a.action as? PDFActionURL)?.url?.absoluteString else { return nil }
            return (a.bounds, u)
        }
    }

    /// Wraps the first occurrence of `text` inside the runs with a link.
    static func linkify(_ runs: [DocInline], text: String, url: String) -> [DocInline] {
        var out: [DocInline] = []
        var done = false
        for r in runs {
            guard !done, case .text(let t) = r, let range = t.range(of: text) else { out.append(r); continue }
            let before = String(t[..<range.lowerBound]), after = String(t[range.upperBound...])
            if !before.isEmpty { out.append(.text(before)) }
            out.append(.link(url: url, [.text(text)]))
            if !after.isEmpty { out.append(.text(after)) }
            done = true
        }
        if !done, runs.plainText.trimmingCharacters(in: .whitespaces) == text { return [.link(url: url, runs)] }
        return out
    }

    static func merge(_ elements: [Element], images: [(DocImage, CGRect)], pageHeight: CGFloat) -> [Element] {
        guard !images.isEmpty else { return elements }
        var out = elements
        // Top of page first: insert each image before the first line that sits below its middle.
        for (im, rect) in images.sorted(by: { $0.1.midY > $1.1.midY }) {
            let idx = out.firstIndex { e in
                if case .line(let l) = e { return l.rect.midY < rect.midY }
                if case .image(_, let y) = e { return y < rect.midY }
                return false
            } ?? out.count
            out.insert(.image(im, y: rect.midY), at: idx)
        }
        return out
    }

    /// Drops running heads/footers: only a page's first and last lines are
    /// candidates, they must sit in the outer 6 % of the page, and they go if
    /// they're a bare page number or a short line repeated on most pages.
    static func stripRunningHeaders(_ pages: inout [[Element]], doc: PDFDocument) {
        func edgeLines(_ p: [Element]) -> [Int] {
            let idx = p.indices.filter { if case .line = p[$0] { return true }; return false }
            guard let first = idx.first, let last = idx.last else { return [] }
            return first == last ? [first] : [first, last]
        }
        var counts: [String: Int] = [:]
        for p in pages {
            var seen = Set<String>()
            for i in edgeLines(p) { if case .line(let l) = p[i], isInBand(l, doc) { seen.insert(normalizeForRepeat(l.text)) } }
            for s in seen { counts[s, default: 0] += 1 }
        }
        let threshold = max(2, Int((Double(pages.count) * 0.5).rounded(.up)))
        for k in pages.indices {
            for i in edgeLines(pages[k]).reversed() {
                guard case .line(let l) = pages[k][i], isInBand(l, doc) else { continue }
                let repeated = pages.count >= 2 && l.text.count <= 90 && (counts[normalizeForRepeat(l.text)] ?? 0) >= threshold
                if isPageNumber(l.text) || repeated { pages[k].remove(at: i) }
            }
        }
    }

    static func isInBand(_ l: Line, _ doc: PDFDocument) -> Bool {
        guard let page = doc.page(at: l.page) else { return false }
        let b = page.bounds(for: .mediaBox)
        let band = b.height * 0.06
        return l.rect.minY > b.maxY - band || l.rect.maxY < b.minY + band
    }

    static func normalizeForRepeat(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"\d+"#, with: "#", options: .regularExpression).lowercased()
    }

    static func isPageNumber(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces).lowercased()
        return t.range(of: #"^(page\s*)?[-–—]?\s*\d{1,4}\s*[-–—]?(\s*(of|/)\s*\d{1,4})?$"#, options: .regularExpression) != nil
            || t.range(of: #"^[ivxlc]{1,6}$"#, options: .regularExpression) != nil
    }

    // MARK: Paragraphs

    struct Para {
        var lines: [Line]
        var inlines: [DocInline]
        var size: Double
        var bold: Bool
        var page: Int
        var image: DocImage?
        var text: String { inlines.plainText }
    }

    /// Bullet glyphs may touch the text; dashes and asterisks need a space (so "-5" stays a number).
    static let bulletPattern = #"^\s*(?:[•◦▪‣●○■□►]\s*|[–—\-\*]\s+)"#
    static let numberPattern = #"^\s*(\d{1,3})[.)]\s+"#

    static func assemble(_ pages: [[Element]], pageBreaks: Bool) -> [DocBlock] {
        // Body size: most common size by characters.
        var weight: [Double: Int] = [:]
        for p in pages { for case .line(let l) in p { weight[l.size, default: 0] += l.text.count } }
        let body = weight.max { $0.value < $1.value }?.key ?? 11
        // Left edge of body text for list indentation.
        var lefts: [CGFloat] = []
        for p in pages { for case .line(let l) in p where abs(l.size - body) < 0.6 { lefts.append(l.rect.minX) } }
        let left = lefts.sorted().dropFirst(lefts.count / 10).first ?? 72

        var paras: [[Para]] = []
        for p in pages {
            var out: [Para] = []
            var cur: Para?
            var prev: Line?
            func flush() { if let c = cur { out.append(c) }; cur = nil }
            for e in p {
                switch e {
                case .image(let im, _):
                    flush(); prev = nil
                    out.append(Para(lines: [], inlines: [], size: body, bold: false, page: -1, image: im))
                case .line(let l):
                    if let pl = prev, var c = cur, !startsNewParagraph(pl, l, body: body) {
                        c.inlines = join(c.inlines, l.runs)
                        c.lines.append(l)
                        cur = c
                    } else {
                        flush()
                        cur = Para(lines: [l], inlines: l.runs, size: l.size, bold: l.bold, page: l.page, image: nil)
                    }
                    if l.bold == false { cur?.bold = false }
                    prev = l
                }
            }
            flush()
            paras.append(out)
        }

        // Heading levels from distinct larger sizes.
        let headingSizes = Set(paras.flatMap { $0 }.filter { isHeadingCandidate($0, body: body) }.map(\.size)).sorted(by: >)
        var blocks: [DocBlock] = []
        var listItems: [(level: Int, ordered: Bool, start: Int, inlines: [DocInline])] = []

        func flushList() {
            guard !listItems.isEmpty else { return }
            var items: [FlowItem] = []
            for it in listItems {
                var p = ParaItem(it.inlines)
                p.list = (it.level, it.ordered, it.start, "pdf")
                items.append(.para(p))
            }
            blocks.append(contentsOf: FlowAssembler.assemble(items, headingHeuristic: false))
            listItems.removeAll()
        }

        for (pi, page) in paras.enumerated() {
            for (k, p) in page.enumerated() {
                if let im = p.image { flushList(); blocks.append(.image(im)); continue }
                let text = p.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                // Rejoin a paragraph split across a page break.
                if k == 0, pi > 0, case .paragraph(let prevInl)? = blocks.last, continues(prevInl.plainText, text), p.size == body {
                    blocks[blocks.count - 1] = .paragraph(join(prevInl, p.inlines).trimmed)
                    continue
                }
                if let idx = headingSizes.firstIndex(of: p.size), isHeadingCandidate(p, body: body) {
                    flushList()
                    blocks.append(.heading(level: min(idx + 1, 6), FlowAssembler.unwrapBold(p.inlines.trimmed)))
                    continue
                }
                if p.bold, abs(p.size - body) < 1, p.lines.count == 1, text.count <= 80, !text.hasSuffix("."), !text.hasSuffix(","), !text.hasSuffix(";"),
                   text.range(of: bulletPattern, options: .regularExpression) == nil {
                    flushList()
                    blocks.append(.heading(level: min(headingSizes.count + 1, 6), FlowAssembler.unwrapBold(p.inlines.trimmed)))
                    continue
                }
                let indent = max(0, Int(((p.lines.first?.rect.minX ?? left) - left) / 18))
                if let r = text.range(of: bulletPattern, options: .regularExpression) {
                    let n = text.distance(from: text.startIndex, to: r.upperBound)
                    listItems.append((min(indent, 8), false, 1, FlowAssembler.dropPrefix(p.inlines.trimmed, count: n)))
                    continue
                }
                if let r = text.range(of: numberPattern, options: .regularExpression) {
                    let n = text.distance(from: text.startIndex, to: r.upperBound)
                    let num = Int(text[r].filter(\.isNumber)) ?? 1
                    listItems.append((min(indent, 8), true, num, FlowAssembler.dropPrefix(p.inlines.trimmed, count: n)))
                    continue
                }
                flushList()
                blocks.append(.paragraph(p.inlines.trimmed))
            }
            if pageBreaks, pi < paras.count - 1 {
                // Page break only if the next page doesn't continue this paragraph.
                let nextFirst = paras[pi + 1].first(where: { $0.image != nil || !$0.text.trimmingCharacters(in: .whitespaces).isEmpty })
                if case .paragraph(let inl)? = blocks.last, let nf = nextFirst, nf.image == nil, nf.size == body,
                   continues(inl.plainText, nf.text.trimmingCharacters(in: .whitespaces)) {
                    continue
                }
                flushList()
                if !blocks.isEmpty, case .pageBreak? = blocks.last {} else if !blocks.isEmpty { blocks.append(.pageBreak) }
            }
        }
        flushList()
        while case .pageBreak? = blocks.last { blocks.removeLast() }
        return blocks
    }

    static func isHeadingCandidate(_ p: Para, body: Double) -> Bool {
        guard p.image == nil, p.size >= body * 1.18, p.lines.count <= 3 else { return false }
        let t = p.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && t.count <= 200
    }

    /// True when `next` reads as the continuation of `prev` (no terminal punctuation, lowercase start).
    static func continues(_ prev: String, _ next: String) -> Bool {
        let p = prev.trimmingCharacters(in: .whitespaces)
        guard let last = p.last, let first = next.first else { return false }
        if ".!?:;\"”)".contains(last) { return false }
        return first.isLowercase || (last == "-" || last == ",")
    }

    static func startsNewParagraph(_ prev: Line, _ line: Line, body: Double) -> Bool {
        let gap = prev.rect.minY - line.rect.minY
        let size = max(prev.size, line.size)
        if gap < -2 || gap > size * 1.75 { return true }                 // column jump or paragraph spacing
        if abs(prev.size - line.size) > max(1, size * 0.12) { return true } // size change
        if prev.bold != line.bold, prev.text.count < 90 { return true }     // bold heading line followed by body
        let t = line.text
        if t.range(of: bulletPattern, options: .regularExpression) != nil || t.range(of: numberPattern, options: .regularExpression) != nil { return true }
        // A short previous line ending a sentence closes the paragraph.
        let prevText = prev.text.trimmingCharacters(in: .whitespaces)
        if let lastChar = prevText.last, ".!?:".contains(lastChar), prev.rect.maxX < line.rect.maxX - size * 6 { return true }
        // Indented first line starts a new paragraph.
        if line.rect.minX > prev.rect.minX + size * 1.5, ".!?:".contains(prevText.last ?? " ") { return true }
        return false
    }

    /// Joins the next line onto a paragraph: de-hyphenates "exam-\nple", otherwise adds a space.
    static func join(_ a: [DocInline], _ b: [DocInline]) -> [DocInline] {
        var left = a
        let lt = left.plainText
        let rt = b.plainText.trimmingCharacters(in: .whitespaces)
        if lt.hasSuffix("-"), let f = rt.first, f.isLowercase, lt.count > 1 {
            left = FlowAssembler.dropSuffix(left, count: 1)
            return (left + b.trimmed).compacted
        }
        if lt.hasSuffix(" ") || lt.isEmpty { return (left + b.trimmed).compacted }
        return (left + [.text(" ")] + b.trimmed).compacted
    }
}

extension FlowAssembler {
    /// Removes the last `count` characters of the trailing text run.
    static func dropSuffix(_ a: [DocInline], count: Int) -> [DocInline] {
        guard var last = a.last else { return a }
        var rest = Array(a.dropLast())
        switch last {
        case .text(let s): last = .text(String(s.dropLast(count)))
        case .strong(let c): last = .strong(dropSuffix(c, count: count))
        case .emphasis(let c): last = .emphasis(dropSuffix(c, count: count))
        case .underline(let c): last = .underline(dropSuffix(c, count: count))
        case .strikethrough(let c): last = .strikethrough(dropSuffix(c, count: count))
        case .link(let u, let c): last = .link(url: u, dropSuffix(c, count: count))
        case .code(let s): last = .code(String(s.dropLast(count)))
        default: return a
        }
        rest.append(last)
        return rest
    }
}

/// Finds raster images painted on a PDF page (with their placement) by scanning
/// the content stream for `Do` while tracking the CTM (`q`/`Q`/`cm`).
enum PDFImageExtractor {
    final class State {
        var stack: [CGAffineTransform] = [.identity]
        var found: [(DocImage, CGRect)] = []
        var depth = 0
        var seen = Set<String>()
    }

    static func images(_ page: PDFPage) -> [(DocImage, CGRect)] {
        guard let cg = page.pageRef else { return [] }
        let state = State()
        let stream = CGPDFContentStreamCreateWithPage(cg)
        scan(stream, state: state)
        CGPDFContentStreamRelease(stream)
        return state.found
    }

    static func scan(_ stream: CGPDFContentStreamRef, state: State) {
        guard let table = CGPDFOperatorTableCreate() else { return }
        CGPDFOperatorTableSetCallback(table, "q") { _, info in
            guard let info else { return }
            let s = Unmanaged<ScanBox>.fromOpaque(info).takeUnretainedValue().state
            s.stack.append(s.stack.last ?? .identity)
        }
        CGPDFOperatorTableSetCallback(table, "Q") { _, info in
            guard let info else { return }
            let s = Unmanaged<ScanBox>.fromOpaque(info).takeUnretainedValue().state
            if s.stack.count > 1 { s.stack.removeLast() }
        }
        CGPDFOperatorTableSetCallback(table, "cm") { scanner, info in
            guard let info else { return }
            let s = Unmanaged<ScanBox>.fromOpaque(info).takeUnretainedValue().state
            var v = [CGPDFReal](repeating: 0, count: 6)
            for k in (0..<6).reversed() { if !CGPDFScannerPopNumber(scanner, &v[k]) { return } }
            let m = CGAffineTransform(a: v[0], b: v[1], c: v[2], d: v[3], tx: v[4], ty: v[5])
            let cur = s.stack.last ?? .identity
            s.stack[s.stack.count - 1] = m.concatenating(cur)
        }
        CGPDFOperatorTableSetCallback(table, "Do") { scanner, info in
            guard let info else { return }
            let box = Unmanaged<ScanBox>.fromOpaque(info).takeUnretainedValue()
            let s = box.state
            var namePtr: UnsafePointer<CChar>?
            guard CGPDFScannerPopName(scanner, &namePtr), let namePtr else { return }
            let content = CGPDFScannerGetContentStream(scanner)
            guard let obj = CGPDFContentStreamGetResource(content, "XObject", namePtr) else { return }
            var streamRef: CGPDFStreamRef?
            guard CGPDFObjectGetValue(obj, .stream, &streamRef), let streamRef, let dict = CGPDFStreamGetDictionary(streamRef) else { return }
            var subtype: UnsafePointer<CChar>?
            guard CGPDFDictionaryGetName(dict, "Subtype", &subtype), let subtype else { return }
            let ctm = s.stack.last ?? .identity
            switch String(cString: subtype) {
            case "Image":
                let rect = CGRect(x: 0, y: 0, width: 1, height: 1).applying(ctm)
                guard rect.width >= 24, rect.height >= 24 else { return }
                let key = "\(String(cString: namePtr))@\(Int(rect.minX)),\(Int(rect.minY))"
                guard !s.seen.contains(key), let im = PDFImageExtractor.decode(streamRef, dict: dict) else { return }
                s.seen.insert(key)
                s.found.append((im, rect))
            case "Form":
                guard s.depth < 6 else { return }
                var resources: CGPDFDictionaryRef?
                _ = CGPDFDictionaryGetDictionary(dict, "Resources", &resources)
                var matrix = CGAffineTransform.identity
                var arr: CGPDFArrayRef?
                if CGPDFDictionaryGetArray(dict, "Matrix", &arr), let arr, CGPDFArrayGetCount(arr) == 6 {
                    var v = [CGPDFReal](repeating: 0, count: 6)
                    for k in 0..<6 { _ = CGPDFArrayGetNumber(arr, k, &v[k]) }
                    matrix = CGAffineTransform(a: v[0], b: v[1], c: v[2], d: v[3], tx: v[4], ty: v[5])
                }
                let sub = CGPDFContentStreamCreateWithStream(streamRef, resources ?? dict, content)
                s.stack.append(matrix.concatenating(ctm))
                s.depth += 1
                PDFImageExtractor.scan(sub, state: s)
                CGPDFContentStreamRelease(sub)
                s.depth -= 1
                s.stack.removeLast()
            default:
                return
            }
        }
        let box = ScanBox(state)
        let ptr = Unmanaged.passRetained(box).toOpaque()
        let scanner = CGPDFScannerCreate(stream, table, ptr)
        CGPDFScannerScan(scanner)
        CGPDFScannerRelease(scanner)
        Unmanaged<ScanBox>.fromOpaque(ptr).release()
        CGPDFOperatorTableRelease(table)
    }

    final class ScanBox {
        let state: State
        init(_ s: State) { state = s }
    }

    /// JPEG streams pass through untouched; 8-bit Gray/RGB/CMYK raw streams are rebuilt as PNG.
    static func decode(_ stream: CGPDFStreamRef, dict: CGPDFDictionaryRef) -> DocImage? {
        var format = CGPDFDataFormat.raw
        guard let cfData = CGPDFStreamCopyData(stream, &format) else { return nil }
        let data = cfData as Data
        if format == .jpegEncoded || format == .JPEG2000 {
            guard let png = format == .JPEG2000 ? ImageSupport.reencodePNG(data) : data else { return nil }
            return DocImage(data: png, mime: format == .JPEG2000 ? "image/png" : "image/jpeg")
        }
        var w: CGPDFInteger = 0, h: CGPDFInteger = 0, bpc: CGPDFInteger = 8
        guard CGPDFDictionaryGetInteger(dict, "Width", &w), CGPDFDictionaryGetInteger(dict, "Height", &h), w > 0, h > 0 else { return nil }
        _ = CGPDFDictionaryGetInteger(dict, "BitsPerComponent", &bpc)
        guard bpc == 8 else { return nil }
        var components = 3
        var csName: UnsafePointer<CChar>?
        var csArray: CGPDFArrayRef?
        if CGPDFDictionaryGetName(dict, "ColorSpace", &csName), let csName {
            switch String(cString: csName) {
            case "DeviceGray", "CalGray": components = 1
            case "DeviceCMYK": components = 4
            default: components = 3
            }
        } else if CGPDFDictionaryGetArray(dict, "ColorSpace", &csArray), let csArray {
            var first: UnsafePointer<CChar>?
            if CGPDFArrayGetName(csArray, 0, &first), let first {
                let n = String(cString: first)
                if n == "ICCBased" {
                    var icc: CGPDFStreamRef?
                    if CGPDFArrayGetStream(csArray, 1, &icc), let icc, let d = CGPDFStreamGetDictionary(icc) {
                        var n: CGPDFInteger = 3
                        _ = CGPDFDictionaryGetInteger(d, "N", &n)
                        components = Int(n)
                    }
                } else if n == "Indexed" {
                    return nil
                } else if n == "CalGray" { components = 1 }
            }
        }
        let rowBytes = Int(w) * components
        guard data.count >= rowBytes * Int(h) else { return nil }
        let space: CGColorSpace
        switch components {
        case 1: space = CGColorSpaceCreateDeviceGray()
        case 4: space = CGColorSpaceCreateDeviceCMYK()
        default: space = CGColorSpaceCreateDeviceRGB()
        }
        guard let provider = CGDataProvider(data: data as CFData),
              let img = CGImage(width: Int(w), height: Int(h), bitsPerComponent: 8, bitsPerPixel: 8 * components, bytesPerRow: rowBytes,
                                space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue), provider: provider,
                                decode: nil, shouldInterpolate: true, intent: .defaultIntent),
              let png = ImageSupport.encode(img, type: .png) else { return nil }
        return DocImage(data: png, mime: "image/png")
    }
}
