import Foundation

/// One ffmpeg invocation (the arguments after the prefix `FFmpeg.run` adds).
public struct AVPass: Sendable, Hashable {
    public var arguments: [String]
    /// Share of the job's progress bar this pass fills.
    public var weight: Double
}

/// A fully decided conversion: what happens to every stream, and the exact
/// ffmpeg arguments. Built by `AVConversionPlanner`, run by `FFmpegAVEngine`.
public struct AVConversionPlan: Sendable, Hashable {
    public enum StreamAction: Sendable, Hashable {
        case copy
        /// ffmpeg encoder name, e.g. `h264_videotoolbox`.
        case encode(String)

        public var encoder: String? { if case .encode(let e) = self { e } else { nil } }
    }

    public var passes: [AVPass]
    public var output: URL
    /// Temporary files (GIF palette) the engine deletes afterwards.
    public var scratch: [URL] = []
    public var video: StreamAction?
    public var audio: [StreamAction] = []
    public var subtitles: [StreamAction] = []
    public var coverArt: StreamAction?
    /// Software-only plan to run if this one fails (VideoToolbox or AudioToolbox unavailable).
    public var fallback: [AVConversionPlan] = []

    public var usesVideoToolbox: Bool { video?.encoder?.hasSuffix("_videotoolbox") ?? false }
    /// Nothing is re-encoded: a remux.
    public var isStreamCopy: Bool {
        (video == nil || video == .copy) && audio.allSatisfy { $0 == .copy } && !(video == nil && audio.isEmpty)
    }
}

/// User options for video targets, read from `StandardSchemas.video`.
struct AVVideoOptions: Sendable, Hashable {
    var quality: AVQualityPreset
    /// Cap on the short edge in pixels ("720p" = 720 on the short side, so portrait clips work too). nil = keep.
    var maxShortEdge: Int?
    /// Frame-rate cap. nil = keep. Never raises the source rate.
    var fps: Double?
    var hardware: Bool
    var removeAudio: Bool
    /// Explicit `videoCodec` (CLI/tools); nil = automatic.
    var codec: String?

    init(_ o: OptionValues) {
        quality = AVQualityPreset(option: o.string(OptionKey.videoQuality, default: "balanced"))
        let r = o.int(OptionKey.resolution, default: 0)
        maxShortEdge = r > 0 ? r : nil
        let f = o.double(OptionKey.fps, default: 0)
        fps = f > 0 ? f : nil
        hardware = o.bool(OptionKey.hardware, default: true)
        removeAudio = o.string(OptionKey.audio, default: "keep") == "remove"
        let c = o.string(OptionKey.videoCodec, default: "auto").lowercased()
        codec = c == "auto" || c.isEmpty ? nil : c
    }
}

/// User options for audio targets, read from `StandardSchemas.audioLossy` / `.audioLossless`.
struct AVAudioOptions: Sendable, Hashable {
    /// kbps for lossy targets.
    var bitrate: Int
    var sampleRate: Int?
    var channels: Int?
    /// 16 or 24; nil = keep the source depth ("keep"/"0", see docs/contract-changes/E.md).
    var bitDepth: Int?

    init(_ o: OptionValues) {
        bitrate = min(512, max(32, o.int(OptionKey.bitrate, default: 256)))
        let sr = o.int(OptionKey.sampleRate, default: 0)
        sampleRate = sr > 0 ? sr : nil
        switch o.string(OptionKey.channels, default: "keep") {
        case "mono": channels = 1
        case "stereo": channels = 2
        default: channels = nil
        }
        let d = o.string(OptionKey.bitDepth, default: "16")
        bitDepth = d == "keep" || d == "0" ? nil : (Int(d) == 24 ? 24 : 16)
    }
}

/// Turns facts + target + options into ffmpeg passes. Pure: no I/O.
enum AVConversionPlanner {
    struct Context {
        var input: URL
        var output: URL
        /// Where scratch files (GIF palette) may go.
        var scratchDirectory: URL
        var metadata: MetadataPolicy
        /// False forces software encoders (used for the fallback plan).
        var allowHardware: Bool = true
        /// False swaps AudioToolbox `aac_at` for ffmpeg's native `aac`.
        var allowAudioToolbox: Bool = true
    }

