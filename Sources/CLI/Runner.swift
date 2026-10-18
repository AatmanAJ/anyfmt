import Foundation
import HaloCore

// Plans and runs conversions and tools for both `halo convert` / `halo tool`
// and the MCP `convert` / `run_tool` tools. Events go to a callback; the CLI
// prints them as NDJSON or human lines, MCP turns progress into notifications.

/// One streamed event. Its `json` form is the NDJSON contract.
enum RunEvent: Sendable {
    case start(jobs: Int)
    case progress(file: String, fraction: Double)
    case output(file: String, path: String)
    case skip(file: String, reason: String)
    case error(file: String?, code: FailureCode, message: String)
    case done(succeeded: Int, failed: Int, skipped: Int, exitCode: ExitCode)

    var json: [String: Any] {
        switch self {
        case .start(let n): return ["event": "start", "jobs": n]
        case .progress(let f, let x): return ["event": "progress", "file": f, "fraction": JSON.number(x)]
        case .output(let f, let p): return ["event": "output", "file": f, "path": p]
        case .skip(let f, let r): return ["event": "skip", "file": f, "reason": r]
        case .error(let f, let c, let m):
            var d: [String: Any] = ["event": "error", "code": c.rawValue, "message": m]
            if let f { d["file"] = f }
            return d
        case .done(let s, let f, let k, let code):
            return ["event": "done", "succeeded": s, "failed": f, "skipped": k, "exitCode": Int(code.rawValue)]
        }
    }
}

typealias EventSink = @Sendable (RunEvent) -> Void

enum OverwriteMode: String, CaseIterable {
    case rename, never
}

/// What `convert` was asked to do, already validated.
struct ConvertRequest {
    var files: [String]
    var to: FormatID
    var options: [String: String] = [:]   // raw --opt text, typed against the route's schema
    var preset: String?
    var outDir: String?
    var overwrite: OverwriteMode = .rename
    var metadata: MetadataPolicy = .keep
    var dryRun = false
}

/// A planned unit of work: one input (per-file routes) or all inputs (combine rows).
struct PlannedJob {
    let inputs: [URL]
    let from: FormatID
    let route: Route
    /// Name decisions are made from this URL (inputs[0], or "Archive" for combines).
    let naming: URL
    let predicted: URL
    let isFolder: Bool

    var file: String { inputs.count == 1 ? inputs[0].path : "\(inputs.count) items" }

    var json: [String: Any] {
        ["inputs": inputs.map(\.path), "from": from.rawValue, "to": route.to.rawValue,
         "route": Catalog.route(route), "output": predicted.path, "outputIsFolder": isFolder]
    }
}

struct PlanFailure {
    let file: String
    let code: FailureCode
    let message: String
}

struct ConvertPlan {
    var jobs: [PlannedJob] = []
    var failures: [PlanFailure] = []
    var skipped: [(file: String, reason: String)] = []
    var options = OptionValues()
    var policy = OutputPolicy.default
}

struct RunSummary {
    var succeeded = 0
    var failed = 0
    var skipped = 0
    var failureCodes: [FailureCode] = []
    var results: [[String: Any]] = []

    /// 0 when nothing failed; the shared code when every job failed the same
    /// way; otherwise 6 (partial). `output_exists` always maps to 6.
    var exitCode: ExitCode {
        guard failed > 0 else { return .ok }
        if failureCodes.contains(.cancelled) { return .cancelled }
        if succeeded == 0, let first = failureCodes.first, failureCodes.allSatisfy({ $0 == first }) {
            return first.exitCode
        }
        return .partial
    }
}

@MainActor
enum Runner {
    // MARK: Options

    /// Types `raw` key=value text against `specs`. Unknown keys and bad values are usage errors.
    static func typedOptions(_ raw: [String: String], specs: [OptionSpec], context: String) throws -> OptionValues {
        var v = OptionValues()
        for key in raw.keys.sorted() {
            let text = raw[key]!
            guard let spec = specs.first(where: { $0.id == key }) else {
                let valid = specs.map(\.id)
                throw CLIError.usage("unknown option “\(key)” for \(context)" + (valid.isEmpty ? " (it takes no options)" : ". Valid: \(valid.joined(separator: ", "))"))
            }
            guard let typed = OptionValue.parse(text, as: spec.kind) else {
                var hint = ""
                if case .choice(let c) = spec.kind { hint = " (one of \(c.map(\.id).joined(separator: ", ")))" }
                throw CLIError.usage("bad value “\(text)” for option \(key)\(hint)")
            }
            v[key] = typed
        }
        return v
    }

