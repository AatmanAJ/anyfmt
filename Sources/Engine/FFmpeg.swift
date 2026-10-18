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
        default:
            // `progress=end` is ignored: ffmpeg also prints it when killed on cancel.
            // FFmpeg.run reports 1.0 itself after a successful exit.
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
        public let disposition: [String: Int]?
        public let side_data_list: [SideData]?
        public let bits_per_raw_sample: String?
        public let bits_per_sample: Int?
        public let sample_fmt: String?
        public let bit_rate: String?

        /// Cover art / attached pictures aren't real video streams.
        public var isAttachedPicture: Bool { disposition?["attached_pic"] == 1 }
        /// Display-matrix rotation in degrees, if any.
        public var rotation: Double? { side_data_list?.compactMap(\.rotation).first }

        private enum CodingKeys: String, CodingKey {
            case index, codec_type, codec_name, width, height, r_frame_rate, avg_frame_rate, sample_rate, channels
            case duration, pix_fmt, tags, disposition, side_data_list, bits_per_raw_sample, bits_per_sample, sample_fmt, bit_rate
        }

        /// Lenient: a field with an unexpected type becomes nil instead of failing the whole probe.
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            index = (try? c.decode(Int.self, forKey: .index)) ?? 0
            codec_type = try? c.decode(String.self, forKey: .codec_type)
            codec_name = try? c.decode(String.self, forKey: .codec_name)
            width = Lenient.int(c, .width)
            height = Lenient.int(c, .height)
            r_frame_rate = try? c.decode(String.self, forKey: .r_frame_rate)
            avg_frame_rate = try? c.decode(String.self, forKey: .avg_frame_rate)
            sample_rate = Lenient.string(c, .sample_rate)
            channels = Lenient.int(c, .channels)
            duration = Lenient.string(c, .duration)
            pix_fmt = try? c.decode(String.self, forKey: .pix_fmt)
            tags = try? c.decode([String: String].self, forKey: .tags)
            disposition = (try? c.decode([String: Lenient.IntValue].self, forKey: .disposition))?.compactMapValues(\.value)
            side_data_list = try? c.decode([SideData].self, forKey: .side_data_list)
            bits_per_raw_sample = Lenient.string(c, .bits_per_raw_sample)
            bits_per_sample = Lenient.int(c, .bits_per_sample)
            sample_fmt = try? c.decode(String.self, forKey: .sample_fmt)
            bit_rate = Lenient.string(c, .bit_rate)
        }
    }
    public struct SideData: Sendable, Decodable {
        public let side_data_type: String?
        public let rotation: Double?

        private enum CodingKeys: String, CodingKey { case side_data_type, rotation }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            side_data_type = try? c.decode(String.self, forKey: .side_data_type)
            rotation = (try? c.decode(Double.self, forKey: .rotation)) ?? Lenient.string(c, .rotation).flatMap(Double.init)
        }
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
    public var video: Stream? { streams.first { $0.codec_type == "video" && !$0.isAttachedPicture } }
    public var audio: Stream? { streams.first { $0.codec_type == "audio" } }
    public var hasVideo: Bool { video != nil }
    public var hasAudio: Bool { audio != nil }
}

/// Tolerant decoding helpers for ffprobe JSON (numbers sometimes arrive as strings).
enum Lenient {
    struct IntValue: Decodable {
        let value: Int?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let i = try? c.decode(Int.self) { value = i }
            else if let s = try? c.decode(String.self) { value = Int(s) }
            else if let b = try? c.decode(Bool.self) { value = b ? 1 : 0 }
            else { value = nil }
        }
    }

    static func int<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ k: K) -> Int? {
        if let i = try? c.decode(Int.self, forKey: k) { return i }
        if let s = try? c.decode(String.self, forKey: k) { return Int(s) }
        return nil
    }

    static func string<K: CodingKey>(_ c: KeyedDecodingContainer<K>, _ k: K) -> String? {
        if let s = try? c.decode(String.self, forKey: k) { return s }
        if let i = try? c.decode(Int.self, forKey: k) { return String(i) }
        if let d = try? c.decode(Double.self, forKey: k) { return String(d) }
        return nil
    }
}
