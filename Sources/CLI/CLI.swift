import AppKit
import HaloCore

/// `halo`: the command-line face of the same capability table, router,
/// engines, tools and presets the wheel uses. Contract: docs/CLI.md.
@MainActor
enum CLI {
    static var usage: String {
        let n = Brand.cliName
        return """
        usage: \(n) <command> [options]

        convert <file>... --to <format> [--opt key=value]... [--preset <id|title>]
                [--out-dir <dir>] [--overwrite rename|never] [--metadata keep|private|strip] [--dry-run]
        targets <file>...              formats these files can become (with routes)
        formats [--from <format>]      every conversion in the live capability table
        options <format>               options for converting to <format>
        tool <tool-id> <file>... [--opt key=value]... [--out-dir <dir>] [--metadata …]
        tools                          tools and their options
        presets [list [--format <f>] | show <id> | add --format <f> --title <t> --opt k=v... | rm <id>]
        jobs                           recent conversions made with the app
        doctor                         engines, packs, paths, signature, permissions
        schema                         everything above in one document (schemaVersion 1)
        route <from> <to>              the planned route between two formats
        mcp                            Model Context Protocol server on stdin/stdout
        version
        help

        Every command takes --json (pretty JSON on stdout; convert and tool stream NDJSON).
        Human messages go to stderr. Outputs never overwrite anything: name.png, then
        name 2.png … Exit codes: 0 ok, 2 usage, 3 unsupported route, 4 input missing,
        5 engine failed, 6 partial batch, 7 cancelled, 8 cloud unavailable.
        """
    }

    static func run(_ args: [String]) async -> Int32 {
        var a = args
        guard let command = a.first else { err(usage); return ExitCode.usage.rawValue }
        a.removeFirst()
        let json = a.contains("--json")
        do {
            let code: ExitCode
            switch command {
            case "convert": code = try await convert(a)
            case "tool": code = try await tool(a)
            case "targets": code = try targets(a)
            case "formats": code = try formats(a)
            case "options": code = try options(a)
            case "tools": code = try tools(a)
            case "presets": code = try presets(a)
            case "jobs": code = try jobs(a)
            case "doctor": code = try Doctor.run(a)
            case "schema": code = try schema(a)
            case "route": code = try route(a)
            case "mcp": code = await MCPServer.serve()
            case "version", "--version", "-v": code = try version(a)
            case "help", "--help", "-h": code = try help(a)
            default: throw CLIError.usage("unknown command “\(command)”\n\n\(usage)")
            }
            return code.rawValue
        } catch let e as CLIError {
            err("error: \(e.message)")
            if json { out(JSON.pretty(["error": ["code": e.code.name, "exitCode": Int(e.code.rawValue), "message": e.message]])) }
            return e.code.rawValue
        } catch {
            err("error: \(Runner.describe(error))")
            return ExitCode.engineFailed.rawValue
        }
    }

    // MARK: convert / tool

