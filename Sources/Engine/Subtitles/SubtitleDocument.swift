import Foundation

/// Which markup dialect a document's cue text is written in. Cue text is kept
/// exactly as it appeared in the source; writers translate between dialects
/// only when the target differs (see `SubtitleMarkup`).
public enum SubtitleDialect: String, Sendable, Hashable {
    /// SubRip: `<i> <b> <u> <font color>`, `{\an8}` ASS overrides, no escaping.
    case srt
    /// WebVTT: `<i> <b> <u> <c.class> <v> <lang> <ruby>`, `&amp;`-style escapes.
    case vtt
}

/// Line terminator style of a source file, preserved on write.
public enum SubtitleLineEnding: String, Sendable, Hashable {
    case lf = "\n"
    case crlf = "\r\n"
    case cr = "\r"
}

/// One timed cue. Times are integer milliseconds, so they round-trip exactly.
public struct SubtitleCue: Sendable, Hashable {
    /// SRT sequence number or VTT cue identifier, as written (nil when absent).
    public var identifier: String?
    public var start: Int
    public var end: Int
    /// Text lines in the document's dialect, styling tags preserved verbatim.
    public var lines: [String]
    /// Raw WebVTT cue settings (`line:0 align:start`), VTT dialect only.
    public var settings: String?

    public init(identifier: String? = nil, start: Int, end: Int, lines: [String], settings: String? = nil) {
        self.identifier = identifier
        self.start = start
        self.end = end
        self.lines = lines
        self.settings = settings
    }
}

/// A WebVTT NOTE, STYLE or REGION block, kept so VTT → VTT is lossless.
public struct SubtitleBlock: Sendable, Hashable {
    public enum Kind: String, Sendable, Hashable { case note, style, region }
    public var kind: Kind
    /// Every line of the block, including the `NOTE`/`STYLE`/`REGION` keyword line.
    public var lines: [String]
    /// Index of the cue this block precedes (`cues.count` = after the last cue).
    public var beforeCue: Int

    public init(kind: Kind, lines: [String], beforeCue: Int) {
        self.kind = kind
        self.lines = lines
        self.beforeCue = beforeCue
    }
}

/// Something the parser skipped or repaired. Parsing never fails outright.
public struct SubtitleWarning: Sendable, Hashable, CustomStringConvertible {
    /// 1-based line number in the source.
    public let line: Int
    public let message: String
    public init(line: Int, message: String) { self.line = line; self.message = message }
    public var description: String { "line \(line): \(message)" }
}

/// A parsed subtitle file.
public struct SubtitleDocument: Sendable, Hashable {
    public var dialect: SubtitleDialect
    public var cues: [SubtitleCue]
    /// VTT only: the `WEBVTT…` signature line plus any header lines after it.
    public var header: [String]
    /// VTT only: NOTE / STYLE / REGION blocks in source order.
    public var blocks: [SubtitleBlock]
    /// The source started with a byte-order mark; writers emit a UTF-8 BOM.
    public var hasBOM: Bool
    public var lineEnding: SubtitleLineEnding
    /// Whether the source's last line was terminated (informational).
    public var endsWithNewline: Bool
    public var warnings: [SubtitleWarning]

    public init(dialect: SubtitleDialect, cues: [SubtitleCue] = [], header: [String] = [],
                blocks: [SubtitleBlock] = [], hasBOM: Bool = false, lineEnding: SubtitleLineEnding = .lf,
                endsWithNewline: Bool = true, warnings: [SubtitleWarning] = []) {
        self.dialect = dialect
        self.cues = cues
        self.header = header
        self.blocks = blocks
        self.hasBOM = hasBOM
        self.lineEnding = lineEnding
        self.endsWithNewline = endsWithNewline
        self.warnings = warnings
    }

    /// Cues in presentation order (stable: equal start times keep source order,
    /// so overlapping cues are kept as they were, never merged).
    public var cuesByStart: [SubtitleCue] {
        cues.enumerated().sorted { a, b in
            (a.element.start, a.offset) < (b.element.start, b.offset)
        }.map(\.element)
    }
}

// MARK: - Shared text plumbing

/// Decoding and line splitting shared by both parsers.
enum SubtitleSource {
    struct Decoded {
        let text: String
        let hasBOM: Bool
    }

    /// Decodes subtitle bytes: UTF-8/UTF-16 BOMs, then strict UTF-8, then
    /// Windows-1252 (the usual encoding of legacy SRT files), then Latin-1.
    static func decode(_ data: Data) -> Decoded {
        let bytes = [UInt8](data.prefix(3))
        if bytes.count >= 3, bytes[0] == 0xEF, bytes[1] == 0xBB, bytes[2] == 0xBF {
            return Decoded(text: String(decoding: data.dropFirst(3), as: UTF8.self), hasBOM: true)
        }
        if bytes.count >= 2, bytes[0] == 0xFF, bytes[1] == 0xFE,
           let s = String(data: data.dropFirst(2), encoding: .utf16LittleEndian) {
            return Decoded(text: s, hasBOM: true)
        }
        if bytes.count >= 2, bytes[0] == 0xFE, bytes[1] == 0xFF,
           let s = String(data: data.dropFirst(2), encoding: .utf16BigEndian) {
            return Decoded(text: s, hasBOM: true)
        }
        if let s = String(data: data, encoding: .utf8) { return Decoded(text: s, hasBOM: false) }
        if let s = String(data: data, encoding: .windowsCP1252) { return Decoded(text: s, hasBOM: false) }
        return Decoded(text: String(data: data, encoding: .isoLatin1) ?? "", hasBOM: false)
    }

    /// The most common terminator in `text` (LF when there are none).
    static func dominantLineEnding(_ text: String) -> SubtitleLineEnding {
        var lf = 0, crlf = 0, cr = 0
        for ch in text {
            switch ch {
            case "\r\n": crlf += 1
            case "\n": lf += 1
            case "\r": cr += 1
            default: break
            }
        }
        if crlf > lf && crlf >= cr { return .crlf }
        if cr > lf && cr > crlf { return .cr }
        return .lf
    }

    /// Splits on LF, CRLF and lone CR. Swift treats "\r\n" as one Character.
    static func lines(_ text: String) -> (lines: [String], endsWithNewline: Bool) {
        let isBreak: (Character) -> Bool = { $0 == "\n" || $0 == "\r" || $0 == "\r\n" }
        var parts = text.split(omittingEmptySubsequences: false, whereSeparator: isBreak).map(String.init)
        let terminated = text.last.map(isBreak) ?? false
        if terminated, parts.last == "" { parts.removeLast() }
        return (parts, terminated)
    }

    static func isBlank(_ line: String) -> Bool {
        line.allSatisfy { $0 == " " || $0 == "\t" || $0 == "\u{FEFF}" }
    }

    /// Joins lines with `ending`, with a terminator after the last line.
    static func encode(_ lines: [String], ending: SubtitleLineEnding, bom: Bool) -> Data {
        var text = lines.joined(separator: ending.rawValue)
        if !lines.isEmpty { text += ending.rawValue }
        var data = bom ? Data([0xEF, 0xBB, 0xBF]) : Data()
        data.append(Data(text.utf8))
        return data
    }
}
