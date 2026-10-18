import Foundation

/// A value snapshot of one job, as the progress window, menu and recents see it.
/// `JobQueue.records` publishes these; mutating a copy changes nothing.
public struct JobRecord: Identifiable, Sendable, Equatable {
    public let id: UUID
    /// "photo.heic → JPG"
    public var title: String
    /// "Converting to JPG" / "Converted to JPG" / "Couldn’t convert to JPG"
    public var activityTitle: String
    public var completedTitle: String
    public var failedTitle: String
    public var inputs: [URL]
    public var resourceClass: ResourceClass
    public var batchID: UUID?
    /// The policy snapshot the job runs (or ran) with.
    public var policy: OutputPolicy
    public var state: JobState
    /// 0...1
    public var fraction: Double
    /// Seconds left, when there's a trustworthy estimate.
    public var eta: TimeInterval?
    public var outputs: [URL]
    public var errorMessage: String?
    /// Technical details + versions + route, for "Copy details".
    public var errorDetails: String?
    public var submittedAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?
    /// The user asked to cancel; the job is winding down.
    public var cancelRequested: Bool
    /// 1 for the first run, +1 per retry.
    public var attempt: Int

    public init(id: UUID = UUID(), title: String, activityTitle: String? = nil, completedTitle: String? = nil,
                failedTitle: String? = nil, inputs: [URL], resourceClass: ResourceClass = .cpu, batchID: UUID? = nil,
                policy: OutputPolicy = .default, state: JobState = .queued, fraction: Double = 0, eta: TimeInterval? = nil,
                outputs: [URL] = [], errorMessage: String? = nil, errorDetails: String? = nil,
                submittedAt: Date = Date(), startedAt: Date? = nil, finishedAt: Date? = nil,
                cancelRequested: Bool = false, attempt: Int = 1) {
        self.id = id
        self.title = title
        self.activityTitle = activityTitle ?? title
        self.completedTitle = completedTitle ?? L("Done")
        self.failedTitle = failedTitle ?? L("Something went wrong")
        self.inputs = inputs
        self.resourceClass = resourceClass
        self.batchID = batchID
        self.policy = policy
        self.state = state
        self.fraction = fraction
        self.eta = eta
        self.outputs = outputs
        self.errorMessage = errorMessage
        self.errorDetails = errorDetails
        self.submittedAt = submittedAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.cancelRequested = cancelRequested
        self.attempt = attempt
    }

    /// The file whose icon/thumbnail represents this job.
    public var iconURL: URL? { inputs.first }

    public var isFinished: Bool {
        switch state {
        case .succeeded, .failed, .cancelled: true
        case .queued, .running: false
        }
    }

    public var isRunning: Bool { state == .running }
    public var isQueued: Bool { state == .queued }
    public var didSucceed: Bool { if case .succeeded = state { return true } else { return false } }
    public var didFail: Bool { if case .failed = state { return true } else { return false } }
    public var wasCancelled: Bool { state == .cancelled }
}

/// Several jobs shown as one card ("3 of 12"): a multi-file drop.
public struct JobBatch: Identifiable, Sendable, Equatable {
    public let id: UUID
    public var title: String
    public var activityTitle: String
    public var completedTitle: String
    public var failedTitle: String
    /// "2 already JPG"
    public var note: String?
    public var jobIDs: [UUID]
    /// Files dropped, including skipped ones.
    public var fileCount: Int
    /// Aggregate 0...1 (finished jobs count as done).
    public var fraction: Double
    public var eta: TimeInterval?
    public var submittedAt: Date

    public init(id: UUID = UUID(), title: String, activityTitle: String? = nil, completedTitle: String? = nil,
                failedTitle: String? = nil, note: String? = nil, jobIDs: [UUID] = [], fileCount: Int? = nil,
                fraction: Double = 0, eta: TimeInterval? = nil, submittedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.activityTitle = activityTitle ?? title
        self.completedTitle = completedTitle ?? L("Done")
        self.failedTitle = failedTitle ?? L("Some items didn’t finish")
        self.note = note
        self.jobIDs = jobIDs
        self.fileCount = fileCount ?? jobIDs.count
        self.fraction = fraction
        self.eta = eta
        self.submittedAt = submittedAt
    }
}

/// Counts and aggregate progress over a batch's records.
public struct BatchProgress: Sendable, Equatable {
    public let total: Int
    public let queued: Int
    public let running: Int
    public let succeeded: Int
    public let failed: Int
    public let cancelled: Int
    public let fraction: Double
    public let outputs: [URL]

    public init(_ records: [JobRecord]) {
        total = records.count
        queued = records.filter(\.isQueued).count
        running = records.filter(\.isRunning).count
        succeeded = records.filter(\.didSucceed).count
        failed = records.filter(\.didFail).count
        cancelled = records.filter(\.wasCancelled).count
        let sum = records.reduce(0.0) { $0 + ($1.isFinished ? 1 : min(1, max(0, $1.fraction))) }
        fraction = total == 0 ? 1 : sum / Double(total)
        outputs = records.flatMap(\.outputs)
    }

    public var finished: Int { succeeded + failed + cancelled }
    public var isFinished: Bool { finished == total }
    /// The "3" in "3 of 12": finished plus the one(s) underway, capped at total.
    public var position: Int { min(total, finished + (running > 0 ? 1 : 0)) }
}
