// DragSense: MIT licence, see LICENSE.

/// A modifier tap the host app cares about.
///
/// `id` is opaque to DragSense: the host maps it to meaning (for example
/// "convert", "tools", "actions"). Change ``DragSenseConfiguration/triggers``
/// at any time to remap keys; the change applies to the next tap.
public struct Trigger: Hashable, Codable, Sendable, Identifiable {
    public var id: String
    public var key: ModifierKey

    public init(id: String, key: ModifierKey) {
        self.id = id
        self.key = key
    }
}

/// What happens when the trigger that opened the wheel is tapped again.
public enum RetapBehavior: String, Codable, Sendable, CaseIterable {
    /// The tap is ignored and the wheel stays open (default). Safer for
    /// people who double-tap by habit.
    case ignore
    /// The wheel closes (``DragSenseState/cancelled``) and the drag carries on;
    /// any trigger tap reopens it.
    case close
}

/// When a trigger key opens (or switches) the wheel.
public enum TriggerActivation: String, Codable, Sendable, CaseIterable {
    /// As soon as the key goes down mid-drag, so a quick tap and a hold both
    /// work (default). A key already held when the drag started (Finder's ⌘
    /// move / ⌥ copy drags) never fires, so those keep working.
    case press
    /// Only a quick tap: press and release within the tap threshold with no
    /// other modifier involved. Holding a key never opens the wheel.
    case tap
}
