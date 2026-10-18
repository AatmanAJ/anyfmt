import Foundation
import UniformTypeIdentifiers
import HaloCore

enum CloudUploadPurpose: String, Sendable {
    case share, job, inbox
}

struct CloudRetryPolicy: Sendable {
    var maxAttempts = 6
    var baseDelay: Duration = .milliseconds(500)
    var maxDelay: Duration = .seconds(8)

    static let standard = CloudRetryPolicy()

    /// Exponential backoff, honouring Retry-After when the server sends one.
    func delay(attempt: Int, retryAfter: TimeInterval?) -> Duration {
        if let retryAfter, retryAfter > 0 { return min(.seconds(retryAfter), maxDelay * 4) }
        let factor = 1 << min(max(0, attempt - 1), 10)
        return min(baseDelay * factor, maxDelay)
    }
}

extension CloudError {
    var retryAfter: TimeInterval? {
        if case .rateLimited(let after) = self { return after }
        return nil
    }
}

/// Remembers unfinished uploads so a later attempt (even after relaunch)
/// resumes from the server's offset instead of starting over.
/// Keyed by server + content hash + size; stores only server upload ids.
final class CloudUploadLedger: Sendable {
    struct Entry: Codable, Sendable, Equatable {
        let uploadID: String
        let createdAt: Date
    }

    private let file: URL?
    private let box: CloudLocked<[String: Entry]>

    /// `directory` nil keeps the ledger in memory only.
    init(directory: URL?) {
        file = directory?.appendingPathComponent("uploads.json")
        var loaded: [String: Entry] = [:]
        if let file, let data = try? Data(contentsOf: file) {
            loaded = (try? JSONDecoder().decode([String: Entry].self, from: data)) ?? [:]
        }
        // Servers expire unfinished uploads after a day; don't keep older ids.
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        box = CloudLocked(loaded.filter { $0.value.createdAt > cutoff })
    }

    static var defaultDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(Brand.name, isDirectory: true)
            .appendingPathComponent("Cloud", isDirectory: true)
    }

    static func key(server: URL, sha256: String, size: Int64, purpose: CloudUploadPurpose) -> String {
        "\(CloudServerAddress.accountKey(for: server))|\(purpose.rawValue)|\(sha256)|\(size)"
    }

    func lookup(_ key: String) -> String? { box.withLock { $0[key]?.uploadID } }

    func record(_ key: String, uploadID: String) {
        let snapshot = box.withLock { s -> [String: Entry] in
            s[key] = Entry(uploadID: uploadID, createdAt: Date())
            return s
        }
        persist(snapshot)
    }

    func remove(_ key: String) {
        let snapshot = box.withLock { s -> [String: Entry]? in
            guard s.removeValue(forKey: key) != nil else { return nil }
            return s
        }
        if let snapshot { persist(snapshot) }
    }

    private func persist(_ entries: [String: Entry]) {
        guard let file else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(entries).write(to: file, options: .atomic)
        } catch {
            Log.cloud.error("upload ledger not saved: \(String(describing: error), privacy: .public)")
        }
    }
}

/// Resumable, chunked upload (Server/openapi.yaml › uploads):
/// create → PUT chunks with Content-Range → on any interruption ask the
/// server for its committed offset (HEAD) and continue from there →
/// complete with the SHA-256, which the server verifies.
final class CloudUploader: Sendable {
    private let client: CloudAPIClient
    private let state: CloudState
    private let ledger: CloudUploadLedger
    private let chunkSize: Int
    private let retry: CloudRetryPolicy

    init(client: CloudAPIClient, state: CloudState, ledger: CloudUploadLedger,
         chunkSize: Int = CloudConfig.uploadChunkSize, retry: CloudRetryPolicy = .standard) {
        self.client = client
        self.state = state
        self.ledger = ledger
        self.chunkSize = max(1, chunkSize)
        self.retry = retry
    }

