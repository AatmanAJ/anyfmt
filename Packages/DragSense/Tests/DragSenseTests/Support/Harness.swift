// DragSense: MIT licence, see LICENSE.
import AppKit
@testable import DragSense

/// Drives a ``DragSense`` against a ``FakeSystem`` and records what it says.
///
/// The default configuration polls at 100 Hz so one tick is exactly 10 ms,
/// which keeps timing in the tests readable.
@MainActor
final class Harness {
    nonisolated static let triggers = [
        Trigger(id: "convert", key: .shift),
        Trigger(id: "tools", key: .command),
        Trigger(id: "actions", key: .control),
    ]

    static func configuration(_ edit: (inout DragSenseConfiguration) -> Void = { _ in }) -> DragSenseConfiguration {
        // The tap-mode suites pin `.tap`; PressActivationTests covers `.press` (the default).
        var config = DragSenseConfiguration(triggers: triggers, activePollRate: 100, activation: .tap)
        edit(&config)
        return config
    }

    let sys = FakeSystem()
    let sense: DragSense
    private(set) var events: [DragSenseEvent] = []
    private(set) var states: [DragSenseState] = []
    /// Runs inside `onEvent`, to test re-entrant calls.
    var onEvent: ((DragSenseEvent) -> Void)?

    init(_ configuration: DragSenseConfiguration = Harness.configuration(), start: Bool = true) {
        sense = DragSense(configuration: configuration, input: sys, scheduler: sys)
        sense.onEvent = { [unowned self] event in
            self.events.append(event)
            self.onEvent?(event)
        }
        sense.onStateChange = { [unowned self] state in self.states.append(state) }
        if start { sense.start() }
    }

    var tick: TimeInterval { 1 / sense.configuration.activePollRate }

    func ticks(_ n: Int) { sys.advance(by: Double(n) * tick) }
    func run(_ seconds: TimeInterval) { sys.advance(by: seconds) }

    // MARK: Mouse

    func mouseDown(wake: Bool = true) {
        sys.buttons = 1
        if wake { sys.wake(.mouseDown) }
    }

    func mouseUp() { sys.buttons = 0 }

    func move(_ dx: CGFloat, _ dy: CGFloat = 0) {
        sys.location.x += dx
        sys.location.y += dy
    }

    func moveTo(_ point: CGPoint) { sys.location = point }

    // MARK: Pasteboard

    nonisolated static let sampleURLs = [URL(fileURLWithPath: "/tmp/photo.heic"), URL(fileURLWithPath: "/tmp/clip.mov")]

    /// What Finder does a few points into a drag: bump the change count and
    /// write file URLs.
    func writeFileDrag(_ urls: [URL] = Harness.sampleURLs) {
        sys.changeCount += 1
        sys.types = [DragPasteboardType.fileURL, DragPasteboardType.legacyFilenames]
        sys.contents = DragPasteboardContents(fileURLs: urls, itemCount: urls.count)
    }

    /// Button down, pointer moves, Finder writes the pasteboard, one tick passes.
    func beginFileDrag(_ urls: [URL] = Harness.sampleURLs) {
        mouseDown()
        move(10)
        writeFileDrag(urls)
        ticks(1)
    }

    // MARK: Keys

    func press(_ key: ModifierKey) {
        sys.flags.insert(key.flag)
        ticks(1)
    }

    func release(_ key: ModifierKey) {
        sys.flags.remove(key.flag)
        ticks(1)
    }

    /// Press, hold, release. The measured duration is `ticksHeld` ticks.
    func tap(_ key: ModifierKey, ticksHeld: Int = 10) {
        press(key)
        ticks(ticksHeld - 1)
        release(key)
    }

    /// `beginFileDrag()` then a Shift tap: the convert wheel is open.
    func openWheel(_ key: ModifierKey = .shift) {
        beginFileDrag()
        tap(key)
    }

    // MARK: Reading what happened

    var tappedTriggerIDs: [String] {
        events.compactMap { if case .triggerTapped(let trigger, _, _) = $0 { return trigger.id } else { return nil } }
    }

    var dragBeganInfos: [DragInfo] {
        events.compactMap { if case .dragBegan(let info) = $0 { return info } else { return nil } }
    }

    var dragEndedCount: Int {
        events.filter { if case .dragEnded = $0 { return true } else { return false } }.count
    }

    var movedPoints: [CGPoint] {
        events.compactMap { if case .dragMoved(let point) = $0 { return point } else { return nil } }
    }

    func clearRecords() {
        events.removeAll()
        states.removeAll()
    }
}
