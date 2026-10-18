import AppKit
import HaloCore
import RadialMenu

/// Decides what each wheel offers for a set of dragged files, and turns that
/// into radial items.
///
/// Rules:
/// - Convert: targets every input can reach (the router intersects multi-file
///   drags and skips inputs already in the target format). Favourites first, in
///   their order; then targets of the input's own kind (a video's video formats
///   before its audio and GIF ones), then the rest in the router's order. Hidden
///   formats and `.hiddenByDefault` rows are dropped unless the user showed them. Folders and mixed selections get whatever the router
///   offers for all of them (archive targets when the archive lane ships them).
/// - Tools: only tools that apply to every input (and whose arity is met).
/// - Actions: always the full set; they work on anything, folders included.
/// - Any wheel that would be empty falls back to Actions (see `resolve`), with
///   the hub explaining why. A dead wheel with one disabled segment is a dead end.
public struct WheelContentProvider: Sendable {
    /// Router lookup (injected so tests and the gallery use fixed tables).
    public var targets: @Sendable ([FormatID]) -> [RouteTarget]
    public var tools: @Sendable ([FormatID]) -> [ToolSpec]
    public var actions: @Sendable () -> [ActionSpec]

    public init(targets: @escaping @Sendable ([FormatID]) -> [RouteTarget],
                tools: @escaping @Sendable ([FormatID]) -> [ToolSpec] = { ToolCatalog.tools(for: $0) },
                actions: @escaping @Sendable () -> [ActionSpec] = { ActionCatalog.all }) {
        self.targets = targets
        self.tools = tools
        self.actions = actions
    }

    /// Uses the live router (engines available right now), built once.
    public static func live() -> WheelContentProvider {
        let router = Router.live()
        return WheelContentProvider(targets: { router.commonTargets(for: $0) })
    }

    public init(router: Router) {
        self.init(targets: { router.commonTargets(for: $0) })
    }

    /// Entries for `kind`. May be empty (see `resolve` for the fallback).
    public func entries(for input: WheelInput, kind: WheelKind, preferences: WheelPreferences) -> [WheelEntry] {
        let detected = input.formats
        let known = detected.compactMap { $0 }
        let allKnown = !detected.isEmpty && known.count == detected.count
        let raw: [WheelEntry]
        switch kind {
        case .convert:
            raw = allKnown ? convertEntries(known, preferences: preferences) : []
        case .tools:
            raw = allKnown ? tools(known).filter { !preferences.hiddenTools.contains($0.id) }.map(WheelEntry.tool) : []
        case .actions:
            raw = actions().map(WheelEntry.action)
        }
        return CloudSegments.filter(raw, showCloudItems: preferences.showCloudItems)
    }

    /// What to actually show for a requested kind: the kind itself, or Actions
    /// when it has nothing to offer. `note` explains the fallback in the hub.
    public func resolve(_ input: WheelInput, kind: WheelKind, preferences: WheelPreferences)
        -> (kind: WheelKind, entries: [WheelEntry], note: String?) {
        let entries = entries(for: input, kind: kind, preferences: preferences)
        if !entries.isEmpty || kind == .actions { return (kind, entries, nil) }
        let note: String
        switch kind {
        case .convert: note = String(localized: "No conversions", comment: "Hub text when a file has no conversion targets")
        case .tools: note = String(localized: "No tools", comment: "Hub text when no editing tool applies")
        case .actions: note = ""
        }
        return (.actions, self.entries(for: input, kind: .actions, preferences: preferences), note)
    }

    private func convertEntries(_ formats: [FormatID], preferences: WheelPreferences) -> [WheelEntry] {
        let all = targets(formats).filter { target in
            if preferences.hiddenFormats.contains(target.format) { return false }
            let hiddenByDefault = target.routes.values.contains { $0.hops.last?.flags.contains(.hiddenByDefault) == true }
            if hiddenByDefault {
                return preferences.shownFormats.contains(target.format) || preferences.favouriteFormats.contains(target.format)
            }
            return true
        }
        let rank = Dictionary(preferences.favouriteFormats.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        let inputKinds = Set(formats.map(Formats.kind))
        func affinity(_ f: FormatID) -> Int { inputKinds.contains(Formats.kind(f)) ? 0 : 1 }
        // Stable: favourites by rank, then same-kind targets, then the router's kind/catalogue order.
        let ordered = all.enumerated().sorted { a, b in
            let ra = rank[a.element.format] ?? Int.max, rb = rank[b.element.format] ?? Int.max
            if ra != rb { return ra < rb }
            let ka = affinity(a.element.format), kb = affinity(b.element.format)
            return ka != kb ? ka < kb : a.offset < b.offset
        }
        return ordered.map { WheelEntry.convert($0.element) }
    }

    // MARK: Items

    /// Radial items for entries, with Pro decoration applied by `cloud`.
    @MainActor
    public static func items(for entries: [WheelEntry], cloud: CloudSegments) -> [RadialItem] {
        entries.map { cloud.decorate(item(for: $0), for: $0) }
    }

    @MainActor
    static func item(for entry: WheelEntry) -> RadialItem {
        switch entry {
        case .convert(let target):
            let format = Formats.format(target.format)
            let label = Formats.label(target.format)
            let via = viaFormat(of: target).map { String(localized: "via \(Formats.label($0))", comment: "Multi-step conversion hint, e.g. via PNG") }
            let name = format?.name ?? label
            var spoken = String(localized: "Convert to \(name)", comment: "VoiceOver label of a conversion segment")
            if let via { spoken += ", \(via)" }
            return RadialItem(id: entry.id, title: label, subtitle: via,
                              image: symbol(format?.glyph ?? Formats.kind(target.format).glyph),
                              prominence: .title, accessibilityLabel: spoken,
                              accessibilityHint: String(localized: "Saves a converted copy beside the original",
                                                        comment: "VoiceOver hint of a conversion segment"))
        case .tool(let tool):
            return RadialItem(id: entry.id, title: tool.title, image: symbol(tool.glyph), prominence: .glyph,
                              accessibilityLabel: tool.title,
                              accessibilityHint: tool.needsEditor
                                  ? String(localized: "Opens an editor, then saves a new copy", comment: "VoiceOver hint of an editor tool")
                                  : String(localized: "Saves a new copy beside the original", comment: "VoiceOver hint of an instant tool"))
        case .action(let action):
            return RadialItem(id: entry.id, title: action.title, image: symbol(action.glyph), prominence: .glyph,
                              accessibilityLabel: action.title)
        }
    }

    /// The first intermediate format of a multi-hop route ("via PNG").
    static func viaFormat(of target: RouteTarget) -> FormatID? {
        guard target.isMultiHop else { return nil }
        let route = target.routes.values.sorted { $0.from < $1.from }.first { !$0.isDirect }
        return route?.hops.first?.to
    }

    /// SF Symbol with a safe fallback (names missing on older systems).
    @MainActor
    static func symbol(_ name: String) -> NSImage? {
        RadialItem.symbol(name) ?? RadialItem.symbol("circle.dashed")
    }
}
