// DragSense: MIT licence, see LICENSE.
import CoreGraphics
import Foundation

/// Tuning for a ``DragSense`` instance. Every value is clamped to a safe
/// range by ``validated()``, which ``DragSense`` applies whenever the
/// configuration is set, so out-of-range values from a settings file can't
/// break detection.
public struct DragSenseConfiguration: Sendable, Equatable, Codable {
    /// The taps that open (or switch) the wheel. Keys must be unique: if two
    /// triggers share a key, or two share an id, the first one wins.
    public var triggers: [Trigger]

    /// Longest press, in seconds, that still counts as a tap when
    /// ``activation`` is `.tap`. Default 0.35 s, range ``tapThresholdRange``.
    public var tapThreshold: TimeInterval

    /// Poll interval while no mouse button is down, in seconds. A global
    /// mouse-down monitor wakes the poller early, so this is only the
    /// fallback. Default 0.25 s, range 0.05–2 s.
    public var idlePollInterval: TimeInterval

    /// Poll rate while the button is down, in Hz. 240 Hz bounds the
    /// detection delay at ~4.2 ms. Default 240, range 30–1000.
    public var activePollRate: Double

    /// Only file drags count: the drag pasteboard must carry `public.file-url`
    /// or a file-promise type. Turn off to sense any drag that writes the drag
    /// pasteboard (text, images, URLs). Default true.
    public var requireFileTypes: Bool

    /// Height, in points, of the band at the top of each screen where taps
    /// never open the wheel (the menu bar and the Mission Control
    /// "drag to top" zone). The band grows to the menu bar or notch inset of
    /// that screen when that is taller. 0 disables the band. Default 24 pt.
    public var topExclusionHeight: CGFloat

    /// How far the pointer must move from where the button went down before a
    /// drag counts, in points. Guards against apps that write the drag
    /// pasteboard on mouse-down. Waived when the poller noticed the button
    /// late (it can't know where the press started). Default 3 pt.
    public var minimumDragDistance: CGFloat

    /// How long to wait for the drag pasteboard contents (URLs, promised
    /// types) before carrying on with partial ``DragInfo``. Taps that land
    /// while the read is pending are held, then delivered. Default 0.25 s.
    public var pasteboardReadTimeout: TimeInterval

    /// After the mouse goes up with the wheel open, how long DragSense waits
    /// for ``DragSense/wheelDidAcceptDrop()`` or ``DragSense/cancelWheel()``
    /// before cancelling by itself. Default 1 s.
    public var dropResolutionTimeout: TimeInterval

    /// Minimum spacing of ``DragSenseEvent/dragMoved(_:)`` events, in
    /// seconds. Default 1/60 s. 0 sends one per poll in which the pointer moved.
    public var dragMovedInterval: TimeInterval

    /// What tapping the open wheel's own trigger does. Default `.ignore`.
    public var retapBehavior: RetapBehavior

    /// Whether the wheel opens when a trigger key goes down (`.press`, so tap
    /// or hold) or only on a quick tap (`.tap`). Default `.press`.
    public var activation: TriggerActivation

    /// A modifier whose quick tap, while a wheel is open, is reported as
    /// ``DragSenseEvent/lockKeyTapped(location:)`` (the host locks the
    /// highlighted segment). Ignored if it's also a trigger key. nil disables.
    /// Default ⌥ Option, which no default trigger uses.
    public var lockKey: ModifierKey?

    public static let tapThresholdRange: ClosedRange<TimeInterval> = 0.15...0.8
    public static let idlePollIntervalRange: ClosedRange<TimeInterval> = 0.05...2
    public static let activePollRateRange: ClosedRange<Double> = 30...1000
    public static let topExclusionHeightRange: ClosedRange<CGFloat> = 0...200
    public static let minimumDragDistanceRange: ClosedRange<CGFloat> = 0...50
    public static let pasteboardReadTimeoutRange: ClosedRange<TimeInterval> = 0.05...2
    public static let dropResolutionTimeoutRange: ClosedRange<TimeInterval> = 0.1...10
    public static let dragMovedIntervalRange: ClosedRange<TimeInterval> = 0...1

    /// One trigger, Shift, with id "primary". Hosts normally pass their own.
    public static let defaultTriggers = [Trigger(id: "primary", key: .shift)]

    public init(
        triggers: [Trigger] = DragSenseConfiguration.defaultTriggers,
        tapThreshold: TimeInterval = 0.35,
        idlePollInterval: TimeInterval = 0.25,
        activePollRate: Double = 240,
        requireFileTypes: Bool = true,
        topExclusionHeight: CGFloat = 24,
        minimumDragDistance: CGFloat = 3,
        pasteboardReadTimeout: TimeInterval = 0.25,
        dropResolutionTimeout: TimeInterval = 1,
        dragMovedInterval: TimeInterval = 1.0 / 60.0,
        retapBehavior: RetapBehavior = .ignore,
        activation: TriggerActivation = .press,
        lockKey: ModifierKey? = .option
    ) {
        self.triggers = triggers
        self.tapThreshold = tapThreshold
        self.idlePollInterval = idlePollInterval
        self.activePollRate = activePollRate
        self.requireFileTypes = requireFileTypes
        self.topExclusionHeight = topExclusionHeight
        self.minimumDragDistance = minimumDragDistance
        self.pasteboardReadTimeout = pasteboardReadTimeout
        self.dropResolutionTimeout = dropResolutionTimeout
        self.dragMovedInterval = dragMovedInterval
        self.retapBehavior = retapBehavior
        self.activation = activation
        self.lockKey = lockKey
    }

