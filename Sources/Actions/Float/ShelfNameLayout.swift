import AppKit

/// Finder-like two-line file names for the shelf grid: break between words
/// (or before the extension), never mid-word, and keep the extension visible
/// by truncating the middle of whatever still doesn't fit.
enum ShelfNameLayout {
    /// Up to two lines joined by "\n", each fitting `width` in `font`.
    static func lines(for name: String, font: NSFont, width: CGFloat) -> String {
        lines(for: name) { measure($0, font) <= width }
    }

    /// Same, with `fits` deciding whether a string fits on one line.
    static func lines(for name: String, fits: (String) -> Bool) -> String {
        if fits(name) { return name }

        // Break points: after spaces (preferred, like Finder), else before the
        // extension's dot.
        var spaces: [String.Index] = []
        var i = name.startIndex
        while i < name.endIndex {
            if name[i] == " " { spaces.append(name.index(after: i)) }
            i = name.index(after: i)
        }
        let dot = name.lastIndex(of: ".").flatMap { $0 > name.startIndex ? $0 : nil }

        func split(_ b: String.Index) -> (String, String) {
            (String(name[..<b]).trimmingCharacters(in: .whitespaces), String(name[b...]).trimmingCharacters(in: .whitespaces))
        }
        // 1. Both lines fit: the longest first line at a space, then at the dot.
        for b in spaces.reversed() + (dot.map { [$0] } ?? []) {
            let (first, rest) = split(b)
            if !first.isEmpty, fits(first), fits(rest) { return first + "\n" + rest }
        }
        // 2. The second line is too long: break as late as possible, then cut
        //    the middle of the second line so the extension stays.
        for b in (spaces + (dot.map { [$0] } ?? [])).sorted().reversed() {
            let (first, rest) = split(b)
            if !first.isEmpty, fits(first) { return first + "\n" + truncateMiddle(rest, fits: fits) }
        }
        // 3. One long word: a single middle-truncated line.
        return truncateMiddle(name, fits: fits)
    }

    /// "Interview-final-v2.mov" → "Interview…v2.mov".
    static func truncateMiddle(_ s: String, fits: (String) -> Bool) -> String {
        if fits(s) { return s }
        let chars = Array(s)
        var keepHead = chars.count / 2, keepTail = chars.count - keepHead
        while keepHead + keepTail > 1 {
            if keepTail >= keepHead { keepTail -= 1 } else { keepHead -= 1 }
            let candidate = String(chars.prefix(keepHead)) + "…" + String(chars.suffix(keepTail))
            if fits(candidate) { return candidate }
        }
        return "…"
    }

    static func measure(_ s: String, _ font: NSFont) -> CGFloat {
        ceil((s as NSString).size(withAttributes: [.font: font]).width)
    }
}
