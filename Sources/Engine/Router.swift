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

    /// Whether the wheel offers this route without the user switching it on in
    /// Settings › Formats. Hidden: anything through a `.hiddenByDefault` row, and
    /// multi-hop routes that jump between families (a photo → DOCX via PDF + OCR).
    /// Direct rows, routes within a family and anything ending in PDF stay visible.
    /// Every route is still shipped: CLI, matrix, and opt-in on the wheel.
    public var isShownByDefault: Bool {
        if hops.contains(where: { $0.flags.contains(.hiddenByDefault) }) { return false }
        if isDirect || Formats.kind(to) == .pdf { return true }
        return Self.family(Formats.kind(from)) == Self.family(Formats.kind(to))
    }

    static func family(_ kind: FileKind) -> String {
        switch kind {
        case .image, .vector: "visual"
        case .document, .ebook: "text"
        case .archive, .folder: "archive"
        default: kind.rawValue
        }
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
    /// Per-instance memo of `allRoutes(from:)`. A Router is immutable, so its
    /// answers never change and the memo never needs invalidating; a new table
    /// means a new Router (see `cached(for:)`).
    private let memo = RouteMemo()

    public init(table: CapabilityTable) {
        self.table = table
        var e: [FormatID: [Capability]] = [:]
        for row in table.bestRows() { e[row.from, default: []].append(row) }
        for k in e.keys { e[k]?.sort { ($0.to, $0.priority) < ($1.to, $1.priority) } }
        edges = e
    }

    /// Router over the default table filtered to engines available right now.
    /// Cheap to call repeatedly: while the available rows are unchanged the same
    /// Router (with its warm route memo) is returned. Installing a pack or a
    /// binary appearing changes the rows, which builds a fresh Router.
    public static func live(registry: EngineRegistry = .default) -> Router {
        cached(for: LiveAvailability.shared.table(registry: registry))
    }

    /// Re-evaluate engine availability now (a pack was installed or removed, an
    /// opt-in changed). Otherwise availability is re-checked at most every 2 s.
    public static func invalidateLive() {
        LiveAvailability.shared.invalidate()
    }

    /// Plans routes from every format the live table reads, so no drag pays a
    /// cold search (≈10 ms for the first file of a format). Call off the main
    /// thread; the work lands in the memo `live()` hands back.
    public static func warmLive(registry: EngineRegistry = .default) {
        _ = live(registry: registry).optionCount()
    }

    /// The memoised Router for `table`, rebuilt only when the rows change.
    static func cached(for table: CapabilityTable) -> Router {
        LiveRouterCache.shared.router(for: table)
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
    /// Memoised per start format.
    public func allRoutes(from start: FormatID) -> [FormatID: Route] {
        memo.routes(from: start) { computeAllRoutes(from: start) }
    }

    /// The uncached search behind `allRoutes(from:)`.
    func computeAllRoutes(from start: FormatID) -> [FormatID: Route] {
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

    /// Start formats already memoised (tests).
    var memoizedStartCount: Int { memo.count }
}

/// Thread-safe memo of best routes per start format for one Router instance.
final class RouteMemo: @unchecked Sendable {
    private let lock = NSLock()
    private var byStart: [FormatID: [FormatID: Route]] = [:]

    func routes(from start: FormatID, compute: () -> [FormatID: Route]) -> [FormatID: Route] {
        if let hit = lock.withLock({ byStart[start] }) { return hit }
        // Computed outside the lock: two threads racing on a cold start format
        // both do the same pure work once, which beats serialising every caller.
        let fresh = compute()
        lock.withLock { byStart[start] = fresh }
        return fresh
    }

    var count: Int { lock.withLock { byStart.count } }
}

/// The Router `Router.live()` hands out, keyed by the exact available rows.
final class LiveRouterCache: @unchecked Sendable {
    static let shared = LiveRouterCache()
    private let lock = NSLock()
    private var rows: [Capability]?
    private var router: Router?

    func router(for table: CapabilityTable) -> Router {
        lock.withLock {
            // Array == is element-wise but short-circuits on shared storage, and
            // rows share their static schemas, so this is microseconds.
            if let rows, let router, rows == table.rows { return router }
            let fresh = Router(table: table)
            rows = table.rows
            router = fresh
            return fresh
        }
    }
}

/// Availability of the default table, re-evaluated at most every `ttl` seconds.
/// Checking ~650 rows (some stat bundled binaries) costs a few milliseconds, too
/// much for every wheel show; within a drag nothing about the Mac changes.
/// An expired snapshot is still answered at once and refreshed in the
/// background, so only the first call (or one after `invalidate()`) waits.
final class LiveAvailability: @unchecked Sendable {
    static let shared = LiveAvailability()
    private let lock = NSLock()
    private let ttl: TimeInterval
    private var snapshot: (ids: Set<EngineID>, at: TimeInterval, table: CapabilityTable)?
    private var refreshing = false
    /// Bumped by `invalidate()`, so a refresh that started earlier can't
    /// overwrite what came after it.
    private var generation = 0

    init(ttl: TimeInterval = 2) { self.ttl = ttl }

    /// When the current snapshot was taken (tests).
    var snapshotTime: TimeInterval? { lock.withLock { snapshot?.at } }

    func table(registry: EngineRegistry) -> CapabilityTable {
        let now = ProcessInfo.processInfo.systemUptime
        let ids = registry.ids
        if let s = lock.withLock({ snapshot }), s.ids == ids {
            if now - s.at >= ttl { refreshInBackground(registry: registry, ids: ids) }
            return s.table
        }
        return evaluate(registry: registry, ids: ids)
    }

    func invalidate() {
        lock.withLock {
            snapshot = nil
            generation += 1
        }
    }

    @discardableResult
    private func evaluate(registry: EngineRegistry, ids: Set<EngineID>) -> CapabilityTable {
        let started = lock.withLock { generation }
        let fresh = CapabilityTable.default.available(in: registry)
        lock.withLock {
            if generation == started { snapshot = (ids, ProcessInfo.processInfo.systemUptime, fresh) }
        }
        return fresh
    }

    private func refreshInBackground(registry: EngineRegistry, ids: Set<EngineID>) {
        let start = lock.withLock { () -> Bool in
            if refreshing { return false }
            refreshing = true
            return true
        }
        guard start else { return }
        DispatchQueue.global(qos: .utility).async {
            self.evaluate(registry: registry, ids: ids)
            self.lock.withLock { self.refreshing = false }
        }
    }
}
