import AppKit
import AVFoundation
import Combine
import HaloCore

/// AVPlayer wrapper for the editors: frame-exact, coalesced seeking (only one
/// seek in flight; the latest request wins), frame stepping, range looping,
/// and an exact still of the paused frame (also what offscreen renders show).
@MainActor
final class PlayerController: ObservableObject {
    let player = AVPlayer()
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var still: NSImage?
    @Published private(set) var stillTime: Double = -1
    private(set) var duration: Double = 0
    private(set) var frameDuration: Double = 1.0 / 30
    /// While set, playback runs inside this range and loops back to its start.
    var loopRange: ClosedRange<Double>?
    /// Called on every time update (60 Hz while playing) — used by the bleep preview.
    var onTick: ((Double) -> Void)?

    private var hasVideo = false
    private var assetURL: URL?
    private var stillSize = CGSize(width: 1600, height: 1600)
    private var timeObserver: Any?
    private var statusCancellable: AnyCancellable?
    private var seeking = false
    private var pendingSeek: Double?
    private var stillTask: Task<Void, Never>?

    init() {
        player.actionAtItemEnd = .pause
        statusCancellable = player.publisher(for: \.timeControlStatus).receive(on: RunLoop.main).sink { [weak self] status in
            MainActor.assumeIsolated { self?.isPlaying = status != .paused }
        }
    }

    func attach(asset: AVURLAsset, duration: Double, frameDuration: Double, hasVideo: Bool, displaySize: CGSize) {
        self.duration = duration
        self.frameDuration = frameDuration
        self.hasVideo = hasVideo
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        assetURL = asset.url
        let scale = min(1, 1600 / max(displaySize.width, displaySize.height))
        stillSize = CGSize(width: displaySize.width * scale, height: displaySize.height * scale)
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 60), queue: .main) { [weak self] time in
            MainActor.assumeIsolated { self?.tick(time.seconds) }
        }
        refreshStill()
    }

    private func tick(_ t: Double) {
        guard t.isFinite, !seeking else { return }
        if isPlaying, let r = loopRange, t >= r.upperBound - frameDuration / 2 {
            seek(to: r.lowerBound)
            return
        }
        currentTime = min(max(0, t), duration)
        onTick?(currentTime)
    }

    func togglePlay() { isPlaying ? pause() : play() }

    func play() {
        if let r = loopRange, !(r.lowerBound..<(r.upperBound - frameDuration)).contains(currentTime) {
            seek(to: r.lowerBound)
        } else if currentTime >= duration - frameDuration {
            seek(to: 0)
        }
        player.play()
    }

    func pause() {
        player.pause()
        refreshStill()
    }

    /// Exact seek, coalesced: while one seek runs, only the newest target is kept.
    func seek(to t: Double) {
        let target = min(max(0, t), max(0, duration - frameDuration / 2))
        currentTime = target
        if seeking { pendingSeek = target; return }
        seeking = true
        let time = CMTime(seconds: target, preferredTimescale: 600_000)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor in self?.seekFinished() }
        }
    }

    private func seekFinished() {
        seeking = false
        if let next = pendingSeek {
            pendingSeek = nil
            seek(to: next)
        } else if !isPlaying {
            refreshStill()
        }
    }

    /// Steps whole frames from the current frame boundary.
    func step(_ frames: Int) {
        player.pause()
        let frame = (currentTime / frameDuration + 1e-4).rounded(.down)
        seek(to: (frame + Double(frames)) * frameDuration)
    }

    func jump(by seconds: Double) {
        player.pause()
        seek(to: currentTime + seconds)
    }

    /// Generates the exact frame for the paused time (debounced).
    private func refreshStill() {
        guard hasVideo, let assetURL else { return }
        stillTask?.cancel()
        let t = currentTime, size = stillSize
        stillTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 40_000_000)
            guard !Task.isCancelled else { return }
            let image = await Self.exactFrame(assetURL, at: t, maximumSize: size)
            guard !Task.isCancelled, let self, let image else { return }
            self.still = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
            self.stillTime = t
        }
    }

    /// The exact frame at `t` (zero tolerance), display orientation.
    nonisolated static func exactFrame(_ url: URL, at t: Double, maximumSize: CGSize) async -> CGImage? {
        let g = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        g.appliesPreferredTrackTransform = true
        g.requestedTimeToleranceBefore = .zero
        g.requestedTimeToleranceAfter = .zero
        g.maximumSize = maximumSize
        return try? await g.image(at: CMTime(seconds: t, preferredTimescale: 600_000)).image
    }

    /// Whether the still matches what's on screen (paused, same frame).
    var stillIsCurrent: Bool { !isPlaying && still != nil && abs(stillTime - currentTime) < frameDuration / 2 }

    /// Waits until a still for the current time exists (offscreen renders, tests).
    func waitForStill(timeout: Double = 5) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !stillIsCurrent && Date() < deadline { try? await Task.sleep(nanoseconds: 20_000_000) }
    }

    func teardown() {
        player.pause()
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        stillTask?.cancel()
        player.replaceCurrentItem(with: nil)
    }
}
