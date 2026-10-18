import Foundation

// Tools 12–14: trim, crop, change speed. All keep the input's container.

/// 12. Trim video. Lossless stream copy when the cut points sit on (or within
/// `TrimPlanner.maxSnap` of) keyframes; otherwise a frame-accurate re-encode.
public struct TrimVideoRunner: ToolRunner {
    public let id = ToolIDs.trimVideo
    public var resourceClass: ResourceClass { .videoToolbox }
    public init() {}

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let run = try MediaRun(request, context)
        let info = try await run.probe(run.input)
        guard let video = info.video else { throw ConversionError.noVideo(run.input) }
        let container = try run.container(of: run.input)
        guard let requested = MediaTimes.range(run.options.string("range", default: "")),
              requested.lowerBound < info.duration else { throw ConversionError.invalidOption("range") }
        let lossless = run.options.bool(OptionKey.lossless, default: true)
        let keyframes = lossless ? try? await KeyframeIndex.load(info, locator: context.locator) : nil
        let fd = video.frameDuration
        var plan = TrimPlanner.plan(requested: requested, duration: info.duration, frameDuration: fd,
                                    keyframes: keyframes, lossless: lossless)
        let out = run.outputURL(ext: run.keptExtension(of: run.input))
        let maps = MediaRun.avMaps(info, container: container)
        let meta = MediaEncoders.metadata(request.metadata, info: info)

        if case .copy(let s, let e, let toEnd) = plan {
            // Input seek lands on the keyframe; -t bounds audio, -frames:v bounds
            // video by packet count so the next GOP's leading frames never leak in.
            let frames = keyframes?.packetCount(from: s, to: e, tolerance: fd / 2) ?? 0
            if toEnd || frames > 0 {
                context.logger.info("trim lossless \(s)–\(e) (requested \(requested.lowerBound)–\(requested.upperBound))")
                var args = s > 0 ? ["-ss", MediaTimes.arg(s)] : []
                args += ["-i", run.input.path]
                if !toEnd { args += ["-t", MediaTimes.arg(e - s), "-frames:v", String(frames)] }
                args += maps + ["-c", "copy"] + meta + MediaRun.muxerFlags(container) + [out.path]
                try await run.ffmpeg.run(args, duration: e - s, progress: context.progress)
                return ConversionOutput(try run.requireOutput(out))
            }
            plan = .reencode(start: TrimPlanner.snapToFrame(requested.lowerBound, fd),
                             end: min(info.duration, TrimPlanner.snapToFrame(requested.upperBound, fd)), reason: .noVideoIndex)
        }

        let s = plan.start, e = plan.end
        context.logger.info("trim re-encode \(s)–\(e)")
        let seek = max(0, s - fd / 2)
        let cap = info.videoBitRate.map { Int(Double($0) * 1.5) }
        let attempts = MediaEncoders.video(container: container, source: video, quality: .transparent, maxRate: cap)
        let audio = info.hasAudio ? MediaEncoders.audio(container: container, source: info.audio) : []
        try await run.runAttempts(attempts, removing: { [out] }) { enc in
            var args = seek > 0 ? ["-ss", MediaTimes.arg(seek)] : []
            args += ["-i", run.input.path, "-t", MediaTimes.arg(e - s)]
            args += maps + enc.args + audio + meta + MediaRun.muxerFlags(container) + [out.path]
            try await run.ffmpeg.run(args, duration: e - s, progress: context.progress)
        }
        return ConversionOutput(try run.requireOutput(out))
    }
}

/// Normalised crop rectangle ("x,y,w,h", 0…1, origin top-left) → even pixel crop.
public struct PixelCrop: Sendable, Equatable {
    public let x: Int, y: Int, width: Int, height: Int

    public init(x: Int, y: Int, width: Int, height: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public static func parse(_ text: String) -> CGRectValue? {
        let p = text.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard p.count == 4, p.allSatisfy(\.isFinite) else { return nil }
        let x = min(max(p[0], 0), 1), y = min(max(p[1], 0), 1)
        let w = min(max(p[2], 0), 1 - x), h = min(max(p[3], 0), 1 - y)
        guard w > 0, h > 0 else { return nil }
        return CGRectValue(x: x, y: y, width: w, height: h)
    }

    /// Even-sized, even-positioned crop inside a `frameWidth × frameHeight` frame.
    public static func make(_ r: CGRectValue, frameWidth fw: Int, frameHeight fh: Int) -> PixelCrop {
        // Nearest even pixel: exact rects from the editor survive float round-trips.
        func even(_ v: Double) -> Int { Int((v / 2).rounded()) * 2 }
        var w = max(2, even(r.width * Double(fw)))
        var h = max(2, even(r.height * Double(fh)))
        w = min(w, fw - fw % 2)
        h = min(h, fh - fh % 2)
        var x = even(r.x * Double(fw)), y = even(r.y * Double(fh))
        x = min(x, max(0, fw - w) / 2 * 2)
        y = min(y, max(0, fh - h) / 2 * 2)
        return PixelCrop(x: x, y: y, width: w, height: h)
    }

    public var filter: String { "crop=\(width):\(height):\(x):\(y)" }
}

/// Plain value rect (CoreGraphics-free so it's trivially Sendable/Equatable).
public struct CGRectValue: Sendable, Equatable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var optionText: String {
        [x, y, width, height].map { String(format: "%.5f", $0) }.joined(separator: ",")
    }

