import Foundation

/// SubRip (.srt) reader. Never throws: malformed cues are skipped and reported
/// in `SubtitleDocument.warnings`.
///
/// Handles BOMs (UTF-8/UTF-16), legacy Windows-1252 text, LF/CRLF/CR, missing
/// or non-numeric indexes, extra blank lines, a missing blank line between
/// cues, `.` instead of `,` before milliseconds, hours ≥ 100, SRT position
/// suffixes (`X1:… Y2:…`, dropped) and a missing trailing newline.
public enum SRTParser {
    public static func parse(_ data: Data) -> SubtitleDocument {
        let decoded = SubtitleSource.decode(data)
        return parse(text: decoded.text, hasBOM: decoded.hasBOM)
    }

    public static func parse(text: String, hasBOM: Bool = false) -> SubtitleDocument {
        let (lines, terminated) = SubtitleSource.lines(text)
        var doc = SubtitleDocument(dialect: .srt, hasBOM: hasBOM,
                                   lineEnding: SubtitleSource.dominantLineEnding(text),
                                   endsWithNewline: terminated)
        var i = 0
        // An index line we already consumed while reading the previous cue's text
        // (happens when the blank line between two cues is missing).
        var carriedIndex: String?

        while i < lines.count {
            if SubtitleSource.isBlank(lines[i]) { i += 1; continue }

            var identifier: String? = carriedIndex
            carriedIndex = nil
            let timingLine: Int
            if SubtitleTiming(lines[i]) != nil {
                timingLine = i
            } else if i + 1 < lines.count, SubtitleTiming(lines[i + 1]) != nil {
                identifier = lines[i].trimmingCharacters(in: .whitespaces)
                timingLine = i + 1
            } else {
                let arrowLine = lines[i].contains("-->") ? i : (i + 1 < lines.count && lines[i + 1].contains("-->") ? i + 1 : nil)
                let reason = arrowLine == nil ? "text without a timing line" : "malformed timing line"
                doc.warnings.append(SubtitleWarning(line: (arrowLine ?? i) + 1, message: "skipped block: \(reason)"))
                i = nextBlank(after: i, in: lines)
                continue
            }

            guard let timing = SubtitleTiming(lines[timingLine]) else { i = timingLine + 1; continue }
            var text: [String] = []
            var j = timingLine + 1
            while j < lines.count, !SubtitleSource.isBlank(lines[j]) {
                if SubtitleTiming(lines[j]) != nil {
                    // Next cue starts without a blank line; a bare number just before it is its index.
                    if let last = text.last, isIndex(last) {
                        carriedIndex = last.trimmingCharacters(in: .whitespaces)
                        text.removeLast()
                    }
                    break
                }
                text.append(lines[j])
                j += 1
            }

            if timing.end < timing.start {
                doc.warnings.append(SubtitleWarning(line: timingLine + 1, message: "skipped cue: ends before it starts"))
            } else {
                doc.cues.append(SubtitleCue(identifier: identifier, start: timing.start, end: timing.end, lines: text))
            }
            // If the next cue was glued on without a blank line, `j` is its timing line.
            i = j
        }
        return doc
    }

    private static func isIndex(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return !t.isEmpty && t.allSatisfy(SubtitleTime.isDigit)
    }

    private static func nextBlank(after i: Int, in lines: [String]) -> Int {
        var k = i + 1
        while k < lines.count, !SubtitleSource.isBlank(lines[k]) { k += 1 }
        return k
    }
}
