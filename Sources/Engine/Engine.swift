import Foundation
import os

/// One conversion step handed to an engine. Engines write into
/// `outputDirectory` (a private temp dir) and return what they wrote; the job
/// runner names and moves results into place. Engines never touch the
/// user's folders and never overwrite anything.
public struct ConversionRequest: Sendable {
    /// One file for `.perFile` rows; all inputs for `.combine` rows.
    public let inputs: [URL]
    public let from: FormatID
    public let to: FormatID
    public let options: OptionValues
    public let outputDirectory: URL
    /// Base name (no extension) engines should use for what they write.
    public let baseName: String
    public let metadata: MetadataPolicy

    public init(inputs: [URL], from: FormatID, to: FormatID, options: OptionValues,
                outputDirectory: URL, baseName: String, metadata: MetadataPolicy) {
        self.inputs = inputs
        self.from = from
        self.to = to
        self.options = options
        self.outputDirectory = outputDirectory
        self.baseName = baseName
        self.metadata = metadata
    }

    public var input: URL { inputs[0] }

    /// `<outputDirectory>/<baseName>.<ext of to>`
    public var defaultOutputURL: URL {
        outputDirectory.appendingPathComponent(baseName).appendingPathExtension(Formats.extension(for: to))
    }
}

public struct ConversionOutput: Sendable {
    /// Files (or folders/packages) the engine wrote, in order.
    public let files: [URL]
    public init(_ files: [URL]) { self.files = files }
    public init(_ file: URL) { self.files = [file] }
}

/// Reports fractional progress 0...1. Thread-safe; call as often as you like.
public struct ProgressSink: Sendable {
    private let report: @Sendable (Double) -> Void
    public init(_ report: @escaping @Sendable (Double) -> Void) { self.report = report }
    public func callAsFunction(_ fraction: Double) { report(min(1, max(0, fraction))) }
    public static let ignore = ProgressSink { _ in }

    /// Maps 0...1 of a sub-step onto `range` of this sink.
    public func scaled(_ range: ClosedRange<Double>) -> ProgressSink {
        let r = report
        return ProgressSink { r(range.lowerBound + (range.upperBound - range.lowerBound) * $0) }
    }
}

/// Everything an engine may use besides its request.
public struct EngineContext: Sendable {
    public let progress: ProgressSink
    public let locator: EngineLocator
    public let logger: Logger
    public init(progress: ProgressSink = .ignore, locator: EngineLocator = .shared, logger: Logger = Log.engine) {
        self.progress = progress
        self.locator = locator
        self.logger = logger
    }
}

/// A conversion engine. One method per route family; the capability table says which rows it serves.
/// Engines must honour Task cancellation (check `Task.isCancelled`, or use `ProcessRunner`, which
/// terminates the child process on cancel).
public protocol ConversionEngine: Sendable {
    var id: EngineID { get }
    /// Runtime availability of a row (bundled binary present, OS encoder present, pack installed).
    func isAvailable(_ capability: Capability) -> Bool
    func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput
}

public extension ConversionEngine {
    func isAvailable(_ capability: Capability) -> Bool { true }
}

/// Looks engines up by id.
public struct EngineRegistry: Sendable {
    private let engines: [EngineID: any ConversionEngine]

    public init(_ list: [any ConversionEngine]) {
        var d: [EngineID: any ConversionEngine] = [:]
        for e in list { d[e.id] = e }
        engines = d
    }

    public subscript(id: EngineID) -> (any ConversionEngine)? { engines[id] }
    public var ids: Set<EngineID> { Set(engines.keys) }

    public func isAvailable(_ c: Capability) -> Bool {
        guard let e = engines[c.engine] else { return false }
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= c.minimumOS else { return false }
        return e.isAvailable(c)
    }

    /// Every engine shipped in this build. Each lane appends its own list.
    public static let `default` = EngineRegistry(
        ImageEngines.all + AVEngines.all + SubtitleEngines.all + DocsEngines.all + ArchiveEngines.all
    )
}
