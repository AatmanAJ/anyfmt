import Foundation
import AnyfmtCore

/// JSON descriptions of formats, routes, option schemas, tools and presets.
/// The CLI (`--json`), `anyfmt schema` and the MCP server all use these, so the
/// three never disagree. Everything comes from the live registry the wheel uses.
@MainActor
enum Catalog {
    static let schemaVersion = 1

    static var router: Router { Router.live() }

    // MARK: Formats

    static func format(_ f: Format) -> [String: Any] {
        ["id": f.id.rawValue, "label": f.label, "name": f.name, "kind": f.kind.rawValue, "extensions": f.extensions]
    }

    /// Every known format that is an input or an output of some live route.
    static func formats() -> [[String: Any]] {
        let r = router
        let targets = Set(r.table.rows.map(\.to))
        return Formats.all.compactMap { f in
            let routes = r.allRoutes(from: f.id)
            guard !routes.isEmpty || targets.contains(f.id) else { return nil }
            var d = format(f)
            d["input"] = !routes.isEmpty
            d["output"] = targets.contains(f.id)
            return d
        }
    }

    // MARK: Routes

    nonisolated static func hop(_ c: Capability) -> [String: Any] {
        ["from": c.from.rawValue, "to": c.to.rawValue, "engine": c.engine.rawValue]
    }

    nonisolated static func route(_ r: Route) -> [String: Any] {
        ["from": r.from.rawValue, "to": r.to.rawValue, "hops": r.hops.map(hop), "shownByDefault": r.isShownByDefault]
    }

    /// Every live route, sorted by (from, to).
    static func routes() -> [[String: Any]] {
        let r = router
        let starts = Set(r.table.rows.map(\.from)).sorted()
        return starts.flatMap { from in
            r.allRoutes(from: from).sorted { $0.key < $1.key }.map { route($0.value) }
        }
    }

    /// Targets every input can reach, as `anyfmt targets` / MCP `targets` show them.
    static func targets(for inputs: [FormatID]) -> [[String: Any]] {
        router.commonTargets(for: inputs).map { t in
            let routes = t.routes.sorted { $0.key < $1.key }.map(\.value)
            return [
                "format": t.format.rawValue,
                "label": Formats.label(t.format),
                "kind": Formats.kind(t.format).rawValue,
                "multiHop": t.isMultiHop,
                "shownByDefault": routes.allSatisfy(\.isShownByDefault),
                "routes": routes.map(route),
            ]
        }
    }

    // MARK: Options

    static func kind(_ k: OptionKind) -> [String: Any] {
        switch k {
        case .slider(let lo, let hi, let step, let unit):
            var d: [String: Any] = ["kind": "slider", "min": lo, "max": hi, "step": step]
            if let unit { d["unit"] = unit }
            return d
        case .integer(let lo, let hi, let unit):
            var d: [String: Any] = ["kind": "integer", "min": lo, "max": hi]
            if let unit { d["unit"] = unit }
            return d
        case .decimal(let lo, let hi, let step):
            return ["kind": "decimal", "min": JSON.number(lo, places: 4), "max": JSON.number(hi, places: 4),
                    "step": JSON.number(step, places: 4)]
        case .toggle: return ["kind": "toggle"]
        case .choice(let choices):
            return ["kind": "choice", "choices": choices.map { ["id": $0.id, "label": $0.label] }]
        case .fileSize: return ["kind": "fileSize", "unit": "bytes"]
        case .pageRange: return ["kind": "pageRange"]
        case .timeRange: return ["kind": "timeRange"]
        case .color: return ["kind": "color"]
        case .rect: return ["kind": "rect"]
        case .text: return ["kind": "text"]
        }
    }

    static func spec(_ s: OptionSpec) -> [String: Any] {
        var d = kind(s.kind)
        d["id"] = s.id
        d["label"] = s.label
        d["default"] = JSON.value(s.defaultValue)
        if let help = s.help { d["help"] = help }
        if !s.visibleWhen.isEmpty { d["visibleWhen"] = JSON.values(OptionValues(s.visibleWhen)) }
        return d
    }

    static func schema(_ s: OptionsSchema) -> [String: Any] {
        ["schema": s.id, "options": s.specs.map(spec)]
    }