    /// Uploads `file` and returns the completed upload. `progress` is
    /// monotonic 0…1 (hashing is the first 5%).
    func upload(_ file: URL, purpose: CloudUploadPurpose, trigger: CloudTrigger = .user,
                progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws -> CloudUpload {
        let high = CloudLocked(0.0)
        let report: @Sendable (Double) -> Void = { value in
            let v = min(1, max(0, value))
            let changed = high.withLock { h -> Bool in
                guard v > h else { return false }
                h = v
                return true
            }
            if changed { progress(v) }
        }
        guard state.snapshot.isSignedIn else { throw CloudError.signedOut }
        let name = file.lastPathComponent
        let size: Int64
        do {
            let values = try file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values.isRegularFile == true, let s = values.fileSize else { throw CloudError.fileUnreadable(name) }
            size = Int64(s)
        } catch { throw CloudError.fileUnreadable(name) }

        var restarts = 0
        while true {
            let sha: String
            do { sha = try CloudHash.sha256(of: file) { report(0.05 * $0) } } catch is CancellationError {
                throw CancellationError()
            } catch { throw CloudError.fileUnreadable(name) }
            let key = CloudUploadLedger.key(server: state.snapshot.server, sha256: sha, size: size, purpose: purpose)
            do {
                let done = try await attempt(file: file, name: name, size: size, sha: sha, key: key,
                                             purpose: purpose, trigger: trigger, report: report)
                ledger.remove(key)
                report(1)
                return done
            } catch let e as CloudError where (e == .checksumMismatch || e == .notFound) && restarts == 0 {
                // The file changed under us or the server dropped the upload: start over once.
                ledger.remove(key)
                restarts += 1
                Log.cloud.info("upload restarting from scratch (\(e.technicalDetails, privacy: .public))")
            }
        }
    }

    private func attempt(file: URL, name: String, size: Int64, sha: String, key: String, purpose: CloudUploadPurpose,
                         trigger: CloudTrigger, report: @escaping @Sendable (Double) -> Void) async throws -> CloudUpload {
        var uploadID: String?
        var offset: Int64 = 0
        var maxChunk = Int64(chunkSize)

        if let known = ledger.lookup(key), let existing = try await client.upload(known, trigger: trigger) {
            if existing.isComplete { return existing }
            uploadID = known
            offset = existing.offset
            maxChunk = min(maxChunk, max(1, existing.maxChunkSize))
            Log.cloud.info("resuming upload at \(offset) of \(size)")
        }
        if uploadID == nil {
            let type = UTType(filenameExtension: file.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
            let created = try await client.createUpload(
                CloudUploadCreate(filename: name, size: size, contentType: type, sha256: sha, purpose: purpose.rawValue),
                trigger: trigger)
            uploadID = created.id
            offset = created.offset
            maxChunk = min(maxChunk, max(1, created.maxChunkSize))
            ledger.record(key, uploadID: created.id)
        }
        guard let id = uploadID else { throw CloudError.invalidResponse("no upload id") }

        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: file) } catch { throw CloudError.fileUnreadable(name) }
        defer { try? handle.close() }

        var failures = 0
        do {
            while offset < size {
                try Task.checkCancellation()
                let length = Int(min(maxChunk, size - offset))
                try handle.seek(toOffset: UInt64(offset))
                guard let data = try handle.read(upToCount: length), data.count == length else {
                    throw CloudError.fileUnreadable(name)
                }
                let base = offset
                let sizeD = Double(max(1, size))
                do {
                    let result = try await client.putChunk(id, data: data, offset: base, total: size, trigger: trigger) { sent in
                        report(0.05 + 0.95 * Double(base + sent) / sizeD)
                    }
                    switch result {
                    case .committed(let off):
                        offset = off
                        failures = 0
                    case .mismatch(let off):
                        offset = off
                    case .gone:
                        throw CloudError.notFound
                    }
                } catch let e as CloudError where e.isTransient {
                    failures += 1
                    guard failures < retry.maxAttempts else { throw e }
                    Log.cloud.info("chunk at \(base) interrupted (\(e.technicalDetails, privacy: .public)); attempt \(failures)")
                    try await Task.sleep(for: retry.delay(attempt: failures, retryAfter: e.retryAfter))
                    // The server commits bytes as they arrive: ask where it really is.
                    do {
                        guard let off = try await client.uploadOffset(id, trigger: trigger) else { throw CloudError.notFound }
                        offset = off
                    } catch let probe as CloudError where probe.isTransient {
                        // Couldn't ask; the next PUT gets a 409 with the real offset if we're behind.
                    }
                }
            }
            return try await client.completeUpload(id, sha256: sha, trigger: trigger)
        } catch is CancellationError {
            // The user cancelled: don't leave their bytes on the server.
            ledger.remove(key)
            let client = self.client
            Task.detached { try? await client.abortUpload(id, trigger: trigger) }
            throw CancellationError()
        }
    }
}
