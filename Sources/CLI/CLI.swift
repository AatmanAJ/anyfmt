import AppKit
import HaloCore

/// `halo` — the command-line face of the same capability table, router,
/// engines and tools the wheel uses.
@MainActor
enum CLI {
    static let usage = """
    usage: \(Brand.cliName) <command> [options]

    commands:
      convert <file>... --to <format> [--opt key=value]... [--out <dir>] [--metadata keep|private|strip]
      tool <tool-id> <file>... [--opt key=value]... [--out <dir>]
      formats [--from <format>] [--json]     list conversions (from the live capability table)
      tools [--json]                         list tools and their options
      route <from> <to>                      show the planned route
      version

    Outputs are written beside each original (or into --out) and never overwrite
    anything: name.png, then name 2.png, name 3.png …
    """

    static func run(_ args: [String]) async -> Int32 {
        var a = args
        guard let command = a.first else { err(usage); return 64 }
        a.removeFirst()
        do {
            switch command {
            case "convert": return try await convert(a)
            case "tool": return try await tool(a)
            case "formats": return formats(a)
            case "tools": return tools(a)
            case "route": return route(a)
            case "version", "--version", "-v":
                out("\(Brand.cliName) \(Bundle.haloCore.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev") (\(Brand.licence))")
                return 0
            case "help", "--help", "-h":
                out(usage); return 0
            default:
                err("unknown command “\(command)”\n\n\(usage)"); return 64
            }
        } catch let e as CLIError {
            err("error: \(e.message)"); return e.code
        } catch let e as ConversionError {
            err("error: \(e.localizedDescription)\n\(e.technicalDetails)"); return 1
        } catch {
            err("error: \(error.localizedDescription)"); return 1
        }
    }

    // MARK: convert

    static func convert(_ args: [String]) async throws -> Int32 {
        let p = try ParsedArgs(args, valued: ["--to", "--out", "--opt", "--metadata"])
        guard let toRaw = p.value("--to") else { throw CLIError("missing --to <format>", code: 64) }
        let to = FormatID(toRaw)
        guard Formats.format(to) != nil else { throw CLIError("unknown format “\(toRaw)”. Try `\(Brand.cliName) formats`.", code: 64) }
        let files = try p.positional.map(existingFile)
        guard !files.isEmpty else { throw CLIError("no input files", code: 64) }
        let options = try parseOptions(p.values("--opt"))
        let policy = try makePolicy(p)
        let router = Router.live()
        let executor = RouteExecutor()

        // Group: combine rows (folder/multi → archive) take all inputs at once.
        var formatsByFile: [(URL, FormatID)] = []
        for f in files {
            guard let fmt = Formats.detect(f) else { throw CLIError("can’t tell what kind of file “\(f.lastPathComponent)” is", code: 65) }
            formatsByFile.append((f, fmt))
        }
        var failures = 0
        let firstRoute = formatsByFile.first.flatMap { router.route(from: $0.1, to: to) }
        if let r = firstRoute, r.isDirect, r.hops[0].arity == .combine, files.count > 1 {
            let ok = await runOne(inputs: files, from: formatsByFile[0].1, to: to, route: r, options: options, policy: policy, executor: executor)
            return ok ? 0 : 1
        }
        for (file, fmt) in formatsByFile {
            if fmt == to { err("skip \(file.lastPathComponent): already \(Formats.label(to))"); continue }
            guard let route = router.route(from: fmt, to: to) else {
                err("skip \(file.lastPathComponent): \(Formats.label(fmt)) → \(Formats.label(to)) isn’t supported")
                failures += 1
                continue
            }
            if !(await runOne(inputs: [file], from: fmt, to: to, route: route, options: options, policy: policy, executor: executor)) {
                failures += 1
            }
        }
        return failures == 0 ? 0 : 1
    }

