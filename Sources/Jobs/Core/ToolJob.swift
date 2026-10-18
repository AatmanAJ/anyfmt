import Foundation

/// Runs a tool (`ToolRunner`) over its inputs and places the results with the
/// tool's suffix: `photo.jpg` → `photo-compressed.jpg`. Tools never carry the
/// source's dates (they make a new thing, not the same thing in a new format).
///
/// Per-file tools run once per input (one after another inside this job; use
/// `ToolJob.batch` to get one job per file so the queue can parallelise).
/// Combine tools (collage, join, images → PDF) run once with every input.
public final class ToolJob: Job, JobDescribing {
    public let id: UUID
    public let tool: ToolID
    public let inputs: [URL]
    public let options: OptionValues
    public let progress: Progress
    public let resourceClass: ResourceClass
    public let title: String
    private let registry: ToolRegistry
    private let spec: ToolSpec?
    private let driver: JobProgressDriver

    /// - Parameter options: editor values; nil uses the tool's defaults.
    public init(tool: ToolID, inputs: [URL], options: OptionValues? = nil,
                registry: ToolRegistry = .default, id: UUID = UUID()) {
        self.id = id
        self.tool = tool
        self.inputs = inputs
        self.registry = registry
        let spec = ToolCatalog.spec(tool)
        self.spec = spec
        self.options = (spec?.defaultOptions ?? OptionValues()).merging(options ?? OptionValues())
        self.progress = JobProgressDriver.makeProgress()
        self.driver = JobProgressDriver(progress)
        self.resourceClass = registry[tool]?.resourceClass ?? .cpu
        let name = spec?.title ?? tool.rawValue
        if inputs.count == 1, let only = inputs.first {
            self.title = L("\(only.lastPathComponent) → \(name)")
        } else {
            self.title = L("\(inputs.count) files → \(name)")
        }
    }

    /// One job per file for per-file tools (so a batch runs in parallel), or a
    /// single job for combine tools.
    public static func batch(tool: ToolID, inputs: [URL], options: OptionValues? = nil,
                             registry: ToolRegistry = .default) -> [ToolJob] {
        guard let spec = ToolCatalog.spec(tool), case .perFile = spec.arity else {
            return [ToolJob(tool: tool, inputs: inputs, options: options, registry: registry)]
        }
        return inputs.map { ToolJob(tool: tool, inputs: [$0], options: options, registry: registry) }
    }

    private var isCombine: Bool {
        if case .combine = spec?.arity { return true }
        return false
    }

    private var suffix: String { spec?.outputSuffix ?? tool.rawValue.split(separator: ".").last.map(String.init) ?? "edited" }

    // MARK: Job

    public func run(context: JobContext) async throws -> [URL] {
        driver.reset()
        guard let runner = registry[tool] else {
            throw ConversionError.other(L("This tool isn’t available in this build of \(Brand.name)."), detail: "no runner for \(tool)")
        }
        guard !inputs.isEmpty else { throw ConversionError.outputMissing("no inputs for \(tool)") }
        if case .combine(let minimum) = spec?.arity, inputs.count < minimum {
            throw ConversionError.other(L("This tool needs at least \(minimum) files."), detail: "\(tool): \(inputs.count) < \(minimum)")
        }
        let placer = OutputPlacer(policy: context.policy)
        let groups: [[URL]] = isCombine ? [inputs] : inputs.map { [$0] }
        let n = Double(groups.count)
        let runDir = { (i: Int) in context.tempDirectory.appendingPathComponent("run\(i + 1)", isDirectory: true) }
        // JobRunner removes the whole scratch folder; this covers direct callers too.
        defer { for i in groups.indices { try? FileManager.default.removeItem(at: runDir(i)) } }
        var placed: [URL] = []
        for (i, group) in groups.enumerated() {
            try Task.checkCancellation()
            let dir = runDir(i)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let request = ToolRequest(tool: tool, inputs: group, options: options, outputDirectory: dir,
                                      baseName: OutputNamer.stem(of: group[0]), metadata: context.policy.metadata)
            let lo = Double(i) / n * 0.97, hi = Double(i + 1) / n * 0.97
            let engine = EngineContext(progress: driver.sink(lo...hi), locator: context.engine.locator, logger: context.engine.logger)
            let out = try await runner.run(request, context: engine)
            for f in out.files where !FileManager.default.fileExists(atPath: f.path) {
                throw ConversionError.outputMissing("\(tool): \(f.lastPathComponent)")
            }
            try Task.checkCancellation()
            placed += try placer.place(out.files, for: group[0], target: nil, toolSuffix: suffix)
            try? FileManager.default.removeItem(at: dir)
        }
        driver.set(1)
        return placed
    }