    static func convert(_ args: [String]) async throws -> ExitCode {
        let p = try ParsedArgs(args, valued: ["--to", "--opt", "--preset", "--out-dir", "--out", "--overwrite", "--metadata"],
                               switches: ["--dry-run"])
        let json = p.has("--json")
        guard let toRaw = p.value("--to") else { throw CLIError.usage("missing --to <format>") }
        var req = ConvertRequest(files: p.positional, to: FormatID(toRaw))
        req.options = try Runner.pairs(p.values("--opt"))
        req.preset = p.value("--preset")
        req.outDir = p.value("--out-dir") ?? p.value("--out")
        req.metadata = try Runner.metadata(p.value("--metadata"))
        req.dryRun = p.has("--dry-run")
        if let o = p.value("--overwrite") {
            guard let mode = OverwriteMode(rawValue: o) else { throw CLIError.usage("--overwrite must be rename or never (got \(o))") }
            req.overwrite = mode
        }
        let plan = try Runner.plan(req)

        if req.dryRun {
            var summary = RunSummary()
            summary.succeeded = plan.jobs.count
            summary.failed = plan.failures.count
            summary.skipped = plan.skipped.count
            summary.failureCodes = plan.failures.map(\.code)
            let code = summary.exitCode
            if json {
                out(JSON.pretty([
                    "dryRun": true,
                    "to": req.to.rawValue,
                    "options": JSON.values(plan.options),
                    "jobs": plan.jobs.map(\.json),
                    "skipped": plan.skipped.map { ["file": $0.file, "reason": $0.reason] },
                    "errors": plan.failures.map { ["file": $0.file, "code": $0.code.rawValue, "message": $0.message] },
                    "exitCode": Int(code.rawValue),
                ]))
            } else {
                for j in plan.jobs {
                    err("\(j.file)\n  route: \(j.route.hops.map { "\($0.from.rawValue) → \($0.to.rawValue) [\($0.engine)]" }.joined(separator: ", "))")
                    out(j.predicted.path)
                }
                for s in plan.skipped { err("skip \(s.file): \(s.reason)") }
                for f in plan.failures { err("✗ \(f.file): \(f.message)") }
            }
            return code
        }

        let summary = await Runner.run(plan, events: sink(json: json, verb: "→ \(Formats.label(req.to))"))
        return summary.exitCode
    }

    static func tool(_ args: [String]) async throws -> ExitCode {
        let p = try ParsedArgs(args, valued: ["--opt", "--out-dir", "--out", "--metadata"])
        guard let id = p.positional.first else { throw CLIError.usage("missing tool id. Try `\(Brand.cliName) tools`.") }
        let plan = try Runner.planTool(id: id, files: Array(p.positional.dropFirst()), options: try Runner.pairs(p.values("--opt")),
                                       outDir: p.value("--out-dir") ?? p.value("--out"), metadata: try Runner.metadata(p.value("--metadata")))
        let summary = await Runner.runTool(plan, events: sink(json: p.has("--json"), verb: plan.spec.title))
        return summary.exitCode
    }

    /// NDJSON on stdout with --json; otherwise output paths on stdout, the rest on stderr.
    private static func sink(json: Bool, verb: String) -> EventSink {
        if json { return { e in out(JSON.line(e.json)) } }
        let line = ProgressLine()
        return { e in
            switch e {
            case .progress(let f, let x): line.update("\((f as NSString).lastPathComponent) \(verb)", x)
            case .output(_, let p): line.clear(); out(p)
            case .skip(let f, let r): line.clear(); err("skip \((f as NSString).lastPathComponent): \(r)")
            case .error(let f, _, let m): line.clear(); err("✗ \(f.map { ($0 as NSString).lastPathComponent } ?? "error"): \(m)")
            case .done(let s, let f, _, _): line.clear(); if f > 0 { err("\(s) succeeded, \(f) failed") }
            case .start: break
            }
        }
    }

    // MARK: listing

    static func targets(_ args: [String]) throws -> ExitCode {
        let p = try ParsedArgs(args, valued: [])
        guard !p.positional.isEmpty else { throw CLIError.usage("usage: \(Brand.cliName) targets <file>...") }
        var inputs: [[String: Any]] = []
        var formats: [FormatID] = []
        for path in p.positional {
            let u = CLIPaths.url(path)
            guard FileManager.default.fileExists(atPath: u.path) else { throw CLIError("no such file: \(path)", code: .inputMissing) }
            guard let f = Formats.detect(u) else { throw CLIError("can’t tell what kind of file “\(u.lastPathComponent)” is", code: .inputMissing) }
            inputs.append(["file": u.path, "format": f.rawValue])
            formats.append(f)
        }
        let targets = Catalog.targets(for: formats)
        if p.has("--json") {
            out(JSON.pretty(["inputs": inputs, "targets": targets]))
        } else {
            for t in targets {
                let fmt = t["format"] as! String
                let shown = (t["shownByDefault"] as? Bool) == true ? "" : "  (not on the wheel by default)"
                let routes = (t["routes"] as? [[String: Any]]) ?? []
                let via = routes.map { r in ((r["hops"] as? [[String: Any]]) ?? []).map { "\($0["to"]!)[\($0["engine"]!)]" }.joined(separator: " → ") }
                out("\(fmt.padding(toLength: 8, withPad: " ", startingAt: 0)) \(via.joined(separator: " | "))\(shown)")
            }
        }
        return targets.isEmpty ? .unsupportedRoute : .ok
    }

