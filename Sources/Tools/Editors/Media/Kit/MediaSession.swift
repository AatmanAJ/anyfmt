import AppKit
import AVFoundation
import HaloCore

/// A private temp folder for preview proxies, removed when the editor goes away.
final class PreviewScratch: Sendable {
    let url: URL

    init() {
        url = FileManager.default.temporaryDirectory.appendingPathComponent("HaloPreview-\(UUID().uuidString)", isDirectory: true)
    }

    deinit { try? FileManager.default.removeItem(at: url) }
}

/// Everything an editor needs about one input: ffprobe facts, an AVFoundation
/// asset to preview (the file itself, or a quick H.264/AAC proxy for formats
/// AVFoundation can't play, such as MKV, WebM, AVI, Ogg), the player and the
/// keyframe index.
@MainActor
final class MediaSession: ObservableObject {
    let url: URL
    let isVideo: Bool
    @Published private(set) var state: MediaLoadState
    @Published private(set) var info: MediaInfo?
    @Published private(set) var keyframes: KeyframeIndex?
    @Published private(set) var asset: AVURLAsset?
    let player = PlayerController()
    let filmstrip = FilmstripLoader()
    private let scratch = PreviewScratch()
    private var loadTask: Task<Void, Never>?

    init(url: URL, isVideo: Bool) {
        self.url = url
        self.isVideo = isVideo
        state = .loading(String(localized: "Opening…"))
    }

    var duration: Double { info?.duration ?? 0 }
    var frameDuration: Double { info?.video?.frameDuration ?? (1.0 / 100) }
    /// Display size (rotation applied).
    var displaySize: CGSize {
        guard let v = info?.video else { return CGSize(width: 16, height: 9) }
        return CGSize(width: max(1, Double(v.displayWidth) * (v.rotation % 180 == 0 ? v.sampleAspect : 1)), height: max(1, Double(v.displayHeight)))
    }

    /// Starts loading once; safe to call repeatedly.
    func load(wantsKeyframes: Bool = false) {
        guard loadTask == nil else { return }
        let url = url, isVideo = isVideo, scratch = scratch
        loadTask = Task { [weak self] in
            do {
                let info = try await MediaInfo.load(url)
                guard let self else { return }
                self.info = info
                if isVideo && !info.hasVideo { throw ConversionError.noVideo(url) }
                if !isVideo && !info.hasAudio { throw ConversionError.noAudio(url) }
                let playable = try await Self.playableAsset(for: url, info: info, isVideo: isVideo, scratch: scratch) { [weak self] message in
                    self?.state = .loading(message)
                }
                self.asset = playable
                self.player.attach(asset: playable, duration: info.duration, frameDuration: self.frameDuration,
                                   hasVideo: isVideo, displaySize: self.displaySize)
                self.state = .ready
                if isVideo { self.filmstrip.attach(asset: playable, duration: info.duration, aspect: self.displaySize) }
                if wantsKeyframes, isVideo {
                    self.keyframes = try? await KeyframeIndex.load(info)
                }
            } catch {
                self?.state = .failed((error as? ConversionError)?.errorDescription ?? error.localizedDescription)
                Log.tools.error("editor load failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// The file itself when AVFoundation plays it, else a proxy in `scratch`.
    private static func playableAsset(for url: URL, info: MediaInfo, isVideo: Bool, scratch: PreviewScratch,
                                      status: @MainActor (String) -> Void) async throws -> AVURLAsset {
        let asset = AVURLAsset(url: url)
        let playable = (try? await asset.load(.isPlayable)) ?? false
        let tracks = (try? await asset.loadTracks(withMediaType: isVideo ? .video : .audio)) ?? []
        if playable && !tracks.isEmpty { return asset }
        status(String(localized: "Preparing preview…"))
        try FileManager.default.createDirectory(at: scratch.url, withIntermediateDirectories: true)
        let ffmpeg = FFmpeg()
        if isVideo {
            let proxy = scratch.url.appendingPathComponent("proxy.mp4")
            let maps = ["-map", "0:\(info.video?.index ?? 0)"] + (info.audio.map { ["-map", "0:\($0.index)"] } ?? [])
            let audio = info.hasAudio ? ["-c:a", "aac_at", "-b:a", "128k"] : []
            // Timestamps stay aligned with the source: no seek, no frame-rate change.
            let base = ["-i", url.path] + maps + ["-vf", "scale=-2:'min(720,ih)'"]
            do {
                try await ffmpeg.run(base + ["-c:v", "h264_videotoolbox", "-q:v", "50", "-pix_fmt", "yuv420p"] + audio + [proxy.path], duration: info.duration)
            } catch {
                try? FileManager.default.removeItem(at: proxy)
                try await ffmpeg.run(base + ["-c:v", "libx264", "-preset", "ultrafast", "-crf", "26", "-pix_fmt", "yuv420p"] + audio + [proxy.path], duration: info.duration)
            }
            return AVURLAsset(url: proxy)
        } else {
            let proxy = scratch.url.appendingPathComponent("proxy.m4a")
            try await ffmpeg.run(["-i", url.path, "-map", "0:\(info.audio?.index ?? 0)", "-c:a", "aac_at", "-b:a", "160k", proxy.path], duration: info.duration)
            return AVURLAsset(url: proxy)
        }
    }

    func stop() {
        loadTask?.cancel()
        player.pause()
        filmstrip.cancel()
    }
}