    /// `key=value` pairs from repeated `--opt`.
    static func pairs(_ list: [String]) throws -> [String: String] {
        var d: [String: String] = [:]
        for pair in list {
            guard let eq = pair.firstIndex(of: "="), eq != pair.startIndex else {
                throw CLIError.usage("--opt expects key=value, got “\(pair)”")
            }
            d[String(pair[..<eq])] = String(pair[pair.index(after: eq)...])
        }
        return d
    }

    static func policy(outDir: String?, metadata: MetadataPolicy, create: Bool) throws -> OutputPolicy {
        var policy = OutputPolicy.default
        if let outDir {
            let u = CLIPaths.url(outDir, directory: true)
            if create { try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true) }
            policy.location = .folder(u)
        }
        policy.metadata = metadata
        policy.revealInFinder = false
        return policy
    }

    static func metadata(_ raw: String?) throws -> MetadataPolicy {
        switch raw {
        case nil, "keep": .keep
        case "private": .stripPrivate
        case "strip": .stripAll
        case let other?: throw CLIError.usage("--metadata must be keep, private or strip (got \(other))")
        }
    }

    // MARK: Planning

    static func plan(_ req: ConvertRequest) throws -> ConvertPlan {
        guard Formats.format(req.to) != nil else {
            throw CLIError.usage("unknown format “\(req.to.rawValue)”. Try `\(Brand.cliName) formats`.")
        }
        guard !req.files.isEmpty else { throw CLIError.usage("no input files") }
        var plan = ConvertPlan()
        plan.policy = try policy(outDir: req.outDir, metadata: req.metadata, create: !req.dryRun)
        let router = Router.live()

        var detected: [(URL, FormatID)] = []
        for path in req.files {
            let u = CLIPaths.url(path)
            guard FileManager.default.isReadableFile(atPath: u.path) else {
                plan.failures.append(PlanFailure(file: u.path, code: .inputMissing, message: "no such file or not readable: \(path)"))
                continue
            }
            guard let fmt = Formats.detect(u) else {
                plan.failures.append(PlanFailure(file: u.path, code: .inputMissing, message: "can’t tell what kind of file “\(u.lastPathComponent)” is"))
                continue
            }
            detected.append((u, fmt))
        }

        // Combine rows (folder / several items → archive) take every input at once.
        if detected.count > 1,
           let r = detected.lazy.compactMap({ router.route(from: $0.1, to: req.to) }).first(where: { $0.isDirect && $0.hops[0].arity == .combine }) {
            let naming = detected[0].0.deletingLastPathComponent().appendingPathComponent("Archive")
            plan.jobs.append(makeJob(inputs: detected.map(\.0), from: r.from, route: r, naming: naming, policy: plan.policy, overwrite: req.overwrite, plan: &plan))
        } else {
            for (u, fmt) in detected {
                if fmt == req.to { plan.skipped.append((u.path, "already \(Formats.label(req.to))")); continue }
                guard let r = router.route(from: fmt, to: req.to) else {
                    plan.failures.append(PlanFailure(file: u.path, code: .unsupportedRoute,
                                                     message: "\(Formats.label(fmt)) → \(Formats.label(req.to)) isn’t supported"))
                    continue
                }
                plan.jobs.append(makeJob(inputs: [u], from: fmt, route: r, naming: u, policy: plan.policy, overwrite: req.overwrite, plan: &plan))
            }
        }
        // `makeJob` may have turned a job into an output_exists failure.
        plan.jobs.removeAll { job in plan.failures.contains { $0.file == job.file && $0.code == .outputExists } }

        // Options: preset values, then --opt, typed against every route's final-hop schema.
        var specs: [OptionSpec] = []
        var seen = Set<String>()
        let schemas = plan.jobs.map(\.route.schema) + [OptionsSchema.forTarget(req.to) ?? .none]
        for s in schemas { for spec in s.specs where seen.insert(spec.id).inserted { specs.append(spec) } }
        var values = OptionValues()
        if let key = req.preset {
            guard let p = Catalog.findPreset(key, format: req.to) else {
                throw CLIError.usage("no \(Formats.label(req.to)) preset “\(key)”. Try `\(Brand.cliName) presets list --format \(req.to.rawValue)`.")
            }
            values = p.values
        }
        var raw = req.options
        if let cloud = raw.removeValue(forKey: OptionKey.cloud), OptionValue.parse(cloud, as: .toggle) == .bool(true) {
            values[OptionKey.cloud] = .bool(true)
        }
        values = values.merging(try typedOptions(raw, specs: specs, context: Formats.label(req.to)))
        if values.bool(OptionKey.cloud, default: false) {
            throw CLIError("cloud conversion (Pro) runs in the app; the CLI only converts on this Mac. Drop --opt cloud=true.", code: .cloudUnavailable)
        }
        values[OptionKey.cloud] = nil
        plan.options = values
        return plan
    }

    private static func makeJob(inputs: [URL], from: FormatID, route: Route, naming: URL, policy: OutputPolicy,
                                overwrite: OverwriteMode, plan: inout ConvertPlan) -> PlannedJob {
        let to = route.to
        let dir = OutputNamer.outputDirectory(for: naming, policy: policy)
        let base = OutputNamer.baseName(for: naming, pattern: policy.namePattern, targetLabel: Formats.label(to))
        let isFolder = route.hops.last?.flags.contains(.multiOutput) == true || to == Formats.folder
        let ext: String
        var name = base
        if to == Formats.folder {
            ext = ""
        } else if route.hops.last?.flags.contains(.multiOutput) == true {
            ext = ""
            name = "\(base) (\(Formats.label(to)))"
        } else if to == Formats.gz, inputs.count == 1, !naming.pathExtension.isEmpty, Formats.kind(from) != .folder {
            ext = naming.pathExtension + ".gz"
        } else {
            ext = Formats.extension(for: to)
        }
        let predicted: URL
        switch overwrite {
        case .rename:
            predicted = OutputNamer.freeURL(in: dir, base: name, ext: ext)
        case .never:
            predicted = dir.appendingPathComponent(ext.isEmpty ? name : "\(name).\(ext)")
        }
        let job = PlannedJob(inputs: inputs, from: from, route: route, naming: naming, predicted: predicted, isFolder: isFolder)
        if overwrite == .never, FileManager.default.fileExists(atPath: predicted.path) {
            plan.failures.append(PlanFailure(file: job.file, code: .outputExists,
                                             message: "\(predicted.path) already exists (--overwrite never)"))
        }
        return job
    }

    // MARK: Running

    /// Runs every planned job in order, streaming events. Returns the summary.
    static func run(_ plan: ConvertPlan, events: @escaping EventSink) async -> RunSummary {
        var summary = RunSummary()
        events(.start(jobs: plan.jobs.count + plan.failures.count))
        for s in plan.skipped {
            events(.skip(file: s.file, reason: s.reason))
            summary.skipped += 1
        }
        for f in plan.failures {
            events(.error(file: f.file, code: f.code, message: f.message))
            summary.failed += 1
            summary.failureCodes.append(f.code)
            summary.results.append(["file": f.file, "error": ["code": f.code.rawValue, "message": f.message]])
        }
        let executor = RouteExecutor()
        for job in plan.jobs {
            if Task.isCancelled {
                fail(&summary, job.file, .cancelled, "cancelled", events)
                continue
            }
            let work = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(Brand.name)-cli/\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: work) }
            let file = job.file
            let throttle = ProgressThrottle { f in events(.progress(file: file, fraction: f)) }
            do {
                if let delay = CLIPaths.testDelay { try await Task.sleep(nanoseconds: delay) }
                let produced = try await executor.execute(
                    job.route, inputs: job.inputs, options: plan.options,
                    baseName: OutputNamer.stem(of: job.naming), metadata: plan.policy.metadata,
                    workDirectory: work, context: EngineContext(progress: throttle.sink))
                try Task.checkCancellation()
                let placed = try OutputPlacer(policy: plan.policy).place(produced, for: job.naming, target: job.route.to)
                throttle.finish()
                for p in placed { events(.output(file: file, path: p.path)) }
                summary.succeeded += 1
                summary.results.append(["file": file, "outputs": placed.map(\.path), "route": Catalog.route(job.route)])
            } catch {
                let code = Task.isCancelled ? .cancelled : FailureCode.classify(error)
                fail(&summary, file, code, describe(error), events)
            }
        }
        events(.done(succeeded: summary.succeeded, failed: summary.failed, skipped: summary.skipped, exitCode: summary.exitCode))
        return summary
    }

    private static func fail(_ s: inout RunSummary, _ file: String, _ code: FailureCode, _ message: String, _ events: EventSink) {
        events(.error(file: file, code: code, message: message))
        s.failed += 1
        s.failureCodes.append(code)
        s.results.append(["file": file, "error": ["code": code.rawValue, "message": message]])
    }

    static func describe(_ error: Error) -> String {
        if error is CancellationError { return "cancelled" }
        if let e = error as? ConversionError {
            let detail = e.technicalDetails.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
            let message = e.localizedDescription
            return detail.isEmpty || detail == message ? message : "\(message) (\(detail.prefix(400)))"
        }
        return error.localizedDescription
    }

    // MARK: Tools

    struct ToolPlan {
        let spec: ToolSpec
        let runner: any ToolRunner
        let groups: [[URL]]
        let failures: [PlanFailure]
        let options: OptionValues
        let policy: OutputPolicy
    }

    static func planTool(id raw: String, files: [String], options: [String: String], outDir: String?,
                         metadata: MetadataPolicy) throws -> ToolPlan {
        let id = ToolID(rawValue: raw)
        guard let spec = ToolCatalog.spec(id) else {
            throw CLIError.usage("unknown tool “\(raw)”. Try `\(Brand.cliName) tools`.")
        }
        guard spec.cloudFeature == nil else {
            throw CLIError("“\(spec.title)” runs in the cloud (Pro); use the app", code: .cloudUnavailable)
        }
        guard let runner = ToolRegistry.default[id] else {
            throw CLIError("“\(spec.title)” isn’t available in this build", code: .unsupportedRoute)
        }
        guard !files.isEmpty else { throw CLIError.usage("no input files") }
        let typed = try typedOptions(options, specs: spec.schema.specs, context: "tool \(raw)")
        var failures: [PlanFailure] = []
        var ok: [URL] = []
        for path in files {
            let u = CLIPaths.url(path)
            guard FileManager.default.isReadableFile(atPath: u.path) else {
                failures.append(PlanFailure(file: u.path, code: .inputMissing, message: "no such file or not readable: \(path)"))
                continue
            }
            guard spec.applies(to: Formats.detect(u) ?? "") else {
                failures.append(PlanFailure(file: u.path, code: .unsupportedRoute, message: "“\(spec.title)” doesn’t apply to \(u.lastPathComponent)"))
                continue
            }
            ok.append(u)
        }
        var groups: [[URL]] = ok.map { [$0] }
        if case .combine(let minimum) = spec.arity {
            groups = ok.isEmpty ? [] : [ok]
            if !ok.isEmpty, ok.count < minimum {
                throw CLIError("“\(spec.title)” needs at least \(minimum) files", code: .usage)
            }
        }
        return ToolPlan(spec: spec, runner: runner, groups: groups, failures: failures,
                        options: spec.defaultOptions.merging(typed),
                        policy: try policy(outDir: outDir, metadata: metadata, create: true))
    }

    static func runTool(_ plan: ToolPlan, events: @escaping EventSink) async -> RunSummary {
        var summary = RunSummary()
        events(.start(jobs: plan.groups.count + plan.failures.count))
        for f in plan.failures { fail(&summary, f.file, f.code, f.message, events) }
        for group in plan.groups {
            let file = group.count == 1 ? group[0].path : "\(group.count) items"
            if Task.isCancelled { fail(&summary, file, .cancelled, "cancelled", events); continue }
            let work = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(Brand.name)-cli/\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: work) }
            let throttle = ProgressThrottle { f in events(.progress(file: file, fraction: f)) }
            do {
                if let delay = CLIPaths.testDelay { try await Task.sleep(nanoseconds: delay) }
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                let request = ToolRequest(tool: plan.spec.id, inputs: group, options: plan.options, outputDirectory: work,
                                          baseName: OutputNamer.stem(of: group[0]), metadata: plan.policy.metadata)
                let output = try await plan.runner.run(request, context: EngineContext(progress: throttle.sink))
                try Task.checkCancellation()
                let placed = try OutputPlacer(policy: plan.policy).place(output.files, for: group[0], target: nil,
                                                                          toolSuffix: plan.spec.outputSuffix)
                throttle.finish()
                for p in placed { events(.output(file: file, path: p.path)) }
                summary.succeeded += 1
                summary.results.append(["file": file, "outputs": placed.map(\.path)])
            } catch {
                let code = Task.isCancelled ? .cancelled : FailureCode.classify(error)
                fail(&summary, file, code, describe(error), events)
            }
        }
        events(.done(succeeded: summary.succeeded, failed: summary.failed, skipped: 0, exitCode: summary.exitCode))
        return summary
    }
}

/// Turns raw engine progress into at most one event per whole percent,
/// strictly increasing, ending at 1.0.
final class ProgressThrottle: @unchecked Sendable {
    private let lock = NSLock()
    private var last = -1
    private let emit: @Sendable (Double) -> Void

    init(_ emit: @escaping @Sendable (Double) -> Void) { self.emit = emit }

    var sink: ProgressSink { ProgressSink { [self] f in self.report(f) } }

    private func report(_ f: Double) {
        let pct = Int((min(1, max(0, f)) * 100).rounded(.down))
        let send: Bool = lock.withLock {
            guard pct > last else { return false }
            last = pct
            return true
        }
        if send { emit(Double(pct) / 100) }
    }

    func finish() { report(1) }
}