    /// `anyfmt options <format>`: the saved-default / preset schema for a target.
    static func options(for format: FormatID) -> [String: Any]? {
        guard let s = OptionsSchema.forTarget(format) else { return nil }
        var d = schema(s)
        d["format"] = format.rawValue
        return d
    }

    /// Every target format's options.
    static func allOptions() -> [String: Any] {
        let targets = Set(router.table.rows.map(\.to)).sorted()
        var d: [String: Any] = [:]
        for t in targets { if let o = options(for: t) { d[t.rawValue] = o } }
        return d
    }

    // MARK: Tools

    static func tool(_ t: ToolSpec) -> [String: Any] {
        let local = t.cloudFeature == nil
        var arity: [String: Any] = ["kind": "perFile"]
        if case .combine(let minimum) = t.arity { arity = ["kind": "combine", "minimum": minimum] }
        return [
            "id": t.id.rawValue,
            "title": t.title,
            "kinds": t.kinds.map(\.rawValue).sorted(),
            "formats": t.formats.map(\.rawValue).sorted(),
            "arity": arity,
            "cloud": !local,
            "available": local && ToolRegistry.default.ids.contains(t.id),
            "suffix": t.outputSuffix,
            "options": t.schema.specs.map(spec),
        ]
    }

    static func tools() -> [[String: Any]] { ToolCatalog.all.map(tool) }

    // MARK: Presets

    static func preset(_ p: ConversionPreset, hidden: Bool = false) -> [String: Any] {
        ["id": p.id, "format": p.format.rawValue, "title": p.title, "builtIn": p.isBuiltIn,
         "hidden": hidden, "values": JSON.values(p.values)]
    }

    /// User presets, then visible built-ins, per format (sorted by format id).
    /// With `includeHidden`, hidden built-ins follow with `"hidden": true`.
    static func presets(format: FormatID? = nil, includeHidden: Bool = false) -> [[String: Any]] {
        let store = CLIPaths.presets
        let formats = format.map { [$0] }
            ?? Set(PresetStore.allBuiltIns.map(\.format) + store.allUserPresets().map(\.format)).sorted()
        return formats.flatMap { f in
            store.presets(for: f).map { preset($0) }
                + (includeHidden ? store.hiddenBuiltIns(for: f).map { preset($0, hidden: true) } : [])
        }
    }

    /// A preset by id, or by title (case-insensitive) within `format`.
    static func findPreset(_ key: String, format: FormatID?) -> ConversionPreset? {
        let store = CLIPaths.presets
        let pool: [ConversionPreset]
        if let format {
            pool = store.presets(for: format)
        } else {
            let formats = Set(PresetStore.allBuiltIns.map(\.format) + store.allUserPresets().map(\.format)).sorted()
            pool = formats.flatMap { store.presets(for: $0) + store.hiddenBuiltIns(for: $0) }
        }
        return pool.first { $0.id == key }
            ?? pool.first { $0.title.compare(key, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    // MARK: Exit codes and events

    static func exitCodes() -> [[String: Any]] {
        ExitCode.allCases.map { ["code": Int($0.rawValue), "name": $0.name, "meaning": $0.meaning] }
    }

    static let events: [[String: Any]] = [
        ["event": "start", "fields": ["jobs"]],
        ["event": "progress", "fields": ["file", "fraction"]],
        ["event": "output", "fields": ["file", "path"]],
        ["event": "skip", "fields": ["file", "reason"]],
        ["event": "error", "fields": ["file", "code", "message"]],
        ["event": "done", "fields": ["succeeded", "failed", "skipped", "exitCode"]],
    ]

    // MARK: Schema

    /// `anyfmt schema`: everything an agent needs to plan, in one document.
    static func everything() -> [String: Any] {
        [
            "schemaVersion": schemaVersion,
            "cli": ["name": Brand.cliName, "version": cliVersion, "licence": Brand.licence],
            "exitCodes": exitCodes(),
            "events": events,
            "formats": formats(),
            "routes": routes(),
            "options": allOptions(),
            "tools": tools(),
            "presets": presets(includeHidden: true),
            "mcp": ["protocolVersions": MCPServer.supportedVersions, "tools": MCPTools.definitions.map { $0["name"] ?? "" }],
        ]
    }
}
