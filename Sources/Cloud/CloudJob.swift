import Foundation
import HaloCore

/// What a `CloudJob` needs from the cloud stack. Sendable so the job queue
/// can run it anywhere.
struct CloudJobDependencies: Sendable {
    let state: CloudState
    let client: CloudAPIClient
    let uploader: CloudUploader
    let notice: CloudUploadNoticeGate
    /// Floor between status polls (the server's `pollAfterMs` can only make it longer).
    var minimumPollInterval: Duration = .milliseconds(500)
}

/// Progress split into the three phases the progress window shows.
/// Only ever moves forward.
struct CloudJobPhases {
    static let upload: ClosedRange<Double> = 0...0.45
    static let processing: ClosedRange<Double> = 0.45...0.90
    static let download: ClosedRange<Double> = 0.90...1.0

    static func map(_ fraction: Double, into range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * min(1, max(0, fraction))
    }
}

/// A conversion or Pro tool that runs on the server: upload → create job →
/// poll → download into the job's temp dir → place beside the original with
/// `OutputPlacer` (never overwrites). Used for the video options schema's
/// `cloud` toggle and for transcribe / upscale / HQ background removal.
final class CloudJob: Job {
    let id = UUID()
    let title: String
    let inputs: [URL]
    let resourceClass: ResourceClass = .network
    let progress: Progress
    let operation: CloudJobOperation

    private let input: URL
    private let deps: CloudJobDependencies
    private let serverJobID = CloudLocked<String?>(nil)
    private let unitsDone = CloudLocked<Int64>(0)
    private static let units: Int64 = 1000

    init(input: URL, operation: CloudJobOperation, dependencies: CloudJobDependencies) {
        self.input = input
        self.inputs = [input]
        self.operation = operation
        self.deps = dependencies
        self.progress = Progress(totalUnitCount: Self.units)
        let what: String
        switch operation {
        case .convert(let target, _): what = Formats.label(target)
        case .tool(let tool, _, _): what = ToolCatalog.spec(tool)?.title ?? tool.rawValue
        }
        self.title = String(localized: "\(input.lastPathComponent) → \(what) (Cloud)")
    }

    /// The server's job id once created (tests and "Copy details").
    var remoteID: String? { serverJobID.current }

    private func advance(to fraction: Double) {
        let target = Int64((min(1, max(0, fraction)) * Double(Self.units)).rounded(.down))
        let move = unitsDone.withLock { done -> Bool in
            guard target > done else { return false }
            done = target
            return true
        }
        if move { progress.completedUnitCount = target }
    }

    func run(context: JobContext) async throws -> [URL] {
        let snap = deps.state.snapshot
        guard snap.isSignedIn else { throw CloudError.signedOut }
        let feature = operation.feature
        guard snap.entitlements.can(feature) else { throw CloudError.notEntitled(feature) }
        guard await deps.notice.confirm(server: snap.server, fileCount: 1) else { throw CancellationError() }

        return try await withTaskCancellationHandler {
            try await perform(context: context)
        } onCancel: {
            // Stop the server side too; local URLSession tasks cancel with this Task.
            if let jobID = serverJobID.current { cancelRemote(jobID) }
        }
    }

    /// Runs outside the cancelled task, which can't make requests any more.
    private func cancelRemote(_ jobID: String) {
        let client = deps.client
        Task.detached { try? await client.cancelJob(jobID) }
    }

    private func perform(context: JobContext) async throws -> [URL] {
        // 1. Upload (0–45 %).
        let upload = try await deps.uploader.upload(input, purpose: .job, trigger: .user) { [weak self] p in
            self?.advance(to: CloudJobPhases.map(p, into: CloudJobPhases.upload))
        }
        advance(to: CloudJobPhases.upload.upperBound)

        // 2. Create + poll (45–90 %).
        var dto = try await deps.client.createJob(CloudJobCreate(
            uploadId: upload.id, operation: CloudJobOperationDTO(operation), clientReference: id.uuidString))
        serverJobID.withLock { $0 = dto.id }
        if Task.isCancelled {
            // Cancelled while the create was in flight; onCancel had no id yet.
            cancelRemote(dto.id)
            throw CancellationError()
        }
        while !dto.status.isTerminal {
            let wait = max(deps.minimumPollInterval, .milliseconds(dto.pollAfterMs ?? 1000))
            try await Task.sleep(for: wait)
            do {
                dto = try await deps.client.job(dto.id)
            } catch let e as CloudError where e.isTransient {
                Log.cloud.info("job poll hiccup: \(e.technicalDetails, privacy: .public)")
                continue
            }
            advance(to: CloudJobPhases.map(dto.progress, into: CloudJobPhases.processing))
        }
        switch dto.status {
        case .succeeded: break
        case .cancelled: throw CancellationError()
        default: throw CloudError.jobFailed(dto.error?.message ?? "")
        }
        advance(to: CloudJobPhases.processing.upperBound)

        // 3. Download (90–100 %) into our temp dir, verify, place.
        let results = dto.results ?? []
        guard !results.isEmpty else { throw ConversionError.outputMissing(input.lastPathComponent) }
        let totalBytes = Double(max(1, results.reduce(0) { $0 + $1.size }))
        var before: Int64 = 0
        var files: [URL] = []
        let work = context.tempDirectory.appendingPathComponent("cloud-\(id.uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        for (index, result) in results.enumerated() {
            let name = CloudFileName.sanitize(result.name, fallback: "result-\(index + 1)")
            let dest = work.appendingPathComponent(name)
            let start = before
            try await deps.client.download(result.downloadUrl, to: dest, trigger: .user) { [weak self] written, _ in
                self?.advance(to: CloudJobPhases.map(Double(start + written) / totalBytes, into: CloudJobPhases.download))
            }
            let actual = try CloudHash.sha256(of: dest)
            guard actual == result.sha256.lowercased() else { throw CloudError.checksumMismatch }
            files.append(dest)
            before += result.size
        }

        let placed = try OutputPlacer(policy: context.policy).place(files, for: input, target: resolvedTarget(files),
                                                                    toolSuffix: toolSuffix)
        advance(to: 1)
        Log.cloud.info("cloud job finished: \(placed.count) output(s)")
        return placed
    }

    private var toolSuffix: String? {
        if case .tool(let tool, _, _) = operation { return ToolCatalog.spec(tool)?.outputSuffix }
        return nil
    }

    private func resolvedTarget(_ files: [URL]) -> FormatID? {
        if let t = operation.target { return t }
        guard let ext = files.first?.pathExtension, !ext.isEmpty else { return nil }
        return FormatID(ext)
    }
}

extension CloudJobOperation {
    /// Transcribe audio/video to subtitles on our GPUs.
    static func transcribe(to format: FormatID = Formats.srt, language: String = "auto") -> CloudJobOperation {
        .tool(ToolIDs.transcribe, target: format, options: OptionValues(["language": .string(language)]))
    }

    static func upscale(scale: Int = 2) -> CloudJobOperation {
        .tool(ToolIDs.upscale, target: Formats.png, options: OptionValues(["scale": .int(scale)]))
    }

    static let removeBackgroundHQ = CloudJobOperation.tool(ToolIDs.removeBackgroundHQ, target: Formats.png, options: OptionValues())

    /// True when the options ask for a cloud conversion (the video schema's `cloud` toggle).
    static func wantsCloud(_ options: OptionValues) -> Bool {
        options.bool(OptionKey.cloud, default: false)
    }
}
