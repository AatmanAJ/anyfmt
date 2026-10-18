// DragSense: MIT licence, see LICENSE.
import AppKit

/// Why an ``InputSource`` woke DragSense between polls.
public enum WakeUpReason: Sendable, Equatable {
    /// A left mouse button went down somewhere.
    case mouseDown
    /// The pointer moved with the left button down.
    case mouseDragged
    /// Modifier flags changed (only from sources that observe them).
    case modifiersChanged
}

/// One display, in global AppKit coordinates.
public struct ScreenInfo: Sendable, Equatable {
    /// The screen's full frame.
    public var frame: CGRect
    /// Height of the system band at the top of this screen (menu bar, notch),
    /// or 0 when there is none (auto-hidden menu bar, secondary display).
    public var topInset: CGFloat

    public init(frame: CGRect, topInset: CGFloat = 0) {
        self.frame = frame
        self.topInset = topInset
    }
}

/// Everything DragSense reads from the system. ``SystemInputSource`` is the
/// real one; tests (yours and ours) supply a fake to drive DragSense
/// deterministically.
///
/// Called on the main actor only.
@MainActor
public protocol InputSource: AnyObject {
    /// Bit mask of mouse buttons held (bit 0 = left), as `NSEvent.pressedMouseButtons`.
    var pressedMouseButtons: Int { get }
    /// Pointer position in global AppKit coordinates, as `NSEvent.mouseLocation`.
    var mouseLocation: CGPoint { get }
    /// Modifier keys held right now, as `NSEvent.modifierFlags`.
    var modifierFlags: NSEvent.ModifierFlags { get }
    /// The drag pasteboard's `changeCount`, or nil while it can't be read
    /// (for example while a contents read is in flight on another thread).
    var dragPasteboardChangeCount: Int? { get }
    /// The drag pasteboard's types. Cheap: metadata only, no item data.
    func dragPasteboardTypes() -> [String]
    /// Pasteboard types that make a drag a file drag. A default
    /// implementation returns ``DragPasteboardType/fileTypes``.
    var fileTypes: Set<String> { get }
    /// Reads file URLs and promised types off the drag pasteboard and calls
    /// `completion` on the main actor. May complete synchronously. The read
    /// can be slow (a lazy pasteboard provider calls back into the drag
    /// source), so real implementations keep it off the main thread.
    func readDragContents(completion: @escaping @MainActor @Sendable (DragPasteboardContents) -> Void)
    /// All displays.
    func screens() -> [ScreenInfo]
    /// Starts calling `handler` on global mouse-down (and similar) events so
    /// the poller can idle at a low rate. Replaces any previous handler.
    func installWakeUpHandler(_ handler: @escaping @MainActor (WakeUpReason) -> Void)
    /// Stops the wake-up handler.
    func removeWakeUpHandler()
}

extension InputSource {
    public var fileTypes: Set<String> { DragPasteboardType.fileTypes }
}

/// The clock and repeating timer that drive DragSense's poll.
/// ``DispatchPollScheduler`` is the real one.
@MainActor
public protocol PollScheduler: AnyObject {
    /// Monotonic seconds (`ProcessInfo.systemUptime` for the real clock).
    var now: TimeInterval { get }
    /// Calls `handler` every `interval` seconds, first after one interval,
    /// replacing any current schedule. `leeway` lets the OS coalesce wake-ups.
    func schedule(interval: TimeInterval, leeway: TimeInterval, handler: @escaping @MainActor () -> Void)
    /// Stops calling the handler.
    func cancel()
}
