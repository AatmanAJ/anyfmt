// DragSense: MIT licence, see LICENSE.
import AppKit
@testable import DragSense

/// A scripted world: manual clock + timer, device state and drag pasteboard.
/// Nothing touches real input.
@MainActor
final class FakeSystem: InputSource, PollScheduler {
    // MARK: Clock and timer

    private(set) var now: TimeInterval = 1000
    private(set) var interval: TimeInterval?
    private(set) var leeway: TimeInterval?
    private var nextFire = TimeInterval.infinity
    private var timerHandler: (@MainActor () -> Void)?
    private(set) var tickCount = 0

    func schedule(interval: TimeInterval, leeway: TimeInterval, handler: @escaping @MainActor () -> Void) {
        self.interval = interval
        self.leeway = leeway
        timerHandler = handler
        nextFire = now + interval
    }

    func cancel() {
        interval = nil
        leeway = nil
        timerHandler = nil
        nextFire = .infinity
    }

    /// Advances the clock, firing the timer at each scheduled time on the way.
    func advance(by seconds: TimeInterval) {
        let target = now + seconds
        while nextFire <= target + 1e-9, let handler = timerHandler {
            now = nextFire
            nextFire = now + (interval ?? .infinity)
            tickCount += 1
            handler() // may reschedule
        }
        now = max(now, target)
    }

    // MARK: Device state

    var buttons = 0
    var location = CGPoint(x: 400, y: 400)
    var flags: NSEvent.ModifierFlags = []

    var pressedMouseButtons: Int { buttons }
    var mouseLocation: CGPoint { location }
    var modifierFlags: NSEvent.ModifierFlags { flags }

    // MARK: Drag pasteboard

    var changeCount = 50
    var changeCountAvailable = true
    var types: [String] = []
    var contents = DragPasteboardContents()
    var readsAreManual = false
    private(set) var pendingReads: [@MainActor @Sendable (DragPasteboardContents) -> Void] = []
    private(set) var readCount = 0
    private(set) var typesReadCount = 0

    var dragPasteboardChangeCount: Int? { changeCountAvailable ? changeCount : nil }

    func dragPasteboardTypes() -> [String] {
        typesReadCount += 1
        return types
    }

    func readDragContents(completion: @escaping @MainActor @Sendable (DragPasteboardContents) -> Void) {
        readCount += 1
        if readsAreManual {
            pendingReads.append(completion)
        } else {
            completion(contents)
        }
    }

    func completePendingReads() {
        let reads = pendingReads
        pendingReads = []
        let snapshot = contents
        reads.forEach { $0(snapshot) }
    }

    // MARK: Screens and wake-ups

    var screenList = [ScreenInfo(frame: CGRect(x: 0, y: 0, width: 1440, height: 900), topInset: 24)]
    func screens() -> [ScreenInfo] { screenList }

    private(set) var wakeHandler: (@MainActor (WakeUpReason) -> Void)?
    func installWakeUpHandler(_ handler: @escaping @MainActor (WakeUpReason) -> Void) { wakeHandler = handler }
    func removeWakeUpHandler() { wakeHandler = nil }
    func wake(_ reason: WakeUpReason) { wakeHandler?(reason) }
}
