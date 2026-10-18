import Foundation

/// Converts one file (per-file routes) or a set of files (combine rows, e.g.
/// a folder or several items → ZIP) to a target format.
///
/// Runs the planned route hop by hop in the job's private scratch folder, then
/// places the result beside the original (or the policy's folder) under a
/// Finder-style free name. Conversions carry the source's dates when the policy
/// allows. Nothing outside the scratch folder is written before placement, and
/// the user's files are never modified.
public final class ConversionJob: Job, JobDescribing {
    public let id: UUID
    public let inputs: [URL]
    public let target: FormatID
    /// Nil when no route exists; `run` then fails with a human message.
    public let route: Route?
    public let options: OptionValues
    public let progress: Progress
    public let resourceClass: ResourceClass
    public let title: String
    private let registry: EngineRegistry
    private let driver: JobProgressDriver

    /// - Parameters:
    ///   - inputs: one file for per-file routes; every item for a combine route.
    ///   - route: a planned route (e.g. from `RouteTarget.routes`).
    ///   - options: the user's choices for the final hop.
    public init(inputs: [URL], route: Route?, target: FormatID? = nil, options: OptionValues = OptionValues(),
                registry: EngineRegistry = .default, id: UUID = UUID()) {
        self.id = id
        self.inputs = inputs
        self.route = route
        self.target = target ?? route?.to ?? ""
        self.options = options
        self.registry = registry
        self.progress = JobProgressDriver.makeProgress()
        self.driver = JobProgressDriver(progress)
        self.resourceClass = Self.resourceClass(for: route, target: self.target, options: options)
        self.title = Self.makeTitle(inputs: inputs, target: self.target)
    }

    /// Plans the route with `router` (default: the live table).
    public convenience init(input: URL, to target: FormatID, options: OptionValues = OptionValues(),
                            router: Router = .live(), registry: EngineRegistry = .default, id: UUID = UUID()) {
        let from = Formats.detect(input)
        let route = from.flatMap { router.route(from: $0, to: target) }
        self.init(inputs: [input], route: route, target: target, options: options, registry: registry, id: id)
    }

    /// A combine conversion of several items (folder/multi → archive).
    public convenience init(combining inputs: [URL], to target: FormatID, options: OptionValues = OptionValues(),
                            router: Router = .live(), registry: EngineRegistry = .default, id: UUID = UUID()) {
        let route = inputs.lazy.compactMap { Formats.detect($0) }
            .compactMap { router.route(from: $0, to: target) }
            .first { $0.isDirect && $0.hops[0].arity == .combine }
        self.init(inputs: inputs, route: route, target: target, options: options, registry: registry, id: id)
    }

    public var isCombine: Bool { route?.hops.last?.arity == .combine }

    // MARK: Job

    public func run(context: JobContext) async throws -> [URL] {
        driver.reset()
        guard let route, let first = inputs.first else {
            let from = inputs.first.flatMap(Formats.detect) ?? ""
            throw ConversionError.noRoute(from: from, to: target)
        }
        let work = context.tempDirectory.appendingPathComponent("work", isDirectory: true)
        // JobRunner removes the whole scratch folder; this covers direct callers too.
        defer { try? FileManager.default.removeItem(at: work) }
        let naming = namingInput(first)
        let engineContext = EngineContext(progress: driver.sink(0...0.97), locator: context.engine.locator,
                                          logger: context.engine.logger)
        let produced = try await RouteExecutor(registry: registry).execute(
            route, inputs: inputs, options: options, baseName: OutputNamer.stem(of: naming),
            metadata: context.policy.metadata, workDirectory: work, context: engineContext)
        // Last chance to stop before anything lands in the user's folder.
        try Task.checkCancellation()
        let placed = try OutputPlacer(policy: context.policy).place(produced, for: naming, target: target)
        driver.set(1)
        Log.jobs.info("converted \(self.title, privacy: .private) via \(route.description, privacy: .public)")
        return placed
    }

