import Foundation
import CoreGraphics

/// How an item lies on the pile: a small fixed tilt and offset, like a print
/// dropped on a desk. Derived from the item's id, so it never reshuffles when
/// items are added or removed.
public struct ShelfPose: Equatable, Sendable {
    /// Radians; within ±`maxAngle`.
    public let angle: CGFloat
    /// Points; within ±`maxOffset`.
    public let dx: CGFloat
    public let dy: CGFloat

    public static let maxAngle: CGFloat = 7 * .pi / 180
    public static let maxOffset: CGFloat = 3

    public static func pose(for id: UUID) -> ShelfPose {
        let b = id.uuid
        // Map three bytes to [-1, 1]. UUIDv4 bytes 0–2 are fully random.
        func unit(_ byte: UInt8) -> CGFloat { CGFloat(byte) / 127.5 - 1 }
        return ShelfPose(angle: unit(b.0) * maxAngle,
                         dx: unit(b.1) * maxOffset,
                         dy: unit(b.2) * maxOffset * 0.6)
    }
}

/// One thing parked on the shelf. The shelf references files where they are;
/// it never copies them.
public struct ShelfItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public private(set) var url: URL
    public let addedAt: Date
    /// Lets the shelf follow the file if it's renamed or moved while parked.
    public private(set) var bookmark: Data?

    public init(id: UUID = UUID(), url: URL, addedAt: Date = Date(), bookmark: Data? = nil) {
        self.id = id
        self.url = url
        self.addedAt = addedAt
        self.bookmark = bookmark
    }

    public var name: String { url.lastPathComponent }
    public var pose: ShelfPose { ShelfPose.pose(for: id) }

    mutating func relocate(to newURL: URL, bookmark: Data?) {
        url = newURL
        if let bookmark { self.bookmark = bookmark }
    }
}

/// What changed, so the view can animate exactly that.
public struct ShelfChange: Equatable, Sendable {
    public var added: [ShelfItem] = []
    /// Already on the shelf: brought back to the top of the pile.
    public var raised: [ShelfItem] = []
    public var removed: [ShelfItem] = []
    /// Removed because they were dragged out (the view fades them instead of
    /// dropping them off the pile: they already left with the drag).
    public var leftByDrag = false
    /// Followed a rename/move.
    public var relocated: [ShelfItem] = []

    public var isEmpty: Bool { added.isEmpty && raised.isEmpty && removed.isEmpty && relocated.isEmpty }
}

/// The shelf's contents, without any window. Items are kept in the order they
/// arrived (oldest first); the pile shows the newest on top.
public struct ShelfModel: Sendable, Equatable {
    /// How many items the collapsed pile draws (the rest are under them).
    public static let visibleStackDepth = 3

    public private(set) var items: [ShelfItem] = []

    public init(items: [ShelfItem] = []) {
        self.items = items
    }

    public var isEmpty: Bool { items.isEmpty }
    public var count: Int { items.count }
    public var urls: [URL] { items.map(\.url) }

    /// Newest first, at most `visibleStackDepth`: index 0 is the top of the pile.
    public var stack: [ShelfItem] { Array(items.reversed().prefix(Self.visibleStackDepth)) }

    public func contains(_ url: URL) -> Bool {
        let key = Self.key(url)
        return items.contains { Self.key($0.url) == key }
    }

    public func item(id: UUID) -> ShelfItem? { items.first { $0.id == id } }

    /// Adds files to the top of the pile. Duplicates (same file, also within
    /// `urls`) aren't added twice: an item that's already parked is raised to
    /// the top instead.
    @discardableResult
    public mutating func add(_ urls: [URL], now: Date = Date(), bookmark: (URL) -> Data? = { _ in nil }) -> ShelfChange {
        var change = ShelfChange()
        var seen = Set<String>()
        for url in urls {
            let key = Self.key(url)
            guard seen.insert(key).inserted else { continue }
            if let i = items.firstIndex(where: { Self.key($0.url) == key }) {
                let existing = items.remove(at: i)
                items.append(existing)
                change.raised.append(existing)
            } else {
                let item = ShelfItem(url: url.standardizedFileURL, addedAt: now, bookmark: bookmark(url))
                items.append(item)
                change.added.append(item)
            }
        }
        return change
    }

    @discardableResult
    public mutating func remove(ids: Set<UUID>) -> ShelfChange {
        var change = ShelfChange()
        change.removed = items.filter { ids.contains($0.id) }
        items.removeAll { ids.contains($0.id) }
        return change
    }

    @discardableResult
    public mutating func remove(urls: [URL]) -> ShelfChange {
        let keys = Set(urls.map(Self.key))
        return remove(ids: Set(items.filter { keys.contains(Self.key($0.url)) }.map(\.id)))
    }

    @discardableResult
    public mutating func removeAll() -> ShelfChange {
        var change = ShelfChange()
        change.removed = items
        items.removeAll()
        return change
    }

    /// Drops items whose file is gone and follows ones that moved.
    /// `locate` returns the item's current URL (and a fresh bookmark if it
    /// changed), or nil if the file no longer exists anywhere.
    @discardableResult
    public mutating func refresh(locate: (ShelfItem) -> (url: URL, bookmark: Data?)?) -> ShelfChange {
        var change = ShelfChange()
        var kept: [ShelfItem] = []
        for var item in items {
            guard let found = locate(item) else {
                change.removed.append(item)
                continue
            }
            if Self.key(found.url) != Self.key(item.url) {
                item.relocate(to: found.url.standardizedFileURL, bookmark: found.bookmark)
                change.relocated.append(item)
            }
            kept.append(item)
        }
        // A relocation can make two items the same file; keep the older one.
        var seen = Set<String>()
        items = kept.filter { item in
            let fresh = seen.insert(Self.key(item.url)).inserted
            if !fresh { change.removed.append(item) }
            return fresh
        }
        return change
    }

    /// Identity of a file on the shelf: standardized and symlink-resolved path.
    static func key(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}

/// When the shelf should be on screen, independent of any window, so the
/// rules can be tested: it appears when something lands on it, hides when
/// toggled, and dismisses itself once it's empty. An empty shelf opened from
/// the menu bar stays up as a drop target until it's toggled off or
/// something is added and later removed.
public struct ShelfPresence: Equatable, Sendable {
    public private(set) var isVisible = false
    /// Opened empty on purpose (menu bar toggle).
    public private(set) var isHeldOpenEmpty = false

    public init() {}

    public enum Effect: Equatable, Sendable { case none, show, hide }

    public mutating func itemsAdded(_ model: ShelfModel) -> Effect {
        isHeldOpenEmpty = false
        guard !model.isEmpty, !isVisible else { return .none }
        isVisible = true
        return .show
    }

    public mutating func itemsRemoved(_ model: ShelfModel) -> Effect {
        guard model.isEmpty, isVisible, !isHeldOpenEmpty else { return .none }
        isVisible = false
        return .hide
    }

    public mutating func toggle(_ model: ShelfModel) -> Effect {
        if isVisible {
            isVisible = false
            isHeldOpenEmpty = false
            return .hide
        }
        isVisible = true
        isHeldOpenEmpty = model.isEmpty
        return .show
    }
}
