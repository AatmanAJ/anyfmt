import Foundation

/// What the media tools need to know about a file, from one ffprobe call.
/// Richer than `MediaProbe` (Engine/FFmpeg.swift): rotation, sample formats,
/// extradata hashes (for lossless joins) and attached-picture flags.
public struct MediaInfo: Sendable, Equatable {
    public struct Video: Sendable, Equatable {
        public let index: Int
        public let codec: String
        /// Coded size (before rotation).
        public let width: Int
        public let height: Int
        /// Display rotation in degrees (0, 90, 180, 270), from the display matrix.
        public let rotation: Int
        public let frameRate: Double
        public let pixelFormat: String?
        public let profile: String?
        public let bitRate: Int?
        public let extradataHash: String?
        public let sampleAspect: Double

        /// Size as shown to the user: rotation applied (ffmpeg autorotates when decoding).
        public var displayWidth: Int { rotation % 180 == 0 ? width : height }
        public var displayHeight: Int { rotation % 180 == 0 ? height : width }
        /// Seconds per frame, or 1/30 when the rate is unknown.
        public var frameDuration: Double { frameRate > 0 ? 1 / frameRate : 1.0 / 30 }
        public var isTenBit: Bool { pixelFormat.map { $0.contains("10") || $0.contains("12") } ?? false }
    }

    public struct Audio: Sendable, Equatable {
        public let index: Int
        public let codec: String
        public let sampleRate: Int
        public let channels: Int
        public let channelLayout: String?
        public let bitRate: Int?
        public let sampleFormat: String?
        public let bitsPerSample: Int?
        public let profile: String?
        public let extradataHash: String?
    }

    public let url: URL
    public let duration: Double
    /// Format start time; tool times are relative to it (what a player shows as 0:00).
    public let startTime: Double
    public let formatName: String
    public let bitRate: Int?
    public let size: Int64?
    /// Real video streams (attached cover pictures excluded).
    public let videos: [Video]
    public let audios: [Audio]
    public let subtitleCount: Int
    public let tags: [String: String]

    public var video: Video? { videos.first }
    public var audio: Audio? { audios.first }
    public var hasVideo: Bool { !videos.isEmpty }
    public var hasAudio: Bool { !audios.isEmpty }

    public init(url: URL, duration: Double, startTime: Double, formatName: String, bitRate: Int?, size: Int64?,
                videos: [Video], audios: [Audio], subtitleCount: Int, tags: [String: String]) {
        self.url = url
        self.duration = duration
        self.startTime = startTime
        self.formatName = formatName
        self.bitRate = bitRate
        self.size = size
        self.videos = videos
        self.audios = audios
        self.subtitleCount = subtitleCount
        self.tags = tags
    }

    /// Bits per second available for video: the stream's own rate, else the
    /// container rate minus audio.
    public var videoBitRate: Int? {
        if let b = video?.bitRate, b > 0 { return b }
        guard let total = bitRate, total > 0 else { return nil }
        let audio = audios.compactMap(\.bitRate).reduce(0, +)
        return max(total - audio, total / 2)
    }

    public static func load(_ url: URL, locator: EngineLocator = .shared) async throws -> MediaInfo {
        guard let exe = locator.ffprobe else { throw ConversionError.engineMissing("ffprobe", detail: "not bundled") }
        let r = try await ProcessRunner.run(exe, ["-v", "error", "-print_format", "json", "-show_data_hash", "MD5",
                                                  "-show_format", "-show_streams", url.path])
        do {
            return try parse(r.stdout, url: url)
        } catch {
            throw ConversionError.unreadable(url, detail: "ffprobe json: \(error)")
        }
    }

    /// Parses `ffprobe -print_format json -show_format -show_streams` output.
    public static func parse(_ data: Data, url: URL) throws -> MediaInfo {
        let raw = try JSONDecoder().decode(RawProbe.self, from: data)
        var videos: [Video] = [], audios: [Audio] = []
        var subs = 0
        for s in raw.streams ?? [] {
            switch s.codec_type {
            case "video":
                if s.disposition?["attached_pic"] == 1 { continue }
                let codec = s.codec_name ?? "unknown"
                if codec == "mjpeg" || codec == "png" || codec == "bmp" { continue } // cover art without the flag
                videos.append(Video(
                    index: s.index, codec: codec, width: s.width ?? 0, height: s.height ?? 0,
                    rotation: normaliseRotation(s.side_data_list?.compactMap(\.rotation).first ?? s.tags?["rotate"].flatMap(Double.init) ?? 0),
                    frameRate: rate(s.avg_frame_rate).flatMap { $0 > 0 && $0 < 1000 ? $0 : nil } ?? rate(s.r_frame_rate) ?? 0,
                    pixelFormat: s.pix_fmt, profile: s.profile, bitRate: s.bit_rate.flatMap(Int.init),
                    extradataHash: s.extradata_hash, sampleAspect: aspect(s.sample_aspect_ratio)))
            case "audio":
                audios.append(Audio(
                    index: s.index, codec: s.codec_name ?? "unknown", sampleRate: s.sample_rate.flatMap(Int.init) ?? 0,
                    channels: s.channels ?? 0, channelLayout: s.channel_layout, bitRate: s.bit_rate.flatMap(Int.init),
                    sampleFormat: s.sample_fmt, bitsPerSample: s.bits_per_raw_sample.flatMap(Int.init).flatMap { $0 > 0 ? $0 : nil },
                    profile: s.profile, extradataHash: s.extradata_hash))
            case "subtitle":
                subs += 1
            default:
                break
            }
        }
        let streamDurations = (raw.streams ?? []).compactMap { $0.duration.flatMap(Double.init) }
        let duration = raw.format?.duration.flatMap(Double.init) ?? streamDurations.max() ?? 0
        return MediaInfo(url: url, duration: duration,
                         startTime: raw.format?.start_time.flatMap(Double.init) ?? 0,
                         formatName: raw.format?.format_name ?? "",
                         bitRate: raw.format?.bit_rate.flatMap(Int.init),
                         size: raw.format?.size.flatMap { Int64($0) },
                         videos: videos, audios: audios, subtitleCount: subs, tags: raw.format?.tags ?? [:])
    }

