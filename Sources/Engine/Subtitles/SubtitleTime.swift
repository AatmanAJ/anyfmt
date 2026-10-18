import Foundation

/// Subtitle timestamps as integer milliseconds.
public enum SubtitleTime {
    /// Parses `HH:MM:SS,mmm`, `HH:MM:SS.mmm` and `MM:SS.mmm`. Hours may have any
    /// number of digits (≥ 100 h is legal). Lenient where real files are sloppy:
    /// either separator, 1–3 fraction digits read as a decimal fraction
    /// (`01.5` = 1 s 500 ms), a missing fraction. Minutes and seconds must be < 60.
    public static func parse<S: StringProtocol>(_ text: S) -> Int? {
        let s = text.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        let parts = s.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { return nil }

        let last = parts[parts.count - 1]
        let secText: Substring, fracText: Substring
        if let sep = last.firstIndex(where: { $0 == "," || $0 == "." }) {
            secText = last[..<sep]
            fracText = last[last.index(after: sep)...]
        } else {
            secText = last
            fracText = ""
        }
        guard let seconds = digits(secText, max: 2), seconds < 60 else { return nil }
        guard let minutes = digits(parts[parts.count - 2], max: 2), minutes < 60 else { return nil }
        var hours = 0
        if parts.count == 3 {
            guard let h = digits(parts[0], max: 9) else { return nil }
            hours = h
        }
        var millis = 0
        if !fracText.isEmpty {
            guard fracText.allSatisfy(isDigit) else { return nil }
            // Fraction semantics: "5" → 500 ms, "05" → 50 ms, "005" → 5 ms; extra digits truncate.
            let padded = (String(fracText.prefix(3)) + "00").prefix(3)
            millis = Int(padded) ?? 0
        }
        return ((hours * 60 + minutes) * 60 + seconds) * 1000 + millis
    }

    /// `HH:MM:SS<sep>mmm`, hours zero-padded to at least two digits.
    public static func format(_ ms: Int, separator: Character) -> String {
        let v = max(0, ms)
        let h = v / 3_600_000, m = (v / 60_000) % 60, s = (v / 1000) % 60, f = v % 1000
        return pad(h, 2) + ":" + pad(m, 2) + ":" + pad(s, 2) + String(separator) + pad(f, 3)
    }

    /// Transcript style `HH:MM:SS` (milliseconds dropped).
    public static func formatClock(_ ms: Int) -> String {
        let v = max(0, ms)
        return pad(v / 3_600_000, 2) + ":" + pad((v / 60_000) % 60, 2) + ":" + pad((v / 1000) % 60, 2)
    }

    static func isDigit(_ c: Character) -> Bool { c.isASCII && c.isNumber }

    private static func pad(_ n: Int, _ width: Int) -> String {
        let s = String(n)
        return s.count >= width ? s : String(repeating: "0", count: width - s.count) + s
    }

    private static func digits<S: StringProtocol>(_ s: S, max: Int) -> Int? {
        guard !s.isEmpty, s.count <= max, s.allSatisfy(isDigit) else { return nil }
        return Int(s)
    }
}

/// A parsed `start --> end [rest]` line.
struct SubtitleTiming {
    let start: Int
    let end: Int
    /// Everything after the end timestamp, trimmed (VTT cue settings, or SRT `X1:` coordinates).
    let rest: String?

    /// Nil when the line has no arrow or either timestamp is malformed.
    init?(_ line: String) {
        guard let arrow = line.range(of: "-->") else { return nil }
        guard let start = SubtitleTime.parse(line[..<arrow.lowerBound]) else { return nil }
        let tail = line[arrow.upperBound...].drop { $0 == " " || $0 == "\t" }
        let endText = tail.prefix { $0 != " " && $0 != "\t" }
        guard let end = SubtitleTime.parse(endText) else { return nil }
        let rest = tail.dropFirst(endText.count).trimmingCharacters(in: .whitespaces)
        self.start = start
        self.end = end
        self.rest = rest.isEmpty ? nil : rest
    }
}

