// DragSense: MIT licence, see LICENSE.
import AppKit
import Combine

/// Package version.
public enum DragSenseVersion {
    public static let string = "1.0.0"
}

/// Global file-drag + modifier-tap detection for background macOS apps, with
/// no TCC permission.
///
/// DragSense watches for a file drag owned by any app (usually Finder) and
/// tells you when one of your ``Trigger`` keys is *tapped* mid-drag, so you
/// can open a drop target under the pointer. It knows nothing about what you
/// do with the files.
///
/// How it works (all public API, no permission):
/// 1. **Idle**: a low-rate timer (``DragSenseConfiguration/idlePollInterval``,
///    generous leeway) plus a global mouse-down monitor as the wake-up. While
///    the button is up, the drag pasteboard's `changeCount` is recorded as
///    the *idle baseline*.
/// 2. **Button down**: a high-rate timer (``DragSenseConfiguration/activePollRate``)
///    samples the button, pointer, modifier flags and drag pasteboard. A drag
///    has begun when the `changeCount` differs from the idle baseline and the
///    pasteboard carries file types. Comparing against the idle baseline,
///    not a mouse-down snapshot, means a late wake-up can't miss the source's
///    write; and an unchanged `changeCount` never counts, so stale contents
///    from an earlier drag never trigger. There is no "N drag events" fallback.
/// 3. **Taps**: press + release within ``DragSenseConfiguration/tapThreshold``
///    with no other modifier involved. Holds and chords never fire, so the
///    drag source's own modifiers (Finder's ⌘ move, ⌥ copy) keep working.
/// 4. The poll keeps running while the pointer is still: the OS sends no
///    drag events then, but a tap still has to be seen.
///
/// Once open, the wheel **stays open** after the key is released, until
/// the host calls ``wheelDidAcceptDrop()`` or ``cancelWheel()``. Tapping a
/// different trigger switches wheels; tapping the same one again follows
/// ``DragSenseConfiguration/retapBehavior``.
///
/// Everything happens on the main actor. Events are delivered synchronously
/// to ``onEvent`` (lowest latency) and to every ``events()`` stream.
@MainActor
public final class DragSense: ObservableObject {
    // MARK: Public surface

    /// Current tuning. Setting it validates the value and applies it
    /// immediately, mid-drag included: remapped triggers apply to the next
    /// tap, new poll rates to the next tick.
    public var configuration: DragSenseConfiguration {
        get { config }
        set { apply(newValue.validated()) }
    }

    /// The state machine's current state. Published for SwiftUI/Combine;
    /// see also ``onStateChange`` and ``stateUpdates()``.
    @Published public private(set) var state: DragSenseState = .idle

    /// The drag being tracked, if any.
    public private(set) var currentDrag: DragInfo?

    /// True between ``start()`` and ``stop()``.
    public private(set) var isRunning = false

    /// Called for every event, synchronously, on the main actor.
    public var onEvent: (@MainActor (DragSenseEvent) -> Void)?

    /// Called for every state change, synchronously, on the main actor.
    public var onStateChange: (@MainActor (DragSenseState) -> Void)?

    /// Verbose logging switch and the tap → wheel-visible latency probe.
    public let diagnostics = DragSenseDiagnostics()

    public let input: any InputSource
    public let scheduler: any PollScheduler

    /// - Parameters:
    ///   - configuration: tuning; validated before use.
    ///   - input: where device and pasteboard state come from. Tests pass a fake.
    ///   - scheduler: the clock and timer. Tests pass a manual clock.
    public init(
        configuration: DragSenseConfiguration = .default,
        input: any InputSource = SystemInputSource(),
        scheduler: any PollScheduler = DispatchPollScheduler()
    ) {
        self.config = configuration.validated()
        self.input = input
        self.scheduler = scheduler
    }

