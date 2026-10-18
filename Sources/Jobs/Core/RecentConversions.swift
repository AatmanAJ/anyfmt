import Foundation

/// One entry in the menu bar's "Recent conversions".
public struct RecentConversion: Sendable, Hashable, Identifiable {
    public let id: UUID
    /// "photo.heic → JPG"
    public let title: String
    public let outputs: [URL]
    public let date: Date

    public init(id: UUID = UUID(), title: String, outputs: [URL], date: Date = Date()) {
        self.id = id
        self.title = title
        self.outputs = outputs
        self.date = date
    }
}

/// The last 10 finished outputs, newest first, persisted as JSON in
/// `Application Support/<Brand.name>/recents.json`.
///
/// Entries whose files were deleted are pruned whenever the list is read (an
/// entry survives while at least one of its outputs exists). Thread-safe.
public final class RecentConversions: @unchecked Sendable {
    public static let limit = 10
    public static let shared = RecentConversions()

    public let fileURL: URL
    private let lock = NSLock()
    private var cache: [RecentConversion]?

    /// - Parameter directory: where `recents.json` lives (tests pass a temp dir).
    public init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDirectory
        fileURL = dir.appendingPathComponent("recents.json")
    }

    public static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent(Brand.name, isDirectory: true)
    }

    /// Newest first, stale entries removed (and the pruned list saved).
    public var items: [RecentConversion] {
        lock.withLock {
            let current = loadLocked()
            let pruned = current.compactMap { item -> RecentConversion? in
                let alive = item.outputs.filter { FileManager.default.fileExists(atPath: $0.path) }
                if alive.isEmpty { return nil }
                return alive.count == item.outputs.count ? item
                    : RecentConversion(id: item.id, title: item.title, outputs: alive, date: item.date)
            }
            if pruned != current { saveLocked(pruned) }
            return pruned
        }
    }

    public func add(title: String, outputs: [URL], date: Date = Date()) {
        guard !outputs.isEmpty else { return }
        lock.withLock {
            var list = loadLocked()
            // The same output again (retry, re-reveal) moves to the top instead of duplicating.
            let paths = Set(outputs.map(\.path))
            list.removeAll { !paths.isDisjoint(with: $0.outputs.map(\.path)) }
            list.insert(RecentConversion(title: title, outputs: outputs, date: date), at: 0)
            saveLocked(Array(list.prefix(Self.limit)))
        }
    }

    /// Records a succeeded job; ignores anything else.
    public func add(_ record: JobRecord) {
        guard case .succeeded(let urls) = record.state else { return }
        add(title: record.title, outputs: urls, date: record.finishedAt ?? Date())
    }

    public func remove(_ id: UUID) {
        lock.withLock { saveLocked(loadLocked().filter { $0.id != id }) }
    }

    public func clear() {
        lock.withLock { saveLocked([]) }
    }

    // MARK: Storage

    private struct Stored: Codable {
        var id: UUID
        var title: String
        var paths: [String]
        var date: Date
    }

    private struct File: Codable {
        var version = 1
        var items: [Stored]
    }

    private func loadLocked() -> [RecentConversion] {
        if let cache { return cache }
        var loaded: [RecentConversion] = []
        if let data = try? Data(contentsOf: fileURL) {
            do {
                let file = try Self.decoder.decode(File.self, from: data)
                loaded = file.items.map {
                    RecentConversion(id: $0.id, title: $0.title, outputs: $0.paths.map { URL(fileURLWithPath: $0) }, date: $0.date)
                }
            } catch {
                Log.jobs.error("recents unreadable, starting fresh: \(error.localizedDescription, privacy: .public)")
            }
        }
        cache = loaded
        return loaded
    }

    private func saveLocked(_ list: [RecentConversion]) {
        cache = list
        let file = File(items: list.map { Stored(id: $0.id, title: $0.title, paths: $0.outputs.map(\.path), date: $0.date) })
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Self.encoder.encode(file).write(to: fileURL, options: .atomic)
        } catch {
            Log.jobs.error("couldn't save recents: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }

    private static var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