    static func plan(_ facts: AVInputFacts, from: FormatID, to: FormatID, options: OptionValues, context: Context) throws -> AVConversionPlan {
        var plan: AVConversionPlan
        if to == Formats.gif {
            plan = try gifPlan(facts, options: options, context: context)
        } else if AVCodecTables.videoContainers.contains(to) {
            plan = try videoPlan(facts, to: to, options: AVVideoOptions(options), context: context)
        } else if AVCodecTables.audioContainers.contains(to) {
            plan = try audioPlan(facts, to: to, options: AVAudioOptions(options), context: context)
        } else {
            throw ConversionError.unsupported(from: from, to: to)
        }
        // Progress every 250 ms instead of ffmpeg's default 500 ms (the bar feels live).
        plan.passes = plan.passes.map { AVPass(arguments: ["-stats_period", "0.25"] + $0.arguments, weight: $0.weight) }
        if context.allowHardware || context.allowAudioToolbox {
            var soft = context
            soft.allowHardware = false
            soft.allowAudioToolbox = false
            if let alt = try? Self.plan(facts, from: from, to: to, options: options, context: soft), alt.passes != plan.passes {
                plan.fallback = [alt]
            }
        }
        return plan
    }

    // MARK: - Video containers

    static func videoPlan(_ facts: AVInputFacts, to: FormatID, options: AVVideoOptions, context: Context) throws -> AVConversionPlan {
        guard facts.video != nil || !facts.audio.isEmpty else {
            throw ConversionError.unreadable(context.input, detail: "no video or audio streams")
        }
        var args = ["-i", context.input.path]
        var plan = AVConversionPlan(passes: [], output: context.output)
        var streamSpecs: [(spec: String, source: Int)] = []

        if let v = facts.video {
            args += ["-map", "0:\(v.index)"]
            streamSpecs.append(("v:0", v.index))
            let size = targetSize(width: v.displayWidth, height: v.displayHeight, maxShortEdge: options.maxShortEdge)
            let resize = options.maxShortEdge != nil && size != (even(v.displayWidth), even(v.displayHeight))
            let sourceFPS = v.frameRate ?? v.nominalFrameRate
            let fpsCap = options.fps.flatMap { cap in (sourceFPS.map { cap < $0 - 0.01 } ?? true) ? cap : nil }
            let codecMatches = options.codec.map { canonicalVideoCodec($0) == v.codec } ?? true
            let copy = AVCodecTables.videoCopyable(to).contains(v.codec) && !resize && fpsCap == nil
                && options.quality != .small && codecMatches
            if copy {
                args += ["-c:v", "copy"]
                if v.codec == "hevc" && AVCodecTables.quickTimeFamily.contains(to) { args += ["-tag:v", "hvc1"] }
                plan.video = .copy
            } else {
                let choice = videoCodec(for: to, source: v, requested: options.codec)
                let enc = videoEncoder(choice, to: to, source: v, quality: options.quality, hardware: options.hardware && context.allowHardware)
                var filters: [String] = []
                if size != (v.displayWidth, v.displayHeight) { filters.append("scale=\(size.0):\(size.1)") }
                if let fpsCap { filters.append("fps=\(formatNumber(fpsCap))") }
                if let pix = enc.pixelFormat { filters.append("format=\(pix)") }
                if !filters.isEmpty { args += ["-vf", filters.joined(separator: ",")] }
                args += enc.arguments
                plan.video = .encode(enc.name)
            }
        }

        if !options.removeAudio {
            for (k, a) in facts.audio.enumerated() {
                args += ["-map", "0:\(a.index)"]
                streamSpecs.append(("a:\(k)", a.index))
                if AVCodecTables.audioCopyable(to).contains(a.codec) {
                    args += ["-c:a:\(k)", "copy"]
                    plan.audio.append(.copy)
                } else {
                    let enc = videoContainerAudioEncoder(to: to, source: a, index: k, audioToolbox: context.allowAudioToolbox)
                    args += enc.arguments
                    plan.audio.append(.encode(enc.name))
                }
            }
        }

        var subIndex = 0
        for s in facts.subtitles {
            guard let codec = AVCodecTables.subtitleCodec(source: s.codec, to: to) else { continue }
            args += ["-map", "0:\(s.index)", "-c:s:\(subIndex)", codec]
            streamSpecs.append(("s:\(subIndex)", s.index))
            plan.subtitles.append(codec == "copy" ? .copy : .encode(codec))
            subIndex += 1
        }

        args += metadataArguments(context.metadata, facts: facts, streams: streamSpecs)
        if AVCodecTables.quickTimeFamily.contains(to) { args += ["-movflags", "+faststart"] }
        args += ["-f", AVCodecTables.muxer(to), context.output.path]
        plan.passes = [AVPass(arguments: args, weight: 1)]
        return plan
    }

