import Foundation

/// How many jobs of each resource class may run at once.
///
/// - CPU: performance cores − 1 (min 1), so a batch of 40 HEICs leaves a core
///   for the UI and Finder.
/// - VideoToolbox: 1. Two hardware encodes fight over the media engine and
///   finish later than running them back to back.
/// - IO (archives): 4. Mostly waiting on the disk.
/// - Network (cloud jobs): 2.
public struct ConcurrencyLimits: Sendable, Hashable {
    public var cpu: Int
    public var videoToolbox: Int
    public var io: Int
    public var network: Int

    public init(cpu: Int, videoToolbox: Int = 1, io: Int = 4, network: Int = 2) {
        self.cpu = max(1, cpu)
        self.videoToolbox = max(1, videoToolbox)
        self.io = max(1, io)
        self.network = max(1, network)
    }

    public static let system = ConcurrencyLimits(cpu: max(1, performanceCoreCount() - 1))

    public func limit(for resource: ResourceClass) -> Int {
        switch resource {
        case .cpu: cpu
        case .videoToolbox: videoToolbox
        case .io: io
        case .network: network
        }
    }

    /// Performance cores from `hw.perflevel0.physicalcpu` (Apple silicon's
    /// fastest cluster); falls back to the active processor count.
    public static func performanceCoreCount() -> Int {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("hw.perflevel0.physicalcpu", &value, &size, nil, 0) == 0, value > 0 {
            return Int(value)
        }
        return ProcessInfo.processInfo.activeProcessorCount
    }
}

/// The ETA a progress window shows, built on `ETAEstimator` but steadier:
///
/// - Silent until the job has run `warmUp` seconds and passed `minFraction`,
///   so the first wild guesses never reach the screen.
/// - The estimator is fed at most every `sampleInterval`, so 30 Hz polling
///   doesn't turn its EWMA into a jitter amplifier.
/// - Between samples the shown value counts down in real time. A new sample may
///   pull it down (blended) but only pushes it up for a real slowdown
///   (`raiseThreshold`), so the number a person reads rarely goes backwards.
public struct ETAModel: Sendable {
    public var warmUp: TimeInterval = 0.8
    public var minFraction = 0.02
    public var sampleInterval: TimeInterval = 0.25
    /// A new estimate must exceed the countdown by this factor (+2 s) to raise it.
    public var raiseThreshold = 1.3

    private var estimator = ETAEstimator()
    private var start: TimeInterval?
    private var lastSample: TimeInterval = -.infinity
    private var shown: TimeInterval?
    private var shownAt: TimeInterval = 0

    public init() {}

    /// - Parameters:
    ///   - fraction: 0...1.
    ///   - time: a monotonic clock in seconds (must be > 0).
    /// - Returns: seconds left to show, or nil while there's no trustworthy estimate.
    public mutating func update(fraction: Double, at time: TimeInterval) -> TimeInterval? {
        guard fraction.isFinite, fraction < 1 else { shown = nil; return nil }
        if start == nil { start = time }
        let countdown = shown.map { max(0, $0 - (time - shownAt)) }
        guard time - lastSample >= sampleInterval else { return countdown }
        lastSample = time
        let raw = estimator.update(fraction: fraction, at: time)
        guard let start, time - start >= warmUp, fraction >= minFraction, let raw, raw.isFinite else {
            return countdown
        }
        let next: TimeInterval
        if let countdown {
            if raw <= countdown {
                next = 0.6 * countdown + 0.4 * raw
            } else if raw > countdown * raiseThreshold + 2 {
                next = raw
            } else {
                next = countdown
            }
        } else {
            next = raw
        }
        shown = next
        shownAt = time
        return next
    }
}
