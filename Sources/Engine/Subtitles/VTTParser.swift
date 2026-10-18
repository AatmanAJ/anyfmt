import Foundation

/// WebVTT (.vtt) reader, following the W3C parsing rules where they matter for
/// conversion and staying lenient elsewhere. Never throws.
///
/// Keeps the `WEBVTT` header text and header lines, NOTE / STYLE / REGION
/// blocks (with their position), cue identifiers, cue settings and cue text
/// verbatim, so VTT → VTT is lossless. Accepts `MM:SS.mmm` and `HH+:MM:SS.mmm`
/// timestamps (and a stray `,` separator).
public enum VTTParser {
    public static func parse(_ data: Data) -> SubtitleDocument {
        let decoded = SubtitleSource.decode(data)
        return parse(text: decoded.text, hasBOM: decoded.hasBOM)
    }

    public static func parse(text: String, hasBOM: Bool = false) -> SubtitleDocument {
        let (lines, terminated) = SubtitleSource.lines(text)
        var doc = SubtitleDocument(dialect: .vtt, hasBOM: hasBOM,
                                   lineEnding: SubtitleSource.dominantLineEnding(text),
                                   endsWithNewline: terminated)
        var i = 0

        // Signature + header block (ends at the first blank line or a timing line).
        if let first = lines.first, isSignature(first) {
            doc.header.append(first)
            i = 1
            while i < lines.count, !SubtitleSource.isBlank(lines[i]), !lines[i].contains("-->") {
                doc.header.append(lines[i])
                i += 1
            }
        } else {
            doc.warnings.append(SubtitleWarning(line: 1, message: "missing WEBVTT signature; parsed anyway"))
            doc.header = ["WEBVTT"]
        }

        while i < lines.count {
            if SubtitleSource.isBlank(lines[i]) { i += 1; continue }
            let line = lines[i]

            if let kind = blockKind(line) {
                var block = [line]
                var j = i + 1
                while j < lines.count, !SubtitleSource.isBlank(lines[j]), !lines[j].contains("-->") {
                    block.append(lines[j])
                    j += 1
                }
                if kind != .note, !doc.cues.isEmpty {
                    // The spec only honours STYLE/REGION before the first cue; keep it, but say so.
                    doc.warnings.append(SubtitleWarning(line: i + 1, message: "\(kind.rawValue.uppercased()) block after the first cue"))
                }
                doc.blocks.append(SubtitleBlock(kind: kind, lines: block, beforeCue: doc.cues.count))
                i = j
                continue
            }

            var identifier: String?
            let timingIndex: Int
            if line.contains("-->") {
                timingIndex = i
            } else if i + 1 < lines.count, lines[i + 1].contains("-->") {
                identifier = line
                timingIndex = i + 1
            } else {
                doc.warnings.append(SubtitleWarning(line: i + 1, message: "skipped block: text without a timing line"))
                i = nextBlank(after: i, in: lines)
                continue
            }

            guard let timing = SubtitleTiming(lines[timingIndex]) else {
                doc.warnings.append(SubtitleWarning(line: timingIndex + 1, message: "skipped cue: malformed timing line"))
                i = nextBlank(after: timingIndex, in: lines)
                continue
            }
            var text: [String] = []
            var j = timingIndex + 1
            // Per spec, a line containing "-->" ends the cue text and starts the next cue.
            while j < lines.count, !SubtitleSource.isBlank(lines[j]), !lines[j].contains("-->") {
                text.append(lines[j])
                j += 1
            }
            if timing.end < timing.start {
                doc.warnings.append(SubtitleWarning(line: timingIndex + 1, message: "skipped cue: ends before it starts"))
            } else {
                doc.cues.append(SubtitleCue(identifier: identifier, start: timing.start, end: timing.end,
                                            lines: text, settings: timing.rest))
            }
            i = j
        }
        return doc
    }

    /// `WEBVTT` alone or followed by a space or tab and header text.
    static func isSignature(_ line: String) -> Bool {
        guard line.hasPrefix("WEBVTT") else { return false }
        let rest = line.dropFirst(6)
        return rest.isEmpty || rest.first == " " || rest.first == "\t"
    }

    private static func blockKind(_ line: String) -> SubtitleBlock.Kind? {
        if line.contains("-->") { return nil }
        for (word, kind) in [("NOTE", SubtitleBlock.Kind.note), ("STYLE", .style), ("REGION", .region)] {
            guard line.hasPrefix(word) else { continue }
            let rest = line.dropFirst(word.count)
            if rest.isEmpty || rest.first == " " || rest.first == "\t" { return kind }
        }
        return nil
    }

    private static func nextBlank(after i: Int, in lines: [String]) -> Int {
        var k = i + 1
        while k < lines.count, !SubtitleSource.isBlank(lines[k]) { k += 1 }
        return k
    }
}