    enum VideoCodecChoice: String { case h264, hevc, prores, vp9, av1, mpeg4, wmv2 }

    /// Encoder family for a container. An explicit `videoCodec` wins when the container can carry it.
    static func videoCodec(for to: FormatID, source: AVInputFacts.Video?, requested: String?) -> VideoCodecChoice {
        let legal: [VideoCodecChoice]
        switch to {
        case Formats.mp4: legal = [.h264, .hevc, .av1]
        case Formats.m4v: legal = [.h264, .hevc]
        case Formats.mov: legal = [.h264, .hevc, .prores]
        case Formats.mkv: legal = [.h264, .hevc, .vp9, .av1, .prores]
        case Formats.webm: legal = [.vp9, .av1]
        case Formats.avi: legal = [.mpeg4]
        case Formats.wmv: legal = [.wmv2]
        default: legal = [.h264]
        }
        if let r = requested.flatMap(VideoCodecChoice.init(rawValue:)), legal.contains(r) { return r }
        switch to {
        case Formats.mov where source?.codec == "hevc": return .hevc
        case Formats.mov where source?.codec == "prores": return .prores
        case Formats.mkv where source?.codec == "hevc": return .hevc
        default: return legal[0]
        }
    }

    struct Encoder {
        var name: String
        var arguments: [String]
        var pixelFormat: String?
    }

    static func videoEncoder(_ choice: VideoCodecChoice, to: FormatID, source: AVInputFacts.Video,
                             quality q: AVQualityPreset, hardware: Bool) -> Encoder {
        let qt = AVCodecTables.quickTimeFamily.contains(to)
        let tenBit = source.bitDepth > 8
        switch choice {
        case .h264:
            return hardware
                ? Encoder(name: "h264_videotoolbox", arguments: ["-c:v", "h264_videotoolbox", "-q:v", "\(q.videoToolboxH264)", "-profile:v", "high"], pixelFormat: "yuv420p")
                : Encoder(name: "libx264", arguments: ["-c:v", "libx264", "-preset", "medium", "-crf", "\(q.x264CRF)"], pixelFormat: "yuv420p")
        case .hevc:
            let tag = qt ? ["-tag:v", "hvc1"] : []
            if hardware {
                return Encoder(name: "hevc_videotoolbox",
                               arguments: ["-c:v", "hevc_videotoolbox", "-q:v", "\(q.videoToolboxHEVC)"] + (tenBit ? ["-profile:v", "main10"] : []) + tag,
                               pixelFormat: tenBit ? "p010le" : "yuv420p")
            }
            return Encoder(name: "libx265",
                           arguments: ["-c:v", "libx265", "-preset", "medium", "-crf", "\(q.x265CRF)", "-x265-params", "log-level=error"] + tag,
                           pixelFormat: tenBit ? "yuv420p10le" : "yuv420p")
        case .prores:
            let profile = ["lt", "standard", "hq"][q.proresProfile - 1]
            return hardware
                ? Encoder(name: "prores_videotoolbox", arguments: ["-c:v", "prores_videotoolbox", "-profile:v", profile], pixelFormat: nil)
                : Encoder(name: "prores_ks", arguments: ["-c:v", "prores_ks", "-profile:v", profile], pixelFormat: "yuv422p10le")
        case .vp9:
            return Encoder(name: "libvpx-vp9", arguments: ["-c:v", "libvpx-vp9", "-crf", "\(q.vp9CRF)", "-b:v", "0",
                                                           "-deadline", "good", "-cpu-used", "4", "-row-mt", "1"], pixelFormat: "yuv420p")
        case .av1:
            return Encoder(name: "libaom-av1", arguments: ["-c:v", "libaom-av1", "-crf", "\(q.av1CRF)", "-b:v", "0",
                                                           "-cpu-used", "6", "-row-mt", "1"], pixelFormat: "yuv420p")
        case .mpeg4:
            return Encoder(name: "mpeg4", arguments: ["-c:v", "mpeg4", "-q:v", "\(q.mpeg4Q)"] + (to == Formats.avi ? ["-tag:v", "XVID"] : []),
                           pixelFormat: "yuv420p")
        case .wmv2:
            return Encoder(name: "wmv2", arguments: ["-c:v", "wmv2", "-q:v", "\(q.wmv2Q)"], pixelFormat: "yuv420p")
        }
    }

