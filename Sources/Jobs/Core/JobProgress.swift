import Foundation

/// Bridges an engine's `ProgressSink` (any thread, any rate) onto a job's
/// `Progress`. Values only ever move forward within one run, so a hop that
/// restarts its own counter can't make the bar jump backwards.
final class JobProgressDriver: @unchecked Sendable {
    static let units: Int64 = 10_000
    let progress: Progress
    private let lock = NSLock()
    private var last: Int64 = 0

    init(_ progress: Progress) {
        self.progress = progress
    }

    /// Back to zero for a fresh run (retry).
    func reset() {
        lock.withLock { last = 0 }
        progress.totalUnitCount = Self.units
        progress.completedUnitCount = 0
    }

    func set(_ fraction: Double) {
        guard fraction.isFinite else { return }
        let v = Int64((min(1, max(0, fraction)) * Double(Self.units)).rounded(.down))
        let advance: Bool = lock.withLock {
            guard v > last else { return false }
            last = v
            return true
        }
        if advance { progress.completedUnitCount = v }
    }

    /// A sink mapping 0...1 onto `range` of this job's progress.
    func sink(_ range: ClosedRange<Double> = 0...1) -> ProgressSink {
        ProgressSink { [self] f in set(range.lowerBound + (range.upperBound - range.lowerBound) * f) }
    }

    static func makeProgress() -> Progress {
        // discreteProgress never attaches to an ambient `Progress.current()` parent.
        Progress.discreteProgress(totalUnitCount: units)
    }
}
