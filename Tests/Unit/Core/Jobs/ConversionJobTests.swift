import XCTest
@testable import AnyfmtCore

final class ConversionJobTests: JobsTestCase {
    private let e: EngineID = "fake"
    private var registry: EngineRegistry { EngineRegistry([ScriptedEngine(e)]) }

    private func run(_ job: any Job, policy: OutputPolicy = .default) async throws -> [URL] {
        try await JobRunner.run(job, policy: policy, scratch: scratch)
    }

    func testTitleAndWords() throws {
        let input = try makeFiles(["photo.heic"])[0]
        let job = ConversionJob(inputs: [input], route: directRoute("heic", "jpg", e), registry: registry)
        XCTAssertEqual(job.title, "photo.heic → JPG")
        XCTAssertEqual(job.activityTitle, "Converting to JPG")
        XCTAssertEqual(job.completedTitle, "Converted to JPG")
        XCTAssertEqual(job.failedTitle, "Couldn’t convert to JPG")
        XCTAssertEqual(job.target, "jpg")
        XCTAssertTrue(job.diagnostics.contains("Route: heic → jpg(fake)"))
    }

    func testNamingNeverOverwritesExistingFiles() async throws {
        let files = try makeFiles(["photo.heic", "photo.jpg", "photo 2.jpg"])
        let job = ConversionJob(inputs: [files[0]], route: directRoute("heic", "jpg", e), registry: registry)
        let out = try await run(job)
        XCTAssertEqual(out.map(\.lastPathComponent), ["photo 3.jpg"])
        XCTAssertEqual(contents(files[1]), "photo.jpg", "existing file untouched")
        XCTAssertEqual(contents(files[2]), "photo 2.jpg", "existing file untouched")
        XCTAssertEqual(contents(files[0]), "photo.heic", "original untouched")
        XCTAssertEqual(contents(out[0]), "photo.heic", "engine saw the original as input")
        XCTAssertEqual(job.progress.fractionCompleted, 1)
        XCTAssertTrue(scratchIsEmpty(), "temp dir removed on success")
    }

    func testConversionPreservesDatesAndHonoursFolderPolicy() async throws {
        let input = try makeFiles(["old.heic"])[0]
        let past = Date(timeIntervalSince1970: 1_000_000_000)
        try FileManager.default.setAttributes([.modificationDate: past, .creationDate: past], ofItemAtPath: input.path)
        let folder = root.appendingPathComponent("Converted", isDirectory: true)
        let job = ConversionJob(inputs: [input], route: directRoute("heic", "png", e), registry: registry)
        let out = try await run(job, policy: OutputPolicy(location: .folder(folder)))
        XCTAssertEqual(out.first?.deletingLastPathComponent().lastPathComponent, "Converted")
        let m = try FileManager.default.attributesOfItem(atPath: out[0].path)[.modificationDate] as? Date
        XCTAssertEqual(m?.timeIntervalSince1970 ?? 0, past.timeIntervalSince1970, accuracy: 1)

        let noDates = ConversionJob(inputs: [input], route: directRoute("heic", "png", e), registry: registry)
        let out2 = try await run(noDates, policy: OutputPolicy(preserveDates: false))
        let m2 = try FileManager.default.attributesOfItem(atPath: out2[0].path)[.modificationDate] as? Date
        XCTAssertGreaterThan(m2?.timeIntervalSince1970 ?? 0, Date().timeIntervalSince1970 - 60)
    }

    func testMultiHopRouteAndUserOptionsOnFinalHop() async throws {
        let seen = Box<[String: OptionValues]>([:])
        let engine = ScriptedEngine(e) { request, context in
            seen.mutate { $0["\(request.from)>\(request.to)"] = request.options }
            return try await ScriptedEngine.writeOutput(request, context)
        }
        let quality = OptionsSchema("q", [OptionSpec(OptionKey.quality, "Q", .slider(min: 1, max: 100, step: 1, unit: nil), default: .int(85))])
        let route = Route([Capability("md", "html", e, schema: quality), Capability("html", "docx", e, schema: quality)])
        let input = try makeFiles(["notes.md"])[0]
        let job = ConversionJob(inputs: [input], route: route, options: OptionValues([OptionKey.quality: .int(42)]),
                                registry: EngineRegistry([engine]))
        let out = try await run(job)
        XCTAssertEqual(out.map(\.lastPathComponent), ["notes.docx"])
        XCTAssertEqual(seen.get["md>html"]?.int(OptionKey.quality, default: 0), 100, "intermediate hops run at full quality")
        XCTAssertEqual(seen.get["html>docx"]?.int(OptionKey.quality, default: 0), 42, "user options apply to the final hop")
    }

    func testNoRouteFailsWithHumanMessage() async throws {
        let input = try makeFiles(["song.flac"])[0]
        let job = ConversionJob(input: input, to: "docx", router: Router(table: CapabilityTable([])), registry: registry)
        XCTAssertNil(job.route)
        do {
            _ = try await run(job)
            XCTFail("should throw")
        } catch {
            XCTAssertEqual(JobFailure.from(error).message, "FLAC files can’t be converted to DOCX.")
        }
        XCTAssertTrue(scratchIsEmpty())
    }

