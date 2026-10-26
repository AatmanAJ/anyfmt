import AppKit
import AnyfmtCore

struct MatrixResult: Sendable {
    let from: FormatID
    let to: FormatID
    let route: String
    let hops: Int
    let ok: Bool
    let detail: String
    let millis: Int
    let bytes: Int64
}

@MainActor
struct MatrixRunner {
    let fixtures: URL
    let outDir: URL
    let report: URL?
    let json: URL?
    let only: Set<FormatID>
    let jobs: Int

    init(args: [String]) {
        func value(_ flag: String) -> String? {
            args.firstIndex(of: flag).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        fixtures = URL(fileURLWithPath: value("--fixtures") ?? "Tests/Fixtures/generated", relativeTo: cwd).standardizedFileURL
        outDir = URL(fileURLWithPath: value("--out") ?? "Tests/Matrix/out", relativeTo: cwd).standardizedFileURL
        report = value("--report").map { URL(fileURLWithPath: $0, relativeTo: cwd).standardizedFileURL }
        json = value("--json").map { URL(fileURLWithPath: $0, relativeTo: cwd).standardizedFileURL }
        only = Set(args.indices.filter { args[$0] == "--only" && args.indices.contains($0 + 1) }.map { FormatID(args[$0 + 1]) })
        jobs = value("--jobs").flatMap(Int.init) ?? max(2, ProcessInfo.processInfo.activeProcessorCount / 2)
    }

    /// Finds `sample.<ext>` (any extension of the format) or `sample-folder/`.
    func fixture(for format: Format) -> URL? {
        if format.id == Formats.folder {
            let u = fixtures.appendingPathComponent("sample-folder", isDirectory: true)
            return FileManager.default.fileExists(atPath: u.path) ? u : nil
        }
        for ext in format.extensions {
            let u = fixtures.appendingPathComponent("sample.\(ext)")
            if FileManager.default.fileExists(atPath: u.path) { return u }
        }
        return nil
    }

    func run() async -> Int32 {
        let registry = EngineRegistry.default
        let table = CapabilityTable.default
        let issues = table.integrityIssues(registry: registry)
        let router = Router.live(registry: registry)
        let validator = Validator()
        try? FileManager.default.removeItem(at: outDir)
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

        struct Work: Sendable { let from: FormatID; let to: FormatID; let route: Route; let input: URL }
        var work: [Work] = []
        var missingFixtures: [FormatID] = []
        let starts = Set(router.table.rows.map(\.from))
        for f in Formats.all where starts.contains(f.id) && (only.isEmpty || only.contains(f.id)) {
            guard let input = fixture(for: f) else { missingFixtures.append(f.id); continue }
            for (to, route) in router.allRoutes(from: f.id).sorted(by: { $0.key < $1.key }) {
                work.append(Work(from: f.id, to: to, route: route, input: input))
            }
        }
        log("matrix: \(work.count) routes from \(Set(work.map(\.from)).count) input formats, \(jobs) at a time")

        var results: [MatrixResult] = []
        var durations: [FormatID: Double] = [:]
        for w in work where Formats.kind(w.from).isTimeBased && durations[w.from] == nil {
            durations[w.from] = (try? await FFmpeg().probe(w.input))?.duration
        }
        let outRoot = outDir
        await withTaskGroup(of: MatrixResult.self) { group in
            var next = 0
            func launch() {
                guard next < work.count else { return }
                let w = work[next]
                next += 1
                let inputDuration = durations[w.from]
                group.addTask {
                    let dir = outRoot.appendingPathComponent("\(w.from.rawValue)-to-\(w.to.rawValue)", isDirectory: true)
                    let start = Date()
                    do {
                        let files = try await RouteExecutor(registry: registry).execute(
                            w.route, inputs: [w.input], options: OptionValues(), baseName: "sample",
                            metadata: .keep, workDirectory: dir, context: EngineContext())
                        let ms = Int(Date().timeIntervalSince(start) * 1000)
                        let verdict = await validator.validate(files, target: w.to, inputDuration: inputDuration)
                        let bytes = files.reduce(Int64(0)) { $0 + Self.size(of: $1) }
                        return MatrixResult(from: w.from, to: w.to, route: "\(w.route)", hops: w.route.hops.count,
                                            ok: verdict.ok, detail: verdict.detail, millis: ms, bytes: bytes)
                    } catch {
                        let ms = Int(Date().timeIntervalSince(start) * 1000)
                        let detail = (error as? ConversionError)?.technicalDetails ?? "\(error)"
                        return MatrixResult(from: w.from, to: w.to, route: "\(w.route)", hops: w.route.hops.count,
                                            ok: false, detail: String(detail.prefix(300)), millis: ms, bytes: 0)
                    }
                }
            }
            for _ in 0..<jobs { launch() }
            for await r in group {
                results.append(r)
                log("\(r.ok ? "✓" : "✗") \(r.from)→\(r.to) \(r.millis)ms \(r.ok ? "" : r.detail)")
                launch()
            }
        }
        results.sort { ($0.from, $0.to) < ($1.from, $1.to) }
        let passed = results.filter(\.ok).count
        log("matrix: \(passed)/\(results.count) passed; \(missingFixtures.count) input formats without fixtures; \(issues.count) table issues")
        if let report { write(markdown(results: results, missing: missingFixtures, issues: issues, router: router), to: report) }
        if let json { writeJSON(results, to: json) }
        return passed == results.count && issues.isEmpty ? 0 : 1
    }

    /// Options the wheel offers out of the box (`Route.isShownByDefault`).
    static func defaultVisibleCount(_ router: Router) -> Int {
        let starts = Set(router.table.rows.map(\.from))
        return starts.reduce(0) { total, from in
            total + router.allRoutes(from: from).values.filter(\.isShownByDefault).count
        }
    }

    nonisolated static func size(of url: URL) -> Int64 {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        if !isDir.boolValue { return Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        var total: Int64 = 0
        while let f = e?.nextObject() as? URL { total += Int64((try? f.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        return total
    }

    func markdown(results: [MatrixResult], missing: [FormatID], issues: [String], router: Router) -> String {
        let passed = results.filter(\.ok).count
        let df = ISO8601DateFormatter()
        var md = """
        # Conversion matrix

        Generated by `make matrix` on \(df.string(from: Date())) (macOS \(ProcessInfo.processInfo.operatingSystemVersionString)).
        Every route runs on its fixture, and the output is **opened and validated**
        (ImageIO decode, ffprobe probe + duration check, PDFKit page count, archive
        listing, document re-parse). Times are wall-clock on the build machine with
        \(jobs) routes running in parallel.

        | | |
        |---|---|
        | **Conversion options shipped** | **\(router.optionCount())** |
        | Shown on the wheel by default (rest enabled in Settings › Formats) | \(Self.defaultVisibleCount(router)) |
        | Routes run | \(results.count) |
        | Passed | \(passed) |
        | Failed | \(results.count - passed) |
        | Direct / multi-hop | \(results.filter { $0.hops == 1 }.count) / \(results.filter { $0.hops > 1 }.count) |
        | Input formats without a fixture (not counted as shipped) | \(missing.isEmpty ? "none" : missing.map(\.rawValue).joined(separator: ", ")) |
        | Capability table integrity | \(issues.isEmpty ? "✓ no duplicates, orphans or unknown formats" : issues.joined(separator: "; ")) |

        """
        let failures = results.filter { !$0.ok }
        if !failures.isEmpty {
            md += "\n## Failures\n\n| From | To | Route | Detail |\n|---|---|---|---|\n"
            for r in failures { md += "| \(r.from) | \(r.to) | \(r.route) | \(r.detail.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ")) |\n" }
        }
        md += "\n## All routes\n"
        let bcf = ByteCountFormatter()
        for from in Array(Set(results.map(\.from))).sorted() {
            let rows = results.filter { $0.from == from }
            md += "\n### \(Formats.label(from)) (\(rows.filter(\.ok).count)/\(rows.count))\n\n| To | | Time | Output | Route | Check |\n|---|---|---:|---:|---|---|\n"
            for r in rows {
                md += "| \(Formats.label(r.to)) | \(r.ok ? "✅" : "❌") | \(r.millis) ms | \(r.ok ? bcf.string(fromByteCount: r.bytes) : "–") | \(r.hops == 1 ? "direct" : r.route) | \(r.detail.replacingOccurrences(of: "|", with: "/").replacingOccurrences(of: "\n", with: " ")) |\n"
            }
        }
        return md
    }

    func write(_ s: String, to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data(s.utf8).write(to: url)
        log("wrote \(url.path)")
    }

    func writeJSON(_ results: [MatrixResult], to url: URL) {
        let rows = results.map { ["from": $0.from.rawValue, "to": $0.to.rawValue, "ok": $0.ok, "ms": $0.millis, "bytes": $0.bytes, "hops": $0.hops, "detail": $0.detail] as [String: Any] }
        if let d = try? JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys]) { try? d.write(to: url) }
    }

    func log(_ s: String) { FileHandle.standardError.write(Data((s + "\n").utf8)) }
}