    /// Audio encoder when a video container can't take the source audio as-is.
    static func videoContainerAudioEncoder(to: FormatID, source a: AVInputFacts.Audio, index k: Int, audioToolbox: Bool) -> Encoder {
        let ch = a.channels ?? 2
        switch to {
        case Formats.mkv, Formats.webm:
            return Encoder(name: "libopus", arguments: ["-c:a:\(k)", "libopus", "-b:a:\(k)", "\(AVDefaultAudio.opusBitrate(channels: ch))k", "-ar:a:\(k)", "48000"])
        case Formats.avi:
            return Encoder(name: "libmp3lame", arguments: ["-c:a:\(k)", "libmp3lame", "-b:a:\(k)", "\(AVDefaultAudio.mp3Bitrate)k"] + (ch > 2 ? ["-ac:a:\(k)", "2"] : []))
        case Formats.wmv:
            return Encoder(name: "wmav2", arguments: ["-c:a:\(k)", "wmav2", "-b:a:\(k)", "\(AVDefaultAudio.wmaBitrate)k"] + (ch > 2 ? ["-ac:a:\(k)", "2"] : []))
        default:
            let enc = audioToolbox ? "aac_at" : "aac"
            return Encoder(name: enc, arguments: ["-c:a:\(k)", enc, "-b:a:\(k)", "\(AVDefaultAudio.aacBitrate(channels: ch))k"])
        }
    }

    // MARK: - Audio containers

    static func audioPlan(_ facts: AVInputFacts, to: FormatID, options o: AVAudioOptions, context: Context) throws -> AVConversionPlan {
        guard let a = facts.primaryAudio else {
            throw ConversionError.other(L("This file has no audio to convert."), detail: "no audio stream in \(context.input.lastPathComponent)")
        }
        var args = ["-i", context.input.path, "-map", "0:\(a.index)"]
        var plan = AVConversionPlan(passes: [], output: context.output)
        var streams: [(spec: String, source: Int)] = [("a:0", a.index)]

        let depth = o.bitDepth ?? ((a.bitDepth ?? 16) > 16 ? 24 : 16)
        if canCopyAudio(a, to: to, options: o, depth: depth) {
            args += ["-c:a", "copy"]
            plan.audio = [.copy]
        } else {
            let enc = audioEncoder(to: to, source: a, options: o, depth: depth, audioToolbox: context.allowAudioToolbox)
            args += enc.arguments
            plan.audio = [.encode(enc.name)]
        }

        // Album art travels into formats that carry it, unless all metadata goes.
        if let cover = facts.coverArt, [Formats.mp3, Formats.m4a, Formats.flac].contains(to), context.metadata != .stripAll {
            args += ["-map", "0:\(cover.index)", "-c:v", ["mjpeg", "png"].contains(cover.codec) ? "copy" : "png", "-disposition:v:0", "attached_pic"]
            streams.append(("v:0", cover.index))
            plan.coverArt = ["mjpeg", "png"].contains(cover.codec) ? .copy : .encode("png")
        } else {
            args += ["-vn"]
        }

        args += metadataArguments(context.metadata, facts: facts, streams: streams)
        switch to {
        case Formats.mp3: args += ["-id3v2_version", "3"]
        case Formats.aiff where context.metadata != .stripAll: args += ["-write_id3v2", "1"]
        case Formats.wav: args += ["-rf64", "auto"]
        default: break
        }
        args += ["-f", AVCodecTables.muxer(to), context.output.path]
        plan.passes = [AVPass(arguments: args, weight: 1)]
        return plan
    }

