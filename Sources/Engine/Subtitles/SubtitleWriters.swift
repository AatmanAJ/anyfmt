import Foundation

/// Writes SubRip. Cues are numbered 1…n in start order (overlaps kept),
/// timestamps use `,`, and WebVTT-only features are dropped: NOTE/STYLE/REGION
/// blocks and cue settings (except explicit placement, which becomes `{\anN}`).
/// Line endings and BOM follow the source document.
public enum SRTWriter {
    public static func write(_ doc: SubtitleDocument) -> Data {
        let classColors = SubtitleMarkup.classColors(from: doc.blocks)
        var out: [String] = []
        for (n, cue) in doc.cuesByStart.enumerated() {
            if n > 0 { out.append("") }
            out.append(String(n + 1))
            out.append(SubtitleTime.format(cue.start, separator: ",") + " --> " + SubtitleTime.format(cue.end, separator: ","))
            switch doc.dialect {
            case .srt: out.append(contentsOf: cue.lines)
            case .vtt: out.append(contentsOf: SubtitleMarkup.vttToSRT(cue.lines, settings: cue.settings, classColors: classColors))
            }
        }
        return SubtitleSource.encode(out, ending: doc.lineEnding, bom: doc.hasBOM)
    }
}

/// Writes WebVTT. A WebVTT source is written back verbatim (header, blocks,
/// identifiers, settings, text); a SubRip source is translated (tags, colours,
/// `{\anN}` placement) and sorted into start order as WebVTT requires.
public enum VTTWriter {
    public static func write(_ doc: SubtitleDocument) -> Data {
        var out: [String] = []
        switch doc.dialect {
        case .vtt:
            out.append(contentsOf: doc.header.isEmpty ? ["WEBVTT"] : doc.header)
            for (k, cue) in doc.cues.enumerated() {
                for block in doc.blocks where block.beforeCue == k { out.append(""); out.append(contentsOf: block.lines) }
                out.append("")
                out.append(contentsOf: cueLines(cue))
            }
            for block in doc.blocks where block.beforeCue >= doc.cues.count { out.append(""); out.append(contentsOf: block.lines) }
        case .srt:
            var styles = VTTStyleSheet()
            let cues = doc.cuesByStart.map { cue -> SubtitleCue in
                let converted = SubtitleMarkup.srtToVTT(cue.lines, styles: &styles)
                return SubtitleCue(start: cue.start, end: cue.end, lines: converted.lines, settings: converted.settings)
            }
            out.append("WEBVTT")
            if let style = styles.styleBlock { out.append(""); out.append(contentsOf: style) }
            for cue in cues { out.append(""); out.append(contentsOf: cueLines(cue)) }
        }
        return SubtitleSource.encode(out, ending: doc.lineEnding, bom: doc.hasBOM)
    }

    private static func cueLines(_ cue: SubtitleCue) -> [String] {
        var lines: [String] = []
        if let id = cue.identifier, !id.isEmpty { lines.append(id) }
        var timing = SubtitleTime.format(cue.start, separator: ".") + " --> " + SubtitleTime.format(cue.end, separator: ".")
        if let s = cue.settings, !s.isEmpty { timing += " " + s }
        lines.append(timing)
        lines.append(contentsOf: cue.lines)
        return lines
    }
}

/// Writes a plain-text transcript: one line per cue in start order, markup
/// stripped, entities decoded. Rolling captions (each cue repeating the
/// previous cue's last line, as auto-generated WebVTT does) are de-duplicated.
/// With `timestamps`, each line starts with `[HH:MM:SS]` (the cue's start).
public enum SubtitleTextWriter {
    public static func write(_ doc: SubtitleDocument, timestamps: Bool) -> Data {
        var out: [String] = []
        var previous: [String] = []
        for cue in doc.cuesByStart {
            let lines = SubtitleMarkup.plainText(cue.lines, dialect: doc.dialect)
            let fresh = Array(lines.dropFirst(overlap(previous, lines)))
            if !lines.isEmpty { previous = lines }
            guard !fresh.isEmpty else { continue }
            let text = fresh.joined(separator: " ")
            out.append(timestamps ? "[\(SubtitleTime.formatClock(cue.start))] \(text)" : text)
        }
        return SubtitleSource.encode(out, ending: doc.lineEnding, bom: doc.hasBOM)
    }

    /// Longest k such that the last k lines of `a` equal the first k lines of `b`.
    static func overlap(_ a: [String], _ b: [String]) -> Int {
        var k = min(a.count, b.count)
        while k > 0 {
            if Array(a.suffix(k)) == Array(b.prefix(k)) { return k }
            k -= 1
        }
        return 0
    }
}
