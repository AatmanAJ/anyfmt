// DragSense: MIT licence, see LICENSE.
import AppKit

/// Turns a stream of modifier-flag samples into taps.
///
/// A tap is one modifier going down and up again within the threshold with
/// no other modifier involved. Rules:
/// - **Holds never fire**: release later than the threshold is not a tap.
/// - **Chords spoil**: if a second modifier goes down while one is held, both
///   are spoiled, whatever happens next. Two keys first seen down in the same
///   sample are spoiled too.
/// - **Already held doesn't count**: keys down when the detector is reset
///   (for example ⌘ held before a Finder ⌘-drag) have no known press time
///   and can never complete a tap.
///
/// Durations are measured between samples, so they're quantised to the poll
/// interval (±4.2 ms at 240 Hz). A press and release that both fall between
/// two samples is invisible; at 240 Hz that needs a tap shorter than ~4 ms,
/// which a human finger doesn't produce.
struct TapDetector: Sendable {
    struct Tap: Equatable, Sendable {
        var key: ModifierKey
        /// Sample time at which the press was first seen.
        var pressedAt: TimeInterval
        /// Sample time at which the release was first seen.
        var releasedAt: TimeInterval
        /// The previous sample's time: the release happened after this.
        var earliestRelease: TimeInterval
    }

    private struct Press: Sendable {
        var pressedAt: TimeInterval?
        var spoiled: Bool
    }

    private var held: [ModifierKey: Press] = [:]
    private var lastSampleTime: TimeInterval = 0
    /// Keys that went down in the latest sample (not keys already held at
    /// reset). Used by `.press` activation, which opens on key-down.
    private(set) var newPresses: [Tap] = []

    /// Floating-point slack for the threshold comparison.
    static let epsilon: TimeInterval = 1e-6

    /// Forget everything; keys in `flags` count as held with no press time.
    mutating func reset(flags: NSEvent.ModifierFlags, at time: TimeInterval) {
        held = [:]
        newPresses = []
        for key in ModifierKey.keys(in: flags) {
            held[key] = Press(pressedAt: nil, spoiled: true)
        }
        lastSampleTime = time
    }

    /// Feeds one sample; returns taps completed by it, in a stable order.
    mutating func feed(flags: NSEvent.ModifierFlags, at time: TimeInterval, threshold: TimeInterval) -> [Tap] {
        let current = ModifierKey.keys(in: flags)
        let previous = Set(held.keys)
        let released = previous.subtracting(current)
        let pressed = current.subtracting(previous)
        let stillHeld = previous.intersection(current)

        var taps: [Tap] = []
        for key in ModifierKey.allCases where released.contains(key) {
            guard let press = held.removeValue(forKey: key) else { continue }
            if !press.spoiled, let pressedAt = press.pressedAt,
               time - pressedAt <= threshold + Self.epsilon {
                taps.append(Tap(key: key, pressedAt: pressedAt, releasedAt: time, earliestRelease: lastSampleTime))
            }
        }

        // A key released and another pressed in the same sample is treated as
        // sequential, not a chord: we can't tell which came first.
        let chord = !stillHeld.isEmpty || pressed.count > 1
        newPresses = []
        for key in ModifierKey.allCases where pressed.contains(key) {
            held[key] = Press(pressedAt: time, spoiled: chord)
            newPresses.append(Tap(key: key, pressedAt: time, releasedAt: time, earliestRelease: lastSampleTime))
        }
        if chord && !pressed.isEmpty {
            for key in stillHeld { held[key]?.spoiled = true }
        }
        lastSampleTime = time
        return taps
    }

    /// Keys currently held, for diagnostics.
    var heldKeys: Set<ModifierKey> { Set(held.keys) }

    /// Keys pressed since the last reset and still down, newest first (keys
    /// already held at reset are excluded). `.press` activation uses this when
    /// a drag is recognised after the key went down.
    var freshlyHeld: [Tap] {
        held.compactMap { key, press in
            press.pressedAt.map { Tap(key: key, pressedAt: $0, releasedAt: $0, earliestRelease: $0) }
        }
        .sorted { $0.pressedAt > $1.pressedAt }
    }
}