    /// Stream copy for audio targets: same codec, same layout, and (lossy) the
    /// source isn't above the requested bitrate. Re-encoding a 128 kbps AAC to
    /// 256 kbps would only lose quality and waste space.
    static func canCopyAudio(_ a: AVInputFacts.Audio, to: FormatID, options o: AVAudioOptions, depth: Int) -> Bool {
        if let sr = o.sampleRate, sr != a.sampleRate { return false }
        if let ch = o.channels, ch != a.channels { return false }
        switch to {
        case Formats.wav: return a.codec == (depth == 24 ? "pcm_s24le" : "pcm_s16le")
        case Formats.aiff: return a.codec == (depth == 24 ? "pcm_s24be" : "pcm_s16be")
        case Formats.flac, Formats.caf: return a.codec == AVCodecTables.canonicalAudioCodec(to) && a.bitDepth == depth
        default:
            guard a.codec == AVCodecTables.canonicalAudioCodec(to) else { return false }
            if to == Formats.mp3, (a.channels ?? 2) > 2 { return false }
            guard let br = a.bitRate else { return true }
            return Double(br) <= Double(o.bitrate) * 1000 * 1.05
        }
    }

    static func audioEncoder(to: FormatID, source a: AVInputFacts.Audio, options o: AVAudioOptions, depth: Int, audioToolbox: Bool) -> Encoder {
        var args: [String] = []
        var name: String
        let channels = o.channels ?? ((a.channels ?? 2) > 2 && [Formats.mp3].contains(to) ? 2 : nil)
        var sampleRate = o.sampleRate
        // 24 → 16 bit (or float → 16 bit) gets triangular dither instead of plain truncation.
        let dither = depth == 16 && (a.bitDepth.map { $0 > 16 } ?? true)
        switch to {
        case Formats.mp3:
            name = "libmp3lame"
            args = ["-c:a", name, "-b:a", "\(o.bitrate)k"]
        case Formats.m4a:
            name = audioToolbox ? "aac_at" : "aac"
            args = ["-c:a", name, "-b:a", "\(min(o.bitrate, 320))k"]
        case Formats.ogg:
            name = "libvorbis"
            args = ["-c:a", name, "-q:a", "\(AVDefaultAudio.vorbisQuality(kbps: o.bitrate))"]
        case Formats.opus:
            name = "libopus"
            // libopus refuses more than 256 kbps per channel (e.g. 320 kbps mono).
            let kbps = min(o.bitrate, 256 * max(1, channels ?? a.channels ?? 2))
            args = ["-c:a", name, "-b:a", "\(kbps)k", "-vbr", "on"]
            sampleRate = 48000 // Opus always runs at 48 kHz.
        case Formats.wav:
            name = depth == 24 ? "pcm_s24le" : "pcm_s16le"
            args = ["-c:a", name]
        case Formats.aiff:
            name = depth == 24 ? "pcm_s24be" : "pcm_s16be"
            args = ["-c:a", name]
        case Formats.flac:
            name = "flac"
            args = ["-c:a", name, "-compression_level", "5"]
                + (depth == 24 ? ["-sample_fmt", "s32", "-bits_per_raw_sample", "24"] : ["-sample_fmt", "s16"])
        case Formats.caf:
            name = "alac"
            args = ["-c:a", name] + (depth == 24 ? ["-sample_fmt", "s32p", "-bits_per_raw_sample", "24"] : ["-sample_fmt", "s16p"])
        default:
            name = "copy"
            args = ["-c:a", "copy"]
        }
        if AVCodecTables.losslessAudio.contains(to), dither { args += ["-af", "aresample=dither_method=triangular"] }
        if let sampleRate, sampleRate != a.sampleRate { args += ["-ar", "\(sampleRate)"] }
        if let channels, channels != a.channels { args += ["-ac", "\(channels)"] }
        return Encoder(name: name, arguments: args)
    }

