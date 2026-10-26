import AppKit
import AnyfmtCore

/// The Float shelf: a floating pile of files you parked to
/// drag somewhere later.
///
/// - `add(urls:near:)` parks files (the Float action, drops onto the shelf).
///   They're referenced where they are, never copied.
/// - Drag the pile out to drag everything; drag one cell of the expanded grid
///   to drag one item. Drag-out behaves like a Finder drag (same disk moves,
///   other disk copies). **A plain drag-out removes the items from the shelf
///   once the drop succeeds; hold Option to copy and keep them on the shelf.**
/// - It follows files that are renamed or moved while parked, drops ones that
///   are deleted or trashed, and dismisses itself once it's empty.
/// - Nothing persists across launches except where you left it.
@MainActor
public final class FloatShelf: ObservableObject {
    public static let shared = FloatShelf()

    @Published public private(set) var isVisible = false
    @Published public private(set) var count = 0

    public private(set) var model = ShelfModel()
    private(set) var presence = ShelfPresence()
    private let presenter: ShelfPresenting
    private let preferences: ActionPreferences
    private let intake: PromiseIntake
    private let locate: (ShelfItem) -> (url: URL, bookmark: Data?)?
    private let makeBookmark: (URL) -> Data?
    private var refreshTimer: Timer?

    public var urls: [URL] { model.urls }

    convenience init() {
        self.init(presenter: ShelfWindowPresenter(), preferences: .shared, intake: PromiseIntake())
    }

    init(presenter: ShelfPresenting,
         preferences: ActionPreferences,
         intake: PromiseIntake,
         locate: @escaping (ShelfItem) -> (url: URL, bookmark: Data?)? = FloatShelf.locateOnDisk,
         makeBookmark: @escaping (URL) -> Data? = FloatShelf.bookmark) {
        self.presenter = presenter
        self.preferences = preferences
        self.intake = intake
        self.locate = locate
        self.makeBookmark = makeBookmark
        presenter.onCommand = { [weak self] in self?.handle($0) }
    }

    // MARK: Public API

    /// Shows or hides the shelf (menu bar item). Hiding keeps the items; an
    /// empty shelf opened this way stays up as a drop target.
    public func toggle() {
        apply(presence.toggle(model), near: nil)
    }

    /// Parks files on the shelf, popping it in at `point` (screen
    /// coordinates) if it isn't showing. Duplicates are raised, not re-added.
    public func add(urls: [URL], near point: CGPoint? = nil) {
        guard !urls.isEmpty else { return }
        let change = model.add(urls, bookmark: makeBookmark)
        let effect = presence.itemsAdded(model)
        if effect == .show {
            apply(effect, near: point)
        } else if !change.isEmpty {
            presenter.update(items: model.items, change: change)
        }
        publish()
    }

    public func remove(_ urls: [URL]) {
        commit(model.remove(urls: urls))
    }

    /// Empties the shelf (which then dismisses itself).
    public func clear() {
        if model.isEmpty {
            if presence.isVisible { apply(presence.toggle(model), near: nil) }
            return
        }
        commit(model.removeAll())
    }

    // MARK: Commands from the window

    func handle(_ command: ShelfCommand) {
        switch command {
        case .receive(let urls, let promises, let point):
            if !urls.isEmpty {
                add(urls: urls, near: point)
            } else if !promises.isEmpty {
                let pending = intake.begin(promises)
                Task { @MainActor in
                    do {
                        self.add(urls: try await pending.files(), near: point)
                    } catch {
                        Log.actions.error("shelf: promised files never arrived")
                        NSSound.beep()
                    }
                }
            }
        case .remove(let ids):
            commit(model.remove(ids: ids))
        case .clear:
            clear()
        case .reveal(let ids):
            NSWorkspace.shared.activateFileViewerSelecting(urls(for: ids))
        case .copy(let ids):
            FileClipboard.copyFiles(urls(for: ids))
        case .copyPaths(let ids):
            FileClipboard.copyText(PathFormatter.posixPaths(urls(for: ids)))
        case .airDrop(let ids):
            let files = urls(for: ids)
            let frame = presenter.cardFrame ?? .zero
            Task { @MainActor in
                let outcome = await AirDropSender.shared.send(files, near: CGPoint(x: frame.midX, y: frame.minY))
                if case .failed(let message) = outcome { Log.actions.error("shelf AirDrop: \(message, privacy: .public)") }
            }
        case .open(let ids):
            for url in urls(for: ids).prefix(20) { NSWorkspace.shared.open(url) }
        case .dragEnded(let ids, let operation, let keep):
            if Self.shouldRemoveAfterDrag(operation: operation, keepOnShelf: keep) {
                var change = model.remove(ids: ids)
                change.leftByDrag = true
                commit(change)
            }
            refresh()
        case .moved:
            if let f = presenter.cardFrame { preferences.shelfOrigin = f.origin }
        case .hovered:
            refresh()
        }
    }

    /// Plain drag-out that landed somewhere → leave the shelf. Option (copy)
    /// keeps it, unless the destination moved the file anyway.
    static func shouldRemoveAfterDrag(operation: NSDragOperation, keepOnShelf: Bool) -> Bool {
        guard !operation.isEmpty else { return false }
        return !keepOnShelf || operation.contains(.move)
    }

    /// Follows renamed/moved files and drops deleted or trashed ones.
    func refresh() {
        guard !model.isEmpty else { return }
        commit(model.refresh(locate: locate))
    }

    // MARK: Private

    private func urls(for ids: Set<UUID>?) -> [URL] {
        guard let ids else { return model.urls }
        return model.items.filter { ids.contains($0.id) }.map(\.url)
    }

    private func commit(_ change: ShelfChange) {
        guard !change.isEmpty else { return }
        presenter.update(items: model.items, change: change)
        apply(presence.itemsRemoved(model), near: nil)
        publish()
    }

    private func apply(_ effect: ShelfPresence.Effect, near point: CGPoint?) {
        switch effect {
        case .none:
            break
        case .show:
            presenter.show(items: model.items, near: point, savedOrigin: preferences.shelfOrigin)
            startRefreshing()
        case .hide:
            presenter.hide()
            stopRefreshing()
        }
        publish()
    }

    private func publish() {
        if isVisible != presence.isVisible { isVisible = presence.isVisible }
        if count != model.count { count = model.count }
    }

    private func startRefreshing() {
        guard refreshTimer == nil else { return }
        let t = Timer(timeInterval: 4, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        t.tolerance = 1.5
        RunLoop.main.add(t, forMode: .common)
        refreshTimer = t
    }

    private func stopRefreshing() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: Disk

    nonisolated static func bookmark(_ url: URL) -> Data? {
        try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    /// Where the item's file is now: its bookmark first (follows renames and
    /// moves), else its path. Trashed counts as gone.
    nonisolated static func locateOnDisk(_ item: ShelfItem) -> (url: URL, bookmark: Data?)? {
        let fm = FileManager.default
        if let data = item.bookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withoutUI, .withoutMounting],
                                  relativeTo: nil, bookmarkDataIsStale: &stale),
               !isInTrash(url), fm.fileExists(atPath: url.path) {
                return (url, stale ? bookmark(url) : nil)
            }
        }
        if !isInTrash(item.url), fm.fileExists(atPath: item.url.path) { return (item.url, nil) }
        return nil
    }

    nonisolated static func isInTrash(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path.contains("/.Trash/") || path.contains("/.Trashes/")
    }
}