    /// Starts watching. Safe to call more than once. A drag that was already
    /// under way when you call this is not picked up.
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        baseline = input.dragPasteboardChangeCount
        input.installWakeUpHandler { [weak self] reason in self?.wake(reason) }
        setRate(.idle)
        diagnostics.verbose("started (baseline \(baseline.map(String.init) ?? "unavailable"))")
    }

    /// Stops watching and returns to ``DragSenseState/idle``. An open wheel
    /// reports ``DragSenseState/cancelled`` first.
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        input.removeWakeUpHandler()
        setRate(.stopped)
        readGeneration += 1
        let wheelWasOpen: Bool
        switch phase {
        case .wheelOpen, .awaitingResolution: wheelWasOpen = true
        default: wheelWasOpen = false
        }
        phase = .idle
        currentDrag = nil
        diagnostics.cancelProbe()
        if wheelWasOpen { publish(.cancelled) }
        publish(.idle)
        diagnostics.verbose("stopped")
        flush()
    }

    /// The host's wheel accepted the drop: the session ends as
    /// ``DragSenseState/dropped``. Call it from your drop target's
    /// `performDragOperation(_:)`, before or after ``DragSenseEvent/dragEnded(location:)``
    /// arrives; both orders work. Ignored when no wheel is open.
    public func wheelDidAcceptDrop() {
        switch phase {
        case .wheelOpen:
            // Our poll still thinks the button is down: wait for it to go up
            // so this same drag can't be detected again.
            finishSession(.dropped, buttonDown: true)
        case .awaitingResolution:
            finishSession(.dropped, buttonDown: false)
        default:
            diagnostics.verbose("wheelDidAcceptDrop ignored: no wheel open")
        }
        flush()
    }

    /// Closes the wheel without a drop: ``DragSenseState/cancelled``. If the
    /// button is still down the drag carries on (state returns to
    /// ``DragSenseState/dragging(dragID:)``) and another tap reopens the
    /// wheel; otherwise the state returns to idle. Ignored when no wheel is open.
    public func cancelWheel() {
        switch phase {
        case .wheelOpen:
            finishSession(.cancelled, buttonDown: true)
        case .awaitingResolution:
            finishSession(.cancelled, buttonDown: false)
        default:
            diagnostics.verbose("cancelWheel ignored: no wheel open")
        }
        flush()
    }

    /// Tell DragSense the wheel is now visible on screen; finishes the latency
    /// probe started by the tap that opened it. Extra calls are ignored.
    public func markWheelVisible() {
        diagnostics.endProbe(at: scheduler.now)
    }

    /// A new stream of every event from now on. Buffers the newest 256 if
    /// you fall behind. The stream ends when you stop iterating it.
    public func events() -> AsyncStream<DragSenseEvent> {
        let (stream, continuation) = AsyncStream<DragSenseEvent>.makeStream(bufferingPolicy: .bufferingNewest(256))
        let id = UUID()
        eventContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.eventContinuations[id] = nil }
        }
        return stream
    }

    /// A new stream of state changes from now on, starting with the current state.
    public func stateUpdates() -> AsyncStream<DragSenseState> {
        let (stream, continuation) = AsyncStream<DragSenseState>.makeStream(bufferingPolicy: .bufferingNewest(256))
        let id = UUID()
        continuation.yield(state)
        stateContinuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.stateContinuations[id] = nil }
        }
        return stream
    }

    // MARK: Internals

    private struct Press {
        var location: CGPoint
        var time: TimeInterval
        /// The poller noticed the button after the fact (timer, not a
        /// mouse-down event), so the true press point is unknown.
        var late: Bool
        var maxDistance: CGFloat = 0
        var rejectedChangeCount: Int?
        var rejectedAt: TimeInterval = 0
    }

    private struct PendingTap {
        var trigger: Trigger
        var probeStart: TimeInterval
    }

    private struct Session {
        var info: DragInfo
        var readGeneration: Int
        var readRequestedAt: TimeInterval
        var lastMoveTime: TimeInterval = 0
        var lastMoveLocation: CGPoint?
    }

    private enum Phase {
        /// Button up (or nothing to track).
        case idle
        /// Button down, waiting for the drag pasteboard to change.
        case armed(Press)
        /// File drag detected, contents read in flight. Public state: idle.
        case reading(Session, pendingTap: PendingTap?)
        case dragging(Session)
        case wheelOpen(Session, Trigger)
        /// Button up with the wheel open, waiting for the host's verdict.
        case awaitingResolution(Session, Trigger, since: TimeInterval)
        /// Session finished while the button is still down.
        case waitingForButtonUp
    }

    private enum TickReason: Equatable {
        case timer
        case wake(WakeUpReason)
    }

    private enum Rate: Equatable {
        case stopped, idle, active
    }

    private enum Output {
        case state(DragSenseState)
        case event(DragSenseEvent)
    }

    /// How long after a non-file `changeCount` bump the types are re-checked,
    /// because some sources bump first and write their types a moment later.
    static let typeSettleWindow: TimeInterval = 0.15
    /// Pointer moves smaller than this don't produce ``DragSenseEvent/dragMoved(_:)``.
    static let moveEpsilon: CGFloat = 0.5

    private var config: DragSenseConfiguration
    private var phase: Phase = .idle
    private var baseline: Int?
    private var taps = TapDetector()
    /// Set by `feedTaps` when the lock key was tapped in the latest sample.
    private var lockTapped = false
    private var rate: Rate = .stopped
    private var readGeneration = 0
    private var outbox: [Output] = []
    private var isFlushing = false
    private var lastQueuedState: DragSenseState = .idle
    private var eventContinuations: [UUID: AsyncStream<DragSenseEvent>.Continuation] = [:]
    private var stateContinuations: [UUID: AsyncStream<DragSenseState>.Continuation] = [:]

    private var isActivePhase: Bool {
        if case .idle = phase { return false }
        return true
    }

    // MARK: Configuration

    private func apply(_ new: DragSenseConfiguration) {
        let old = config
        config = new
        if old.idlePollInterval != new.idlePollInterval || old.activePollRate != new.activePollRate {
            let current = rate
            rate = .stopped
            setRate(current)
        }
        diagnostics.verbose("configuration applied: triggers \(new.triggers.map { "\($0.id)=\($0.key.rawValue)" }.joined(separator: ","))")
    }

    private func setRate(_ newRate: Rate) {
        guard newRate != rate else { return }
        rate = newRate
        switch newRate {
        case .stopped:
            scheduler.cancel()
        case .idle:
            let interval = config.idlePollInterval
            scheduler.schedule(interval: interval, leeway: interval) { [weak self] in self?.tick(.timer) }
        case .active:
            let interval = 1 / config.activePollRate
            scheduler.schedule(interval: interval, leeway: min(0.0005, interval / 4)) { [weak self] in self?.tick(.timer) }
        }
    }

    // MARK: Polling

    private func wake(_ reason: WakeUpReason) {
        guard isRunning else { return }
        switch reason {
        case .mouseDown:
            tick(.wake(reason))
        case .mouseDragged:
            // Only useful if the mouse-down was missed; the active timer covers the rest.
            if case .idle = phase { tick(.wake(reason)) }
        case .modifiersChanged:
            if isActivePhase { tick(.wake(reason)) }
        }
    }

    private func tick(_ reason: TickReason) {
        guard isRunning else { return }
        let now = scheduler.now
        let down = input.pressedMouseButtons & 1 != 0
        let location = input.mouseLocation

        switch phase {
        case .idle:
            if down {
                beginPress(at: location, time: now, late: reason != .wake(.mouseDown))
            } else {
                refreshBaseline()
            }

        case .waitingForButtonUp:
            if !down { returnToIdle() }

        case .armed(let press):
            if !down {
                returnToIdle()
            } else {
                _ = feedTaps(at: now) // taps before the drag starts don't count, but presses are tracked
                evaluate(press, location: location, now: now)
            }

        case .reading(var session, var pending):
            if !down {
                // Ended before the contents arrived: never announced, so end quietly.
                readGeneration += 1
                returnToIdle()
                break
            }
            for tap in feedTaps(at: now) {
                if let trigger = config.trigger(for: tap.key) {
                    pending = PendingTap(trigger: trigger, probeStart: tap.earliestRelease)
                }
            }
            if now - session.readRequestedAt >= config.pasteboardReadTimeout - TapDetector.epsilon {
                session.info.isPartial = true
                DragSenseLog.sense.notice("drag pasteboard read timed out; continuing with partial drag info")
                beginDragging(session, pendingTap: pending, now: now)
            } else {
                phase = .reading(session, pendingTap: pending)
            }

        case .dragging(let session):
            if !down {
                endDragWithoutWheel(session, location: location)
            } else {
                for tap in feedTaps(at: now) { handle(tap, location: location, now: now) }
            }

        case .wheelOpen(let session, let trigger):
            if !down {
                phase = .awaitingResolution(session, trigger, since: now)
                diagnostics.verbose("mouse up with wheel \(trigger.id) open; awaiting host")
                emit(.dragEnded(location: location))
            } else {
                lockTapped = false
                for tap in feedTaps(at: now) { handle(tap, location: location, now: now) }
                if lockTapped {
                    lockTapped = false
                    emit(.lockKeyTapped(location: location))
                }
                emitMoveIfNeeded(location: location, now: now)
            }

        case .awaitingResolution(_, let trigger, let since):
            if down {
                // A new press before the host answered: that wheel is over.
                diagnostics.verbose("new press while wheel \(trigger.id) awaited a verdict; cancelling it")
                finishSession(.cancelled, buttonDown: false)
                beginPress(at: location, time: now, late: reason != .wake(.mouseDown))
            } else {
                refreshBaseline()
                if now - since >= config.dropResolutionTimeout - TapDetector.epsilon {
                    diagnostics.verbose("no drop verdict within \(config.dropResolutionTimeout)s; cancelling")
                    finishSession(.cancelled, buttonDown: false)
                }
            }
        }
        flush()
    }

    private func refreshBaseline() {
        if let count = input.dragPasteboardChangeCount { baseline = count }
    }

    private func beginPress(at location: CGPoint, time: TimeInterval, late: Bool) {
        taps.reset(flags: input.modifierFlags, at: time)
        let press = Press(location: location, time: time, late: late)
        phase = .armed(press)
        setRate(.active)
        diagnostics.verbose("button down\(late ? " (seen late)" : "")")
        evaluate(press, location: location, now: time)
    }

    /// Decides whether the armed press has become a file drag.
    private func evaluate(_ pressIn: Press, location: CGPoint, now: TimeInterval) {
        var press = pressIn
        press.maxDistance = max(press.maxDistance, hypot(location.x - press.location.x, location.y - press.location.y))
        phase = .armed(press)

        guard let count = input.dragPasteboardChangeCount else { return }
        guard let idleBaseline = baseline else {
            // Never had a baseline (pasteboard unavailable so far): adopt this
            // one rather than guess. Conservative: may miss this drag.
            baseline = count
            return
        }
        guard count != idleBaseline else { return }
        guard press.late || press.maxDistance >= config.minimumDragDistance else { return }
        if press.rejectedChangeCount == count, now - press.rejectedAt > Self.typeSettleWindow { return }

        let types = input.dragPasteboardTypes()
        let acceptable = config.requireFileTypes
            ? DragPasteboardType.isFileDrag(types, fileTypes: input.fileTypes)
            : !types.isEmpty
        guard acceptable else {
            if press.rejectedChangeCount != count {
                press.rejectedChangeCount = count
                press.rejectedAt = now
                phase = .armed(press)
                diagnostics.verbose("drag pasteboard changed (\(idleBaseline) → \(count)) without file types; ignoring")
            }
            return
        }
        startReading(press: press, changeCount: count, types: types, now: now)
    }

    private func startReading(press: Press, changeCount: Int, types: [String], now: TimeInterval) {
        // Consume this count now: however the session ends, and even if the
        // pasteboard stays unreadable for a while (slow read in flight), the
        // same drag can never be detected twice.
        baseline = changeCount
        readGeneration += 1
        let generation = readGeneration
        let info = DragInfo(
            fileURLs: [], promisedTypes: [], pasteboardTypes: types, itemCount: 0,
            changeCount: changeCount, startLocation: press.location, startTime: press.time
        )
        phase = .reading(Session(info: info, readGeneration: generation, readRequestedAt: now), pendingTap: nil)
        diagnostics.verbose("file drag detected (changeCount \(changeCount)); reading contents")
        // Last thing we do: the completion may run synchronously.
        input.readDragContents { @MainActor [weak self] contents in
            self?.contentsArrived(contents, generation: generation)
        }
    }

    private func contentsArrived(_ contents: DragPasteboardContents, generation: Int) {
        guard generation == readGeneration else { return } // a later drag, or stopped
        func filled(_ session: Session) -> Session {
            var copy = session
            copy.info.fileURLs = contents.fileURLs
            copy.info.promisedTypes = contents.promisedTypes
            copy.info.itemCount = contents.itemCount
            copy.info.isPartial = false
            return copy
        }
        switch phase {
        case .reading(let session, let pending):
            beginDragging(filled(session), pendingTap: pending, now: scheduler.now)
        case .dragging(let session) where session.info.isPartial:
            let s = filled(session)
            phase = .dragging(s)
            currentDrag = s.info
        case .wheelOpen(let session, let trigger) where session.info.isPartial:
            let s = filled(session)
            phase = .wheelOpen(s, trigger)
            currentDrag = s.info
        case .awaitingResolution(let session, let trigger, let since) where session.info.isPartial:
            let s = filled(session)
            phase = .awaitingResolution(s, trigger, since: since)
            currentDrag = s.info
        default:
            break
        }
        flush()
    }

    private func beginDragging(_ session: Session, pendingTap: PendingTap?, now: TimeInterval) {
        phase = .dragging(session)
        currentDrag = session.info
        publish(.dragging(dragID: session.info.id))
        emit(.dragBegan(session.info))
        if let pendingTap {
            openOrSwitch(pendingTap.trigger, location: input.mouseLocation, now: now, probeStart: pendingTap.probeStart)
        } else if config.activation == .press,
                  let held = taps.freshlyHeld.first(where: { config.trigger(for: $0.key) != nil }),
                  let trigger = config.trigger(for: held.key) {
            // The key went down after the mouse button but before the drag was
            // recognised (a tap right as the drag starts) and is still held.
            diagnostics.verbose("key \(held.key.rawValue) held since before the drag was recognised")
            openOrSwitch(trigger, location: input.mouseLocation, now: now, probeStart: held.pressedAt)
        }
    }

    /// Trigger key activity in this sample: key-downs for `.press` activation,
    /// completed taps for `.tap`.
    private func feedTaps(at now: TimeInterval) -> [TapDetector.Tap] {
        var found = taps.feed(flags: input.modifierFlags, at: now, threshold: config.tapThreshold)
        // The lock key's taps are never triggers: set them aside for an open wheel.
        if let lock = config.lockKey, config.trigger(for: lock) == nil {
            if found.contains(where: { $0.key == lock }) {
                lockTapped = true
                diagnostics.verbose("lock key tapped")
            }
            found.removeAll { $0.key == lock }
        }
        if config.activation == .press {
            let presses = taps.newPresses.filter { $0.key != config.lockKey || config.trigger(for: $0.key) != nil }
            for press in presses { diagnostics.verbose("key down \(press.key.rawValue)") }
            return presses
        }
        for tap in found {
            diagnostics.verbose("tap \(tap.key.rawValue) (\(Int(((tap.releasedAt - tap.pressedAt) * 1000).rounded())) ms)")
        }
        return found
    }

    private func handle(_ tap: TapDetector.Tap, location: CGPoint, now: TimeInterval) {
        guard let trigger = config.trigger(for: tap.key) else {
            diagnostics.verbose("tap \(tap.key.rawValue) isn't bound to a trigger")
            return
        }
        openOrSwitch(trigger, location: location, now: now, probeStart: tap.earliestRelease)
    }

    private func openOrSwitch(_ trigger: Trigger, location: CGPoint, now: TimeInterval, probeStart: TimeInterval) {
        switch phase {
        case .dragging(var session):
            guard !isInTopBand(location) else {
                diagnostics.verbose("tap \(trigger.id) ignored: pointer in the top exclusion band")
                return
            }
            session.lastMoveLocation = location
            session.lastMoveTime = now
            phase = .wheelOpen(session, trigger)
            diagnostics.beginProbe(at: probeStart)
            publish(.wheelOpen(triggerID: trigger.id))
            emit(.triggerTapped(trigger, session.info, location: location))

        case .wheelOpen(let session, let current):
            if trigger.id == current.id {
                switch config.retapBehavior {
                case .ignore:
                    diagnostics.verbose("re-tap of open trigger \(trigger.id) ignored")
                case .close:
                    finishSession(.cancelled, buttonDown: true)
                }
                return
            }
            phase = .wheelOpen(session, trigger)
            publish(.wheelOpen(triggerID: trigger.id))
            emit(.triggerTapped(trigger, session.info, location: location))

        default:
            break
        }
    }

    private func emitMoveIfNeeded(location: CGPoint, now: TimeInterval) {
        guard case .wheelOpen(var session, let trigger) = phase else { return }
        if let last = session.lastMoveLocation,
           hypot(location.x - last.x, location.y - last.y) < Self.moveEpsilon {
            return
        }
        guard now - session.lastMoveTime >= config.dragMovedInterval - TapDetector.epsilon else { return }
        session.lastMoveLocation = location
        session.lastMoveTime = now
        phase = .wheelOpen(session, trigger)
        emit(.dragMoved(location))
    }

    private func endDragWithoutWheel(_ session: Session, location: CGPoint) {
        phase = .idle
        currentDrag = nil
        diagnostics.verbose("drag \(session.info.id) ended without a wheel")
        emit(.dragEnded(location: location))
        publish(.idle)
        setRate(.idle)
        refreshBaseline()
    }

    /// Ends the wheel part of a session as dropped or cancelled.
    private func finishSession(_ outcome: DragSenseState, buttonDown: Bool) {
        let session: Session?
        switch phase {
        case .wheelOpen(let s, _), .awaitingResolution(let s, _, _): session = s
        default: session = nil
        }
        diagnostics.cancelProbe()
        publish(outcome)

        if outcome == .cancelled, buttonDown, let session {
            // The drag goes on; another tap reopens the wheel.
            phase = .dragging(session)
            publish(.dragging(dragID: session.info.id))
            return
        }
        currentDrag = nil
        if buttonDown {
            phase = .waitingForButtonUp
            publish(.idle)
        } else {
            phase = .idle
            publish(.idle)
            setRate(.idle)
            refreshBaseline()
        }
    }

    private func returnToIdle() {
        phase = .idle
        currentDrag = nil
        setRate(.idle)
        refreshBaseline()
        diagnostics.verbose("button up")
    }

    private func isInTopBand(_ point: CGPoint) -> Bool {
        guard config.topExclusionHeight > 0 else { return false }
        let containing = input.screens().first { screen in
            let f = screen.frame
            return point.x >= f.minX && point.x <= f.maxX && point.y >= f.minY && point.y <= f.maxY
        }
        guard let screen = containing else { return false }
        let band = max(config.topExclusionHeight, screen.topInset)
        return point.y >= screen.frame.maxY - band
    }

    // MARK: Delivery

    private func publish(_ newState: DragSenseState) {
        guard newState != lastQueuedState else { return }
        lastQueuedState = newState
        outbox.append(.state(newState))
        diagnostics.verbose("state → \(newState)")
    }

    private func emit(_ event: DragSenseEvent) {
        outbox.append(.event(event))
    }

    /// Delivers queued outputs in order. Re-entrant calls (a callback calling
    /// back into DragSense) just queue more; the outer loop drains them.
    private func flush() {
        guard !isFlushing else { return }
        isFlushing = true
        defer { isFlushing = false }
        while !outbox.isEmpty {
            let output = outbox.removeFirst()
            switch output {
            case .state(let newState):
                state = newState
                onStateChange?(newState)
                for continuation in stateContinuations.values { continuation.yield(newState) }
            case .event(let event):
                onEvent?(event)
                for continuation in eventContinuations.values { continuation.yield(event) }
            }
        }
    }
}
