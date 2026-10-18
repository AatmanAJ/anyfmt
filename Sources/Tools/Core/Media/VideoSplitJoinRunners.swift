import Foundation

// Tools 15–16: split and join.

/// 15. Split into parts "<name>-part-001.ext"…, at times or every N seconds.
/// Lossless (segment muxer, stream copy) when every cut has a keyframe close
/// after it; otherwise one re-encode with keyframes forced at the cuts, so
/// parts start exactly where asked.
public struct SplitVideoRunner: ToolRunner {
    public let id = ToolIDs.splitVideo
    public var resourceClass: ResourceClass { .videoToolbox }
    public init() {}

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let run = try MediaRun(request, context)
        let info = try await run.probe(run.input)
        guard let video = info.video else { throw ConversionError.noVideo(run.input) }
        let container = try run.container(of: run.input)
        let fd = video.frameDuration
        let mode = run.options.string("mode", default: "every")
        let requested = SplitPlan.requestedCuts(mode: mode, every: Double(run.options.int("every", default: 60)),
                                                at: MediaTimes.list(run.options.string("at", default: "")),
                                                duration: info.duration, minimumSegment: max(fd, 0.1))
        guard !requested.isEmpty else {
            throw ConversionError.other(L("Choose at least one split point inside the video."), detail: "no cuts for \(mode)")
        }
        let preferLossless = run.options.bool(OptionKey.lossless, default: true)
        let keyframes = preferLossless ? try? await KeyframeIndex.load(info, locator: context.locator) : nil
        let plan = SplitPlan.make(cuts: requested, duration: info.duration, frameDuration: fd,
                                  keyframes: keyframes, preferLossless: preferLossless)
        context.logger.info("split \(plan.segmentCount) parts lossless=\(plan.lossless)")

        let scratch = try run.makeScratch()
        defer { run.cleanup(scratch) }
        let ext = run.keptExtension(of: run.input)
        let pattern = scratch.appendingPathComponent("part-%03d.\(ext)").path
        // Each cut a hair early so the segment muxer takes the keyframe at the cut itself.
        let times = plan.cuts.map { MediaTimes.arg(max(0, $0 - fd / 2)) }.joined(separator: ",")
        let maps = MediaRun.avMaps(info, container: container)
        let meta = MediaEncoders.metadata(request.metadata, info: info)
        var segment = ["-f", "segment", "-segment_format", container.muxer, "-segment_times", times,
                       "-reset_timestamps", "1", "-segment_start_number", "1"]
        if container.isQuickTime { segment += ["-segment_format_options", "movflags=+faststart"] }

        if plan.lossless {
            let args = ["-i", run.input.path] + maps + ["-c", "copy"] + meta + segment + [pattern]
            try await run.ffmpeg.run(args, duration: info.duration, progress: context.progress)
        } else {
            let attempts = MediaEncoders.video(container: container, source: video, quality: .transparent,
                                               maxRate: info.videoBitRate.map { Int(Double($0) * 1.5) })
            let audio = info.hasAudio ? MediaEncoders.audio(container: container, source: info.audio) : []
            try await run.runAttempts(attempts, removing: { Self.parts(in: scratch) }) { enc in
                let args = ["-i", run.input.path] + maps + enc.args + ["-force_key_frames", times] + audio + meta + segment + [pattern]
                try await run.ffmpeg.run(args, duration: info.duration, progress: context.progress)
            }
        }

        let parts = Self.parts(in: scratch)
        guard !parts.isEmpty else { throw ConversionError.outputMissing("split parts") }
        var placed: [URL] = []
        for (i, part) in parts.enumerated() {
            let dest = run.outputURL(ext: ext, suffix: String(format: "-%03d", i + 1))
            try FileManager.default.moveItem(at: part, to: dest)
            placed.append(dest)
        }
        return ConversionOutput(placed)
    }

    static func parts(in dir: URL) -> [URL] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        return names.filter { $0.hasPrefix("part-") }.sorted().map { dir.appendingPathComponent($0) }
    }
}

/// Decides whether clips can be joined by stream copy.
public enum JoinPlanner {
    public struct Verdict: Sendable, Equatable {
        public let lossless: Bool
        /// Human reasons a re-encode is needed (empty when lossless).
        public let reasons: [String]
        /// Re-encode canvas: the largest input (by pixel area), even-sized.
        public let width: Int
        public let height: Int
        public let frameRate: Double
    }

    public static func verdict(_ infos: [MediaInfo]) -> Verdict {
        let videos = infos.compactMap(\.video)
        let biggest = videos.max { $0.displayWidth * $0.displayHeight < $1.displayWidth * $1.displayHeight }
        let w = max(16, (biggest?.displayWidth ?? 1280) / 2 * 2), h = max(16, (biggest?.displayHeight ?? 720) / 2 * 2)
        let fps = min(60, videos.map(\.frameRate).filter { $0 > 0 }.max() ?? 30)
        var reasons: [String] = []
        guard videos.count == infos.count, let first = infos.first, let v0 = first.video else {
            return Verdict(lossless: false, reasons: [L("Every clip needs a video track.")], width: w, height: h, frameRate: fps)
        }
        let containers = Set(infos.map { MediaContainer(extension: $0.url.pathExtension) })
        let quickTimeOnly = containers.allSatisfy { $0?.isQuickTime == true }
        if containers.count > 1 && !quickTimeOnly { reasons.append(L("The clips use different file formats.")) }
        if Set(videos.map(\.codec)).count > 1 { reasons.append(L("The clips use different video codecs.")) }
        if Set(videos.map { "\($0.displayWidth)×\($0.displayHeight)" }).count > 1 { reasons.append(L("The clips have different sizes.")) }
        if videos.contains(where: { abs($0.frameRate - v0.frameRate) > 0.01 }) { reasons.append(L("The clips have different frame rates.")) }
        if Set(videos.map { $0.pixelFormat ?? "" }).count > 1 || Set(videos.map(\.rotation)).count > 1
            || Set(videos.compactMap(\.extradataHash)).count > 1 {
            if reasons.isEmpty { reasons.append(L("The clips were encoded with different settings.")) }
        }
        let audios = infos.map(\.audio)
        if audios.contains(where: { $0 == nil }) != audios.allSatisfy({ $0 == nil }) {
            reasons.append(L("Some clips have sound and some don’t."))
        } else if let a0 = first.audio {
            let mismatch = audios.compactMap { $0 }.contains {
                $0.codec != a0.codec || $0.sampleRate != a0.sampleRate || $0.channels != a0.channels
                    || ($0.extradataHash != nil && a0.extradataHash != nil && $0.extradataHash != a0.extradataHash)
            }
            if mismatch { reasons.append(L("The clips’ audio formats differ.")) }
        }
        return Verdict(lossless: reasons.isEmpty, reasons: reasons, width: w, height: h, frameRate: fps)
    }

