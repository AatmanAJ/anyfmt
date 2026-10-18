import Foundation

/// Runs a planned `Route` hop by hop inside a private temp directory.
/// Used by conversion jobs, the CLI and the matrix runner.
public struct RouteExecutor: Sendable {
    public let registry: EngineRegistry
    public init(registry: EngineRegistry = .default) { self.registry = registry }

    /// - Parameters:
    ///   - inputs: one file for per-file routes; all inputs for a combine row.
    ///   - options: user options; applied to the final hop. Intermediate hops
    ///     get their schema defaults with lossless settings where offered.
    ///   - workDirectory: a private temp dir (created if missing).
    /// - Returns: the final hop's outputs (still inside `workDirectory`).
    public func execute(_ route: Route, inputs: [URL], options: OptionValues, baseName: String,
                        metadata: MetadataPolicy, workDirectory: URL, context: EngineContext) async throws -> [URL] {
        guard !route.hops.isEmpty else { throw ConversionError.noRoute(from: route.from, to: route.to) }
        var current = inputs
        // The previous intermediate step's folder. It's deleted as soon as the
        // next hop has consumed it, so a 3-hop route over a large video never
        // holds more than two generations on disk.
        var previousStepDir: URL?
        let n = Double(route.hops.count)
        for (i, hop) in route.hops.enumerated() {
            try Task.checkCancellation()
            guard let engine = registry[hop.engine] else {
                throw ConversionError.engineMissing(hop.engine.rawValue, detail: "not registered")
            }
            let isLast = i == route.hops.count - 1
            let stepDir = workDirectory.appendingPathComponent("step\(i + 1)", isDirectory: true)
            try FileManager.default.createDirectory(at: stepDir, withIntermediateDirectories: true)
            var opts = hop.schema.defaults
            if isLast {
                opts = opts.merging(options)
            } else if hop.schema.spec(OptionKey.lossless) != nil {
                opts[OptionKey.lossless] = .bool(true)
            } else if hop.schema.spec(OptionKey.quality) != nil {
                opts[OptionKey.quality] = .int(100)
            }
            let request = ConversionRequest(
                inputs: current, from: hop.from, to: hop.to, options: opts,
                outputDirectory: stepDir, baseName: baseName,
                metadata: isLast ? metadata : .keep)
            let sink = context.progress.scaled((Double(i) / n)...(Double(i + 1) / n))
            let stepContext = EngineContext(progress: sink, locator: context.locator, logger: context.logger)
            let out = try await engine.convert(request, context: stepContext)
            guard !out.files.isEmpty else { throw ConversionError.outputMissing("\(hop)") }
            for f in out.files where !FileManager.default.fileExists(atPath: f.path) {
                throw ConversionError.outputMissing("\(hop): \(f.lastPathComponent)")
            }
            // Never delete a folder an engine handed straight back as its output.
            if let prev = previousStepDir, !out.files.contains(where: { Self.isInside($0, prev) }) {
                try? FileManager.default.removeItem(at: prev)
            }
            previousStepDir = isLast ? nil : stepDir
            current = out.files
        }
        context.progress(1)
        return current
    }

    /// True if `url` is `dir` itself or lies inside it.
    static func isInside(_ url: URL, _ dir: URL) -> Bool {
        let d = dir.standardizedFileURL.path
        let p = url.standardizedFileURL.path
        return p == d || p.hasPrefix(d.hasSuffix("/") ? d : d + "/")
    }
}