    // MARK: - GIF

    /// Two passes: palettegen over the whole clip (stats_mode=diff favours what
    /// moves), then paletteuse with sierra2_4a dithering. Two passes instead of
    /// a split filter so a long clip never buffers every frame in memory.
    static func gifPlan(_ facts: AVInputFacts, options: OptionValues, context: Context) throws -> AVConversionPlan {
        guard let v = facts.video else {
            throw ConversionError.other(L("This file has no video to turn into a GIF."), detail: "no video stream in \(context.input.lastPathComponent)")
        }
        let requestedWidth = options.int(OptionKey.gifWidth, default: 640)
        let width = max(2, requestedWidth > 0 ? min(requestedWidth, v.displayWidth) : v.displayWidth)
        let requestedFPS = Double(max(1, options.int(OptionKey.fps, default: 15)))
        let fps = min(requestedFPS, (v.frameRate ?? v.nominalFrameRate).map { max(1, $0) } ?? requestedFPS)
        let chain = "fps=\(formatNumber(fps)),scale=\(width):-1:flags=lanczos"
        let palette = context.scratchDirectory.appendingPathComponent(".palette-\(UUID().uuidString).png")
        let pass1 = ["-i", context.input.path, "-map", "0:\(v.index)", "-vf", "\(chain),palettegen=stats_mode=diff",
                     "-frames:v", "1", "-update", "1", "-f", "image2", palette.path]
        let pass2 = ["-i", context.input.path, "-i", palette.path,
                     "-filter_complex", "[0:\(v.index)]\(chain)[x];[x][1:v]paletteuse=dither=sierra2_4a:diff_mode=rectangle",
                     "-an", "-map_metadata", "-1", "-loop", "0", "-f", "gif", context.output.path]
        var plan = AVConversionPlan(passes: [AVPass(arguments: pass1, weight: 0.35), AVPass(arguments: pass2, weight: 0.65)],
                                    output: context.output)
        plan.scratch = [palette]
        plan.video = .encode("gif")
        return plan
    }

    // MARK: - Metadata

    /// Keys that identify a person, place or device. `stripPrivate` removes them;
    /// titles, dates, artists and chapters stay.
    static func isPrivateTag(_ key: String) -> Bool {
        let k = key.lowercased()
        if k.contains("location") || k.contains("gps") || k.hasSuffix("xyz") { return true }
        let exact: Set<String> = ["make", "model", "software", "author", "camera", "lens", "serial", "device",
                                  "com.apple.quicktime.author", "com.apple.quicktime.displayname"]
        if exact.contains(k) { return true }
        let prefixes = ["com.apple.quicktime.make", "com.apple.quicktime.model", "com.apple.quicktime.software",
                        "com.apple.quicktime.camera", "com.apple.quicktime.content.identifier",
                        "com.apple.quicktime.live-photo", "com.apple.photos", "com.android."]
        return prefixes.contains { k.hasPrefix($0) }
    }

    /// Demuxer pseudo-tags (ftyp brands) that must never be written back as
    /// metadata; Matroska would otherwise store them as tags.
    static let pseudoTags = ["major_brand", "minor_version", "compatible_brands"]

