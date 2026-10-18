import Foundation

/// Input to a tool run. Editors fill `options` (crop rect, trim range, …);
/// instant tools use `ToolSpec.defaultOptions`.
public struct ToolRequest: Sendable {
    public let tool: ToolID
    /// One file for `.perFile` tools; all files for `.combine` tools.
    public let inputs: [URL]
    public let options: OptionValues
    public let outputDirectory: URL
    public let baseName: String
    public let metadata: MetadataPolicy

    public init(tool: ToolID, inputs: [URL], options: OptionValues, outputDirectory: URL,
                baseName: String, metadata: MetadataPolicy = .keep) {
        self.tool = tool
        self.inputs = inputs
        self.options = options
        self.outputDirectory = outputDirectory
        self.baseName = baseName
        self.metadata = metadata
    }
}

/// Implementation of one tool from `ToolCatalog`. Pure: reads inputs, writes
/// into `outputDirectory`, returns what it wrote. The job layer names/places it.
public protocol ToolRunner: Sendable {
    var id: ToolID { get }
    var resourceClass: ResourceClass { get }
    func run(_ request: ToolRequest, context: EngineContext) async throws -> ConversionOutput
}

public extension ToolRunner {
    var resourceClass: ResourceClass { .cpu }
}

/// Tool runners shipped in this build. Lane G fills `ToolRunners.all`.
public struct ToolRegistry: Sendable {
    private let runners: [ToolID: any ToolRunner]
    public init(_ list: [any ToolRunner]) {
        var d: [ToolID: any ToolRunner] = [:]
        for r in list { d[r.id] = r }
        runners = d
    }
    public subscript(id: ToolID) -> (any ToolRunner)? { runners[id] }
    public var ids: Set<ToolID> { Set(runners.keys) }

    public static let `default` = ToolRegistry(ToolRunners.all)
}