    // MARK: Words

    public var activityTitle: String { Self.activity(for: tool) ?? (spec?.title ?? tool.rawValue) }
    public var completedTitle: String { Self.completed(for: tool) ?? L("Done") }
    public var failedTitle: String { L("Couldn’t finish “\(spec?.title ?? tool.rawValue)”") }

    public var diagnostics: String {
        let names = inputs.map(\.lastPathComponent).joined(separator: ", ")
        let opts = options.values.keys.sorted().map { "\($0)=\(options.values[$0]?.description ?? "")" }.joined(separator: " ")
        return "Inputs: \(names)\nTool: \(tool) (suffix \(suffix))\nResource: \(resourceClass.rawValue)\nOptions: \(opts)"
    }

    static func activity(for tool: ToolID) -> String? {
        switch tool {
        case ToolIDs.compressImage, ToolIDs.compressVideo, ToolIDs.compressPDF: L("Compressing")
        case ToolIDs.resizeImage: L("Resizing")
        case ToolIDs.cropImage: L("Cropping")
        case ToolIDs.cropVideo: L("Cropping video")
        case ToolIDs.adjustImage: L("Adjusting")
        case ToolIDs.annotateImage: L("Saving annotations")
        case ToolIDs.redactImage: L("Redacting")
        case ToolIDs.removeBackground: L("Removing background")
        case ToolIDs.addBackground: L("Adding background")
        case ToolIDs.collage: L("Making collage")
        case ToolIDs.imagesToPDF: L("Making PDF")
        case ToolIDs.readCodes: L("Reading codes")
        case ToolIDs.trimVideo, ToolIDs.trimAudio: L("Trimming")
        case ToolIDs.speedVideo: L("Changing speed")
        case ToolIDs.splitVideo: L("Splitting")
        case ToolIDs.joinVideo: L("Joining")
        case ToolIDs.snapshotVideo: L("Saving frames")
        case ToolIDs.normalizeAudio: L("Normalizing")
        case ToolIDs.bleepAudio: L("Bleeping")
        case ToolIDs.channelsAudio: L("Changing channels")
        case ToolIDs.editMetadata: L("Saving metadata")
        case ToolIDs.stripMetadata: L("Stripping metadata")
        case ToolIDs.organizePDF: L("Saving pages")
        default: nil
        }
    }

    static func completed(for tool: ToolID) -> String? {
        switch tool {
        case ToolIDs.compressImage, ToolIDs.compressVideo, ToolIDs.compressPDF: L("Compressed")
        case ToolIDs.resizeImage: L("Resized")
        case ToolIDs.cropImage, ToolIDs.cropVideo: L("Cropped")
        case ToolIDs.adjustImage: L("Adjusted")
        case ToolIDs.annotateImage: L("Annotated")
        case ToolIDs.redactImage: L("Redacted")
        case ToolIDs.removeBackground: L("Background removed")
        case ToolIDs.addBackground: L("Background added")
        case ToolIDs.collage: L("Collage saved")
        case ToolIDs.imagesToPDF: L("PDF saved")
        case ToolIDs.readCodes: L("Codes read")
        case ToolIDs.trimVideo, ToolIDs.trimAudio: L("Trimmed")
        case ToolIDs.speedVideo: L("Speed changed")
        case ToolIDs.splitVideo: L("Split")
        case ToolIDs.joinVideo: L("Joined")
        case ToolIDs.snapshotVideo: L("Frames saved")
        case ToolIDs.normalizeAudio: L("Normalized")
        case ToolIDs.bleepAudio: L("Bleeped")
        case ToolIDs.channelsAudio: L("Channels changed")
        case ToolIDs.editMetadata: L("Metadata saved")
        case ToolIDs.stripMetadata: L("Metadata stripped")
        case ToolIDs.organizePDF: L("Pages saved")
        default: nil
        }
    }
}
