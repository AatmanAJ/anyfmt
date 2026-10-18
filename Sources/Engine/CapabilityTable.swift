import Foundation

/// THE capability table. The wheel, the CLI, the router and the tests all
/// read this. It is the concatenation of each lane's declarative rows:
///
///   Engine/Image/ImageRoutes.swift        (lane D: images, SVG, PDF)
///   Engine/AV/AVRoutes.swift              (lane E: audio, video)
///   Engine/Subtitles/SubtitleRoutes.swift (lane E: SRT/VTT)
///   Engine/Docs/DocsRoutes.swift          (lane F: documents, slides, sheets, EPUB)
///   Engine/Archive/ArchiveRoutes.swift    (lane F: archives, folders)
///
/// Adding a format = one row in the lane file + one engine method.
public struct CapabilityTable: Sendable {
    public let rows: [Capability]

    public init(_ rows: [Capability]) { self.rows = rows }

    public static let `default` = CapabilityTable(
        ImageRoutes.rows + AVRoutes.rows + SubtitleRoutes.rows + DocsRoutes.rows + ArchiveRoutes.rows
    )

    /// Rows whose engine is registered and available at runtime.
    public func available(in registry: EngineRegistry) -> CapabilityTable {
        CapabilityTable(rows.filter { registry.isAvailable($0) })
    }

    /// Best row per (from, to) pair: highest priority, then lowest cost.
    public func bestRows() -> [Capability] {
        var best: [String: Capability] = [:]
        for r in rows {
            let k = "\(r.from.rawValue)>\(r.to.rawValue)"
            if let cur = best[k], (cur.priority, -cur.cost) >= (r.priority, -r.cost) { continue }
            best[k] = r
        }
        return Array(best.values)
    }

    /// Integrity problems: duplicate rows (same pair + engine), unknown formats,
    /// engines without an implementation. Empty array = healthy.
    public func integrityIssues(registry: EngineRegistry) -> [String] {
        var issues: [String] = []
        var seen = Set<String>()
        for r in rows {
            let k = "\(r.from)>\(r.to)@\(r.engine)"
            if !seen.insert(k).inserted { issues.append("duplicate row \(k)") }
            if Formats.format(r.from) == nil { issues.append("unknown source format \(r.from) in \(k)") }
            if Formats.format(r.to) == nil { issues.append("unknown target format \(r.to) in \(k)") }
            if r.from == r.to { issues.append("identity row \(k)") }
            if registry[r.engine] == nil { issues.append("orphan row: engine \(r.engine) not registered (\(k))") }
        }
        let used = Set(rows.map(\.engine))
        for e in registry.ids where !used.contains(e) { issues.append("orphan engine \(e): no rows") }
        return issues
    }
}
