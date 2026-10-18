import Foundation

/// Translates cue text between SubRip and WebVTT markup, and to plain text.
///
/// What is kept where it's legal, and how:
///
/// | SRT                    | WebVTT                                         |
/// |------------------------|------------------------------------------------|
/// | `<i> <b> <u>`          | `<i> <b> <u>` (classes dropped going to SRT)   |
/// | `<font color="red">`   | `<c.red>` (the eight WebVTT default colours)   |
/// | `<font color="#f80">`  | `<c.c_ff8800>` plus a generated STYLE rule      |
/// | `{\an8}` etc.          | cue settings `line:0` (+ `align:start/end`)    |
/// | `{\i1}…{\i0}`          | `<i>…</i>` (same for `\b`, `\u`)               |
/// | `& < >` (raw)          | `&amp; &lt; &gt;`                              |
/// | (dropped)              | `<v>`, `<lang>`, `<ruby>`, `<rt>…</rt>`, timestamps |
///
/// Unknown SRT tags such as `<3` stay literal text. Plain text drops every tag.
enum SubtitleMarkup {
    // MARK: - SRT → WebVTT

    struct VTTCue: Equatable {
        var lines: [String]
        var settings: String?
    }

    static func srtToVTT(_ lines: [String], styles: inout VTTStyleSheet) -> VTTCue {
        var out = ""
        var numpad: Int?
        var fontStack: [Bool] = []
        for token in SRTTokenizer.tokens(lines.joined(separator: "\n")) {
            switch token {
            case .text(let t):
                out += escapeVTT(t)
            case .tag(let name, let closing, let attributes):
                switch name {
                case "i", "b", "u":
                    out += closing ? "</\(name)>" : "<\(name)>"
                case "font":
                    if closing {
                        if fontStack.popLast() == true { out += "</c>" }
                    } else if let color = attributes["color"], let cls = styles.className(forColor: color) {
                        out += "<c.\(cls)>"
                        fontStack.append(true)
                    } else {
                        fontStack.append(false)
                    }
                default:
                    break // <s> and friends have no WebVTT equivalent; the text stays.
                }
            case .override(let tags):
                for tag in tags {
                    if let a = alignment(fromOverride: tag) {
                        if numpad == nil { numpad = a }
                    } else if let html = inlineStyle(fromOverride: tag) {
                        out += html
                    }
                }
            }
        }
        let converted = out.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            .filter { !SubtitleSource.isBlank($0) }
        return VTTCue(lines: converted, settings: numpad.flatMap(vttSettings(forAlignment:)))
    }

    /// WebVTT cue settings for an ASS `\anN` numpad alignment (2 = default, no settings).
    static func vttSettings(forAlignment an: Int) -> String? {
        let line: String
        switch an {
        case 1, 2, 3: line = "line:-1"
        case 4, 5, 6: line = "line:50%"
        case 7, 8, 9: line = "line:0"
        default: return nil
        }
        if an == 2 { return nil }
        switch an % 3 {
        case 1: return line + " align:start"
        case 0: return line + " align:end"
        default: return line
        }
    }

