import Foundation

/// Parses the `pages` option: "" = all pages, otherwise a comma list of pages and
/// ranges, 1-based, e.g. "1-3,5", "2-", "-4", "7". Whitespace is ignored, pages are
/// de-duplicated and kept in ascending order, and anything past the last page is dropped.
enum PageRange {
    enum ParseError: Error, Equatable { case invalid(String) }

    /// 1-based page numbers to render, or throws on malformed text.
    static func parse(_ text: String, pageCount: Int) throws -> [Int] {
        let spec = text.filter { !$0.isWhitespace }
        guard pageCount > 0 else { return [] }
        if spec.isEmpty || spec.lowercased() == "all" { return Array(1...pageCount) }
        var pages = Set<Int>()
        for part in spec.split(separator: ",", omittingEmptySubsequences: true) {
            let bounds = part.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            if bounds.count == 1 {
                guard let p = Int(bounds[0]), p >= 1 else { throw ParseError.invalid(String(part)) }
                if p <= pageCount { pages.insert(p) }
            } else {
                let lo = bounds[0].isEmpty ? 1 : Int(bounds[0])
                let hi = bounds[1].isEmpty ? pageCount : Int(bounds[1])
                guard let lo, let hi, lo >= 1, hi >= lo else { throw ParseError.invalid(String(part)) }
                if lo <= pageCount { pages.formUnion(lo...min(hi, pageCount)) }
            }
        }
        return pages.sorted()
    }
}
