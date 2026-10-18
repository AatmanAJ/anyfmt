import Foundation
import HaloCore

// Exit codes, errors, flag parsing and the JSON writers shared by every
// command and by `halo mcp`. Everything here is part of the documented
// contract in docs/CLI.md: change it on purpose only.

/// Stable process exit codes. Agents branch on these.
enum ExitCode: Int32, CaseIterable {
    case ok = 0
    case usage = 2
    case unsupportedRoute = 3
    case inputMissing = 4
    case engineFailed = 5
    case partial = 6
    case cancelled = 7
    case cloudUnavailable = 8

    var name: String {
        switch self {
        case .ok: "ok"
        case .usage: "usage"
        case .unsupportedRoute: "unsupported_route"
        case .inputMissing: "input_missing"
        case .engineFailed: "engine_failed"
        case .partial: "partial"
        case .cancelled: "cancelled"
        case .cloudUnavailable: "cloud_unavailable"
        }
    }

    var meaning: String {
        switch self {
        case .ok: "Success: every file converted (or nothing needed converting)."
        case .usage: "Bad command line: unknown command, flag, format, option or value."
        case .unsupportedRoute: "No route from the input format to the target (or the tool doesn't apply)."
        case .inputMissing: "An input file is missing, unreadable or of an unknown kind."
        case .engineFailed: "An engine ran and failed; the original is untouched."
        case .partial: "Batch finished with some files failed (or an output name was taken with --overwrite never)."
        case .cancelled: "Cancelled (SIGINT / MCP cancellation)."
        case .cloudUnavailable: "The request needs the cloud (Pro), which the CLI never uses."
        }
    }
}

/// Per-file failure codes used in NDJSON `error` events and MCP results.
enum FailureCode: String, Sendable {
    case usage
    case unsupportedRoute = "unsupported_route"
    case inputMissing = "input_missing"
    case engineFailed = "engine_failed"
    case outputExists = "output_exists"
    case cancelled
    case cloudUnavailable = "cloud_unavailable"

    var exitCode: ExitCode {
        switch self {
        case .usage: .usage
        case .unsupportedRoute: .unsupportedRoute
        case .inputMissing: .inputMissing
        case .engineFailed: .engineFailed
        case .outputExists: .partial
        case .cancelled: .cancelled
        case .cloudUnavailable: .cloudUnavailable
        }
    }

    /// Classifies an error thrown by an engine, tool runner or the placer.
    static func classify(_ error: Error) -> FailureCode {
        if error is CancellationError { return .cancelled }
        guard let e = error as? ConversionError else { return .engineFailed }
        switch e {
        case .unsupported, .noRoute: return .unsupportedRoute
        case .unreadable: return .inputMissing
        case .cancelled: return .cancelled
        case .invalidOption: return .usage
        case .engineMissing, .engineFailed, .outputMissing, .other: return .engineFailed
        }
    }
}

/// A failure that ends the command before any work starts.
struct CLIError: Error {
    let message: String
    let code: ExitCode
    init(_ message: String, code: ExitCode) { self.message = message; self.code = code }

    static func usage(_ message: String) -> CLIError { CLIError(message, code: .usage) }
}

/// Minimal flag parser: `--flag value`, `--flag=value`, repeated flags,
/// boolean flags, positionals. Unknown flags are a usage error.
struct ParsedArgs {
    private(set) var positional: [String] = []
    private var flags: [String: [String]] = [:]

    /// - Parameters:
    ///   - valued: flags that take a value.
    ///   - switches: flags that don't (`--json` and `--dry-run` style).
    init(_ args: [String], valued: Set<String>, switches: Set<String> = []) throws {
        let switches = switches.union(["--json"])
        var i = 0
        var onlyPositional = false
        while i < args.count {
            let a = args[i]
            if onlyPositional || !a.hasPrefix("--") || a == "-" {
                positional.append(a)
            } else if a == "--" {
                onlyPositional = true
            } else if let eq = a.firstIndex(of: "="), valued.contains(String(a[..<eq])) {
                flags[String(a[..<eq]), default: []].append(String(a[a.index(after: eq)...]))
            } else if valued.contains(a) {
                guard i + 1 < args.count else { throw CLIError.usage("\(a) needs a value") }
                flags[a, default: []].append(args[i + 1])
                i += 1
            } else if switches.contains(a) {
                flags[a, default: []].append("")
            } else {
                throw CLIError.usage("unknown flag \(a)")
            }
            i += 1
        }
    }

    func value(_ flag: String) -> String? { flags[flag]?.last }
    func values(_ flag: String) -> [String] { flags[flag] ?? [] }
    func has(_ flag: String) -> Bool { flags[flag] != nil }
}

