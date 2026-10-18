// DragSense: MIT licence, see LICENSE.
import Foundation
import os

/// `os.Logger`s, subsystem "DragSense". Stream them with
/// `log stream --level debug --predicate 'subsystem == "DragSense"'`.
enum DragSenseLog {
    static let subsystem = "DragSense"
    static let sense = Logger(subsystem: subsystem, category: "sense")
    static let input = Logger(subsystem: subsystem, category: "input")
    static let hotKey = Logger(subsystem: subsystem, category: "hotkey")
    static let latency = Logger(subsystem: subsystem, category: "latency")
}

/// Percentiles of the tap → wheel-visible latency, in seconds.
public struct LatencySummary: Sendable, Equatable {
    public var count: Int
    public var p50: TimeInterval
    public var p95: TimeInterval
    public var max: TimeInterval
    public var mean: TimeInterval

    /// Nearest-rank percentiles of `samples`; nil when empty.
    public init?(samples: [TimeInterval]) {
        guard !samples.isEmpty else { return nil }
        let sorted = samples.sorted()
        func percentile(_ p: Double) -> TimeInterval {
            let rank = Int((p * Double(sorted.count)).rounded(.up))
            return sorted[Swift.min(sorted.count - 1, Swift.max(0, rank - 1))]
        }
        count = sorted.count
        p50 = percentile(0.5)
        p95 = percentile(0.95)
        max = sorted[sorted.count - 1]
        mean = sorted.reduce(0, +) / Double(sorted.count)
    }
}

/// Optional verbose logging and the latency probe.
///
/// **Latency probe.** When DragSense opens a wheel it starts a measurement at
/// the earliest moment the key could have been released (the poll *before*
/// the one that saw the release), so the number includes the polling delay
/// and any main-thread stall. Call ``DragSense/markWheelVisible()`` once the
/// wheel's window is really on screen (for example from
/// `NSWindow.didChangeOcclusionStateNotification`) to finish it. Switches
/// between wheels aren't measured, only opens.
@MainActor
public final class DragSenseDiagnostics {
    /// Log every state transition, tap and suppressed tap (subsystem
    /// "DragSense", category "sense"). Off by default; warnings and errors are
    /// always logged.
    public var isVerbose = false

    /// Most recent latency samples in seconds, oldest first, capped at
    /// ``sampleCapacity``.
    public private(set) var latencySamples: [TimeInterval] = []

    /// Called with each new latency sample.
    public var onLatencySample: (@MainActor (TimeInterval) -> Void)?

    public static let sampleCapacity = 1000

    /// The probe's start time while a wheel open is waiting to be marked visible.
    private(set) var pendingProbeStart: TimeInterval?

    public init() {}

    /// p50/p95/max/mean of the recorded samples, or nil when there are none.
    public func latencySummary() -> LatencySummary? {
        LatencySummary(samples: latencySamples)
    }

    public func resetLatencySamples() {
        latencySamples.removeAll()
        pendingProbeStart = nil
    }

    func beginProbe(at time: TimeInterval) {
        pendingProbeStart = time
    }

    func cancelProbe() {
        pendingProbeStart = nil
    }

    /// Finishes the pending probe, returning the sample if there was one.
    @discardableResult
    func endProbe(at time: TimeInterval) -> TimeInterval? {
        guard let start = pendingProbeStart else { return nil }
        pendingProbeStart = nil
        let sample = max(0, time - start)
        latencySamples.append(sample)
        if latencySamples.count > Self.sampleCapacity {
            latencySamples.removeFirst(latencySamples.count - Self.sampleCapacity)
        }
        DragSenseLog.latency.info("tap → wheel visible: \(sample * 1000, format: .fixed(precision: 2), privacy: .public) ms")
        onLatencySample?(sample)
        return sample
    }

    func verbose(_ message: @autoclosure () -> String) {
        guard isVerbose else { return }
        let text = message()
        DragSenseLog.sense.info("\(text, privacy: .public)")
    }
}