    static func rate(_ s: String?) -> Double? {
        guard let s else { return nil }
        let parts = s.split(separator: "/")
        if parts.count == 2, let n = Double(parts[0]), let d = Double(parts[1]), d != 0 { return n / d }
        return Double(s)
    }

    static func aspect(_ s: String?) -> Double {
        guard let s, s != "0:1" else { return 1 }
        let p = s.split(separator: ":")
        guard p.count == 2, let n = Double(p[0]), let d = Double(p[1]), n > 0, d > 0 else { return 1 }
        return n / d
    }

    static func normaliseRotation(_ degrees: Double) -> Int {
        // ffprobe reports the display matrix rotation counter-clockwise (e.g. -90).
        let r = Int((degrees / 90).rounded()) * 90
        return ((r % 360) + 360) % 360
    }

    private struct RawProbe: Decodable {
        let streams: [RawStream]?
        let format: RawFormat?
    }

    private struct RawSideData: Decodable {
        let rotation: Double?
        enum CodingKeys: String, CodingKey { case rotation }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let d = try? c.decode(Double.self, forKey: .rotation) { rotation = d }
            else if let s = try? c.decode(String.self, forKey: .rotation) { rotation = Double(s) }
            else { rotation = nil }
        }
    }

    private struct RawStream: Decodable {
        let index: Int
        let codec_type: String?
        let codec_name: String?
        let profile: String?
        let width: Int?
        let height: Int?
        let pix_fmt: String?
        let sample_aspect_ratio: String?
        let r_frame_rate: String?
        let avg_frame_rate: String?
        let sample_rate: String?
        let sample_fmt: String?
        let channels: Int?
        let channel_layout: String?
        let bits_per_raw_sample: String?
        let bit_rate: String?
        let duration: String?
        let extradata_hash: String?
        let disposition: [String: Int]?
        let tags: [String: String]?
        let side_data_list: [RawSideData]?
    }

    private struct RawFormat: Decodable {
        let format_name: String?
        let duration: String?
        let start_time: String?
        let size: String?
        let bit_rate: String?
        let tags: [String: String]?
    }
}

/// Presentation times of a video stream's packets, used to plan lossless cuts.
public struct KeyframeIndex: Sendable, Equatable {
    /// Keyframe times in seconds relative to the file start, ascending.
    public let keyframes: [Double]
    /// Every video packet's time, ascending (for counting frames between cuts).
    public let packets: [Double]

    public init(keyframes: [Double], packets: [Double]) {
        self.keyframes = keyframes
        self.packets = packets
    }

    /// Packet scan (no decoding): fast even for long files.
    public static func load(_ info: MediaInfo, locator: EngineLocator = .shared) async throws -> KeyframeIndex {
        guard let video = info.video else { return KeyframeIndex(keyframes: [], packets: []) }
        guard let exe = locator.ffprobe else { throw ConversionError.engineMissing("ffprobe", detail: "not bundled") }
        let r = try await ProcessRunner.run(exe, ["-v", "error", "-select_streams", String(video.index),
                                                  "-show_entries", "packet=pts_time,dts_time,flags",
                                                  "-of", "csv=p=0", info.url.path])
        return parse(r.stdoutString, startTime: info.startTime)
    }

    /// Parses `pts_time,dts_time,flags` CSV lines.
    public static func parse(_ csv: String, startTime: Double) -> KeyframeIndex {
        var keys: [Double] = [], all: [Double] = []
        for line in csv.split(whereSeparator: \.isNewline) {
            let f = line.split(separator: ",", omittingEmptySubsequences: false)
            guard f.count >= 3 else { continue }
            guard let t = Double(f[0]) ?? Double(f[1]) else { continue }
            let rel = t - startTime
            all.append(rel)
            if f[2].hasPrefix("K") { keys.append(rel) }
        }
        return KeyframeIndex(keyframes: keys.sorted(), packets: all.sorted())
    }

    /// Number of packets with time in [start, end).
    public func packetCount(from start: Double, to end: Double, tolerance: Double) -> Int {
        packets.reduce(0) { $0 + (($1 >= start - tolerance && $1 < end - tolerance) ? 1 : 0) }
    }

    /// Latest keyframe at or before `t` (within `tolerance`).
    public func keyframe(atOrBefore t: Double, tolerance: Double) -> Double? {
        keyframes.last { $0 <= t + tolerance }
    }

    /// Earliest keyframe at or after `t` (within `tolerance`).
    public func keyframe(atOrAfter t: Double, tolerance: Double) -> Double? {
        keyframes.first { $0 >= t - tolerance }
    }
}