    /// - keep: everything ffmpeg can carry, plus Apple's QuickTime keys translated (below).
    /// - stripPrivate: the same minus every `isPrivateTag` key, container and stream level.
    /// - stripAll: nothing, not even chapters or ffmpeg's versioned encoder string.
    static func metadataArguments(_ policy: MetadataPolicy, facts: AVInputFacts, streams: [(spec: String, source: Int)]) -> [String] {
        switch policy {
        case .stripAll:
            return ["-map_metadata", "-1", "-map_chapters", "-1", "-fflags", "+bitexact"]
        case .keep, .stripPrivate:
            var args = ["-map_metadata", "0"]
            for k in pseudoTags where facts.formatTags[k] != nil { args += ["-metadata", "\(k)="] }
            for (key, value) in appleTagTranslations(facts.formatTags, includePrivate: policy == .keep) {
                args += ["-metadata", "\(key)=\(value)"]
            }
            if policy == .stripPrivate {
                for k in facts.formatTags.keys.sorted() where isPrivateTag(k) { args += ["-metadata", "\(k)="] }
                for s in streams {
                    for k in (facts.streamTags[s.source] ?? [:]).keys.sorted() where isPrivateTag(k) {
                        args += ["-metadata:s:\(s.spec)", "\(k)="]
                    }
                }
            }
            return args
        }
    }

    /// iPhone and AVFoundation files keep metadata as `com.apple.quicktime.*` keys.
    /// ffmpeg's mp4/mov muxers drop those, and `-movflags use_metadata_tags` writes
    /// them in a form AVFoundation reads back as numbered iTunes items, so the
    /// useful ones become standard tags Apple apps do read (©nam, ©day, ©xyz, ©mak,
    /// ©mod, movie creation time). Checked with AVURLAsset; see docs/lanes/E-av.md.
    static func appleTagTranslations(_ tags: [String: String], includePrivate: Bool) -> [(String, String)] {
        let q = "com.apple.quicktime."
        var out: [(String, String)] = []
        func carry(_ standard: String, _ appleKey: String) {
            guard tags[standard] == nil, let v = tags[q + appleKey], !v.isEmpty else { return }
            out.append((standard, v))
        }
        carry("title", "title")
        carry("artist", "artist")
        carry("comment", "comment")
        carry("description", "description")
        if let created = tags[q + "creationdate"], !created.isEmpty {
            if tags["date"] == nil { out.append(("date", created)) }
            // The capture time beats the container's, which is often the export time.
            if let utc = utcTimestamp(created) { out.append(("creation_time", utc)) }
        }
        if includePrivate {
            carry("location", "location.ISO6709")
            carry("make", "make")
            carry("model", "model")
        }
        return out
    }

    /// "2024-05-01T12:00:00+0200" → "2024-05-01T10:00:00Z" (ffmpeg's creation_time wants UTC).
    static func utcTimestamp(_ text: String) -> String? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        var date: Date?
        for format in ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd'T'HH:mm:ssXXXXX", "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"] {
            parser.dateFormat = format
            if let d = parser.date(from: text) { date = d; break }
        }
        guard let date else { return nil }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.timeZone = TimeZone(identifier: "UTC")
        out.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return out.string(from: date)
    }

    // MARK: - Geometry

    /// Even output size with the short edge capped at `maxShortEdge` (never upscales).
    static func targetSize(width w: Int, height h: Int, maxShortEdge: Int?) -> (Int, Int) {
        guard let m = maxShortEdge, m > 0, min(w, h) > m else { return (even(w), even(h)) }
        let scale = Double(m) / Double(min(w, h))
        return (nearestEven(Double(w) * scale), nearestEven(Double(h) * scale))
    }

    /// Odd sizes round down (321 → 320): 4:2:0 encoders need even dimensions.
    static func even(_ v: Int) -> Int { max(2, v - v % 2) }

    private static func nearestEven(_ v: Double) -> Int { max(2, Int((v / 2).rounded()) * 2) }

    static func canonicalVideoCodec(_ option: String) -> String {
        switch option {
        case "h265": "hevc"
        case "vp09": "vp9"
        default: option
        }
    }

    private static func formatNumber(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.3f", d)
    }
}
