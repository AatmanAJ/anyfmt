// DragSense: MIT licence, see LICENSE.
import AppKit

/// A modifier key that can be tapped mid-drag.
///
/// Raw values are stable and safe to persist.
public enum ModifierKey: String, CaseIterable, Codable, Sendable {
    case shift
    case command
    case control
    case option
    /// The fn / Globe key. Some keyboards also report this flag for arrow and
    /// function keys, so it makes a noisy trigger; prefer the other four.
    case function

    /// The matching `NSEvent.ModifierFlags` bit.
    public var flag: NSEvent.ModifierFlags {
        switch self {
        case .shift: return .shift
        case .command: return .command
        case .control: return .control
        case .option: return .option
        case .function: return .function
        }
    }

    /// The symbol macOS uses in menus: ⇧ ⌘ ⌃ ⌥, and "fn" for the function key.
    public var symbol: String {
        switch self {
        case .shift: return "⇧"
        case .command: return "⌘"
        case .control: return "⌃"
        case .option: return "⌥"
        case .function: return "fn"
        }
    }

    /// Creates the key for a single modifier flag. Returns nil for anything
    /// that isn't exactly one of the five supported flags.
    public init?(flag: NSEvent.ModifierFlags) {
        guard let key = ModifierKey.allCases.first(where: { $0.flag == flag }) else { return nil }
        self = key
    }

    /// All five flags DragSense tracks. Caps Lock, numeric-pad and help bits
    /// are deliberately excluded: they describe state, not a key being held.
    public static let trackedFlags: NSEvent.ModifierFlags = [.shift, .command, .control, .option, .function]

    /// The keys currently held in `flags`.
    public static func keys(in flags: NSEvent.ModifierFlags) -> Set<ModifierKey> {
        Set(allCases.filter { flags.contains($0.flag) })
    }

    /// Apple's display order for modifier glyphs (fn ⌃ ⌥ ⇧ ⌘).
    public static let displayOrder: [ModifierKey] = [.function, .control, .option, .shift, .command]

    /// Glyphs for a set of keys in Apple's display order, e.g. "⌃⌥⌘".
    public static func symbols(for keys: Set<ModifierKey>) -> String {
        displayOrder.filter(keys.contains).map(\.symbol).joined()
    }
}