    /// "2,1,3" (1-based) → indices into `count` inputs; empty keeps drag order.
    public static func order(_ text: String, count: Int) -> [Int]? {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return Array(0..<count) }
        let idx = t.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.map { $0 - 1 }
        guard !idx.isEmpty, idx.allSatisfy({ (0..<count).contains($0) }) else { return nil }
        return idx
    }
}

/// 16. Join clips in drag order (or "order"). Concat-demuxer stream copy when
/// the clips match; otherwise one re-encode to H.264/AAC MP4 on the largest
/// clip's canvas, letterboxing the rest.
public struct JoinVideoRunner: ToolRunner {
    public let id = ToolIDs.joinVideo
    public var resourceClass: ResourceClass { .videoToolbox }
    public init() {}

    public func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput {
        let run = try MediaRun(request, context)
        guard let order = JoinPlanner.order(run.options.string("order", default: ""), count: request.inputs.count) else {
            throw ConversionError.invalidOption("order")
        }
        let urls = order.map { request.inputs[$0] }
        guard urls.count >= 2 else { throw ConversionError.other(L("Choose at least two clips to join."), detail: "\(urls.count) inputs") }
        var infos: [MediaInfo] = []
        for u in urls { infos.append(try await run.probe(u)) }
        let verdict = JoinPlanner.verdict(infos)
        let total = infos.map(\.duration).reduce(0, +)
        let scratch = try run.makeScratch()
        defer { run.cleanup(scratch) }
        let meta = MediaEncoders.metadata(request.metadata, info: infos[0])

        if verdict.lossless, let first = urls.first {
            let container = try run.container(of: first)
            let list = scratch.appendingPathComponent("list.ffconcat")
            let body = "ffconcat version 1.0\n" + urls.map { "file '\($0.path.replacingOccurrences(of: "'", with: "'\\''"))'\n" }.joined()
            try body.write(to: list, atomically: true, encoding: .utf8)
            let out = run.outputURL(ext: run.keptExtension(of: first))
            var maps = ["-map", "0:v:0"]
            if infos[0].hasAudio { maps += ["-map", "0:a:0"] }
            let args = ["-f", "concat", "-safe", "0", "-i", list.path] + maps + ["-c", "copy"] + meta
                + MediaRun.muxerFlags(container) + [out.path]
            try await run.ffmpeg.run(args, duration: total, progress: context.progress)
            return ConversionOutput(try run.requireOutput(out))
        }

        context.logger.info("join re-encode: \(verdict.reasons.joined(separator: " "), privacy: .public)")
        let out = run.outputURL(ext: "mp4")
        let W = verdict.width, H = verdict.height
        let fps = String(format: "%.3f", verdict.frameRate)
        let withAudio = infos.contains { $0.hasAudio }
        var graph: [String] = [], concatInputs = ""
        for (i, info) in infos.enumerated() {
            graph.append("[\(i):v:0]scale=\(W):\(H):force_original_aspect_ratio=decrease,pad=\(W):\(H):(ow-iw)/2:(oh-ih)/2:color=black,setsar=1,fps=\(fps),format=yuv420p[v\(i)]")
            concatInputs += "[v\(i)]"
            if withAudio {
                if info.hasAudio {
                    graph.append("[\(i):a:0]aresample=48000,aformat=sample_fmts=fltp:channel_layouts=stereo[a\(i)]")
                } else {
                    graph.append("anullsrc=r=48000:cl=stereo,atrim=duration=\(MediaTimes.arg(info.duration))[a\(i)]")
                }
                concatInputs += "[a\(i)]"
            }
        }
        graph.append("\(concatInputs)concat=n=\(infos.count):v=1:a=\(withAudio ? 1 : 0)[vout]\(withAudio ? "[aout]" : "")")
        let inputs = urls.flatMap { ["-i", $0.path] }
        let maps = ["-map", "[vout]"] + (withAudio ? ["-map", "[aout]", "-c:a", "aac_at", "-b:a", "192k"] : [])
        let attempts = MediaEncoders.video(container: .mp4, source: nil, quality: .transparent)
        try await run.runAttempts(attempts, removing: { [out] }) { enc in
            let args = inputs + ["-filter_complex", graph.joined(separator: ";")] + maps + enc.args + meta
                + MediaRun.muxerFlags(.mp4) + [out.path]
            try await run.ffmpeg.run(args, duration: total, progress: context.progress)
        }
        return ConversionOutput(try run.requireOutput(out))
    }
}
