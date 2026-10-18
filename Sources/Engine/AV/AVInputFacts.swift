import Foundation

/// What the AV planner needs to know about an input, distilled from ffprobe.
/// A plain value so planning is pure and unit-testable with synthetic inputs.
public struct AVInputFacts: Sendable, Hashable {
    public struct Video: Sendable, Hashable {
        public var index: Int
        public var codec: String
        public var width: Int
        public var height: Int
        /// Display rotation in degrees, normalised to 0/90/180/270.
        public var rotation: Int
        /// Average frame rate (VFR-aware), if known.
        public var frameRate: Double?
        /// Nominal (`r_frame_rate`) frame rate, if known.
        public var nominalFrameRate: Double?
        public var pixelFormat: String?
        public var bitDepth: Int

        public init(index: Int, codec: String, width: Int, height: Int, rotation: Int = 0,
                    frameRate: Double? = nil, nominalFrameRate: Double? = nil, pixelFormat: String? = "yuv420p", bitDepth: Int = 8) {
            self.index = index
            self.codec = codec
            self.width = width
            self.height = height
            self.rotation = rotation
            self.frameRate = frameRate
            self.nominalFrameRate = nominalFrameRate
            self.pixelFormat = pixelFormat
            self.bitDepth = bitDepth
        }

        /// Size as shown on screen (rotation applied).
        public var displayWidth: Int { rotation % 180 == 0 ? width : height }
        public var displayHeight: Int { rotation % 180 == 0 ? height : width }
        /// Timestamps irregular enough that the average differs from the nominal rate.
        public var isVariableFrameRate: Bool {
            guard let a = frameRate, let n = nominalFrameRate, a > 0, n > 0 else { return false }
            return abs(a - n) / n > 0.02
        }
    }

    public struct Audio: Sendable, Hashable {
        public var index: Int
        public var codec: String
        public var sampleRate: Int?
        public var channels: Int?
        /// Bits per second, if the container reports it.
        public var bitRate: Int?
        /// Integer sample depth (16, 24, 32) for PCM/lossless; nil for float or lossy sources.
        public var bitDepth: Int?
        public var isDefault: Bool

        public init(index: Int, codec: String, sampleRate: Int? = 44100, channels: Int? = 2,
                    bitRate: Int? = nil, bitDepth: Int? = nil, isDefault: Bool = false) {
            self.index = index
            self.codec = codec
            self.sampleRate = sampleRate
            self.channels = channels
            self.bitRate = bitRate
            self.bitDepth = bitDepth
            self.isDefault = isDefault
        }
    }

    public struct Stream: Sendable, Hashable {
        public var index: Int
        public var codec: String
        public init(index: Int, codec: String) { self.index = index; self.codec = codec }
    }

    public var duration: Double?
    /// Main picture stream (attached cover art excluded).
    public var video: Video?
    public var audio: [Audio]
    public var subtitles: [Stream]
    /// Attached picture (album art / cover), if any.
    public var coverArt: Stream?
    public var formatTags: [String: String]
    /// Tags per absolute stream index.
    public var streamTags: [Int: [String: String]]

    public init(duration: Double? = nil, video: Video? = nil, audio: [Audio] = [], subtitles: [Stream] = [],
                coverArt: Stream? = nil, formatTags: [String: String] = [:], streamTags: [Int: [String: String]] = [:]) {
        self.duration = duration
        self.video = video
        self.audio = audio
        self.subtitles = subtitles
        self.coverArt = coverArt
        self.formatTags = formatTags
        self.streamTags = streamTags
    }

    /// The audio stream extraction and audio conversions use: the default one, else the first.
    public var primaryAudio: Audio? { audio.first(where: \.isDefault) ?? audio.first }
}

// MARK: - ffprobe

/// Runs the bundled ffprobe once and decodes both the shared `MediaProbe`
/// contract and the extra fields lane E needs (disposition, display-matrix
/// rotation, sample depth, per-stream bitrate). See docs/contract-changes/E-av.md.
enum AVProbe {
    static func facts(for url: URL, locator: EngineLocator) async throws -> AVInputFacts {
        guard let exe = locator.ffprobe else {
            throw ConversionError.engineMissing("ffprobe", detail: "not found in \(locator.helperDirectories.map(\.path))")
        }
        let result: ProcessResult
        do {
            result = try await ProcessRunner.run(exe, ["-v", "error", "-print_format", "json", "-show_format", "-show_streams", url.path])
        } catch let error as ConversionError {
            if case .engineFailed(_, _, let detail) = error { throw ConversionError.unreadable(url, detail: "ffprobe: \(detail)") }
            throw error
        }
        return try facts(fromJSON: result.stdout, url: url)
    }

