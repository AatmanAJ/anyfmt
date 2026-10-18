import Foundation

/// Containers the media tools write, keyed by file extension. Tools keep the
/// input's container, so this decides which encoders a re-encode may use.
public enum MediaContainer: String, Sendable, CaseIterable {
    case mp4, mov, m4v, mkv, webm, avi, wmv
    case mp3, m4a, wav, flac, aiff, ogg, opus, caf, wma

    public init?(extension ext: String) {
        switch ext.lowercased() {
        case "mp4": self = .mp4
        case "mov", "qt": self = .mov
        case "m4v": self = .m4v
        case "mkv": self = .mkv
        case "webm": self = .webm
        case "avi": self = .avi
        case "wmv", "asf": self = .wmv
        case "mp3": self = .mp3
        case "m4a", "m4b": self = .m4a
        case "wav", "wave": self = .wav
        case "flac": self = .flac
        case "aif", "aiff", "aifc": self = .aiff
        case "ogg", "oga": self = .ogg
        case "opus": self = .opus
        case "caf": self = .caf
        case "wma": self = .wma
        default: return nil
        }
    }

    /// ffmpeg muxer name (needed by the segment muxer, which can't infer it).
    public var muxer: String {
        switch self {
        case .mp4, .m4v: "mp4"
        case .mov: "mov"
        case .mkv: "matroska"
        case .webm: "webm"
        case .avi: "avi"
        case .wmv, .wma: "asf"
        case .mp3: "mp3"
        case .m4a: "ipod"
        case .wav: "wav"
        case .flac: "flac"
        case .aiff: "aiff"
        case .ogg: "ogg"
        case .opus: "opus"
        case .caf: "caf"
        }
    }

    /// QuickTime-family containers (edit lists, `hvc1` tagging, faststart).
    public var isQuickTime: Bool { self == .mp4 || self == .mov || self == .m4v || self == .m4a }
}

/// Encoder quality targets for re-encodes.
public enum VideoQuality: String, Sendable, CaseIterable {
    /// For edits (trim/crop/speed/split/join): looks like the source.
    case transparent
    case high, balanced, small

    /// VideoToolbox `-q:v` (constant quality, arm64 only; see PLATFORM_RESEARCH G).
    var vtQuality: Int { switch self { case .transparent: 72; case .high: 65; case .balanced: 55; case .small: 45 } }
    var x264CRF: Int { switch self { case .transparent: 18; case .high: 21; case .balanced: 24; case .small: 28 } }
    var x265CRF: Int { switch self { case .transparent: 20; case .high: 23; case .balanced: 26; case .small: 29 } }
    var vp9CRF: Int { switch self { case .transparent: 28; case .high: 31; case .balanced: 34; case .small: 38 } }
    /// mpeg4 / wmv2 qscale (lower is better).
    var qscale: Int { switch self { case .transparent: 2; case .high: 3; case .balanced: 5; case .small: 8 } }
}

/// One way to encode a stream. Runners try attempts in order and fall back to
/// the next on failure (e.g. VideoToolbox unavailable in a VM).
public struct EncoderAttempt: Sendable, Equatable {
    public let label: String
    public let args: [String]
    public let hardware: Bool
    /// Two-pass capable software encoder (for target-size encodes).
    public let twoPass: Bool

    public init(label: String, args: [String], hardware: Bool, twoPass: Bool = false) {
        self.label = label
        self.args = args
        self.hardware = hardware
        self.twoPass = twoPass
    }
}

public enum MediaEncoders {
    /// Video family a container + source codec maps to on re-encode.
    enum VideoFamily { case h264, hevc, prores, vp9, mpeg4, wmv2 }

    static func videoFamily(_ container: MediaContainer, sourceCodec: String?) -> VideoFamily {
        let src = sourceCodec ?? ""
        switch container {
        case .mp4, .m4v: return src == "hevc" ? .hevc : .h264
        case .mov: return src == "hevc" ? .hevc : (src == "prores" ? .prores : .h264)
        case .mkv: return src == "hevc" ? .hevc : (["vp9", "vp8", "av1"].contains(src) ? .vp9 : .h264)
        case .webm: return .vp9
        case .avi: return src == "h264" ? .h264 : .mpeg4
        case .wmv: return .wmv2
        default: return .h264
        }
    }