    private static func runOne(inputs: [URL], from: FormatID, to: FormatID, route: Route, options: OptionValues,
                               policy: OutputPolicy, executor: RouteExecutor) async -> Bool {
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("\(Brand.name)-cli/\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: work) }
        let name = inputs.count == 1 ? inputs[0].lastPathComponent : "\(inputs.count) items"
        let progress = ProgressLine(label: "\(name) → \(Formats.label(to))")
        do {
            let files = try await executor.execute(
                route, inputs: inputs, options: options,
                baseName: OutputNamer.stem(of: inputs[0]), metadata: policy.metadata,
                workDirectory: work, context: EngineContext(progress: progress.sink))
            let placed = try OutputPlacer(policy: policy).place(files, for: inputs[0], target: to)
            progress.finish()
            placed.forEach { out($0.path) }
            return true
        } catch {
            progress.finish()
            let detail = (error as? ConversionError)?.technicalDetails ?? "\(error)"
            err("✗ \(name): \(error.localizedDescription)\n  \(detail.replacingOccurrences(of: "\n", with: "\n  "))")
            return false
        }
    }

    // MARK: tool

    static func tool(_ args: [String]) async throws -> Int32 {
        let p = try ParsedArgs(args, valued: ["--out", "--opt", "--metadata"])
        guard let idRaw = p.positional.first else { throw CLIError("missing tool id. Try `\(Brand.cliName) tools`.", code: 64) }
        let id = ToolID(rawValue: idRaw)
        guard let spec = ToolCatalog.spec(id) else { throw CLIError("unknown tool “\(idRaw)”", code: 64) }
        guard spec.cloudFeature == nil else { throw CLIError("“\(spec.title)” runs in the cloud; use the app", code: 69) }
        guard let runner = ToolRegistry.default[id] else { throw CLIError("“\(spec.title)” isn’t available in this build", code: 69) }
        let files = try p.positional.dropFirst().map(existingFile)
        guard !files.isEmpty else { throw CLIError("no input files", code: 64) }
        let formats = files.map { Formats.detect($0) ?? "" }
        guard spec.applies(to: formats) else { throw CLIError("“\(spec.title)” doesn’t apply to these files", code: 65) }
        let options = spec.defaultOptions.merging(try parseOptions(p.values("--opt")))
        let policy = try makePolicy(p)
        let groups: [[URL]] = { if case .combine = spec.arity { return [files] } else { return files.map { [$0] } } }()
        var failures = 0
        for group in groups {
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("\(Brand.name)-cli/\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: work) }
            let label = group.count == 1 ? group[0].lastPathComponent : "\(group.count) files"
            let progress = ProgressLine(label: "\(spec.title): \(label)")
            do {
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                let base = OutputNamer.stem(of: group[0])
                let request = ToolRequest(tool: id, inputs: group, options: options, outputDirectory: work,
                                          baseName: base, metadata: policy.metadata)
                let output = try await runner.run(request, context: EngineContext(progress: progress.sink))
                let placed = try OutputPlacer(policy: policy).place(output.files, for: group[0], target: nil, toolSuffix: spec.outputSuffix)
                progress.finish()
                placed.forEach { out($0.path) }
            } catch {
                progress.finish()
                err("✗ \(label): \(error.localizedDescription)")
                failures += 1
            }
        }
        return failures == 0 ? 0 : 1
    }

    // MARK: listing

    static func formats(_ args: [String]) -> Int32 {
        let json = args.contains("--json")
        let from = (args.firstIndex(of: "--from").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }).map { FormatID($0) }
        let router = Router.live()
        if args.contains("--markdown") {
            out(markdownTable(router))
            return 0
        }
        var rows: [[String: Any]] = []
        for f in Formats.all where from == nil || f.id == from {
            let routes = router.allRoutes(from: f.id)
            guard !routes.isEmpty else { continue }
            let targets = routes.keys.sorted()
            if json {
                rows.append(["from": f.id.rawValue, "kind": f.kind.rawValue,
                             "to": targets.map { ["format": $0.rawValue, "hops": routes[$0]?.hops.count ?? 0] }])
            } else {
                out("\(f.label.padding(toLength: 10, withPad: " ", startingAt: 0)) → \(targets.map { Formats.label($0) }.joined(separator: " "))")
            }
        }
        let count = router.optionCount()
        if json {
            let obj: [String: Any] = ["options": count, "formats": rows]
            if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
                out(String(decoding: d, as: UTF8.self))
            }
        } else {
            out("\n\(count) conversion options")
        }
        return 0
    }

    /// README table, generated from the live capability registry (`make readme-formats`).
    static func markdownTable(_ router: Router) -> String {
        var md = "| Category | From | To |\n|---|---|---|\n"
        for kind in FileKind.allCases {
            let inputs = Formats.all.filter { $0.kind == kind && !router.allRoutes(from: $0.id).isEmpty }
            guard !inputs.isEmpty else { continue }
            var byTargets: [String: [String]] = [:]
            var order: [String] = []
            for f in inputs {
                let targets = router.allRoutes(from: f.id).keys
                    .sorted { (Formats.format($0)?.kind.rawValue ?? "", Formats.format($0)?.order ?? 0) < (Formats.format($1)?.kind.rawValue ?? "", Formats.format($1)?.order ?? 0) }
                    .map { Formats.label($0) }.joined(separator: ", ")
                if byTargets[targets] == nil { order.append(targets) }
                byTargets[targets, default: []].append(f.label)
            }
            for t in order {
                md += "| \(kind.rawValue.capitalized) | \(byTargets[t, default: []].joined(separator: ", ")) | \(t) |\n"
            }
        }
        md += "\n**\(router.optionCount()) conversion options** (each input × output pair, direct or routed through up to 3 steps).\n"
        return md
    }