    static func facts(fromJSON data: Data, url: URL) throws -> AVInputFacts {
        let probe: MediaProbe, extra: ExtraProbe
        do {
            probe = try JSONDecoder().decode(MediaProbe.self, from: data)
            extra = try JSONDecoder().decode(ExtraProbe.self, from: data)
        } catch {
            throw ConversionError.unreadable(url, detail: "ffprobe json: \(error)")
        }
        var facts = AVInputFacts(duration: probe.duration, formatTags: probe.format?.tags ?? [:])
        let extras = Dictionary(extra.streams.map { ($0.index, $0) }, uniquingKeysWith: { a, _ in a })
        for s in probe.streams {
            let x = extras[s.index]
            if let tags = s.tags, !tags.isEmpty { facts.streamTags[s.index] = tags }
            guard let codec = s.codec_name else { continue }
            switch s.codec_type {
            case "video":
                if x?.disposition?["attached_pic"] == 1 {
                    if facts.coverArt == nil { facts.coverArt = .init(index: s.index, codec: codec) }
                } else if facts.video == nil, let w = s.width, let h = s.height, w > 0, h > 0 {
                    let rotation = x?.side_data_list?.compactMap(\.rotation).first ?? 0
                    let pix = s.pix_fmt
                    let depth = x?.bits_per_raw_sample.flatMap(Int.init)
                        ?? (pix.map { $0.contains("10") ? 10 : ($0.contains("12") ? 12 : 8) } ?? 8)
                    facts.video = .init(index: s.index, codec: codec, width: w, height: h,
                                        rotation: normalise(rotation),
                                        frameRate: rate(s.avg_frame_rate), nominalFrameRate: rate(s.r_frame_rate),
                                        pixelFormat: pix, bitDepth: depth)
                }
            case "audio":
                facts.audio.append(.init(index: s.index, codec: codec,
                                         sampleRate: s.sample_rate.flatMap(Int.init), channels: s.channels,
                                         bitRate: x?.bit_rate.flatMap(Int.init),
                                         bitDepth: audioDepth(codec: codec, sampleFormat: x?.sample_fmt,
                                                              raw: x?.bits_per_raw_sample.flatMap(Int.init), coded: x?.bits_per_sample),
                                         isDefault: x?.disposition?["default"] == 1))
            case "subtitle":
                facts.subtitles.append(.init(index: s.index, codec: codec))
            default:
                break
            }
        }
        return facts
    }

    /// "30000/1001" → 29.97; "0/0" → nil.
    static func rate(_ s: String?) -> Double? {
        guard let s else { return nil }
        let p = s.split(separator: "/")
        if p.count == 2, let n = Double(p[0]), let d = Double(p[1]), d > 0, n > 0 { return n / d }
        if let v = Double(s), v > 0 { return v }
        return nil
    }

    static func normalise(_ degrees: Double) -> Int {
        let r = Int((degrees / 90).rounded()) * 90
        return ((r % 360) + 360) % 360
    }

    /// Integer depth for PCM and lossless codecs; nil for float or lossy.
    static func audioDepth(codec: String, sampleFormat: String?, raw: Int?, coded: Int?) -> Int? {
        if codec.hasPrefix("pcm_s") || codec.hasPrefix("pcm_u") {
            let digits = codec.dropFirst(5).prefix { $0.isNumber }
            return Int(digits)
        }
        guard ["flac", "alac", "wavpack", "ape", "tta", "truehd", "mlp"].contains(codec) else { return nil }
        if let raw, raw > 0 { return raw }
        switch sampleFormat {
        case "s16", "s16p": return 16
        case "s32", "s32p": return (coded ?? 0) > 0 ? coded : 24
        default: return nil
        }
    }

    /// Decoded leniently: an unexpected type in any of these optional fields
    /// leaves it nil instead of failing the whole probe.
    private struct ExtraProbe: Decodable {
        struct SideData: Decodable {
            let rotation: Double?
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: Keys.self)
                rotation = try? c.decodeIfPresent(Double.self, forKey: .rotation)
            }
            enum Keys: String, CodingKey { case rotation }
        }
        struct Stream: Decodable {
            let index: Int
            let bit_rate: String?
            let bits_per_raw_sample: String?
            let bits_per_sample: Int?
            let sample_fmt: String?
            let disposition: [String: Int]?
            let side_data_list: [SideData]?

            enum Keys: String, CodingKey {
                case index, bit_rate, bits_per_raw_sample, bits_per_sample, sample_fmt, disposition, side_data_list
            }
            init(from decoder: Decoder) throws {
                let c = try decoder.container(keyedBy: Keys.self)
                index = try c.decode(Int.self, forKey: .index)
                bit_rate = try? c.decodeIfPresent(String.self, forKey: .bit_rate)
                bits_per_raw_sample = try? c.decodeIfPresent(String.self, forKey: .bits_per_raw_sample)
                bits_per_sample = try? c.decodeIfPresent(Int.self, forKey: .bits_per_sample)
                sample_fmt = try? c.decodeIfPresent(String.self, forKey: .sample_fmt)
                disposition = try? c.decodeIfPresent([String: Int].self, forKey: .disposition)
                side_data_list = try? c.decodeIfPresent([SideData].self, forKey: .side_data_list)
            }
        }
        let streams: [Stream]
    }
}