    /// Encoder attempts for a video re-encode in `container`.
    /// - Parameters:
    ///   - maxRate: optional VBV cap (bits/s) so a quality encode never balloons.
    ///   - bitRate: average bitrate (bits/s) instead of constant quality (target-size mode).
    public static func video(container: MediaContainer, source: MediaInfo.Video?, quality: VideoQuality,
                             maxRate: Int? = nil, bitRate: Int? = nil, allowHardware: Bool = true) -> [EncoderAttempt] {
        let tenBit = source?.isTenBit ?? false
        let family = videoFamily(container, sourceCodec: source?.codec)
        let vbv: [String] = maxRate.map { ["-maxrate", String($0), "-bufsize", String($0 * 2)] } ?? []
        let hvc1: [String] = container.isQuickTime ? ["-tag:v", "hvc1"] : []
        var out: [EncoderAttempt] = []
        switch family {
        case .h264, .hevc:
            let isHEVC = family == .hevc
            if allowHardware {
                var a = ["-c:v", isHEVC ? "hevc_videotoolbox" : "h264_videotoolbox"]
                a += bitRate.map { ["-b:v", String($0)] } ?? ["-q:v", String(quality.vtQuality)]
                a += vbv
                if isHEVC {
                    a += tenBit ? ["-profile:v", "main10", "-pix_fmt", "p010le"] : ["-pix_fmt", "yuv420p"]
                    a += hvc1
                } else {
                    a += ["-profile:v", "high", "-pix_fmt", "yuv420p"]
                }
                out.append(EncoderAttempt(label: isHEVC ? "hevc_videotoolbox" : "h264_videotoolbox", args: a, hardware: true))
            }
            if isHEVC {
                var a = ["-c:v", "libx265", "-preset", "fast", "-x265-params", "log-level=error"]
                a += bitRate.map { ["-b:v", String($0)] } ?? ["-crf", String(quality.x265CRF)]
                a += vbv + ["-pix_fmt", tenBit ? "yuv420p10le" : "yuv420p"] + hvc1
                out.append(EncoderAttempt(label: "libx265", args: a, hardware: false))
            } else {
                var a = ["-c:v", "libx264", "-preset", "medium"]
                a += bitRate.map { ["-b:v", String($0)] } ?? ["-crf", String(quality.x264CRF)]
                a += vbv + ["-pix_fmt", "yuv420p"]
                out.append(EncoderAttempt(label: "libx264", args: a, hardware: false, twoPass: true))
            }
        case .prores:
            if allowHardware {
                out.append(EncoderAttempt(label: "prores_videotoolbox", args: ["-c:v", "prores_videotoolbox"], hardware: true))
            }
            out.append(EncoderAttempt(label: "libx264", args: ["-c:v", "libx264", "-preset", "medium", "-crf", "16", "-pix_fmt", "yuv420p"], hardware: false, twoPass: true))
        case .vp9:
            var a = ["-c:v", "libvpx-vp9", "-row-mt", "1", "-deadline", "good", "-cpu-used", "4"]
            a += bitRate.map { ["-b:v", String($0)] } ?? ["-crf", String(quality.vp9CRF), "-b:v", "0"]
            a += vbv
            out.append(EncoderAttempt(label: "libvpx-vp9", args: a, hardware: false, twoPass: true))
        case .mpeg4:
            var a = ["-c:v", "mpeg4", "-tag:v", "XVID"]
            a += bitRate.map { ["-b:v", String($0)] } ?? ["-q:v", String(quality.qscale)]
            out.append(EncoderAttempt(label: "mpeg4", args: a + vbv, hardware: false, twoPass: true))
        case .wmv2:
            var a = ["-c:v", "wmv2"]
            a += bitRate.map { ["-b:v", String($0)] } ?? ["-q:v", String(quality.qscale)]
            out.append(EncoderAttempt(label: "wmv2", args: a + vbv, hardware: false, twoPass: true))
        }
        return out
    }

    /// Software-only, two-pass capable encoder for exact target sizes.
    public static func twoPassVideo(container: MediaContainer, source: MediaInfo.Video?, bitRate: Int) -> EncoderAttempt {
        let attempts = video(container: container, source: source, quality: .balanced, bitRate: bitRate, allowHardware: false)
        if let tp = attempts.first(where: \.twoPass) { return tp }
        // HEVC sources: target-size mode uses H.264 (x264 two-pass is far more accurate than x265's ABR).
        return EncoderAttempt(label: "libx264", args: ["-c:v", "libx264", "-preset", "medium", "-b:v", String(bitRate), "-pix_fmt", "yuv420p"],
                              hardware: false, twoPass: true)
    }

    // MARK: Audio

    static let lossyLadder = [64, 96, 128, 160, 192, 224, 256, 320]

    /// Nearest standard bitrate (kbps) to the source's.
    static func ladderBitrate(_ bps: Int?, default d: Int, range: ClosedRange<Int> = 64...320) -> Int {
        guard let bps, bps > 0 else { return d }
        let k = bps / 1000
        let nearest = lossyLadder.min { abs($0 - k) < abs($1 - k) } ?? d
        return min(range.upperBound, max(range.lowerBound, nearest))
    }