    public static let `default` = DragSenseConfiguration()

    /// A copy with every number clamped into its range (NaN becomes the
    /// default) and duplicate trigger keys or ids removed, first one winning.
    public func validated() -> DragSenseConfiguration {
        let base = DragSenseConfiguration.default
        var copy = self
        copy.tapThreshold = Self.clamp(tapThreshold, to: Self.tapThresholdRange, fallback: base.tapThreshold)
        copy.idlePollInterval = Self.clamp(idlePollInterval, to: Self.idlePollIntervalRange, fallback: base.idlePollInterval)
        copy.activePollRate = Self.clamp(activePollRate, to: Self.activePollRateRange, fallback: base.activePollRate)
        copy.topExclusionHeight = Self.clamp(topExclusionHeight, to: Self.topExclusionHeightRange, fallback: base.topExclusionHeight)
        copy.minimumDragDistance = Self.clamp(minimumDragDistance, to: Self.minimumDragDistanceRange, fallback: base.minimumDragDistance)
        copy.pasteboardReadTimeout = Self.clamp(pasteboardReadTimeout, to: Self.pasteboardReadTimeoutRange, fallback: base.pasteboardReadTimeout)
        copy.dropResolutionTimeout = Self.clamp(dropResolutionTimeout, to: Self.dropResolutionTimeoutRange, fallback: base.dropResolutionTimeout)
        copy.dragMovedInterval = Self.clamp(dragMovedInterval, to: Self.dragMovedIntervalRange, fallback: base.dragMovedInterval)

        var seenKeys = Set<ModifierKey>()
        var seenIDs = Set<String>()
        copy.triggers = triggers.filter { trigger in
            guard !seenKeys.contains(trigger.key), !seenIDs.contains(trigger.id) else { return false }
            seenKeys.insert(trigger.key)
            seenIDs.insert(trigger.id)
            return true
        }
        return copy
    }

    /// The trigger bound to `key`, if any.
    public func trigger(for key: ModifierKey) -> Trigger? {
        triggers.first { $0.key == key }
    }

    private static func clamp<T: BinaryFloatingPoint>(_ value: T, to range: ClosedRange<T>, fallback: T) -> T {
        guard !value.isNaN else { return fallback }
        return min(max(value, range.lowerBound), range.upperBound)
    }

    // MARK: Codable (missing keys fall back to defaults, so saved settings survive new fields)

    private enum CodingKeys: String, CodingKey {
        case triggers, tapThreshold, idlePollInterval, activePollRate, requireFileTypes
        case topExclusionHeight, minimumDragDistance, pasteboardReadTimeout
        case dropResolutionTimeout, dragMovedInterval, retapBehavior, activation, lockKey
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DragSenseConfiguration.default
        self.init(
            triggers: try c.decodeIfPresent([Trigger].self, forKey: .triggers) ?? d.triggers,
            tapThreshold: try c.decodeIfPresent(TimeInterval.self, forKey: .tapThreshold) ?? d.tapThreshold,
            idlePollInterval: try c.decodeIfPresent(TimeInterval.self, forKey: .idlePollInterval) ?? d.idlePollInterval,
            activePollRate: try c.decodeIfPresent(Double.self, forKey: .activePollRate) ?? d.activePollRate,
            requireFileTypes: try c.decodeIfPresent(Bool.self, forKey: .requireFileTypes) ?? d.requireFileTypes,
            topExclusionHeight: try c.decodeIfPresent(CGFloat.self, forKey: .topExclusionHeight) ?? d.topExclusionHeight,
            minimumDragDistance: try c.decodeIfPresent(CGFloat.self, forKey: .minimumDragDistance) ?? d.minimumDragDistance,
            pasteboardReadTimeout: try c.decodeIfPresent(TimeInterval.self, forKey: .pasteboardReadTimeout) ?? d.pasteboardReadTimeout,
            dropResolutionTimeout: try c.decodeIfPresent(TimeInterval.self, forKey: .dropResolutionTimeout) ?? d.dropResolutionTimeout,
            dragMovedInterval: try c.decodeIfPresent(TimeInterval.self, forKey: .dragMovedInterval) ?? d.dragMovedInterval,
            retapBehavior: try c.decodeIfPresent(RetapBehavior.self, forKey: .retapBehavior) ?? d.retapBehavior,
            activation: try c.decodeIfPresent(TriggerActivation.self, forKey: .activation) ?? d.activation,
            lockKey: c.contains(.lockKey) ? try c.decodeIfPresent(ModifierKey.self, forKey: .lockKey) : d.lockKey
        )
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(triggers, forKey: .triggers)
        try c.encode(tapThreshold, forKey: .tapThreshold)
        try c.encode(idlePollInterval, forKey: .idlePollInterval)
        try c.encode(activePollRate, forKey: .activePollRate)
        try c.encode(requireFileTypes, forKey: .requireFileTypes)
        try c.encode(topExclusionHeight, forKey: .topExclusionHeight)
        try c.encode(minimumDragDistance, forKey: .minimumDragDistance)
        try c.encode(pasteboardReadTimeout, forKey: .pasteboardReadTimeout)
        try c.encode(dropResolutionTimeout, forKey: .dropResolutionTimeout)
        try c.encode(dragMovedInterval, forKey: .dragMovedInterval)
        try c.encode(retapBehavior, forKey: .retapBehavior)
        try c.encode(activation, forKey: .activation)
        try c.encode(lockKey, forKey: .lockKey) // null = disabled on purpose
    }
}