    private static func escapeVTT(_ s: String) -> String {
        var r = ""
        r.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": r += "&amp;"
            case "<": r += "&lt;"
            case ">": r += "&gt;"
            default: r.append(ch)
            }
        }
        return r
    }

    /// `an8` → 8; legacy SSA `a6` → 8 (SSA: 1–3 bottom, 5–7 top, 9–11 middle).
    private static func alignment(fromOverride tag: String) -> Int? {
        if tag.hasPrefix("an"), let n = Int(tag.dropFirst(2)), (1...9).contains(n) { return n }
        if tag.hasPrefix("a"), !tag.hasPrefix("an"), let n = Int(tag.dropFirst(1)) {
            switch n {
            case 1, 2, 3: return n
            case 5, 6, 7: return n + 2
            case 9, 10, 11: return n - 5
            default: return nil
            }
        }
        return nil
    }

    /// `i1` → `<i>`, `i0` → `</i>`, likewise `b` (any weight > 0 is bold) and `u`.
    private static func inlineStyle(fromOverride tag: String) -> String? {
        guard let first = tag.first, "ibu".contains(first) else { return nil }
        let rest = tag.dropFirst()
        guard !rest.isEmpty, rest.allSatisfy(SubtitleTime.isDigit), let n = Int(rest) else { return nil }
        return n == 0 ? "</\(first)>" : "<\(first)>"
    }

    // MARK: - WebVTT → SRT

    /// - Parameter classColors: `::cue(.class) { color: … }` rules from the document's STYLE blocks.
    static func vttToSRT(_ lines: [String], settings: String?, classColors: [String: String]) -> [String] {
        var out = ""
        var cStack: [Bool] = []
        var rubyTextDepth = 0
        for token in VTTTokenizer.tokens(lines.joined(separator: "\n")) {
            switch token {
            case .text(let t):
                if rubyTextDepth == 0 { out += t }
            case .tag(let name, let closing, let classes):
                switch name {
                case "i", "b", "u":
                    if rubyTextDepth == 0 { out += closing ? "</\(name)>" : "<\(name)>" }
                case "c":
                    if closing {
                        if cStack.popLast() == true { out += "</font>" }
                    } else if let color = classes.lazy.compactMap({ color(forClass: $0, classColors: classColors) }).first {
                        out += "<font color=\"\(color)\">"
                        cStack.append(true)
                    } else {
                        cStack.append(false)
                    }
                case "rt":
                    rubyTextDepth = max(0, rubyTextDepth + (closing ? -1 : 1))
                default:
                    break // v, lang, ruby, timestamps: no SRT equivalent.
                }
            }
        }
        var result = out.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            .filter { !SubtitleSource.isBlank($0) }
        if let an = srtAlignment(fromSettings: settings), an != 2 {
            if result.isEmpty { result = ["{\\an\(an)}"] } else { result[0] = "{\\an\(an)}" + result[0] }
        }
        return result
    }

    private static func color(forClass cls: String, classColors: [String: String]) -> String? {
        if VTTStyleSheet.defaultColors.contains(cls) { return cls }
        return classColors[cls]
    }

    /// Numpad alignment implied by explicit `line` (+ `align`) settings; nil when
    /// the cue has no `line` setting (its default bottom placement needs no tag).
    static func srtAlignment(fromSettings settings: String?) -> Int? {
        guard let settings else { return nil }
        var line: String?, align: String?
        for pair in settings.split(whereSeparator: { $0 == " " || $0 == "\t" }) {
            guard let colon = pair.firstIndex(of: ":") else { continue }
            let key = pair[..<colon], value = String(pair[pair.index(after: colon)...])
            if key == "line" { line = value } else if key == "align" { align = value }
        }
        guard let lineValue = line?.split(separator: ",").first.map(String.init) else { return nil }
        let row: Int // 0 bottom, 1 middle, 2 top
        if lineValue.hasSuffix("%"), let p = Double(lineValue.dropLast()) {
            row = p < 100.0 / 3 ? 2 : (p <= 200.0 / 3 ? 1 : 0)
        } else if let n = Int(lineValue) {
            row = n >= 0 ? 2 : 0
        } else {
            return nil
        }
        let column: Int
        switch align {
        case "start", "left": column = 1
        case "end", "right": column = 3
        default: column = 2
        }
        return row * 3 + column
    }

    /// `::cue(.name) { color: X }` → [name: X], from STYLE blocks.
    static func classColors(from blocks: [SubtitleBlock]) -> [String: String] {
        var map: [String: String] = [:]
        let css = blocks.filter { $0.kind == .style }.flatMap { $0.lines.dropFirst() }.joined(separator: "\n")
        guard !css.isEmpty, let regex = try? NSRegularExpression(
            pattern: #"::cue\(\s*\.([A-Za-z0-9_-]+)\s*\)\s*\{[^}]*?(?<![-\w])color\s*:\s*([^;}\s]+)"#) else { return map }
        let ns = css as NSString
        for m in regex.matches(in: css, range: NSRange(location: 0, length: ns.length)) where m.numberOfRanges == 3 {
            let cls = ns.substring(with: m.range(at: 1)), color = ns.substring(with: m.range(at: 2))
            if map[cls] == nil { map[cls] = color }
        }
        return map
    }

    // MARK: - Plain text

    /// Cue text with all markup removed and entities decoded, one string per
    /// non-empty line, whitespace trimmed.
    static func plainText(_ lines: [String], dialect: SubtitleDialect) -> [String] {
        var out = ""
        let joined = lines.joined(separator: "\n")
        switch dialect {
        case .srt:
            for token in SRTTokenizer.tokens(joined) {
                if case .text(let t) = token { out += t }
            }
        case .vtt:
            var rubyTextDepth = 0
            for token in VTTTokenizer.tokens(joined) {
                switch token {
                case .text(let t): if rubyTextDepth == 0 { out += t }
                case .tag("rt", let closing, _): rubyTextDepth = max(0, rubyTextDepth + (closing ? -1 : 1))
                case .tag: break
                }
            }
        }
        return out.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}

// MARK: - Colour classes

/// Colour classes needed when SRT `<font color>` becomes WebVTT `<c.class>`.
struct VTTStyleSheet {
    /// Classes every WebVTT renderer styles without a STYLE block.
    static let defaultColors: Set<String> = ["white", "lime", "cyan", "red", "yellow", "magenta", "blue", "black"]

    private(set) var rules: [(cls: String, css: String)] = []

    /// Class for an SRT colour (`red`, `#ff8800`, `f80`, `orange`), or nil if it isn't a colour.
    mutating func className(forColor raw: String) -> String? {
        let c = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if Self.defaultColors.contains(c) { return c }
        var hex = c.hasPrefix("#") ? String(c.dropFirst()) : c
        let isHex = !hex.isEmpty && hex.allSatisfy(\.isHexDigit)
        let cls: String, css: String
        if isHex && (hex.count == 3 || hex.count == 6) {
            if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
            cls = "c_" + hex
            css = "#" + hex
        } else if (2...24).contains(c.count), c.allSatisfy({ $0.isASCII && $0.isLetter }) {
            cls = "c_" + c
            css = c
        } else {
            return nil
        }
        if !rules.contains(where: { $0.cls == cls }) { rules.append((cls, css)) }
        return cls
    }

    /// A STYLE block for the non-default colours, or nil when none were used.
    var styleBlock: [String]? {
        rules.isEmpty ? nil : ["STYLE"] + rules.map { "::cue(.\($0.cls)) { color: \($0.css); }" }
    }
}

// MARK: - Tokenizers

/// SubRip markup: a handful of HTML-ish tags and `{\…}` ASS override blocks.
/// Anything that isn't one of those is literal text.
enum SRTTokenizer {
    enum Token: Equatable {
        case text(String)
        case tag(name: String, closing: Bool, attributes: [String: String])
        case override([String])
    }

    private static let knownTags: Set<String> = ["i", "b", "u", "s", "font"]

    static func tokens(_ s: String) -> [Token] {
        var tokens: [Token] = []
        var text = ""
        var i = s.startIndex
        func flush() { if !text.isEmpty { tokens.append(.text(text)); text = "" } }
        while i < s.endIndex {
            let ch = s[i]
            if ch == "<", let close = s[i...].firstIndex(of: ">"), let tag = parseTag(s[s.index(after: i)..<close]) {
                flush()
                tokens.append(tag)
                i = s.index(after: close)
                continue
            }
            if ch == "{", s.index(after: i) < s.endIndex, s[s.index(after: i)] == "\\",
               let close = s[i...].firstIndex(of: "}") {
                flush()
                let body = s[s.index(i, offsetBy: 2)..<close]
                let tags = body.split(separator: "\\").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                tokens.append(.override(tags))
                i = s.index(after: close)
                continue
            }
            text.append(ch)
            i = s.index(after: i)
        }
        flush()
        return tokens
    }

    /// The tag name must follow `<` or `</` directly, so `a < b > c` stays text.
    private static func parseTag(_ body: Substring) -> Token? {
        var b = body
        let closing = b.hasPrefix("/")
        if closing { b = b.dropFirst() }
        let name = b.prefix { $0.isLetter }.lowercased()
        guard knownTags.contains(name) else { return nil }
        let rest = b.dropFirst(name.count)
        guard rest.isEmpty || rest.first == " " || rest.first == "\t" || rest.first == "/" else { return nil }
        return .tag(name: name, closing: closing, attributes: closing ? [:] : attributes(rest))
    }

    /// `color="red" face='Arial' size=12` → lowercase keys.
    private static func attributes(_ s: Substring) -> [String: String] {
        var result: [String: String] = [:]
        var i = s.startIndex
        while i < s.endIndex {
            while i < s.endIndex, s[i] == " " || s[i] == "\t" || s[i] == "/" { i = s.index(after: i) }
            let keyStart = i
            while i < s.endIndex, s[i] != "=", s[i] != " ", s[i] != "\t" { i = s.index(after: i) }
            let key = s[keyStart..<i].lowercased()
            guard i < s.endIndex, s[i] == "=" else { continue }
            i = s.index(after: i)
            var value = ""
            if i < s.endIndex, s[i] == "\"" || s[i] == "'" {
                let quote = s[i]
                i = s.index(after: i)
                while i < s.endIndex, s[i] != quote { value.append(s[i]); i = s.index(after: i) }
                if i < s.endIndex { i = s.index(after: i) }
            } else {
                while i < s.endIndex, s[i] != " ", s[i] != "\t" { value.append(s[i]); i = s.index(after: i) }
            }
            if !key.isEmpty { result[key] = value }
        }
        return result
    }
}

/// WebVTT cue text: tags (`<c.a.b>`, `</i>`, `<v Name>`, `<00:01.000>`) and
/// character references (`&amp;`, `&#x2014;`). Text tokens are unescaped.
enum VTTTokenizer {
    enum Token: Equatable {
        case text(String)
        case tag(name: String, closing: Bool, classes: [String])
    }

    static func tokens(_ s: String) -> [Token] {
        var tokens: [Token] = []
        var text = ""
        var i = s.startIndex
        func flush() { if !text.isEmpty { tokens.append(.text(text)); text = "" } }
        while i < s.endIndex {
            let ch = s[i]
            if ch == "<" {
                let close = s[i...].firstIndex(of: ">") ?? s.endIndex
                flush()
                tokens.append(parseTag(s[s.index(after: i)..<close]))
                i = close < s.endIndex ? s.index(after: close) : close
                continue
            }
            if ch == "&", let (decoded, next) = entity(in: s, at: i) {
                text += decoded
                i = next
                continue
            }
            text.append(ch)
            i = s.index(after: i)
        }
        flush()
        return tokens
    }

    private static func parseTag(_ body: Substring) -> Token {
        var b = body
        let closing = b.hasPrefix("/")
        if closing { b = b.dropFirst() }
        if b.first.map(SubtitleTime.isDigit) == true { return .tag(name: "timestamp", closing: false, classes: []) }
        let head = b.prefix { $0 != " " && $0 != "\t" && $0 != "\n" }
        let parts = head.split(separator: ".", omittingEmptySubsequences: true).map(String.init)
        let name = head.hasPrefix(".") ? "" : (parts.first ?? "").lowercased()
        let classes = head.hasPrefix(".") ? parts : Array(parts.dropFirst())
        return .tag(name: name, closing: closing, classes: classes)
    }

    private static let named: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "nbsp": "\u{00A0}", "lrm": "\u{200E}", "rlm": "\u{200F}",
        "quot": "\"", "apos": "'",
    ]

    private static func entity(in s: String, at i: String.Index) -> (String, String.Index)? {
        let start = s.index(after: i)
        guard let semi = s[start...].prefix(12).firstIndex(of: ";") else { return nil }
        let body = s[start..<semi]
        let next = s.index(after: semi)
        if let v = named[String(body)] { return (v, next) }
        if body.hasPrefix("#") {
            let num = body.dropFirst()
            let value = num.first == "x" || num.first == "X" ? UInt32(num.dropFirst(), radix: 16) : UInt32(num)
            if let value, let scalar = Unicode.Scalar(value) { return (String(Character(scalar)), next) }
        }
        return nil
    }
}