    static func formats(_ args: [String]) throws -> ExitCode {
        let p = try ParsedArgs(args, valued: ["--from"], switches: ["--markdown"])
        let from = p.value("--from").map { FormatID($0) }
        let router = Router.live()
        if p.has("--markdown") {
            out(markdownTable(router))
            return .ok
        }
        var rows: [[String: Any]] = []
        for f in Formats.all where from == nil || f.id == from {
            let routes = router.allRoutes(from: f.id)
            guard !routes.isEmpty else { continue }
            let targets = routes.keys.sorted()
            if p.has("--json") {
                rows.append(["from": f.id.rawValue, "kind": f.kind.rawValue,
                             "to": targets.map { ["format": $0.rawValue, "hops": routes[$0]?.hops.count ?? 0] }])
            } else {
                out("\(f.label.padding(toLength: 10, withPad: " ", startingAt: 0)) → \(targets.map { Formats.label($0) }.joined(separator: " "))")
            }
        }
        let count = router.optionCount()
        if p.has("--json") {
            out(JSON.pretty(["options": count, "formats": rows]))
        } else {
            out("\n\(count) conversion options")
        }
        return .ok
    }

    /// README table, generated from the live capability registry (`make readme-formats`).
    /// "On the wheel" = `Route.isShownByDefault`; the rest ship too (CLI, opt-in in Settings › Formats).
    static func markdownTable(_ router: Router) -> String {
        func order(_ f: FormatID) -> (Int, Int) {
            (FileKind.allCases.firstIndex(of: Formats.kind(f)) ?? 99, Formats.format(f)?.order ?? 999)
        }
        func labels(_ ids: [FormatID]) -> String { ids.sorted { order($0) < order($1) }.map { Formats.label($0) }.joined(separator: ", ") }
        var md = "| Category | From | On the wheel | Also available (opt-in, CLI) |\n|---|---|---|---|\n"
        var shown = 0, total = 0
        for kind in FileKind.allCases {
            let inputs = Formats.all.filter { $0.kind == kind && !router.allRoutes(from: $0.id).isEmpty }
            guard !inputs.isEmpty else { continue }
            var rows: [(String, String, [String])] = []
            for f in inputs {
                let routes = router.allRoutes(from: f.id)
                let visible = routes.filter { $0.value.isShownByDefault }.map(\.key)
                let extra = routes.filter { !$0.value.isShownByDefault }.map(\.key)
                shown += visible.count; total += routes.count
                let key = labels(visible), more = labels(extra)
                if let i = rows.firstIndex(where: { $0.0 == key && $0.1 == more }) { rows[i].2.append(f.label) }
                else { rows.append((key, more, [f.label])) }
            }
            for r in rows {
                md += "| \(categoryName(kind)) | \(r.2.joined(separator: ", ")) | \(r.0) | \(r.1.isEmpty ? "–" : r.1) |\n"
            }
        }
        md += "\n**\(total) conversion options** (each input × output pair, direct or routed through up to 3 steps), **\(shown)** of them on the wheel by default. "
        md += "Every one is run on a real file and validated by `make matrix` ([MATRIX.md](MATRIX.md)).\n"
        return md
    }

    static func categoryName(_ kind: FileKind) -> String {
        switch kind {
        case .pdf: "PDF"
        case .ebook: "Ebook"
        case .subtitle: "Subtitles"
        case .spreadsheet: "Spreadsheet"
        default: kind.rawValue.capitalized
        }
    }