    static func tools(_ args: [String]) -> Int32 {
        let available = ToolRegistry.default.ids
        for t in ToolCatalog.all {
            let state = t.cloudFeature != nil ? "cloud (Pro)" : (available.contains(t.id) ? "" : "not in this build")
            out("\(t.id.rawValue.padding(toLength: 24, withPad: " ", startingAt: 0)) \(t.title) \(state.isEmpty ? "" : "[\(state)]")")
            for s in t.schema.specs { out("    --opt \(s.id)=\(s.defaultValue)   \(s.label)") }
        }
        return 0
    }

    static func route(_ args: [String]) -> Int32 {
        guard args.count >= 2 else { err("usage: \(Brand.cliName) route <from> <to>"); return 64 }
        guard let r = Router.live().route(from: FormatID(args[0]), to: FormatID(args[1])) else {
            err("no route"); return 1
        }
        out("\(r)  (cost \(String(format: "%.1f", r.cost)))")
        return 0
    }

    // MARK: helpers

    static func existingFile(_ path: String) throws -> URL {
        let u = URL(fileURLWithPath: (path as NSString).expandingTildeInPath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: u.path) else { throw CLIError("no such file: \(path)", code: 66) }
        return u
    }

    static func parseOptions(_ pairs: [String]) throws -> OptionValues {
        var v = OptionValues()
        for pair in pairs {
            guard let eq = pair.firstIndex(of: "=") else { throw CLIError("--opt expects key=value, got “\(pair)”", code: 64) }
            let key = String(pair[..<eq]), raw = String(pair[pair.index(after: eq)...])
            if let b = ["true": true, "false": false, "yes": true, "no": false][raw.lowercased()] { v[key] = .bool(b) }
            else if let i = Int(raw) { v[key] = .int(i) }
            else if let d = Double(raw) { v[key] = .double(d) }
            else { v[key] = .string(raw) }
        }
        return v
    }

    static func makePolicy(_ p: ParsedArgs) throws -> OutputPolicy {
        var policy = OutputPolicy.default
        if let outDir = p.value("--out") {
            let u = URL(fileURLWithPath: (outDir as NSString).expandingTildeInPath, isDirectory: true)
            try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
            policy.location = .folder(u)
        }
        switch p.value("--metadata") {
        case nil, "keep": policy.metadata = .keep
        case "private": policy.metadata = .stripPrivate
        case "strip": policy.metadata = .stripAll
        case let other?: throw CLIError("--metadata must be keep, private or strip (got \(other))", code: 64)
        }
        policy.revealInFinder = false
        return policy
    }

    static func out(_ s: String) { FileHandle.standardOutput.write(Data((s + "\n").utf8)) }
    static func err(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }
}

struct CLIError: Error {
    let message: String
    let code: Int32
    init(_ message: String, code: Int32) { self.message = message; self.code = code }
}

/// Minimal flag parser: `--flag value`, repeated flags, positionals.
struct ParsedArgs {
    private(set) var positional: [String] = []
    private var flags: [String: [String]] = [:]

    init(_ args: [String], valued: Set<String>) throws {
        var i = 0
        while i < args.count {
            let a = args[i]
            if a.hasPrefix("--") {
                if let eq = a.firstIndex(of: "="), valued.contains(String(a[..<eq])) {
                    flags[String(a[..<eq]), default: []].append(String(a[a.index(after: eq)...]))
                } else if valued.contains(a) {
                    guard i + 1 < args.count else { throw CLIError("\(a) needs a value", code: 64) }
                    flags[a, default: []].append(args[i + 1])
                    i += 1
                } else {
                    flags[a, default: []].append("")
                }
            } else {
                positional.append(a)
            }
            i += 1
        }
    }

    func value(_ flag: String) -> String? { flags[flag]?.last }
    func values(_ flag: String) -> [String] { flags[flag] ?? [] }
}

/// Single-line progress on stderr when attached to a terminal.
final class ProgressLine: @unchecked Sendable {
    private let label: String
    private let tty = isatty(STDERR_FILENO) == 1
    private let lock = NSLock()
    private var lastPercent = -1

    init(label: String) { self.label = label }

    var sink: ProgressSink {
        ProgressSink { [weak self] f in self?.update(f) }
    }

    private func update(_ f: Double) {
        guard tty else { return }
        let pct = Int(f * 100)
        let changed: Bool = lock.withLock { if pct != lastPercent { lastPercent = pct; return true } else { return false } }
        guard changed else { return }
        FileHandle.standardError.write(Data("\r\u{1B}[2K\(label)  \(pct)%".utf8))
    }

    func finish() {
        guard tty else { return }
        FileHandle.standardError.write(Data("\r\u{1B}[2K".utf8))
    }
}
