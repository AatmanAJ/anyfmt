import Foundation

/// Shared driver for the bundled ffmpeg/ffprobe. Used by the AV engine,
/// image fallbacks (WebP/AVIF) and the video/audio tools.
public struct FFmpeg: Sendable {
    public let locator: EngineLocator
    public init(locator: EngineLocator = .shared) { self.locator = locator }

    public var isAvailable: Bool { locator.ffmpeg != nil }

    /// Runs ffmpeg with `args` (inputs, filters, outputs). Prepends quiet,
    /// non-interactive, never-overwrite flags and streams `-progress` so
    /// `progress` gets out_time / duration live.
    @discardableResult
    public func run(_ args: [String], duration: Double? = nil, progress: ProgressSink = .ignore) async throws -> ProcessResult {
        guard let exe = locator.ffmpeg else { throw ConversionError.engineMissing("ffmpeg", detail: "not found in \(locator.helperDirectories.map(\.path))") }
        let full = ["-hide_banner", "-nostdin", "-n", "-loglevel", "error", "-progress", "pipe:1", "-nostats"] + args
        let parser = FFmpegProgressParser(duration: duration, sink: progress)
        let result = try await ProcessRunner.run(exe, full, captureStdout: false, onStdoutLine: { parser.feed($0) })
        progress(1)
        return result
    }

    /// ffprobe JSON for a file.
    public func probe(_ url: URL) async throws -> MediaProbe {
        guard let exe = locator.ffprobe else { throw ConversionError.engineMissing("ffprobe", detail: "not bundled") }
        let r = try await ProcessRunner.run(exe, ["-v", "error", "-print_format", "json", "-show_format", "-show_streams", url.path])
        do {
            return try JSONDecoder().decode(MediaProbe.self, from: r.stdout)
        } catch {
            throw ConversionError.unreadable(url, detail: "ffprobe json: \(error)")
        }
    }
}

/// Parses `-progress pipe:1` key=value lines into a fraction.
public final class FFmpegProgressParser: @unchecked Sendable {
    private let duration: Double?
    private let sink: ProgressSink
    private let lock = NSLock()
    private var last: Double = 0

    public init(duration: Double?, sink: ProgressSink) {
        self.duration = duration
        self.sink = sink
    }

    public func feed(_ line: String) {
        guard let eq = line.firstIndex(of: "=") else { return }
        let key = line[..<eq], value = line[line.index(after: eq)...]
        switch key {
        case "out_time_us", "out_time_ms": // both are microseconds in ffmpeg ≥ 4
            guard let us = Double(value), let d = duration, d > 0 else { return }
            let f = min(0.999, max(0, us / 1_000_000 / d))
            let emit: Bool = lock.withLock { if f > last { last = f; return true } else { return false } }
            if emit { sink(f) }
        case "progress" where value == "end":
            sink(1)
        default:
            break
        }
    }

    /// Exposed for tests.
    public var lastFraction: Double { lock.withLock { last } }
}

public struct MediaProbe: Sendable, Decodable {
    public struct Stream: Sendable, Decodable {
        public let index: Int
        public let codec_type: String?
        public let codec_name: String?
        public let width: Int?
        public let height: Int?
        public let r_frame_rate: String?
        public let avg_frame_rate: String?
        public let sample_rate: String?
        public let channels: Int?
        public let duration: String?
        public let pix_fmt: String?
        public let tags: [String: String]?
    }
    public struct Format: Sendable, Decodable {
        public let format_name: String?
        public let duration: String?
        public let size: String?
        public let bit_rate: String?
        public let tags: [String: String]?
    }
    public let streams: [Stream]
    public let format: Format?

    public var duration: Double? {
        if let d = format?.duration.flatMap(Double.init) { return d }
        return streams.compactMap { $0.duration.flatMap(Double.init) }.max()
    }
    public var video: Stream? { streams.first { $0.codec_type == "video" && $0.codec_name != "mjpeg" && $0.codec_name != "png" } }
    public var audio: Stream? { streams.first { $0.codec_type == "audio" } }
    public var hasVideo: Bool { video != nil }
    public var hasAudio: Bool { audio != nil }
}