    /// The URL naming decisions are made from. Several combined items are named
    /// "Archive" (as Finder does) in the first item's folder.
    private func namingInput(_ first: URL) -> URL {
        guard isCombine, inputs.count > 1 else { return first }
        return first.deletingLastPathComponent().appendingPathComponent(L("Archive"))
    }

    // MARK: Words

    private var targetLabel: String { Formats.label(target) }

    private enum Verb { case convert, compress, combine, extract }

    private var verb: Verb {
        if target == Formats.folder { return .extract }
        if isCombine { return Formats.kind(target) == .archive ? .compress : .combine }
        return .convert
    }

    public var activityTitle: String {
        switch verb {
        case .convert: L("Converting to \(targetLabel)")
        case .compress: L("Compressing to \(targetLabel)")
        case .combine: L("Combining into \(targetLabel)")
        case .extract: L("Extracting")
        }
    }

    public var completedTitle: String {
        switch verb {
        case .convert: L("Converted to \(targetLabel)")
        case .compress: L("Compressed to \(targetLabel)")
        case .combine: L("Combined into \(targetLabel)")
        case .extract: L("Extracted")
        }
    }

    public var failedTitle: String {
        switch verb {
        case .convert: L("Couldn’t convert to \(targetLabel)")
        case .compress: L("Couldn’t compress to \(targetLabel)")
        case .combine: L("Couldn’t combine into \(targetLabel)")
        case .extract: L("Couldn’t extract")
        }
    }

    public var diagnostics: String {
        let kinds = inputs.map { "\($0.lastPathComponent) (\(Formats.detect($0)?.rawValue ?? "?"))" }
        var lines = ["Inputs: \(kinds.joined(separator: ", "))",
                     "Route: \(route?.description ?? "none → \(target)")",
                     "Resource: \(resourceClass.rawValue)"]
        if !options.values.isEmpty {
            let opts = options.values.keys.sorted().map { "\($0)=\(options.values[$0]?.description ?? "")" }
            lines.append("Options: \(opts.joined(separator: " "))")
        }
        return lines.joined(separator: "\n")
    }

    static func makeTitle(inputs: [URL], target: FormatID) -> String {
        let label = Formats.label(target)
        if inputs.count == 1, let only = inputs.first { return L("\(only.lastPathComponent) → \(label)") }
        return L("\(inputs.count) items → \(label)")
    }

    // MARK: Resource class

    /// `.videoToolbox` when the final hop encodes video with a codec the media
    /// engine can do (H.264/HEVC/ProRes) and hardware isn't switched off;
    /// `.io` for archives; otherwise `.cpu`.
    static func resourceClass(for route: Route?, target: FormatID, options: OptionValues) -> ResourceClass {
        guard let last = route?.hops.last else { return .cpu }
        let kind = Formats.kind(target)
        if last.engine == EngineIDs.archiveTool || kind == .archive || kind == .folder { return .io }
        guard kind == .video, last.engine == EngineIDs.ffmpeg || last.engine == EngineIDs.avFoundation else { return .cpu }
        let hardware = options.bool(OptionKey.hardware, default: last.schema.defaults.bool(OptionKey.hardware, default: true))
        guard hardware else { return .cpu }
        // VideoToolbox has no VP8/VP9/AV1 (or WMV/MPEG-4 Part 2) encoder, so only
        // the H.264/HEVC/ProRes containers count as hardware encodes.
        let hardwareContainers: Set<FormatID> = [Formats.mp4, Formats.mov, Formats.m4v, Formats.mkv]
        guard hardwareContainers.contains(target) else { return .cpu }
        let codec = options.string(OptionKey.videoCodec, default: last.schema.defaults.string(OptionKey.videoCodec, default: "auto"))
        if codec == "av1" || codec == "vp9" { return .cpu }
        return .videoToolbox
    }
}
