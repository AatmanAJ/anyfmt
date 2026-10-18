// DragSense: MIT licence, see LICENSE.
import CoreGraphics

/// The drag-and-wheel state machine.
///
/// ```
/// idle ─▶ dragging ─▶ wheelOpen(trigger) ─▶ dropped ───▶ idle
///            ▲            │   ▲   │       └▶ cancelled ─▶ idle
///            │            │   └───┘ tap another trigger: switch
///            │            └─ mouse up, no wheel ─────────▶ idle
///            └── cancelled while the button is still down
/// ```
///
/// `dropped` and `cancelled` are transient: observers see them, then the
/// next state (`idle`, or `dragging` when the host cancels mid-drag)
/// immediately after.
public enum DragSenseState: Equatable, Sendable {
    /// No file drag in progress (the button may be down for a click or a
    /// non-file drag).
    case idle
    /// A file drag is in progress and the wheel is closed. `dragID` is
    /// ``DragInfo/id``.
    case dragging(dragID: Int)
    /// The wheel opened by the trigger with this id is showing. It stays open
    /// after the key is released, until the host reports a drop or cancel.
    case wheelOpen(triggerID: String)
    /// The host accepted the drop on its wheel.
    case dropped
    /// The wheel closed without a drop.
    case cancelled

    /// True while a file drag is being tracked (dragging or wheel open).
    public var isTrackingDrag: Bool {
        switch self {
        case .dragging, .wheelOpen: return true
        case .idle, .dropped, .cancelled: return false
        }
    }

    /// The open wheel's trigger id, if any.
    public var openTriggerID: String? {
        if case .wheelOpen(let id) = self { return id }
        return nil
    }
}

/// What DragSense tells the host. Locations are global AppKit coordinates
/// (origin bottom-left of the primary screen, y up), as `NSEvent.mouseLocation`.
public enum DragSenseEvent: Sendable, Equatable {
    /// A file drag started (the drag pasteboard changed while the button was
    /// down, and it carries file types).
    case dragBegan(DragInfo)
    /// A trigger was tapped mid-drag: open the wheel at `location`, or switch
    /// it if one is already open. Never sent inside the top exclusion band
    /// when the wheel is closed.
    case triggerTapped(Trigger, DragInfo, location: CGPoint)
    /// The pointer moved while the wheel is open (throttled by
    /// ``DragSenseConfiguration/dragMovedInterval``).
    case dragMoved(CGPoint)
    /// The mouse button went up, ending the drag. If the wheel is open,
    /// answer with ``DragSense/wheelDidAcceptDrop()`` or
    /// ``DragSense/cancelWheel()`` (DragSense cancels by itself after
    /// ``DragSenseConfiguration/dropResolutionTimeout``).
    case dragEnded(location: CGPoint)
}
