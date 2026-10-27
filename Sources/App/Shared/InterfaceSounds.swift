import AVFoundation
import AppKit

/// anyfmt's interface sounds (Settings › General › Sounds): a soft pop as the wheel opens,
/// a tiny tap per segment, two glassy plucks on a drop, a breath on cancel, and a chime when a
/// batch finishes. Synthesized for anyfmt (Resources/Sounds), quiet by design.
///
/// Each sound keeps a few preloaded players so fast ticks overlap instead of cutting off.
@MainActor
final class InterfaceSounds {
    enum Cue: String, CaseIterable {
        case open, tick, page, select, cancel, done, fail

        /// Mixed against each other by ear: ticks sit well under everything else.
        var volume: Float {
            switch self {
            case .tick: 0.22
            case .page: 0.26
            case .open, .cancel: 0.3
            case .select: 0.4
            case .done, .fail: 0.45
            }
        }
    }

    static let shared = InterfaceSounds()

    /// Mirrors the Settings switch.
    var isEnabled = true

    private var pools: [Cue: [AVAudioPlayer]] = [:]
    private var next: [Cue: Int] = [:]
    private var lastTick = Date.distantPast

    private init() {
        for cue in Cue.allCases {
            guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav", subdirectory: "Sounds")
                    ?? Bundle.main.url(forResource: cue.rawValue, withExtension: "wav") else { continue }
            let count = cue == .tick || cue == .page ? 4 : 2
            pools[cue] = (0..<count).compactMap { _ in
                let player = try? AVAudioPlayer(contentsOf: url)
                player?.volume = cue.volume
                player?.prepareToPlay()
                return player
            }
        }
    }

    func play(_ cue: Cue) {
        guard isEnabled, let pool = pools[cue], !pool.isEmpty else { return }
        if cue == .tick {
            // A fast sweep across the ring is one rattle, not a machine gun.
            let now = Date()
            guard now.timeIntervalSince(lastTick) > 0.035 else { return }
            lastTick = now
        }
        let i = next[cue, default: 0]
        next[cue] = (i + 1) % pool.count
        let player = pool[i]
        player.currentTime = 0
        player.play()
    }
}
