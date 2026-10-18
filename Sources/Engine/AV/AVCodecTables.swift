import Foundation

/// Containers, the codecs each may carry without re-encoding, and the codecs
/// we encode to. Copy sets are deliberately conservative: a codec is listed
/// only where the result plays in the apps people open that container with
/// (QuickTime/Finder for mp4/mov/m4v, browsers for webm, VLC/IINA for mkv).
enum AVCodecTables {
    static let videoContainers: Set<FormatID> = [Formats.mp4, Formats.mov, Formats.mkv, Formats.webm, Formats.avi, Formats.wmv, Formats.m4v]
    static let audioContainers: Set<FormatID> = [Formats.mp3, Formats.m4a, Formats.wav, Formats.flac, Formats.ogg, Formats.opus, Formats.aiff, Formats.caf]
    static let losslessAudio: Set<FormatID> = [Formats.wav, Formats.flac, Formats.aiff, Formats.caf]
    static let quickTimeFamily: Set<FormatID> = [Formats.mp4, Formats.mov, Formats.m4v]

    /// ffmpeg muxer per target (explicit, so the extension never decides).
    static func muxer(_ to: FormatID) -> String {
        switch to {
        case Formats.mp4, Formats.m4v: "mp4"
        case Formats.mov: "mov"
        case Formats.mkv: "matroska"
        case Formats.webm: "webm"
        case Formats.avi: "avi"
        case Formats.wmv: "asf"
        case Formats.gif: "gif"
        case Formats.mp3: "mp3"
        case Formats.m4a: "ipod"
        case Formats.wav: "wav"
        case Formats.flac: "flac"
        case Formats.ogg: "ogg"
        case Formats.opus: "opus"
        case Formats.aiff: "aiff"
        case Formats.caf: "caf"
        default: to.rawValue
        }
    }

    /// Video codecs a container takes as-is (stream copy).
    static func videoCopyable(_ to: FormatID) -> Set<String> {
        switch to {
        case Formats.mp4, Formats.m4v: ["h264", "hevc"]
        case Formats.mov: ["h264", "hevc", "prores", "mjpeg"]
        case Formats.mkv: ["h264", "hevc", "vp8", "vp9", "av1", "mpeg4", "mpeg2video", "prores", "ffv1", "theora", "mjpeg"]
        case Formats.webm: ["vp8", "vp9", "av1"]
        case Formats.avi: ["mpeg4", "msmpeg4v3", "mjpeg"]
        case Formats.wmv: ["wmv1", "wmv2", "wmv3", "vc1"]
        default: []
        }
    }

    /// Audio codecs a video container takes as-is.
    static func audioCopyable(_ to: FormatID) -> Set<String> {
        switch to {
        case Formats.mp4: ["aac", "mp3", "alac", "ac3", "eac3"]
        case Formats.m4v: ["aac", "alac", "ac3", "eac3"]
        case Formats.mov: ["aac", "alac", "mp3", "ac3", "eac3", "pcm_s16le", "pcm_s16be", "pcm_s24le", "pcm_s24be", "pcm_f32le"]
        case Formats.mkv: ["aac", "mp3", "opus", "vorbis", "flac", "alac", "ac3", "eac3", "dts", "truehd", "pcm_s16le", "pcm_s24le"]
        case Formats.webm: ["opus", "vorbis"]
        case Formats.avi: ["mp3", "ac3", "pcm_s16le"]
        case Formats.wmv: ["wmav1", "wmav2", "wmapro"]
        default: []
        }
    }

    static let textSubtitles: Set<String> = ["subrip", "srt", "ass", "ssa", "webvtt", "mov_text", "text"]
    static let bitmapSubtitles: Set<String> = ["hdmv_pgs_subtitle", "dvd_subtitle", "dvb_subtitle", "xsub"]

    /// How subtitle streams travel into a video container: copy, convert, or drop (nil).
    static func subtitleCodec(source: String, to: FormatID) -> String? {
        let text = textSubtitles.contains(source)
        switch to {
        case Formats.mkv:
            if text { return source == "mov_text" ? "srt" : "copy" }
            return bitmapSubtitles.contains(source) ? "copy" : nil
        case Formats.mp4, Formats.mov, Formats.m4v:
            return text ? (source == "mov_text" ? "copy" : "mov_text") : nil
        case Formats.webm:
            return text ? (source == "webvtt" ? "copy" : "webvtt") : nil
        default:
            return nil
        }
    }

    /// Canonical audio codec of an audio-only target (what "already in this format" means).
    static func canonicalAudioCodec(_ to: FormatID) -> String? {
        switch to {
        case Formats.mp3: "mp3"
        case Formats.m4a: "aac"
        case Formats.ogg: "vorbis"
        case Formats.opus: "opus"
        case Formats.flac: "flac"
        case Formats.caf: "alac"
        default: nil // wav/aiff: PCM codec depends on depth
        }
    }
}

/// The `videoQuality` option. Values are calibrated so each encoder lands at
/// about the same SSIM per preset (60 s 1080p30, testsrc2 with and without
/// grain, M5 Max; numbers in docs/lanes/E-av.md):
///
/// |            | x264 CRF | VT H.264 q | x265 CRF | VT HEVC q | VP9 CRF | AV1 CRF | MPEG-4 q | WMV2 q | ProRes |
/// |------------|----------|------------|----------|-----------|---------|---------|----------|--------|--------|
/// | high       | 18       | 75         | 22       | 62        | 24      | 24      | 2        | 2      | HQ     |
/// | balanced   | 23       | 58         | 27       | 54        | 32      | 32      | 4        | 4      | 422    |
/// | small      | 28       | 45         | 32       | 46        | 40      | 40      | 8        | 7      | LT     |
enum AVQualityPreset: String, Sendable, CaseIterable {
    case high, balanced, small

    init(option: String) { self = AVQualityPreset(rawValue: option) ?? .balanced }

    var x264CRF: Int { [18, 23, 28][ordinal] }
    var videoToolboxH264: Int { [75, 58, 45][ordinal] }
    var x265CRF: Int { [22, 27, 32][ordinal] }
    var videoToolboxHEVC: Int { [62, 54, 46][ordinal] }
    var vp9CRF: Int { [24, 32, 40][ordinal] }
    var av1CRF: Int { [24, 32, 40][ordinal] }
    var mpeg4Q: Int { [2, 4, 8][ordinal] }
    var wmv2Q: Int { [2, 4, 7][ordinal] }
    /// ffmpeg ProRes profile numbers: 1 LT, 2 standard (422), 3 HQ.
    var proresProfile: Int { [3, 2, 1][ordinal] }

    private var ordinal: Int {
        switch self {
        case .high: 0
        case .balanced: 1
        case .small: 2
        }
    }
}

/// Audio bitrates used when audio has to be re-encoded inside a video container
/// (the video schema has no audio options).
enum AVDefaultAudio {
    static func aacBitrate(channels: Int?) -> Int { (channels ?? 2) > 2 ? 384 : 192 }
    static func opusBitrate(channels: Int?) -> Int { (channels ?? 2) > 2 ? 320 : 160 }
    static let mp3Bitrate = 192
    static let wmaBitrate = 192

    /// libvorbis `-q:a` for a nominal bitrate (Vorbis quality scale: q2≈96k … q9≈320k).
    static func vorbisQuality(kbps: Int) -> Int {
        switch kbps {
        case ..<112: 2
        case ..<144: 4
        case ..<176: 5
        case ..<208: 6
        case ..<240: 7
        case ..<288: 8
        default: 9
        }
    }
}
