import Foundation

/// What a job is limited by, for queue concurrency:
/// CPU jobs run (performance cores − 1) at a time, VideoToolbox jobs 1 at a time.
public enum ResourceClass: String, Sendable, Hashable {
    case cpu
    case videoToolbox
    case io
    case network
}

public enum JobState: Sendable, Equatable {
    case queued
    case running
    case succeeded([URL])
    case failed(message: String, details: String)
    case cancelled
}

/// Context handed to a running job.
public struct JobContext: Sendable {
    /// Private scratch directory, deleted after the job.
    public let tempDirectory: URL
    public let policy: OutputPolicy
    public let engine: EngineContext
    public init(tempDirectory: URL, policy: OutputPolicy, engine: EngineContext) {
        self.tempDirectory = tempDirectory
        self.policy = policy
        self.engine = engine
    }
}

/// A unit of work the queue runs and the progress window shows.
/// Conversions, tools and cloud jobs all conform.
public protocol Job: AnyObject, Sendable {
    var id: UUID { get }
    /// e.g. "photo.heic → JPG"
    var title: String { get }
    var inputs: [URL] { get }
    var resourceClass: ResourceClass { get }
    /// Thread-safe progress; `fractionCompleted` drives the bar.
    var progress: Progress { get }
    /// Do the work. Write only inside `context.tempDirectory`, then place
    /// results with `OutputPlacer`. Return the final URLs. Honour Task cancellation.
    func run(context: JobContext) async throws -> [URL]
}

/// Seconds-remaining estimate from progress over time (EWMA of rate).
public struct ETAEstimator: Sendable {
    private var lastFraction = 0.0
    private var lastTime: TimeInterval = 0
    private var rate: Double? // fraction per second
    public init() {}

    public mutating func update(fraction: Double, at time: TimeInterval) -> TimeInterval? {
        defer { lastFraction = fraction; lastTime = time }
        guard lastTime > 0, time > lastTime, fraction > lastFraction else { return eta(fraction) }
        let r = (fraction - lastFraction) / (time - lastTime)
        rate = rate.map { 0.8 * $0 + 0.2 * r } ?? r
        return eta(fraction)
    }

    private func eta(_ f: Double) -> TimeInterval? {
        guard let rate, rate > 0, f < 1 else { return nil }
        return (1 - f) / rate
    }
}