// MARK: - JSON

enum JSON {
    /// Pretty, sorted keys, unescaped slashes: the `--json` document format.
    static func pretty(_ object: Any) -> String {
        encode(object, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    /// One line, sorted keys: NDJSON events and MCP messages.
    static func line(_ object: Any) -> String {
        encode(object, options: [.sortedKeys, .withoutEscapingSlashes])
    }

    private static func encode(_ object: Any, options: JSONSerialization.WritingOptions) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let d = try? JSONSerialization.data(withJSONObject: object, options: options) else {
            return "{}"
        }
        return String(decoding: d, as: UTF8.self)
    }

    /// A double as a JSON number with at most `places` decimals (JSONSerialization
    /// would print 0.42 as 0.41999999999999998).
    static func number(_ d: Double, places: Int = 2) -> NSDecimalNumber {
        guard d.isFinite else { return 0 }
        return NSDecimalNumber(string: String(format: "%.\(places)f", d), locale: Locale(identifier: "en_US_POSIX"))
    }

    /// The typed JSON form of an option value.
    static func value(_ v: OptionValue) -> Any {
        switch v {
        case .bool(let b): b
        case .int(let i): i
        case .double(let d): number(d, places: 4)
        case .string(let s): s
        }
    }

    /// Option values as a JSON object.
    static func values(_ v: OptionValues) -> [String: Any] {
        v.values.mapValues(value)
    }

    /// True for a JSON boolean that JSONSerialization handed back as NSNumber.
    static func isBool(_ any: Any) -> Bool {
        guard let n = any as? NSNumber else { return false }
        return CFGetTypeID(n) == CFBooleanGetTypeID()
    }

    /// Text form of a decoded JSON scalar, for `OptionValue.parse`.
    static func text(_ any: Any) -> String? {
        if isBool(any) { return (any as! NSNumber).boolValue ? "true" : "false" }
        if let n = any as? NSNumber { return n.stringValue }
        if let s = any as? String { return s }
        return nil
    }
}

/// Serialised writes to stdout / stderr from any thread.
final class Output: @unchecked Sendable {
    static let shared = Output()
    private let lock = NSLock()

    func out(_ s: String) {
        lock.withLock { FileHandle.standardOutput.write(Data((s + "\n").utf8)) }
    }

    func err(_ s: String) {
        lock.withLock { FileHandle.standardError.write(Data((s + "\n").utf8)) }
    }
}

func out(_ s: String) { Output.shared.out(s) }
func err(_ s: String) { Output.shared.err(s) }

// MARK: - Paths and stores

enum CLIPaths {
    /// Resolves a user path (tilde, relative to the working directory).
    static func url(_ path: String, directory: Bool = false) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: directory).standardizedFileURL
    }

    /// Where presets.json and recents.json live: the app's Application Support
    /// folder, or `HALO_SUPPORT_DIR` (tests, sandboxes).
    static var supportDirectory: URL {
        if let d = ProcessInfo.processInfo.environment["HALO_SUPPORT_DIR"], !d.isEmpty {
            return URL(fileURLWithPath: d, isDirectory: true)
        }
        return RecentConversions.defaultDirectory
    }

    static var usesDefaultSupportDirectory: Bool {
        (ProcessInfo.processInfo.environment["HALO_SUPPORT_DIR"] ?? "").isEmpty
    }

    /// The same presets file the app reads.
    static let presets: PresetStore = usesDefaultSupportDirectory
        ? PresetStore.shared
        : PresetStore(fileURL: supportDirectory.appendingPathComponent("presets.json"))

    static var recents: RecentConversions {
        usesDefaultSupportDirectory ? RecentConversions.shared : RecentConversions(directory: supportDirectory)
    }

    /// The running binary, symlinks resolved.
    static var executable: URL {
        let raw = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments.first ?? "halo")
        return raw.resolvingSymlinksInPath()
    }

    /// The app bundle this CLI ships in (Contents/Helpers/halo), if any.
    static var appBundle: URL? {
        var dir = executable.deletingLastPathComponent()
        for _ in 0..<4 {
            if dir.pathExtension == "app" { return dir }
            dir.deleteLastPathComponent()
        }
        return nil
    }

    /// Test hook: `HALO_TEST_DELAY_MS` delays each conversion job (cancellably)
    /// so exit-code 7 and MCP cancellation can be tested deterministically.
    static var testDelay: UInt64? {
        guard let s = ProcessInfo.processInfo.environment["HALO_TEST_DELAY_MS"], let ms = UInt64(s), ms > 0 else { return nil }
        return ms * 1_000_000
    }
}

var cliVersion: String {
    Bundle.haloCore.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
}
