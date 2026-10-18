import Foundation

/// Audio, video and GIF conversions through the bundled ffmpeg.
///
/// Probe → plan (`AVConversionPlanner`, pure) → run. Streams are copied
/// whenever the target container can carry them and no option asks for a
/// re-encode; otherwise each stream gets the container's encoder. Video uses
/// VideoToolbox by default (measured faster at equal quality, see
/// docs/lanes/E-av.md); if a hardware or AudioToolbox encoder can't start, the
/// conversion reruns once on the software-only fallback plan.
public struct FFmpegAVEngine: ConversionEngine {
    public let id = EngineIDs.ffmpeg
    private let locator: EngineLocator

    public init(locator: EngineLocator = .shared) {
        self.locator = locator
    }

    public func isAvailable(_ capability: Capability) -> Bool {
        locator.ffmpeg != nil && locator.ffprobe != nil
    }

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        let planned = try await plan(for: request, locator: context.locator)
        try await run(planned.plan, context: context, duration: planned.sourceDuration)
        return ConversionOutput(planned.plan.output)
    }

    struct PlannedConversion {
        let plan: AVConversionPlan
        let sourceDuration: Double?
    }

    /// Probes the input and decides every stream. Exposed for tests and tools.
    func plan(for request: ConversionRequest, locator: EngineLocator) async throws -> PlannedConversion {
        let facts = try await AVProbe.facts(for: request.input, locator: locator)
        try Task.checkCancellation()
        let ctx = AVConversionPlanner.Context(input: request.input, output: request.defaultOutputURL,
                                              scratchDirectory: request.outputDirectory, metadata: request.metadata)
        let plan = try AVConversionPlanner.plan(facts, from: request.from, to: request.to, options: request.options, context: ctx)
        return PlannedConversion(plan: plan, sourceDuration: facts.duration)
    }

    func run(_ plan: AVConversionPlan, context: EngineContext, duration: Double?) async throws {
        let ffmpeg = FFmpeg(locator: context.locator)
        do {
            try await execute(plan, ffmpeg: ffmpeg, duration: duration, progress: context.progress)
        } catch let error as ConversionError {
            guard let fallback = plan.fallback.first, Self.isEncoderStartupFailure(error) else { throw error }
            context.logger.notice("ffmpeg: \(plan.video?.encoder ?? "audio", privacy: .public) failed, retrying with software encoders")
            try await execute(fallback, ffmpeg: ffmpeg, duration: duration, progress: context.progress)
        }
    }

    private func execute(_ plan: AVConversionPlan, ffmpeg: FFmpeg, duration: Double?, progress: ProgressSink) async throws {
        let fm = FileManager.default
        defer { for url in plan.scratch { try? fm.removeItem(at: url) } }
        // ffmpeg prints `progress=end` even when it stops on SIGTERM, so passes
        // only ever reach 99.9 %; 100 % is reported once the output checks out.
        let capped = ProgressSink { progress(min($0, 0.999)) }
        do {
            var done = 0.0
            for pass in plan.passes {
                let sink = capped.scaled(done...min(1, done + pass.weight))
                try await ffmpeg.run(pass.arguments, duration: duration, progress: sink)
                done += pass.weight
            }
        } catch {
            // Leave nothing half-written behind (this is our private temp dir, never the user's).
            try? fm.removeItem(at: plan.output)
            throw error
        }
        let size = (try? fm.attributesOfItem(atPath: plan.output.path)[.size] as? Int) ?? 0
        guard size > 0 else {
            try? fm.removeItem(at: plan.output)
            throw ConversionError.outputMissing(plan.output.lastPathComponent)
        }
        progress(1)
    }

    /// An encoder that couldn't open (no VideoToolbox session, AudioToolbox
    /// refused the layout) rather than a bad input.
    static func isEncoderStartupFailure(_ error: ConversionError) -> Bool {
        guard case .engineFailed(_, _, let detail) = error else { return false }
        let d = detail.lowercased()
        return d.contains("toolbox") || d.contains("encoder") || d.contains("aac_at")
    }
}
