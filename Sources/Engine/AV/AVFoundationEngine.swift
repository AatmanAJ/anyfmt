import AVFoundation
import Foundation

/// Apple-framework fast path: `AVAssetExportSession` passthrough remux between
/// MOV, MP4 and M4V, and AppleM4A export.
///
/// Passthrough copies samples untouched and, unlike an ffmpeg remux, keeps
/// QuickTime-specific tracks and metadata (timecode, Apple keys, HDR/spatial
/// metadata) exactly. Whenever the user's options need a re-encode, or the
/// source isn't passthrough-compatible with the target, the request goes to
/// `FFmpegAVEngine` instead, so options are never silently ignored. Only when
/// ffmpeg is missing does this engine re-encode itself with export presets.
public struct AVFoundationEngine: ConversionEngine {
    public let id = EngineIDs.avFoundation

    /// Inputs AVFoundation reads reliably on macOS 13+.
    static let readable: Set<FormatID> = [Formats.mov, Formats.mp4, Formats.m4v, Formats.m4a,
                                          Formats.mp3, Formats.wav, Formats.aiff, Formats.caf, Formats.flac]
    static let remuxFormats: Set<FormatID> = [Formats.mov, Formats.mp4, Formats.m4v]

    private let ffmpeg: FFmpegAVEngine

    public init(ffmpeg: FFmpegAVEngine = FFmpegAVEngine()) {
        self.ffmpeg = ffmpeg
    }

    public func isAvailable(_ capability: Capability) -> Bool {
        guard Self.readable.contains(capability.from) else { return false }
        if capability.to == Formats.m4a { return true }
        return Self.remuxFormats.contains(capability.from) && Self.remuxFormats.contains(capability.to)
    }

    enum Decision: Equatable {
        case passthrough
        case appleM4A
        case delegate(String)
    }

    /// What to do before looking inside the file. Pure, for tests.
    static func decide(_ request: ConversionRequest, ffmpegAvailable: Bool) -> Decision {
        if request.to == Formats.m4a {
            // ffmpeg honours bitrate/sample rate/channels and keeps cover art; AppleM4A can't.
            return ffmpegAvailable ? .delegate("m4a options") : .appleM4A
        }
        let o = AVVideoOptions(request.options)
        if o.maxShortEdge != nil { return .delegate("resolution") }
        if o.fps != nil { return .delegate("frame rate") }
        if o.quality == .small { return .delegate("small file") }
        if o.removeAudio { return .delegate("remove audio") }
        if o.codec != nil { return .delegate("explicit codec") }
        return .passthrough
    }

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        let ffmpegAvailable = context.locator.ffmpeg != nil && context.locator.ffprobe != nil
        switch Self.decide(request, ffmpegAvailable: ffmpegAvailable) {
        case .delegate(let why):
            context.logger.debug("avfoundation: \(why, privacy: .public) → ffmpeg")
            return try await ffmpeg.convert(request, context: context)
        case .appleM4A:
            return try await export(request, preset: AVAssetExportPresetAppleM4A, context: context)
        case .passthrough:
            do {
                return try await export(request, preset: AVAssetExportPresetPassthrough, context: context)
            } catch let error as ConversionError where ffmpegAvailable {
                context.logger.notice("avfoundation passthrough failed (\(error.technicalDetails, privacy: .public)) → ffmpeg")
                try? FileManager.default.removeItem(at: request.defaultOutputURL)
                return try await ffmpeg.convert(request, context: context)
            } catch let error as ConversionError {
                // No ffmpeg in this build: re-encode with an export preset rather than fail.
                context.logger.notice("avfoundation passthrough failed (\(error.technicalDetails, privacy: .public)), re-encoding")
                try? FileManager.default.removeItem(at: request.defaultOutputURL)
                return try await export(request, preset: Self.reencodePreset(request.options), context: context)
            }
        }
    }

    /// Export preset used only when ffmpeg is unavailable and passthrough isn't possible.
    static func reencodePreset(_ options: OptionValues) -> String {
        let o = AVVideoOptions(options)
        switch o.maxShortEdge {
        case .some(let e) where e <= 480: return AVAssetExportPreset640x480
        case .some(let e) where e <= 720: return AVAssetExportPreset1280x720
        case .some(let e) where e <= 1080: return AVAssetExportPreset1920x1080
        case .some: return AVAssetExportPreset3840x2160
        case .none: return o.quality == .small ? AVAssetExportPresetMediumQuality : AVAssetExportPresetHighestQuality
        }
    }

    static func fileType(_ format: FormatID) -> AVFileType? {
        switch format {
        case Formats.mov: .mov
        case Formats.mp4: .mp4
        case Formats.m4v: .m4v
        case Formats.m4a: .m4a
        default: nil
        }
    }

    private func export(_ request: ConversionRequest, preset: String, context: EngineContext) async throws -> ConversionOutput {
        try Task.checkCancellation()
        guard let type = Self.fileType(request.to) else { throw ConversionError.unsupported(from: request.from, to: request.to) }
        let asset = AVURLAsset(url: request.input)
        let (readable, exportable) = try await loadFlags(asset, url: request.input)
        guard readable, exportable else {
            throw ConversionError.unreadable(request.input, detail: "AVFoundation: readable=\(readable) exportable=\(exportable)")
        }
        guard await AVAssetExportSession.compatibility(ofExportPreset: preset, with: asset, outputFileType: type),
              let session = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw ConversionError.unsupported(from: request.from, to: request.to)
        }
        let output = request.defaultOutputURL
        session.outputURL = output
        session.outputFileType = type
        session.shouldOptimizeForNetworkUse = true
        switch request.metadata {
        case .keep: break
        case .stripPrivate: session.metadataItemFilter = .forSharing()
        case .stripAll:
            session.metadataItemFilter = .forSharing()
            session.metadata = []
        }
        let box = ExportSessionBox(session)
        try await box.run(progress: context.progress)
        guard FileManager.default.fileExists(atPath: output.path) else { throw ConversionError.outputMissing(output.lastPathComponent) }
        context.progress(1)
        return ConversionOutput(output)
    }

    private func loadFlags(_ asset: AVURLAsset, url: URL) async throws -> (Bool, Bool) {
        do {
            return try await asset.load(.isReadable, .isExportable)
        } catch {
            throw ConversionError.unreadable(url, detail: "AVFoundation: \(error.localizedDescription)")
        }
    }
}

/// Owns a non-Sendable export session across the cancellation and progress
/// polling boundary. The session is only touched through its thread-safe API.
private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession
    init(_ session: AVAssetExportSession) { self.session = session }

    func run(progress: ProgressSink) async throws {
        let poller = Task { [self] in
            while !Task.isCancelled {
                progress(Double(session.progress))
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        defer { poller.cancel() }
        await withTaskCancellationHandler {
            await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
                session.exportAsynchronously { done.resume() }
            }
        } onCancel: {
            session.cancelExport()
        }
        switch session.status {
        case .completed:
            return
        case .cancelled:
            if let url = session.outputURL { try? FileManager.default.removeItem(at: url) }
            throw CancellationError()
        default:
            if let url = session.outputURL { try? FileManager.default.removeItem(at: url) }
            let detail = session.error.map { "\($0)" } ?? "status \(session.status.rawValue)"
            throw ConversionError.engineFailed("AVAssetExportSession", status: Int32(session.status.rawValue), detail: detail)
        }
    }
}
