import AppKit
import Darwin
import HaloCore

/// Live example for the naming-pattern field.
enum NamingPreview {
    struct Token: Identifiable {
        let token: String
        let title: String
        var id: String { token }
    }

    static let tokens: [Token] = [
        Token(token: "{name}", title: String(localized: "Name", comment: "Naming token")),
        Token(token: "{format}", title: String(localized: "Format", comment: "Naming token")),
        Token(token: "{date}", title: String(localized: "Date", comment: "Naming token")),
    ]

    /// The first and the collision name the pattern produces, e.g.
    /// ("photo.jpg", "photo 2.jpg"). Uses the real `OutputNamer`.
    static func names(pattern: String, input: String = "photo.heic", target: FormatID = Formats.jpg,
                      date: Date = Date()) -> (first: String, second: String) {
        let url = URL(fileURLWithPath: "/preview").appendingPathComponent(input)
        let base = OutputNamer.baseName(for: url, pattern: pattern, targetLabel: Formats.label(target), date: date)
        let ext = Formats.extension(for: target)
        return ("\(base).\(ext)", "\(base) 2.\(ext)")
    }

    /// "photo.heic → photo.jpg, then photo 2.jpg"
    static func line(pattern: String, input: String = "photo.heic", target: FormatID = Formats.jpg, date: Date = Date()) -> String {
        let n = names(pattern: pattern, input: input, target: target, date: date)
        return String(localized: "\(input) → \(n.first), then \(n.second)", comment: "Naming preview: original → first name, then collision name")
    }

    /// A gentle warning for patterns that will surprise people.
    static func issue(pattern: String) -> String? {
        let p = pattern.trimmingCharacters(in: .whitespaces)
        if p.isEmpty { return nil } // empty means {name}
        let known = Set(tokens.map(\.token) + ["{ext}", "{tool}"])
        let used = matches(in: p)
        if let unknown = used.first(where: { !known.contains($0) }) {
            return String(localized: "\(unknown) isn’t a token. Use {name}, {format} or {date}.")
        }
        if !used.contains("{name}") {
            return String(localized: "Without {name}, every file gets the same name, then a number.")
        }
        return nil
    }

    private static func matches(in s: String) -> [String] {
        var out: [String] = []
        var rest = s[...]
        while let open = rest.firstIndex(of: "{"), let close = rest[open...].firstIndex(of: "}") {
            out.append(String(rest[open...close]))
            rest = rest[rest.index(after: close)...]
        }
        return out
    }
}

/// CPU concurrency facts for Settings › Advanced.
enum ConcurrencyInfo {
    /// Performance cores (`hw.perflevel0.physicalcpu`), else all active cores.
    static var performanceCores: Int {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.perflevel0.physicalcpu", &value, &size, nil, 0) == 0, value > 0 { return Int(value) }
        return ProcessInfo.processInfo.activeProcessorCount
    }

    /// What 0 ("Automatic") means: performance cores − 1, at least 1.
    static var automatic: Int { max(1, performanceCores - 1) }

    static var maximum: Int { max(automatic, ProcessInfo.processInfo.activeProcessorCount) }
}

/// "Copy Diagnostics": versions, macOS, engines and settings, without file
/// paths or anything else personal.
enum Diagnostics {
    @MainActor
    static func report(settings: AppSettings, info: AppInfo, engines: [EngineInfo], packs: [PackStatus]) -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        var lines = [
            "\(Brand.name) \(info.version) (\(info.build))",
            "macOS \(os) · \(machine) · \(ConcurrencyInfo.performanceCores) performance cores",
            "",
            "Engines:",
        ]
        lines += engines.map { "  \($0.name) \($0.version) — \($0.licence)" }
        if !packs.isEmpty {
            lines += ["", "Packs:"]
            lines += packs.map { "  \($0.name) \($0.installed ? $0.version : "not installed")" }
        }
        lines += ["", "Settings:", settingsJSON(settings)]
        return lines.joined(separator: "\n")
    }

    /// Settings as stable-keyed JSON. The output folder becomes "custom folder",
    /// and any string that looks like a path is redacted.
    @MainActor
    static func settingsJSON(_ s: AppSettings) -> String {
        var defaults: [String: Any] = [:]
        for (fmt, values) in s.formatDefaults {
            var v: [String: Any] = [:]
            for (k, value) in values.values { v[k] = json(value) }
            defaults[fmt.rawValue] = v
        }
        let dict: [String: Any] = [
            "general.sounds": s.soundsEnabled,
            "general.haptics": s.hapticsEnabled,
            "general.updateChecks": s.updateChecksEnabled,
            "general.onboardingCompleted": s.onboardingCompleted,
            "keys.convert": s.convertKey,
            "keys.tools": s.toolsKey,
            "keys.actions": s.actionsKey,
            "keys.tapThreshold": s.tapThreshold,
            "keys.finderShortcut": s.finderShortcutEnabled,
            "keys.dropRing": Hotkey(keyCode: s.dropRingKeyCode, rawModifiers: s.dropRingModifiers).displayString,
            "keys.dropRing.enabled": s.dropRingHotKeyEnabled,
            "output.location": s.outputFolderBookmark == nil ? "beside original" : "custom folder",
            "output.namePattern": redact(s.namePattern),
            "output.metadata": s.metadataPolicy.rawValue,
            "output.preserveDates": s.preserveDates,
            "output.reveal": s.revealInFinder,
            "formats.favourites": s.favouriteFormats.map(\.rawValue),
            "formats.hidden": s.hiddenFormats.map(\.rawValue).sorted(),
            "formats.shown": s.shownFormats.map(\.rawValue).sorted(),
            "tools.hidden": s.hiddenTools.map(\.rawValue).sorted(),
            "formats.defaults": defaults,
            "advanced.cpuConcurrency": s.cpuConcurrency,
            "advanced.verboseLogging": s.verboseLogging,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    private static func json(_ v: OptionValue) -> Any {
        switch v {
        case .bool(let b): b
        case .int(let i): i
        case .double(let d): d
        case .string(let s): redact(s)
        }
    }

    /// Paths (anything with a slash under a home or volume) become "<path>".
    static func redact(_ s: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if s.contains(home) || s.hasPrefix("/") || s.hasPrefix("~") || s.contains("/Users/") || s.contains("/Volumes/") {
            return "<path>"
        }
        return s
    }

    private static var machine: String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        guard size > 0 else { return "Mac" }
        var buf = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &buf, &size, nil, 0)
        let bytes = buf.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

/// Where logs go and how to read them.
enum LogsInfo {
    static func command(bundleID: String) -> String {
        "log show --last 1h --info --debug --predicate 'subsystem == \"\(bundleID)\"'"
    }

    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs", isDirectory: true)
            .appendingPathComponent(Brand.name, isDirectory: true)
    }

    /// Creates `~/Library/Logs/<Brand>` if needed and shows it in Finder.
    @MainActor
    static func revealFolder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([folder])
    }
}

extension NSPasteboard {
    @MainActor
    func copyString(_ s: String) {
        clearContents()
        setString(s, forType: .string)
    }
}
