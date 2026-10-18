// DragSense: MIT licence, see LICENSE.
import Foundation

/// The real ``PollScheduler``: one `DispatchSourceTimer` on the main queue,
/// rescheduled in place when DragSense switches between its idle and active
/// rates. The clock is `ProcessInfo.systemUptime`, the same base as
/// `NSEvent.timestamp`.
///
/// A `DispatchSourceTimer` keeps firing while the pointer is still, which is
/// the point: the OS sends no drag events then, but a modifier tap still has
/// to be seen.
@MainActor
public final class DispatchPollScheduler: PollScheduler {
    private let timer: TimerBox
    private var handler: (@MainActor () -> Void)?

    public init() {
        timer = TimerBox(DispatchSource.makeTimerSource(flags: [], queue: .main))
        timer.source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.handler?() }
        }
        // Parked, not suspended: releasing a suspended source traps.
        timer.source.schedule(deadline: .distantFuture)
        timer.source.resume()
    }

    deinit {
        timer.source.cancel()
    }

    public var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    public func schedule(interval: TimeInterval, leeway: TimeInterval, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        let leewayNanos = Int(max(0, leeway) * 1_000_000_000)
        timer.source.schedule(deadline: .now() + interval, repeating: interval, leeway: .nanoseconds(leewayNanos))
    }

    public func cancel() {
        handler = nil
        timer.source.schedule(deadline: .distantFuture)
    }
}

/// Lets the nonisolated `deinit` cancel the timer.
private final class TimerBox: @unchecked Sendable {
    let source: DispatchSourceTimer
    init(_ source: DispatchSourceTimer) { self.source = source }
}