    public static let full = CGRectValue(x: 0, y: 0, width: 1, height: 1)
}

/// 13. Crop video. Re-encodes video in the input's codec family; audio is copied.
public struct CropVideoRunner: ToolRunner {
    public let id = ToolIDs.cropVideo
    public var resourceClass: ResourceClass { .videoToolbox }
    public init() {}

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let run = try MediaRun(request, context)
        let info = try await run.probe(run.input)
        guard let video = info.video else { throw ConversionError.noVideo(run.input) }
        let container = try run.container(of: run.input)
        guard let rect = PixelCrop.parse(run.options.string("rect", default: "")) else { throw ConversionError.invalidOption("rect") }
        // ffmpeg autorotates before filters, so the crop is in display orientation.
        let crop = PixelCrop.make(rect, frameWidth: video.displayWidth, frameHeight: video.displayHeight)
        guard crop.width >= 16, crop.height >= 16 else {
            throw ConversionError.other(L("The crop area is too small. Make it at least 16 × 16 pixels."), detail: "\(crop)")
        }
        guard crop.width < video.displayWidth - 1 || crop.height < video.displayHeight - 1 else {
            throw ConversionError.other(L("The crop area covers the whole frame, so there’s nothing to crop."), detail: "\(crop)")
        }
        let out = run.outputURL(ext: run.keptExtension(of: run.input))
        let maps = MediaRun.avMaps(info, container: container)
        let meta = MediaEncoders.metadata(request.metadata, info: info)
        let attempts = MediaEncoders.video(container: container, source: video, quality: .transparent,
                                           maxRate: info.videoBitRate.map { Int(Double($0) * 1.5) })
        let audioArgs: [String] = info.hasAudio ? ["-c:a", "copy"] : []
        try await run.runAttempts(attempts, removing: { [out] }) { enc in
            let args = ["-i", run.input.path] + maps + ["-vf", crop.filter] + enc.args + audioArgs + meta
                + MediaRun.muxerFlags(container) + [out.path]
            try await run.ffmpeg.run(args, duration: info.duration, progress: context.progress)
        }
        return ConversionOutput(try run.requireOutput(out))
    }
}

/// 14. Change speed: setpts for video, chained atempo (keeps pitch) or
/// asetrate (chipmunk/slow-mo voice) for audio.
public struct SpeedVideoRunner: ToolRunner {
    public let id = ToolIDs.speedVideo
    public var resourceClass: ResourceClass { .videoToolbox }
    public init() {}

    /// Splits `factor` into atempo stages each within 0.5…2 (best quality per stage).
    public static func atempoChain(_ factor: Double) -> [Double] {
        var f = factor, out: [Double] = []
        while f > 2.0 + 1e-9 { out.append(2.0); f /= 2.0 }
        while f < 0.5 - 1e-9 { out.append(0.5); f /= 0.5 }
        out.append(f)
        return out
    }

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let run = try MediaRun(request, context)
        let info = try await run.probe(run.input)
        guard let video = info.video else { throw ConversionError.noVideo(run.input) }
        let container = try run.container(of: run.input)
        let factor = min(4, max(0.25, run.options.double("factor", default: 2)))
        guard abs(factor - 1) > 0.001 else { throw ConversionError.invalidOption("factor") }
        let keepPitch = run.options.bool("keepPitch", default: true)
        let out = run.outputURL(ext: run.keptExtension(of: run.input))

        // Constant output frame rate: speeding up drops frames, slowing down repeats them.
        let fps = video.frameRate > 0 ? min(video.frameRate, 120) : 30
        let vf = "setpts=PTS/\(fmt(factor)),fps=\(fmt(fps))"
        var audioArgs: [String] = []
        var maps = ["-map", "0:\(video.index)"]
        if let a = info.audio {
            maps += ["-map", "0:\(a.index)"]
            let af: String
            if keepPitch {
                af = Self.atempoChain(factor).map { "atempo=\(fmt($0))" }.joined(separator: ",")
            } else {
                let sr = a.sampleRate > 0 ? a.sampleRate : 48000
                af = "asetrate=\(Int((Double(sr) * factor).rounded())),aresample=\(sr)"
            }
            audioArgs = ["-af", af] + MediaEncoders.audio(container: container, source: a)
        }
        // Subtitles and chapters would be out of sync after retiming, so they're dropped.
        var meta = MediaEncoders.metadata(request.metadata, info: info)
        if let i = meta.firstIndex(of: "-map_chapters"), i + 1 < meta.count { meta[i + 1] = "-1" }
        let attempts = MediaEncoders.video(container: container, source: video, quality: .transparent,
                                           maxRate: info.videoBitRate.map { Int(Double($0) * 1.5) })
        let outDuration = info.duration / factor
        try await run.runAttempts(attempts, removing: { [out] }) { enc in
            let args = ["-i", run.input.path] + maps + ["-vf", vf] + enc.args + audioArgs + meta
                + MediaRun.muxerFlags(container) + [out.path]
            try await run.ffmpeg.run(args, duration: outDuration, progress: context.progress)
        }
        return ConversionOutput(try run.requireOutput(out))
    }

    private func fmt(_ v: Double) -> String {
        var s = String(format: "%.6f", v)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
