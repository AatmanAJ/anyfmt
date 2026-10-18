import Foundation

/// Turns N dragged files + the target the user dropped on into jobs.
///
/// - Per-file targets: one `ConversionJob` per file that needs converting.
///   Files already in the target format are skipped and reported ("2 already JPG").
/// - Combine targets (the route's single hop has `.combine` arity, e.g.
///   folder/multi → ZIP): one job for every item. Items already in the target
///   format go *into* the archive rather than being skipped.
public struct BatchConversion: Sendable {
    public let target: FormatID
    public let jobs: [ConversionJob]
    /// Already in the target format; nothing to do.
    public let skipped: [URL]
    /// No route for this file's format (or unrecognised). Shouldn't happen for
    /// targets offered by `Router.commonTargets`, but never silently dropped.
    public let unsupported: [URL]
    public let isCombine: Bool
    /// Total items dragged.
    public let fileCount: Int

    /// - Parameters:
    ///   - files: the dragged items, in drag order.
    ///   - target: the segment dropped on (routes per input format).
    ///   - formatOf: format detection (injectable for tests).
    public init(files: [URL], target: RouteTarget, options: OptionValues = OptionValues(),
                registry: EngineRegistry = .default, formatOf: (URL) -> FormatID? = Formats.detect) {
        self.target = target.format
        self.fileCount = files.count
        let formats = files.map(formatOf)
        let combineRoute = target.routes.values
            .filter { $0.isDirect && $0.hops[0].arity == .combine }
            .min { $0.from < $1.from }

        if let combineRoute {
            var members: [URL] = []
            var unsupported: [URL] = []
            for (file, format) in zip(files, formats) {
                if let format, format == target.format || target.routes[format] != nil { members.append(file) } else { unsupported.append(file) }
            }
            isCombine = true
            skipped = []
            self.unsupported = unsupported
            jobs = members.isEmpty ? [] : [ConversionJob(inputs: members, route: combineRoute, target: target.format,
                                                         options: options, registry: registry)]
            return
        }

        var jobs: [ConversionJob] = []
        var skipped: [URL] = []
        var unsupported: [URL] = []
        for (file, format) in zip(files, formats) {
            guard let format else { unsupported.append(file); continue }
            if format == target.format { skipped.append(file); continue }
            guard let route = target.routes[format] else { unsupported.append(file); continue }
            jobs.append(ConversionJob(inputs: [file], route: route, target: target.format, options: options, registry: registry))
        }
        isCombine = false
        self.jobs = jobs
        self.skipped = skipped
        self.unsupported = unsupported
    }

    /// Plans with `router` for a target format (CLI, Enter-on-selection path).
    public init(files: [URL], to format: FormatID, options: OptionValues = OptionValues(),
                router: Router = .live(), registry: EngineRegistry = .default) {
        let detected = files.map { Formats.detect($0) }
        var routes: [FormatID: Route] = [:]
        for f in Set(detected.compactMap { $0 }) where f != format {
            if let r = router.route(from: f, to: format) { routes[f] = r }
        }
        let cache = Dictionary(zip(files, detected), uniquingKeysWith: { a, _ in a })
        self.init(files: files, target: RouteTarget(format: format, routes: routes), options: options,
                  registry: registry, formatOf: { cache[$0] ?? nil })
    }

    // MARK: Words

    private var label: String { Formats.label(target) }

    /// "2 already JPG" (nil when nothing was skipped).
    public var skippedNote: String? {
        var parts: [String] = []
        if !skipped.isEmpty { parts.append(L("\(skipped.count) already \(label)")) }
        if !unsupported.isEmpty { parts.append(L("\(unsupported.count) can’t be converted")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    public var title: String {
        if isCombine, let job = jobs.first { return job.title }
        return L("\(jobs.count) files → \(label)")
    }

    private var isArchive: Bool { Formats.kind(target) == .archive }

    public var activityTitle: String {
        if isCombine { return isArchive ? L("Compressing to \(label)") : L("Combining into \(label)") }
        return jobs.count == 1 ? L("Converting to \(label)") : L("Converting \(jobs.count) files to \(label)")
    }

    public var completedTitle: String {
        if isCombine { return isArchive ? L("Compressed to \(label)") : L("Combined into \(label)") }
        return jobs.count == 1 ? L("Converted to \(label)") : L("Converted \(jobs.count) files to \(label)")
    }

    public var failedTitle: String {
        if isCombine { return isArchive ? L("Couldn’t compress to \(label)") : L("Couldn’t combine into \(label)") }
        return jobs.count == 1 ? L("Couldn’t convert to \(label)") : L("Some files couldn’t be converted to \(label)")
    }
}
