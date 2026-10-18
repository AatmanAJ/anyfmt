import AppKit
import HaloCore

/// Receives file promises (drags from Mail, Photos, Safari's downloads, the
/// screenshot thumbnail) into our own staging area so actions have real files:
///
///     ~/Library/Application Support/<Brand.name>/Received/<uuid>/<file>
///
/// One `<uuid>` folder per promise receiver, so two attachments with the same
/// name never collide. The files are app-owned copies (the originals stay in
/// Mail or Photos): the shelf, Copy and Move hand them on, and `purge` removes
/// batches older than a few days at launch.
public struct PromiseIntake: Sendable {
    public let root: URL

    public init(root: URL = PromiseIntake.defaultRoot) {
        self.root = root
    }

    public static var defaultRoot: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        return support
            .appendingPathComponent(Brand.name, isDirectory: true)
            .appendingPathComponent("Received", isDirectory: true)
    }

    /// `<root>/<uuid>/`. Doesn't create it.
    public func folder(for id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    /// Creates a fresh, empty batch folder.
    public func makeFolder(id: UUID = UUID()) throws -> URL {
        let url = folder(for: id)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// True for files we received (anything under `root`).
    public func contains(_ url: URL) -> Bool {
        let base = root.standardizedFileURL.resolvingSymlinksInPath().path
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        return path.hasPrefix(base + "/")
    }

    public static let defaultRetention: TimeInterval = 3 * 24 * 3600

    /// Removes batch folders last modified before `now - age`. Only touches
    /// direct children of `root` whose names are UUIDs (ours, by construction).
    @discardableResult
    public func purge(olderThan age: TimeInterval = PromiseIntake.defaultRetention, now: Date = Date()) -> Int {
        let fm = FileManager.default
        guard let children = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey],
                                                         options: [.skipsHiddenFiles]) else { return 0 }
        var removed = 0
        for child in children where UUID(uuidString: child.lastPathComponent) != nil {
            let modified = (try? child.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
            if modified < now.addingTimeInterval(-age), (try? fm.removeItem(at: child)) != nil {
                removed += 1
            }
        }
        return removed
    }

    public enum IntakeError: Error, Equatable {
        case nothingReceived
        public var message: String { String(localized: "Couldn’t get the dragged files from the app they came from.") }
    }

    /// Asks every receiver to write its files, then waits for all of them (or
    /// `timeout`). Returns files in receiver order. Throws only when nothing
    /// at all arrived.
    @MainActor
    public func receive(_ promises: [NSFilePromiseReceiver], timeout: TimeInterval = 300) async throws -> [URL] {
        guard !promises.isEmpty else { return [] }
        return try await begin(promises).files(timeout: timeout)
    }

    /// Issues every request **now** (synchronously), so it can be called
    /// straight from `performDragOperation` while the drag is fresh, and
    /// returns a handle to await the files with.
    @MainActor
    public func begin(_ promises: [NSFilePromiseReceiver]) -> PendingPromises {
        let expected = promises.map { max(1, $0.fileTypes.count) }
        let batch = PromiseBatch(expected: expected.reduce(0, +))
        guard !promises.isEmpty else { return PendingPromises(batch: batch, queue: nil) }
        let queue = OperationQueue()
        queue.name = Brand.bundleID + ".promises"
        queue.qualityOfService = .userInitiated

        for (index, receiver) in promises.enumerated() {
            let destination: URL
            do {
                destination = try makeFolder()
            } catch {
                Log.actions.error("promise folder: \(error.localizedDescription, privacy: .public)")
                batch.fail(count: expected[index], index: index, error: error)
                continue
            }
            // The reader runs on `queue`, not the main thread. It must not inherit
            // this method's @MainActor isolation, or Swift 6's runtime check traps
            // the moment a promised file arrives (crash seen on real hardware).
            receiver.receivePromisedFiles(atDestination: destination, options: [:], operationQueue: queue,
                                          reader: Self.reader(batch, index: index))
        }
        return PendingPromises(batch: batch, queue: queue)
    }
}

extension PromiseIntake {
    nonisolated static func reader(_ batch: PromiseBatch, index: Int) -> @Sendable (URL, (any Error)?) -> Void {
        { url, error in batch.deliver(url: error == nil ? url : nil, index: index, error: error) }
    }
}

/// Files on their way from a promise drag.
public struct PendingPromises: Sendable {
    fileprivate let batch: PromiseBatch
    /// Held so the reader queue lives until the files arrive.
    fileprivate let queue: QueueBox?

    fileprivate init(batch: PromiseBatch, queue: OperationQueue?) {
        self.batch = batch
        self.queue = queue.map(QueueBox.init)
    }

    /// The received files in receiver order; throws if none arrived.
    public func files(timeout: TimeInterval = 300) async throws -> [URL] {
        let urls = await batch.wait(timeout: timeout)
        _ = queue
        guard !urls.isEmpty else { throw PromiseIntake.IntakeError.nothingReceived }
        return urls
    }
}

/// `OperationQueue` is thread-safe; this only keeps it alive.
fileprivate struct QueueBox: @unchecked Sendable {
    let queue: OperationQueue
}

/// Collects reader callbacks from any queue and resumes one waiter.
final class PromiseBatch: @unchecked Sendable {
    private let lock = NSLock()
    private var remaining: Int
    private var results: [(index: Int, order: Int, url: URL)] = []
    private var arrivals = 0
    private var continuation: CheckedContinuation<[URL], Never>?
    private var finished = false

    init(expected: Int) { remaining = expected }

    func deliver(url: URL?, index: Int, error: Error?) {
        if let error { Log.actions.error("promise failed: \(error.localizedDescription, privacy: .public)") }
        lock.lock()
        if let url {
            results.append((index, arrivals, url))
            arrivals += 1
        }
        remaining -= 1
        let done = remaining <= 0
        lock.unlock()
        if done { finish() }
    }

    func fail(count: Int, index: Int, error: Error) {
        for _ in 0..<count { deliver(url: nil, index: index, error: error) }
    }

    func wait(timeout: TimeInterval) async -> [URL] {
        await withCheckedContinuation { (c: CheckedContinuation<[URL], Never>) in
            lock.lock()
            if finished || remaining <= 0 {
                finished = true
                let urls = sortedURLs()
                lock.unlock()
                c.resume(returning: urls)
                return
            }
            continuation = c
            lock.unlock()
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self else { return }
                self.finish(timedOut: true)
            }
        }
    }

    private func finish(timedOut: Bool = false) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        let c = continuation
        continuation = nil
        let urls = sortedURLs()
        lock.unlock()
        if timedOut { Log.actions.error("promise receive timed out with \(urls.count) file(s)") }
        c?.resume(returning: urls)
    }

    /// Call with the lock held.
    private func sortedURLs() -> [URL] {
        results.sorted { ($0.index, $0.order) < ($1.index, $1.order) }.map(\.url)
    }
}