    static func options(_ args: [String]) throws -> ExitCode {
        let p = try ParsedArgs(args, valued: [])
        guard let raw = p.positional.first else { throw CLIError.usage("usage: \(Brand.cliName) options <format>") }
        let f = FormatID(raw)
        guard Formats.format(f) != nil else { throw CLIError.usage("unknown format “\(raw)”. Try `\(Brand.cliName) formats`.") }
        guard let o = Catalog.options(for: f) else { throw CLIError("nothing converts to \(Formats.label(f))", code: .unsupportedRoute) }
        if p.has("--json") {
            out(JSON.pretty(o))
        } else {
            for s in OptionsSchema.forTarget(f)?.specs ?? [] {
                var line = "--opt \(s.id)=\(s.defaultValue)".padding(toLength: 32, withPad: " ", startingAt: 0) + " \(s.label)"
                if case .choice(let c) = s.kind { line += " [\(c.map(\.id).joined(separator: "|"))]" }
                if let h = s.help { line += " — \(h)" }
                out(line)
            }
        }
        return .ok
    }

    static func tools(_ args: [String]) throws -> ExitCode {
        let p = try ParsedArgs(args, valued: [])
        if p.has("--json") {
            out(JSON.pretty(["tools": Catalog.tools()]))
            return .ok
        }
        let available = ToolRegistry.default.ids
        for t in ToolCatalog.all {
            let state = t.cloudFeature != nil ? "cloud (Pro)" : (available.contains(t.id) ? "" : "not in this build")
            out("\(t.id.rawValue.padding(toLength: 24, withPad: " ", startingAt: 0)) \(t.title) \(state.isEmpty ? "" : "[\(state)]")")
            for s in t.schema.specs { out("    --opt \(s.id)=\(s.defaultValue)   \(s.label)") }
        }
        return .ok
    }

