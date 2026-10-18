import Foundation
import HaloCore

/// The MCP tools `halo mcp` exposes. Each one is a thin wrapper over the same
/// code path as the CLI command of the same name (Catalog / Runner), so the
/// two never disagree.
@MainActor
enum MCPTools {
    // MARK: Definitions

    private static let filesSchema: [String: Any] = [
        "type": "array", "minItems": 1, "items": ["type": "string"],
        "description": "Absolute paths of local files (or folders, for archive targets).",
    ]
    private static let optionsSchema: [String: Any] = [
        "type": "object",
        "additionalProperties": ["type": ["string", "number", "boolean"]],
        "description": "Option id → value, e.g. {\"quality\": 80}. Ids and ranges come from the `options` tool.",
    ]
    private static func readOnly(_ title: String) -> [String: Any] {
        ["title": title, "readOnlyHint": true, "openWorldHint": false]
    }

    /// Deterministic order (the spec asks for it so clients can cache).
    static let definitions: [[String: Any]] = [
        [
            "name": "convert",
            "title": "Convert files",
            "description": "Convert local files to another format on this Mac. Outputs go beside each original (or outDir) and never overwrite: name.png, then name 2.png. Use dryRun first to see the route (hops and engines) and the exact output paths. Returns per-file outputs or errors with codes (unsupported_route, input_missing, engine_failed, output_exists, cancelled, cloud_unavailable). Sends progress notifications when the request has a progressToken.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "files": filesSchema,
                    "to": ["type": "string", "description": "Target format id, e.g. jpg, mp4, pdf (see `targets` / `formats`)."],
                    "options": optionsSchema,
                    "preset": ["type": "string", "description": "Preset id or title for the target format (see `presets`). Explicit options win."],
                    "outDir": ["type": "string", "description": "Folder for outputs (created if missing). Default: beside each original."],
                    "overwrite": ["type": "string", "enum": ["rename", "never"], "default": "rename",
                                  "description": "rename: Finder-style free name. never: fail the file if the name is taken."],
                    "metadata": ["type": "string", "enum": ["keep", "private", "strip"], "default": "keep"],
                    "dryRun": ["type": "boolean", "default": false, "description": "Plan only: routes and output paths, nothing written."],
                ],
                "required": ["files", "to"],
                "additionalProperties": false,
            ],
            "annotations": ["title": "Convert files", "readOnlyHint": false, "destructiveHint": false,
                            "idempotentHint": false, "openWorldHint": false],
        ],
        [
            "name": "estimate",
            "title": "Estimate output",
            "description": "Estimate the output size (bytes), duration, frame count and pixel size of converting one file, using the same encoder settings as the real conversion (short sample for audio/video). Nothing is written.",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "file": ["type": "string", "description": "Absolute path of the input file."],
                    "to": ["type": "string", "description": "Target format id."],
                    "options": optionsSchema,
                ],
                "required": ["file", "to"],
                "additionalProperties": false,
            ],
            "annotations": readOnly("Estimate output"),
        ],
        [
            "name": "formats",
            "title": "List formats",
            "description": "Every format Halo reads or writes, with kind and extensions. With `from`, the formats that one input format converts to and the number of hops.",
            "inputSchema": [
                "type": "object",
                "properties": ["from": ["type": "string", "description": "Optional input format id."]],
                "additionalProperties": false,
            ],
            "annotations": readOnly("List formats"),
        ],
        [
            "name": "options",
            "title": "Options for a target",
            "description": "The options for converting to a format: id, label, kind (slider, integer, decimal, toggle, choice, …), choices, min/max/step, default, help and visibleWhen.",
            "inputSchema": [
                "type": "object",
                "properties": ["format": ["type": "string", "description": "Target format id, e.g. gif."]],
                "required": ["format"],
                "additionalProperties": false,
            ],
            "annotations": readOnly("Options for a target"),
        ],
        [
            "name": "presets",
            "title": "List presets",
            "description": "Saved option sets (the user's and the built-ins), shared with the Halo app. Pass a preset's id or title as `preset` to `convert`.",
            "inputSchema": [
                "type": "object",
                "properties": ["format": ["type": "string", "description": "Only presets for this target format."]],
                "additionalProperties": false,
            ],
            "annotations": readOnly("List presets"),
        ],
        [
            "name": "run_tool",
            "title": "Run a tool",
            "description": "Run a Halo tool (compress, resize, trim, normalise, strip metadata, …) on local files. Tool ids are the `tool` enum below; each tool's options are listed by `halo tools --json` (also in `halo schema --json`). Outputs never overwrite (name-compressed.jpg, …).",
            "inputSchema": [
                "type": "object",
                "properties": [
                    "tool": ["type": "string", "enum": ToolCatalog.all.filter { $0.cloudFeature == nil }.map(\.id.rawValue)],
                    "files": filesSchema,
                    "options": optionsSchema,
                    "outDir": ["type": "string", "description": "Folder for outputs. Default: beside each original."],
                ],
                "required": ["tool", "files"],
                "additionalProperties": false,
            ],
            "annotations": ["title": "Run a tool", "readOnlyHint": false, "destructiveHint": false,
                            "idempotentHint": false, "openWorldHint": false],
        ],
        [
            "name": "targets",
            "title": "What can these files become",
            "description": "The formats every given file can be converted to, with the planned route (hops and engines) per input format and whether the wheel shows it by default.",
            "inputSchema": [
                "type": "object",
                "properties": ["files": filesSchema],
                "required": ["files"],
                "additionalProperties": false,
            ],
            "annotations": readOnly("What can these files become"),
        ],
    ]

    static var names: Set<String> { Set(definitions.compactMap { $0["name"] as? String }) }

    // MARK: Calls

    /// Runs one tool. Returns the JSON payload and whether it is a tool error.
    static func call(_ name: String, _ args: [String: Any], progress: MCPProgress?) async -> ([String: Any], Bool) {
        do {
            switch name {
            case "convert": return try await convert(args, progress: progress)
            case "run_tool": return try await runTool(args, progress: progress)
            case "targets": return (try targets(args), false)
            case "options": return (try options(args), false)
            case "formats": return (try formats(args), false)
            case "presets": return (try presets(args), false)
            case "estimate": return (try await estimate(args), false)
            default: throw CLIError.usage("unknown tool \(name)")
            }
        } catch let e as CLIError {
            return (["error": ["code": e.code.name, "exitCode": Int(e.code.rawValue), "message": e.message]], true)
        } catch {
            let code = FailureCode.classify(error)
            return (["error": ["code": code.rawValue, "exitCode": Int(code.exitCode.rawValue), "message": Runner.describe(error)]], true)
        }
    }

    private static func string(_ args: [String: Any], _ key: String, required: Bool = true) throws -> String? {
        guard let v = args[key] else {
            if required { throw CLIError.usage("missing argument “\(key)”") }
            return nil
        }
        guard let s = v as? String, !s.isEmpty else { throw CLIError.usage("argument “\(key)” must be a non-empty string") }
        return s
    }

    private static func files(_ args: [String: Any], _ key: String = "files") throws -> [String] {
        guard let list = args[key] as? [Any], !list.isEmpty else { throw CLIError.usage("argument “\(key)” must be a non-empty array of paths") }
        return try list.map {
            guard let s = $0 as? String, !s.isEmpty else { throw CLIError.usage("argument “\(key)” must contain only paths") }
            return s
        }
    }

    private static func optionPairs(_ args: [String: Any]) throws -> [String: String] {
        guard let raw = args["options"] else { return [:] }
        guard let dict = raw as? [String: Any] else { throw CLIError.usage("argument “options” must be an object") }
        var pairs: [String: String] = [:]
        for (k, v) in dict {
            guard let text = JSON.text(v) else { throw CLIError.usage("option “\(k)” must be a string, number or boolean") }
            pairs[k] = text
        }
        return pairs
    }

    private static func convert(_ args: [String: Any], progress: MCPProgress?) async throws -> ([String: Any], Bool) {
        var req = ConvertRequest(files: try files(args), to: FormatID(try string(args, "to")!))
        req.options = try optionPairs(args)
        req.preset = try string(args, "preset", required: false)
        req.outDir = try string(args, "outDir", required: false)
        if let o = try string(args, "overwrite", required: false) {
            guard let mode = OverwriteMode(rawValue: o) else { throw CLIError.usage("overwrite must be rename or never") }
            req.overwrite = mode
        }
        req.metadata = try Runner.metadata(try string(args, "metadata", required: false))
        if let d = args["dryRun"] {
            guard JSON.isBool(d) else { throw CLIError.usage("dryRun must be a boolean") }
            req.dryRun = (d as! NSNumber).boolValue
        }
        let plan = try Runner.plan(req)
        if req.dryRun {
            var s = RunSummary()
            s.succeeded = plan.jobs.count
            s.failed = plan.failures.count
            s.failureCodes = plan.failures.map(\.code)
            return ([
                "dryRun": true, "to": req.to.rawValue, "options": JSON.values(plan.options),
                "jobs": plan.jobs.map(\.json),
                "skipped": plan.skipped.map { ["file": $0.file, "reason": $0.reason] },
                "errors": plan.failures.map { ["file": $0.file, "code": $0.code.rawValue, "message": $0.message] },
                "exitCode": Int(s.exitCode.rawValue),
            ], s.failed > 0)
        }
        let summary = await Runner.run(plan, events: { e in progress?.handle(e) })
        return (payload(summary), summary.failed > 0)
    }

    private static func runTool(_ args: [String: Any], progress: MCPProgress?) async throws -> ([String: Any], Bool) {
        let plan = try Runner.planTool(id: try string(args, "tool")!, files: try files(args), options: try optionPairs(args),
                                       outDir: try string(args, "outDir", required: false), metadata: .keep)
        let summary = await Runner.runTool(plan, events: { e in progress?.handle(e) })
        return (payload(summary), summary.failed > 0)
    }

    private static func payload(_ s: RunSummary) -> [String: Any] {
        ["succeeded": s.succeeded, "failed": s.failed, "skipped": s.skipped, "exitCode": Int(s.exitCode.rawValue), "results": s.results]
    }

    private static func targets(_ args: [String: Any]) throws -> [String: Any] {
        var inputs: [[String: Any]] = []
        var formats: [FormatID] = []
        for path in try files(args) {
            let u = CLIPaths.url(path)
            guard FileManager.default.fileExists(atPath: u.path) else { throw CLIError("no such file: \(path)", code: .inputMissing) }
            guard let f = Formats.detect(u) else { throw CLIError("can’t tell what kind of file “\(u.lastPathComponent)” is", code: .inputMissing) }
            inputs.append(["file": u.path, "format": f.rawValue])
            formats.append(f)
        }
        return ["inputs": inputs, "targets": Catalog.targets(for: formats)]
    }

    private static func options(_ args: [String: Any]) throws -> [String: Any] {
        let raw = try string(args, "format")!
        let f = FormatID(raw)
        guard Formats.format(f) != nil else { throw CLIError.usage("unknown format “\(raw)”") }
        guard let o = Catalog.options(for: f) else { throw CLIError("nothing converts to \(Formats.label(f))", code: .unsupportedRoute) }
        return o
    }

    private static func formats(_ args: [String: Any]) throws -> [String: Any] {
        if let raw = try string(args, "from", required: false) {
            let f = FormatID(raw)
            guard Formats.format(f) != nil else { throw CLIError.usage("unknown format “\(raw)”") }
            let routes = Router.live().allRoutes(from: f)
            return ["from": f.rawValue, "to": routes.keys.sorted().map { ["format": $0.rawValue, "hops": routes[$0]!.hops.count,
                                                                           "shownByDefault": routes[$0]!.isShownByDefault] }]
        }
        return ["formats": Catalog.formats(), "conversionOptions": Router.live().optionCount()]
    }

    private static func presets(_ args: [String: Any]) throws -> [String: Any] {
        let f = try string(args, "format", required: false).map { FormatID($0) }
        if let f, Formats.format(f) == nil { throw CLIError.usage("unknown format “\(f.rawValue)”") }
        return ["presets": Catalog.presets(format: f)]
    }

    private static func estimate(_ args: [String: Any]) async throws -> [String: Any] {
        let path = try string(args, "file")!
        let to = FormatID(try string(args, "to")!)
        guard Formats.format(to) != nil else { throw CLIError.usage("unknown format “\(to.rawValue)”") }
        let u = CLIPaths.url(path)
        guard FileManager.default.isReadableFile(atPath: u.path) else { throw CLIError("no such file: \(path)", code: .inputMissing) }
        var specs = OptionsSchema.forTarget(to)?.specs ?? []
        if let from = Formats.detect(u), let r = Router.live().route(from: from, to: to) {
            specs += r.schema.specs.filter { s in !specs.contains { $0.id == s.id } }
        }
        let options = try Runner.typedOptions(try optionPairs(args), specs: specs, context: Formats.label(to))
        let e = try await Estimator.estimate(input: u, target: to, options: options)
        var d: [String: Any] = ["file": u.path, "to": to.rawValue, "isExact": e.isExact]
        if let b = e.bytes { d["bytes"] = b }
        if let b = e.inputBytes { d["inputBytes"] = b }
        if let x = e.duration { d["duration"] = JSON.number(x, places: 3) }
        if let x = e.frames { d["frames"] = x }
        if let s = e.pixelSize { d["width"] = Int(s.width); d["height"] = Int(s.height) }
        return d
    }
}