    static func pcmCodec(for source: MediaInfo.Audio?, bigEndian: Bool) -> String {
        let suffix = bigEndian ? "be" : "le"
        if let c = source?.codec, c.hasPrefix("pcm_"), c.hasSuffix(suffix) { return c }
        let bits = source?.bitsPerSample ?? 0
        if source?.sampleFormat?.hasPrefix("flt") == true && !bigEndian { return "pcm_f32le" }
        if bits > 16 || source?.sampleFormat?.hasPrefix("s32") == true { return "pcm_s24\(suffix)" }
        return "pcm_s16\(suffix)"
    }

    /// Encoder arguments for an audio re-encode that keeps the source's codec
    /// family and bitrate where the container allows.
    public static func audio(container: MediaContainer, source: MediaInfo.Audio?, bitRateKbps: Int? = nil) -> [String] {
        let src = source?.codec ?? ""
        let rate: [String] = (source?.sampleRate ?? 0) > 0 ? ["-ar", String(source?.sampleRate ?? 48000)] : []
        func aac(_ d: Int = 192) -> [String] { ["-c:a", "aac_at", "-b:a", "\(bitRateKbps ?? ladderBitrate(source?.bitRate, default: d))k"] + rate }
        func mp3() -> [String] { ["-c:a", "libmp3lame", "-b:a", "\(bitRateKbps ?? ladderBitrate(source?.bitRate, default: 192))k"] + rate }
        func opus() -> [String] { ["-c:a", "libopus", "-b:a", "\(bitRateKbps ?? ladderBitrate(source?.bitRate, default: 128, range: 32...256))k", "-ar", "48000"] }
        func vorbis() -> [String] { ["-c:a", "libvorbis", "-b:a", "\(bitRateKbps ?? ladderBitrate(source?.bitRate, default: 192))k"] + rate }
        func flac() -> [String] {
            let sixteen = (source?.bitsPerSample ?? 16) <= 16 || source?.sampleFormat?.hasPrefix("s16") == true
            return ["-c:a", "flac"] + (sixteen ? ["-sample_fmt", "s16"] : ["-sample_fmt", "s32"]) + rate
        }
        func wma() -> [String] { ["-c:a", "wmav2", "-b:a", "\(bitRateKbps ?? ladderBitrate(source?.bitRate, default: 192))k"] + rate }
        func pcm(bigEndian: Bool) -> [String] { ["-c:a", pcmCodec(for: source, bigEndian: bigEndian)] + rate }

        switch container {
        case .mp4, .m4v, .m4a:
            return src == "alac" ? ["-c:a", "alac"] + rate : aac()
        case .mov:
            if src == "alac" { return ["-c:a", "alac"] + rate }
            if src.hasPrefix("pcm_") { return pcm(bigEndian: src.hasSuffix("be")) }
            return aac()
        case .mkv:
            switch src {
            case "mp3": return mp3()
            case "opus": return opus()
            case "vorbis": return vorbis()
            case "flac": return flac()
            default: return src.hasPrefix("pcm_") ? pcm(bigEndian: false) : aac()
            }
        case .webm: return src == "vorbis" ? vorbis() : opus()
        case .avi: return src.hasPrefix("pcm_") ? pcm(bigEndian: false) : mp3()
        case .wmv, .wma: return wma()
        case .mp3: return mp3()
        case .wav: return pcm(bigEndian: false)
        case .aiff: return pcm(bigEndian: true)
        case .flac: return flac()
        case .ogg:
            switch src {
            case "opus": return opus()
            case "flac": return flac()
            default: return vorbis()
            }
        case .opus: return opus()
        case .caf:
            if src == "alac" { return ["-c:a", "alac"] + rate }
            if src.hasPrefix("pcm_") { return pcm(bigEndian: src.hasSuffix("be")) }
            if src == "opus" { return opus() }
            return aac()
        }
    }

    // MARK: Metadata

    /// Keys dropped by `MetadataPolicy.stripPrivate`: location, device and author fields.
    static func isPrivateKey(_ key: String) -> Bool {
        let k = key.lowercased()
        let needles = ["location", "gps", "xyz", "make", "model", "software", "author", "creator", "encoder"]
        return needles.contains { k.contains($0) } && !k.contains("handler")
    }

    /// `-map_metadata` / `-metadata` arguments for a policy.
    public static func metadata(_ policy: MetadataPolicy, info: MediaInfo?, input: Int = 0) -> [String] {
        switch policy {
        case .keep:
            return ["-map_metadata", String(input), "-map_chapters", String(input)]
        case .stripAll:
            return ["-map_metadata", "-1", "-map_chapters", "-1", "-fflags", "+bitexact"]
        case .stripPrivate:
            var a = ["-map_metadata", String(input), "-map_chapters", String(input)]
            for key in (info?.tags.keys.sorted() ?? []) where isPrivateKey(key) { a += ["-metadata", "\(key)="] }
            return a
        }
    }
}