    static func presets(_ args: [String]) throws -> ExitCode {
        var a = args
        let sub = a.first.flatMap { $0.hasPrefix("--") ? nil : $0 } ?? "list"
        if a.first == sub { a.removeFirst() }
        let p = try ParsedArgs(a, valued: ["--format", "--title", "--opt"], switches: ["--all"])
        let json = p.has("--json")
        let store = CLIPaths.presets
        func show(_ list: [[String: Any]]) {
            if json { out(JSON.pretty(["presets": list])); return }
            for d in list {
                let vals = ((d["values"] as? [String: Any]) ?? [:]).sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
                let tag = (d["builtIn"] as? Bool) == true ? ((d["hidden"] as? Bool) == true ? " [built-in, hidden]" : " [built-in]") : ""
                out("\(d["format"]!)\t\(d["id"]!)\t\(d["title"]!)\(tag)\t\(vals)")
            }
        }
        switch sub {
        case "list":
            let f = p.value("--format").map { FormatID($0) }
            if let f, Formats.format(f) == nil { throw CLIError.usage("unknown format “\(f.rawValue)”") }
            show(Catalog.presets(format: f, includeHidden: p.has("--all")))
        case "show":
            guard let id = p.positional.first else { throw CLIError.usage("usage: \(Brand.cliName) presets show <id>") }
            guard let preset = Catalog.findPreset(id, format: p.value("--format").map { FormatID($0) }) else {
                throw CLIError.usage("no preset “\(id)”")
            }
            let hidden = store.hiddenBuiltIns(for: preset.format).contains { $0.id == preset.id }
            if json { out(JSON.pretty(Catalog.preset(preset, hidden: hidden))) } else { show([Catalog.preset(preset, hidden: hidden)]) }
        case "add":
            guard let fRaw = p.value("--format") else { throw CLIError.usage("presets add needs --format <format>") }
            guard let title = p.value("--title"), !title.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw CLIError.usage("presets add needs --title <title>")
            }
            let f = FormatID(fRaw)
            guard let schema = OptionsSchema.forTarget(f) else { throw CLIError.usage("nothing converts to “\(fRaw)”, so it has no presets") }
            let values = try Runner.typedOptions(try Runner.pairs(p.values("--opt")), specs: schema.specs, context: Formats.label(f))
            guard !values.values.isEmpty else { throw CLIError.usage("presets add needs at least one --opt key=value") }
            let preset = store.add(title, format: f, values: values)
            if json { out(JSON.pretty(Catalog.preset(preset))) } else { out(preset.id) }
        case "rm", "remove", "delete":
            guard let id = p.positional.first else { throw CLIError.usage("usage: \(Brand.cliName) presets rm <id>") }
            guard let preset = Catalog.findPreset(id, format: nil) else { throw CLIError.usage("no preset “\(id)”") }
            store.delete(preset.id)
            let result: [String: Any] = ["id": preset.id, "removed": !preset.isBuiltIn, "hidden": preset.isBuiltIn]
            if json { out(JSON.pretty(result)) } else { err(preset.isBuiltIn ? "hid built-in preset \(preset.id)" : "removed \(preset.id)") }
        default:
            throw CLIError.usage("presets: unknown subcommand “\(sub)” (list, show, add, rm)")
        }
        return .ok
    }

    static func jobs(_ args: [String]) throws -> ExitCode {
        let p = try ParsedArgs(args, valued: [])
        let iso = ISO8601DateFormatter()
        let items: [[String: Any]] = CLIPaths.recents.items.map {
            ["id": $0.id.uuidString, "title": $0.title, "outputs": $0.outputs.map(\.path), "date": iso.string(from: $0.date)]
        }
        if p.has("--json") {
            out(JSON.pretty(["jobs": items, "limit": RecentConversions.limit,
                             "source": CLIPaths.supportDirectory.appendingPathComponent("recents.json").path]))
        } else if items.isEmpty {
            err("no recent conversions")
        } else {
            for i in items { out("\(i["date"]!)  \(i["title"]!)\n    \(((i["outputs"] as? [String]) ?? []).joined(separator: "\n    "))") }
        }
        return .ok
    }

    static func schema(_ args: [String]) throws -> ExitCode {
        _ = try ParsedArgs(args, valued: [])
        out(JSON.pretty(Catalog.everything()))
        return .ok
    }

    static func route(_ args: [String]) throws -> ExitCode {
        let p = try ParsedArgs(args, valued: [])
        guard p.positional.count >= 2 else { throw CLIError.usage("usage: \(Brand.cliName) route <from> <to>") }
        guard let r = Router.live().route(from: FormatID(p.positional[0]), to: FormatID(p.positional[1])) else {
            throw CLIError("no route", code: .unsupportedRoute)
        }
        if p.has("--json") { out(JSON.pretty(Catalog.route(r))) } else { out("\(r)  (cost \(String(format: "%.1f", r.cost)))") }
        return .ok
    }

    static func version(_ args: [String]) throws -> ExitCode {
        let p = try ParsedArgs(args, valued: [])
        if p.has("--json") {
            out(JSON.pretty(["name": Brand.cliName, "version": cliVersion, "licence": Brand.licence, "schemaVersion": Catalog.schemaVersion]))
        } else {
            out("\(Brand.cliName) \(cliVersion) (\(Brand.licence))")
        }
        return .ok
    }

    static func help(_ args: [String]) throws -> ExitCode {
        let p = try ParsedArgs(args, valued: [])
        if p.has("--json") {
            let commands = ["convert", "targets", "formats", "options", "tool", "tools", "presets", "jobs", "doctor",
                            "schema", "route", "mcp", "version", "help"]
            out(JSON.pretty(["usage": usage, "commands": commands, "exitCodes": Catalog.exitCodes()]))
        } else {
            out(usage)
        }
        return .ok
    }
}

/// Single-line progress on stderr when it is a terminal; silent otherwise.
final class ProgressLine: @unchecked Sendable {
    private let tty = isatty(STDERR_FILENO) == 1
    private let lock = NSLock()
    private var shown = false

    func update(_ label: String, _ fraction: Double) {
        guard tty else { return }
        lock.withLock { shown = true }
        FileHandle.standardError.write(Data("\r\u{1B}[2K\(label)  \(Int(fraction * 100))%".utf8))
    }

    func clear() {
        guard tty, lock.withLock({ let s = shown; shown = false; return s }) else { return }
        FileHandle.standardError.write(Data("\r\u{1B}[2K".utf8))
    }
}