    func testEngineMissingFromRegistry() async throws {
        let input = try makeFiles(["a.png"])[0]
        let job = ConversionJob(inputs: [input], route: directRoute("png", "jpg", "nope"), registry: registry)
        do {
            _ = try await run(job)
            XCTFail("should throw")
        } catch {
            XCTAssertTrue(JobFailure.from(error).message.contains("is missing"))
        }
    }

    func testMultiOutputGoesIntoFolder() async throws {
        let engine = ScriptedEngine(e) { request, _ in
            let pages = (1...3).map { request.outputDirectory.appendingPathComponent("\(request.baseName)-\($0).png") }
            for p in pages { try Data().write(to: p) }
            return ConversionOutput(pages)
        }
        let input = try makeFiles(["deck.pdf"])[0]
        let job = ConversionJob(inputs: [input], route: Route([Capability("pdf", "png", e, flags: .multiOutput)]),
                                registry: EngineRegistry([engine]))
        let out = try await run(job)
        XCTAssertEqual(out.map(\.lastPathComponent), ["deck (PNG)"])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: out[0].path).count, 3)
    }

    func testCombineNamesSeveralItemsArchive() async throws {
        let files = try makeFiles(["Photos/", "Docs/", "notes.txt"])
        let route = directRoute("folder", "zip", e, arity: .combine)
        let job = ConversionJob(inputs: files, route: route, registry: registry)
        XCTAssertTrue(job.isCombine)
        XCTAssertEqual(job.title, "3 items → ZIP")
        XCTAssertEqual(job.activityTitle, "Compressing to ZIP")
        XCTAssertEqual(job.resourceClass, .io)
        let out = try await run(job)
        XCTAssertEqual(out.map(\.lastPathComponent), ["Archive.zip"])
        XCTAssertEqual(contents(out[0]), "Photos\nDocs\nnotes.txt", "one engine call with every item")

        let single = ConversionJob(inputs: [files[0]], route: route, registry: registry)
        let out2 = try await run(single)
        XCTAssertEqual(out2.map(\.lastPathComponent), ["Photos.zip"])
    }

    func testResourceClass() {
        let video = OptionsSchema("video", [OptionSpec(OptionKey.hardware, "HW", .toggle, default: .bool(true))])
        func cls(_ from: FormatID, _ to: FormatID, _ engine: EngineID, _ options: OptionValues = OptionValues()) -> ResourceClass {
            ConversionJob(inputs: [URL(fileURLWithPath: "/x/in.\(from)")], route: directRoute(from, to, engine, schema: video),
                          options: options, registry: registry).resourceClass
        }
        XCTAssertEqual(cls("mov", "mp4", EngineIDs.ffmpeg), .videoToolbox)
        XCTAssertEqual(cls("mkv", "mov", EngineIDs.avFoundation), .videoToolbox)
        XCTAssertEqual(cls("mov", "mp4", EngineIDs.ffmpeg, OptionValues([OptionKey.hardware: .bool(false)])), .cpu)
        XCTAssertEqual(cls("mov", "mp4", EngineIDs.ffmpeg, OptionValues([OptionKey.videoCodec: .string("av1")])), .cpu)
        XCTAssertEqual(cls("mov", "webm", EngineIDs.ffmpeg), .cpu, "no VP9/AV1 hardware encoder")
        XCTAssertEqual(cls("mov", "mp3", EngineIDs.ffmpeg), .cpu, "audio extract is CPU")
        XCTAssertEqual(cls("heic", "jpg", EngineIDs.imageIO), .cpu)
        XCTAssertEqual(cls("zip", "folder", EngineIDs.archiveTool), .io)
        XCTAssertEqual(ConversionJob(inputs: [], route: nil, target: "jpg").resourceClass, .cpu)
    }

    func testRunTwiceResetsProgress() async throws {
        let input = try makeFiles(["a.png"])[0]
        let job = ConversionJob(inputs: [input], route: directRoute("png", "jpg", e), registry: registry)
        _ = try await run(job)
        XCTAssertEqual(job.progress.fractionCompleted, 1)
        _ = try await run(job)
        XCTAssertEqual(job.progress.fractionCompleted, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: input.deletingLastPathComponent().path).sorted(),
                       ["a 2.jpg", "a.jpg", "a.png"])
    }

    func testScratchPurgeIsAgeGated() throws {
        let fresh = try scratch.makeDirectory(for: UUID())
        let stale = try scratch.makeDirectory(for: UUID())
        try FileManager.default.setAttributes([.modificationDate: Date(timeIntervalSinceNow: -86_400)], ofItemAtPath: stale.path)
        scratch.purgeStale()
        XCTAssertTrue(FileManager.default.fileExists(atPath: fresh.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        scratch.remove(root) // outside the scratch root: refused
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
    }
}
