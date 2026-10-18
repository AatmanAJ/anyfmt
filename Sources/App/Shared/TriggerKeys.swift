import AppKit

/// A modifier key that can open a wheel. Raw values match DragSense's
/// `ModifierKey` and the strings stored in `AppSettings.convertKey` etc.
enum TriggerKey: String, CaseIterable, Identifiable, Sendable, Hashable {
    case shift, command, control, option, function

    var id: String { rawValue }

    /// Keyboard symbol, as printed on Apple keyboards.
    var symbol: String {
        switch self {
        case .shift: "⇧"
        case .command: "⌘"
        case .control: "⌃"
        case .option: "⌥"
        case .function: "fn"
        }
    }

    var name: String {
        switch self {
        case .shift: String(localized: "Shift", comment: "Modifier key name")
        case .command: String(localized: "Command", comment: "Modifier key name")
        case .control: String(localized: "Control", comment: "Modifier key name")
        case .option: String(localized: "Option", comment: "Modifier key name")
        case .function: String(localized: "Function", comment: "Modifier key name (fn / globe)")
        }
    }

    /// "⇧ Shift"
    var displayName: String { "\(symbol) \(name)" }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .shift: .shift
        case .command: .command
        case .control: .control
        case .option: .option
        case .function: .function
        }
    }

    /// Modifier keys held in `flags` (Caps Lock and device-dependent bits ignored).
    static func keys(in flags: NSEvent.ModifierFlags) -> Set<TriggerKey> {
        Set(allCases.filter { flags.contains($0.flag) })
    }

    /// Lenient parse of a stored value; unknown strings fall back to `fallback`.
    static func parse(_ raw: String, fallback: TriggerKey) -> TriggerKey {
        TriggerKey(rawValue: raw.lowercased()) ?? fallback
    }
}

/// The three wheels a trigger key can open.
enum TriggerRole: String, CaseIterable, Identifiable, Sendable, Hashable {
    case convert, tools, actions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .convert: String(localized: "Convert", comment: "Wheel name")
        case .tools: String(localized: "Tools", comment: "Wheel name")
        case .actions: String(localized: "Actions", comment: "Wheel name")
        }
    }

    var summary: String {
        switch self {
        case .convert: String(localized: "Formats this file can become")
        case .tools: String(localized: "Compress, resize, trim and more")
        case .actions: String(localized: "AirDrop, Float, Copy, Move, Path, Terminal")
        }
    }

    var glyph: String {
        switch self {
        case .convert: "arrow.triangle.2.circlepath"
        case .tools: "wand.and.stars"
        case .actions: "square.and.arrow.up"
        }
    }

    var defaultKey: TriggerKey {
        switch self {
        case .convert: .shift
        case .tools: .command
        case .actions: .control
        }
    }
}

/// Which key opens which wheel. Keys are always distinct: assigning a key that
/// another wheel uses swaps the two, so there is never a conflict to resolve.
struct TriggerAssignment: Equatable, Sendable {
    private(set) var keys: [TriggerRole: TriggerKey]

    init(convert: TriggerKey, tools: TriggerKey, actions: TriggerKey) {
        keys = [.convert: convert, .tools: tools, .actions: actions]
        repairDuplicates()
    }

    static let `default` = TriggerAssignment(convert: .shift, tools: .command, actions: .control)

    subscript(role: TriggerRole) -> TriggerKey { keys[role] ?? role.defaultKey }

    func role(for key: TriggerKey) -> TriggerRole? {
        TriggerRole.allCases.first { self[$0] == key }
    }

    /// Assigns `key` to `role`; the wheel that had `key` takes `role`'s old key.
    mutating func assign(_ key: TriggerKey, to role: TriggerRole) {
        let previous = self[role]
        guard previous != key else { return }
        if let other = self.role(for: key) { keys[other] = previous }
        keys[role] = key
    }

    /// Stored settings could have been edited by hand; make them distinct again.
    private mutating func repairDuplicates() {
        var used = Set<TriggerKey>()
        for role in TriggerRole.allCases {
            let k = self[role]
            if used.insert(k).inserted { continue }
            let free = ([role.defaultKey] + TriggerKey.allCases).first { !used.contains($0) } ?? role.defaultKey
            keys[role] = free
            used.insert(free)
        }
    }
}

/// Recognises a modifier *tap*: one modifier pressed and released within the
/// threshold, with no other modifier or key joining in. Holds and chords never
/// count, so Finder's own ⌘/⌥ drag modifiers keep working (D-001).
struct ModifierTapDetector: Sendable {
    enum Outcome: Equatable, Sendable {
        case tap(TriggerKey, duration: TimeInterval)
        case held(TriggerKey, duration: TimeInterval)
        /// More than one modifier, or a regular key, was involved.
        case chord(Set<TriggerKey>)
    }

    var threshold: TimeInterval
    private var held: Set<TriggerKey> = []
    private var candidate: (key: TriggerKey, start: TimeInterval)?
    private var involved: Set<TriggerKey> = []
    private var spoiled = false

    init(threshold: TimeInterval) { self.threshold = threshold }

    /// True while any modifier is down.
    var isPressing: Bool { !held.isEmpty }

    /// The key currently being pressed as a possible tap.
    var pendingKey: TriggerKey? { spoiled ? nil : candidate?.key }

    /// Feed every `flagsChanged`. Returns an outcome when the last modifier is released.
    mutating func flagsChanged(to keys: Set<TriggerKey>, at time: TimeInterval) -> Outcome? {
        defer { held = keys }
        if held.isEmpty {
            guard !keys.isEmpty else { return nil }
            involved = keys
            spoiled = keys.count > 1
            candidate = keys.count == 1 ? keys.first.map { ($0, time) } : nil
            return nil
        }
        involved.formUnion(keys)
        if keys.count > 1 || !keys.isSubset(of: held) { spoiled = true }
        guard keys.isEmpty else { return nil }
        defer { candidate = nil; spoiled = false; involved = [] }
        if !spoiled, let c = candidate {
            let d = max(0, time - c.start)
            return d < threshold ? .tap(c.key, duration: d) : .held(c.key, duration: d)
        }
        return .chord(involved)
    }

    /// A non-modifier key went down while a modifier was held (e.g. ⌘C): not a tap.
    mutating func otherKeyPressed() {
        if !held.isEmpty { spoiled = true }
    }

    mutating func reset() {
        held = []
        candidate = nil
        involved = []
        spoiled = false
    }
}
