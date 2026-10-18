import Foundation
import HaloCore

/// Turns a failed job's raw details into the "Copy details" report: the
/// versions (app, macOS, engines), the job and its route, the engine's exit
/// line and the tail of its stderr, with the home folder written as `~` so
/// nothing personal leaves the Mac by accident.
enum ProgressDiagnostics {
    /// Most engine stderr is a long banner; the end is what explains the failure.
    static let stderrTailLines = 40

    static func report(_ details: String, home: String = NSHomeDirectory(),
                       engines: [EngineInfo] = BundledEngines.all) -> String {
        var lines = trimmed(details).components(separatedBy: "\n")
        if !lines.contains(where: { $0.hasPrefix("Engines:") }), let row = enginesLine(engines) {
            // Right after the app/macOS line, so every version is together at the top.
            lines.insert(row, at: min(1, lines.count))
        }
        return redact(lines.joined(separator: "\n"), home: home)
    }

    /// "Engines: FFmpeg 9.0.2 · resvg 0.48.1" (the binaries we ship, not the libraries inside them).
    static func enginesLine(_ engines: [EngineInfo]) -> String? {
        let shipped = engines.filter { $0.location.contains("Contents/Helpers") }
        guard !shipped.isEmpty else { return nil }
        return "Engines: " + shipped.map { "\($0.shortName) \($0.version)" }.joined(separator: " · ")
    }

    /// Keeps the last `stderrTailLines` lines of each failure block (the engine's
    /// stderr follows its "exited N" line), noting how much was dropped.
    static func trimmed(_ details: String) -> String {
        let blocks = details.components(separatedBy: "\n\n")
        return blocks.map { block -> String in
            let lines = block.components(separatedBy: "\n")
            guard let exit = lines.firstIndex(where: { $0.contains(" exited ") }) else { return block }
            let head = Array(lines[...exit])
            let stderr = Array(lines[(exit + 1)...])
            guard stderr.count > stderrTailLines else { return block }
            let dropped = stderr.count - stderrTailLines
            return (head + ["[… \(dropped) earlier stderr lines]"] + stderr.suffix(stderrTailLines)).joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    /// The home folder → `~`, in plain paths and in file URLs (also percent-encoded).
    static func redact(_ text: String, home: String) -> String {
        let h = home.hasSuffix("/") ? String(home.dropLast()) : home
        guard h.count > 1 else { return text }
        var out = text
        let encoded = h.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? h
        for form in Set([encoded, h]) {
            // Whole path components only: /Users/sam must not eat /Users/samantha.
            let pattern = NSRegularExpression.escapedPattern(for: form) + #"(?=/|$|[^A-Za-z0-9._%-])"#
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { continue }
            out = re.stringByReplacingMatches(in: out, range: NSRange(out.startIndex..., in: out), withTemplate: "~")
        }
        return out
    }
}
