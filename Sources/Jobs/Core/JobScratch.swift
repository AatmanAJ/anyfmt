import Foundation

/// Private scratch folders for running jobs:
/// `FileManager.temporaryDirectory/<Brand.name>-jobs/<job uuid>`.
///
/// Every job gets a fresh folder and loses it when it finishes, whatever the
/// outcome (success, failure, cancel). `purgeStale` sweeps up after crashes.
public struct JobScratch: Sendable {
    public let root: URL

    public init(root: URL) { self.root = root }

    public static let `default` = JobScratch(
        root: FileManager.default.temporaryDirectory.appendingPathComponent("\(Brand.name)-jobs", isDirectory: true)
    )

    public func directory(for id: UUID) -> URL {
        root.appendingPathComponent(id.uuidString, isDirectory: true)
    }

    /// Creates an empty folder for `id`, clearing leftovers from an earlier attempt.
    public func makeDirectory(for id: UUID) throws -> URL {
        let dir = directory(for: id)
        let fm = FileManager.default
        if fm.fileExists(atPath: dir.path) { try? fm.removeItem(at: dir) }
        do {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            throw ConversionError.other(L("Couldn’t create a temporary folder for the conversion."),
                                        detail: "mkdir \(dir.path): \(error)")
        }
        return dir
    }

    /// Removes a job folder. Refuses anything outside `root`.
    public func remove(_ dir: URL) {
        guard RouteExecutor.isInside(dir, root), dir.standardizedFileURL != root.standardizedFileURL else {
            Log.jobs.error("refusing to remove \(dir.path, privacy: .public): outside scratch root")
            return
        }
        do {
            try FileManager.default.removeItem(at: dir)
        } catch CocoaError.fileNoSuchFile {
            // Already gone.
        } catch {
            Log.jobs.error("couldn't remove scratch \(dir.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Deletes job folders untouched for `age` seconds (left behind by a crash).
    /// Age-gated, not "delete all": the CLI may be running a job right now.
    public func purgeStale(olderThan age: TimeInterval = 6 * 3600, now: Date = Date()) {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for item in items {
            let modified = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if now.timeIntervalSince(modified) > age { remove(item) }
        }
    }
}

/// Runs a `Job` the way the queue does: fresh scratch folder in, folder always
/// removed afterwards. The CLI uses this directly.
public enum JobRunner {
    public static func run(_ job: any Job, policy: OutputPolicy, engine: EngineContext = EngineContext(),
                           scratch: JobScratch = .default) async throws -> [URL] {
        let dir = try scratch.makeDirectory(for: job.id)
        defer { scratch.remove(dir) }
        try Task.checkCancellation()
        return try await job.run(context: JobContext(tempDirectory: dir, policy: policy, engine: engine))
    }
}
