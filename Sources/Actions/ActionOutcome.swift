import Foundation

/// What a Control-wheel action did. The caller (the wheel overlay) shows the
/// message in its confirmation HUD or error toast.
public enum ActionOutcome: Equatable, Sendable {
    /// Finished. The message is a short confirmation ("Copied 3 items") for
    /// actions with no UI of their own, or nil when the action's own UI is the
    /// feedback (the shelf, the terminal window, the AirDrop sheet).
    case done(String?)
    /// The user backed out (closed the chooser, cancelled AirDrop).
    case cancelled
    /// Nothing (or not everything) happened. The message is human and ready to show.
    case failed(String)

    public var isSuccess: Bool {
        if case .done = self { return true }
        return false
    }

    public var message: String? {
        switch self {
        case .done(let m): m
        case .cancelled: nil
        case .failed(let m): m
        }
    }
}
