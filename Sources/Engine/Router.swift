import Foundation

/// A planned chain of capabilities from one format to another.
public struct Route: Sendable, Hashable, CustomStringConvertible {
    public let hops: [Capability]
    public init(_ hops: [Capability]) { self.hops = hops }

    public var from: FormatID { hops.first?.from ?? "" }
    public var to: FormatID { hops.last?.to ?? "" }
    public var isDirect: Bool { hops.count == 1 }
    public var cost: Double { Router.cost(of: hops) }
    /// Options schema the user sees for this route = the final hop's schema.
    public var schema: OptionsSchema { hops.last?.schema ?? .none }
    public var description: String {
        ([from.rawValue] + hops.map { "\($0.to.rawValue)(\($0.engine))" }).joined(separator: " → ")
    }
}

/// A target offered for a set of dragged files.
public struct RouteTarget: Sendable, Hashable, Identifiable {
    public let format: FormatID
    /// Route per distinct input format. Inputs already in `format` are absent (skipped).
    public let routes: [FormatID: Route]
    public var id: FormatID { format }
    /// True if any file needs more than one hop (shown as a subtle "via" hint).
    public var isMultiHop: Bool { routes.values.contains { !$0.isDirect } }
    /// Schema shown in the options popover: union of final-hop schemas, first wins per key.
    public var schema: OptionsSchema {
        var seen = Set<String>()
        var specs: [OptionSpec] = []
        for r in routes.values.sorted(by: { $0.from < $1.from }) {
            for s in r.schema.specs where seen.insert(s.id).inserted { specs.append(s) }
        }
        return OptionsSchema("target.\(format.rawValue)", specs)
    }
}

/// Multi-hop route planning over the capability table.
///
/// Rules:
/// - At most `maxHops` (3) steps.
/// - Crossing between still kinds (image/PDF/docs/…) and time-based kinds
///   (audio/video) is only allowed as a single direct step. So PNG→GIF→MP4 is
///   never planned, but GIF→MP4 (a direct row) is.
/// - `.multiOutput` and `.terminalOnly` rows may only be the last step.
/// - `.combine` rows are never chained.
/// - Cost = Σ row cost + 0.5 per extra hop + 1 per lossy intermediate + 4 per
///   structure-losing step, so direct/native/lossless paths win.
public struct Router: Sendable {
    public static let maxHops = 3
    public let table: CapabilityTable
    private let edges: [FormatID: [Capability]]

    public init(table: CapabilityTable) {
        self.table = table
        var e: [FormatID: [Capability]] = [:]
        for row in table.bestRows() { e[row.from, default: []].append(row) }
        for k in e.keys { e[k]?.sort { ($0.to, $0.priority) < ($1.to, $1.priority) } }
        edges = e
    }

    /// Router over the default table filtered to engines available right now.
    public static func live(registry: EngineRegistry = .default) -> Router {
        Router(table: CapabilityTable.default.available(in: registry))
    }

    static func cost(of hops: [Capability]) -> Double {
        var c = 0.0
        for (i, h) in hops.enumerated() {
            c += h.cost
            if i > 0 { c += 0.5 }
            let isLast = i == hops.count - 1
            if !isLast && !h.flags.contains(.lossless) { c += 1 }
            if h.flags.contains(.lossyStructure) { c += 4 }
        }
        return c
    }

    private func allowed(_ path: [Capability], start: FormatID) -> Bool {
        guard path.count > 1 else { return true }
        let startTimed = Formats.kind(start).isTimeBased
        // No crossing still⇄time-based except as the single direct step.
        for h in path where Formats.kind(h.to).isTimeBased != startTimed { return false }
        for h in path.dropLast() where h.flags.contains(.multiOutput) || h.flags.contains(.terminalOnly) {
            return false
        }
        return !path.contains { $0.arity == .combine }
    }

    /// Cheapest route from → to, or nil.
    public func route(from: FormatID, to: FormatID) -> Route? {
        guard from != to else { return nil }
        return allRoutes(from: from)[to]
    }

    /// Best route to every reachable format from `from` (bounded Dijkstra over paths).
    public func allRoutes(from start: FormatID) -> [FormatID: Route] {
        var best: [FormatID: Route] = [:]
        // Frontier of partial paths. Small graph (≈70 nodes, ≤3 hops) → exhaustive is cheap.
        var frontier: [[Capability]] = (edges[start] ?? []).map { [$0] }
        while !frontier.isEmpty {
            var next: [[Capability]] = []
            for path in frontier {
                guard allowed(path, start: start), let last = path.last else { continue }
                let target = last.to
                if target == start { continue }
                if path.dropLast().contains(where: { $0.to == target }) { continue } // no cycles
                let candidate = Route(path)
                if let cur = best[target], cur.cost <= candidate.cost { /* keep cheaper */ } else { best[target] = candidate }
                if path.count < Router.maxHops {
                    for e in edges[target] ?? [] where e.to != start { next.append(path + [e]) }
                }
            }
            frontier = next
        }
        return best
    }

    /// Targets every input can produce (inputs already in that format are skipped,
    /// but at least one input must need converting). Sorted by kind then catalogue order.
    public func commonTargets(for inputs: [FormatID]) -> [RouteTarget] {
        let distinct = Array(Set(inputs)).sorted()
        guard !distinct.isEmpty else { return [] }
        let routesByInput = Dictionary(uniqueKeysWithValues: distinct.map { ($0, allRoutes(from: $0)) })
        var candidates = Set<FormatID>()
        for (_, r) in routesByInput { candidates.formUnion(r.keys) }
        var out: [RouteTarget] = []
        for t in candidates {
            var routes: [FormatID: Route] = [:]
            var ok = true
            for i in distinct {
                if i == t { continue }
                guard let r = routesByInput[i]?[t] else { ok = false; break }
                routes[i] = r
            }
            if ok && !routes.isEmpty { out.append(RouteTarget(format: t, routes: routes)) }
        }
        return out.sorted { a, b in
            let fa = Formats.format(a.format), fb = Formats.format(b.format)
            let ka = FileKind.allCases.firstIndex(of: fa?.kind ?? .other) ?? 99
            let kb = FileKind.allCases.firstIndex(of: fb?.kind ?? .other) ?? 99
            return (ka, fa?.order ?? 999, a.format.rawValue) < (kb, fb?.order ?? 999, b.format.rawValue)
        }
    }

    /// Number of distinct (input, output) conversion options offered. `make matrix` prints this.
    public func optionCount(inputs: [FormatID]? = nil) -> Int {
        let starts = inputs ?? Array(Set(table.rows.map(\.from)))
        return starts.reduce(0) { $0 + allRoutes(from: $1).count }
    }
}
