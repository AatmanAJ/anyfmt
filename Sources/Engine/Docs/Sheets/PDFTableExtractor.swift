import CoreGraphics
import Foundation
import PDFKit

/// Rebuilds tables from a text PDF's word positions (no ruling lines needed):
/// words → cells (merged when gaps are small) → lines (shared baseline) →
/// column bands from the x-coverage of consecutive multi-cell lines. Lines
/// outside a table become single-cell rows, so nothing is lost.
public enum PDFTableExtractor {
    struct Word { var text: String; var rect: CGRect }
    struct Segment { var text: String; var rect: CGRect }
    struct Line { var segments: [Segment]; var rect: CGRect; var height: CGFloat }

    public static func workbook(_ url: URL) throws -> Workbook {
        guard let doc = PDFDocument(url: url) else { throw ConversionError.unreadable(url, detail: "PDFKit could not open the file") }
        if doc.isLocked { throw ConversionError.other(L("This PDF is password-protected."), detail: url.path) }
        var rows: [[Cell]] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let pageRows = self.rows(page)
            if !rows.isEmpty, !pageRows.isEmpty, i > 0 { rows.append([]) }
            rows.append(contentsOf: pageRows)
        }
        let name = url.deletingPathExtension().lastPathComponent
        return Workbook(sheets: [Sheet(name: name, rows: rows).trimmed])
    }

    static func words(_ page: PDFPage) -> [Word] {
        guard let s = page.string, !s.isEmpty else { return [] }
        let ns = s as NSString
        var out: [Word] = []
        var cur = ""
        var rect = CGRect.null
        func flush() {
            if !cur.isEmpty, !rect.isNull { out.append(Word(text: cur, rect: rect)) }
            cur = ""
            rect = .null
        }
        for i in 0..<ns.length {
            guard let scalar = Unicode.Scalar(ns.character(at: i)) else { continue }
            let ch = Character(scalar)
            if ch.isWhitespace { flush(); continue }
            let b = page.characterBounds(at: i)
            if b.width <= 0 && b.height <= 0 { continue }
            // A big jump inside one "word" means PDFKit glued separate runs.
            if !rect.isNull, abs(b.midY - rect.midY) > max(rect.height, b.height) * 0.6 || b.minX - rect.maxX > max(b.height, 4) * 0.6 { flush() }
            cur.append(ch)
            rect = rect.isNull ? b : rect.union(b)
        }
        flush()
        return out
    }

    static func lines(_ words: [Word]) -> [Line] {
        let sorted = words.sorted { a, b in abs(a.rect.midY - b.rect.midY) < 1 ? a.rect.minX < b.rect.minX : a.rect.midY > b.rect.midY }
        var groups: [[Word]] = []
        for w in sorted {
            if var last = groups.last, let ref = last.first, abs(ref.rect.midY - w.rect.midY) < max(ref.rect.height, w.rect.height) * 0.5 {
                last.append(w)
                groups[groups.count - 1] = last
            } else {
                groups.append([w])
            }
        }
        return groups.map { g in
            let ws = g.sorted { $0.rect.minX < $1.rect.minX }
            let height = ws.map(\.rect.height).sorted()[ws.count / 2]
            var segs: [Segment] = []
            for w in ws {
                if var last = segs.last, w.rect.minX - last.rect.maxX < height * 0.9 {
                    last.text += " " + w.text
                    last.rect = last.rect.union(w.rect)
                    segs[segs.count - 1] = last
                } else {
                    segs.append(Segment(text: w.text, rect: w.rect))
                }
            }
            let r = segs.map(\.rect).reduce(CGRect.null) { $0.union($1) }
            return Line(segments: segs, rect: r, height: height)
        }
    }

    static func rows(_ page: PDFPage) -> [[Cell]] {
        let ls = lines(words(page))
        var out: [[Cell]] = []
        var i = 0
        while i < ls.count {
            // A table block: consecutive lines with ≥ 2 segments (allowing single-cell rows inside).
            guard ls[i].segments.count >= 2 else {
                out.append([cell(ls[i].segments.map(\.text).joined(separator: " "))])
                i += 1
                continue
            }
            var j = i
            while j < ls.count, ls[j].segments.count >= 2 || (j + 1 < ls.count && ls[j + 1].segments.count >= 2 && j > i) { j += 1 }
            let block = Array(ls[i..<j])
            out.append(contentsOf: grid(block))
            i = j
        }
        return out
    }

    /// Column bands = maximal x-intervals covered by segments of the block's multi-cell lines.
    static func grid(_ block: [Line]) -> [[Cell]] {
        let h = block.map(\.height).sorted()[block.count / 2]
        var intervals: [(CGFloat, CGFloat)] = []
        for l in block where l.segments.count >= 2 { for s in l.segments { intervals.append((s.rect.minX, s.rect.maxX)) } }
        intervals.sort { $0.0 < $1.0 }
        var bands: [(CGFloat, CGFloat)] = []
        for iv in intervals {
            if let last = bands.last, iv.0 <= last.1 + h * 0.3 { bands[bands.count - 1].1 = max(last.1, iv.1) } else { bands.append(iv) }
        }
        guard bands.count >= 2 else { return block.map { [cell($0.segments.map(\.text).joined(separator: " "))] } }
        return block.map { l in
            var row = [Cell](repeating: .empty, count: bands.count)
            for s in l.segments {
                // Band with the largest overlap (nearest centre as a tiebreak).
                var best = 0
                var bestScore = -CGFloat.infinity
                for (k, b) in bands.enumerated() {
                    let overlap = min(b.1, s.rect.maxX) - max(b.0, s.rect.minX)
                    let score = overlap > 0 ? overlap : -abs((b.0 + b.1) / 2 - s.rect.midX)
                    if score > bestScore { bestScore = score; best = k }
                }
                if case .empty = row[best] { row[best] = cell(s.text) } else { row[best] = cell(row[best].text + " " + s.text) }
            }
            return row
        }
    }

    /// Numbers (incl. thousands separators, currency, parentheses negatives) become numeric cells.
    static func cell(_ raw: String) -> Cell {
        let t = raw.trimmingCharacters(in: .whitespaces)
        var s = t
        var negative = false
        if s.hasPrefix("("), s.hasSuffix(")") { negative = true; s = String(s.dropFirst().dropLast()) }
        s = s.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: "€", with: "").replacingOccurrences(of: "£", with: "")
        if s.range(of: #"^[-+]?\d{1,3}(,\d{3})+(\.\d+)?$"#, options: .regularExpression) != nil { s = s.replacingOccurrences(of: ",", with: "") }
        if s != t || negative, let n = Cell.number(s, decimalComma: false) { return .number(negative ? -n : n) }
        return Cell.infer(t)
    }
}
