import XCTest
@testable import AnyfmtCore

final class PresetStoreTests: XCTestCase {
    private var dir: URL!
    private var file: URL { dir.appendingPathComponent("presets.json") }

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("presets-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func titles(_ s: PresetStore, _ f: FormatID) -> [String] { s.presets(for: f).map(\.title) }

    // MARK: Built-ins

    func testEveryBuiltInValidatesUnchangedAgainstItsSchema() throws {
        XCTAssertFalse(PresetStore.allBuiltIns.isEmpty)
        XCTAssertEqual(Set(PresetStore.allBuiltIns.map(\.id)).count, PresetStore.allBuiltIns.count, "unique ids")
        for p in PresetStore.allBuiltIns {
            XCTAssertTrue(p.isBuiltIn)
            XCTAssertTrue(p.id.hasPrefix("builtin.\(p.format.rawValue)."), p.id)
            XCTAssertFalse(p.values.values.isEmpty, p.id)
            let schema = try XCTUnwrap(OptionsSchema.forTarget(p.format), "\(p.format) has no schema")
            XCTAssertEqual(PresetStore.validated(p.values, against: schema), p.values, p.id)
        }
        for f in [Formats.gif, Formats.mp4, Formats.mov, Formats.webm, Formats.jpg, Formats.webp, Formats.heic,
                  Formats.avif, Formats.mp3, Formats.m4a, Formats.png] {
            XCTAssertEqual(PresetStore.builtIns(for: f).count, 2, "\(f)")
        }
        XCTAssertEqual(PresetStore.builtIns(for: Formats.gif).map(\.id), ["builtin.gif.small", "builtin.gif.smooth"])
    }

    func testForTargetMergesRowsAndDropsPerJobOptions() throws {
        let gif = try XCTUnwrap(OptionsSchema.forTarget(Formats.gif))
        XCTAssertEqual(gif.specs.first?.id, OptionKey.gifWidth, "the GIF schema wins the tie with image → GIF")
        for k in [OptionKey.gifWidth, OptionKey.fps, OptionKey.gifLoop, OptionKey.gifColors, OptionKey.gifDither, OptionKey.maxDimension] {
            XCTAssertNotNil(gif.spec(k), k)
        }
        let png = try XCTUnwrap(OptionsSchema.forTarget(Formats.png))
        XCTAssertEqual(png.specs.first?.id, OptionKey.maxDimension)
        XCTAssertNotNil(png.spec(OptionKey.dpi), "PDF → PNG resolution")
        XCTAssertNil(png.spec(OptionKey.quality), "PNG has no quality")
        XCTAssertNil(png.spec(OptionKey.pages), "page ranges are per job")
        let mp4 = try XCTUnwrap(OptionsSchema.forTarget(Formats.mp4))
        XCTAssertNil(mp4.spec(OptionKey.cloud))
        XCTAssertNotNil(mp4.spec(OptionKey.videoQuality))
        XCTAssertEqual(OptionsSchema.forTarget(Formats.jpg)?.specs.first?.id, OptionKey.quality)
        XCTAssertNil(OptionsSchema.forTarget(Formats.gif, table: CapabilityTable([])))
        // Every schema the table can produce has unique keys.
        for f in Set(CapabilityTable.default.rows.map(\.to)) {
            let s = try XCTUnwrap(OptionsSchema.forTarget(f))
            XCTAssertEqual(Set(s.specs.map(\.id)).count, s.specs.count, "\(f)")
        }
    }

    // MARK: Editing

    func testAddRenameDeleteAndHiddenBuiltIns() {
        let s = PresetStore(fileURL: file)
        XCTAssertEqual(titles(s, Formats.gif), ["Small · 10 fps · 480 w", "Smooth · 24 fps · 720 w"])
        let mine = s.add("  Tiny  ", format: Formats.gif, values: OptionValues([OptionKey.gifWidth: .string("320")]))
        XCTAssertFalse(mine.isBuiltIn)
        XCTAssertNotNil(UUID(uuidString: mine.id))
        XCTAssertEqual(mine.title, "Tiny", "trimmed")
        XCTAssertEqual(titles(s, Formats.gif), ["Tiny", "Small · 10 fps · 480 w", "Smooth · 24 fps · 720 w"], "user presets first")
        XCTAssertTrue(s.presets(for: Formats.jpg).allSatisfy(\.isBuiltIn), "per format")

        s.rename(mine.id, to: "Tiny GIF")
        XCTAssertEqual(s.presets(for: Formats.gif).first?.title, "Tiny GIF")
        s.rename("builtin.gif.small", to: "Mine now")
        XCTAssertEqual(PresetStore.builtIns(for: Formats.gif).first?.title, "Small · 10 fps · 480 w", "built-ins keep their title")

        s.delete("builtin.gif.small")
        XCTAssertEqual(titles(s, Formats.gif), ["Tiny GIF", "Smooth · 24 fps · 720 w"])
        XCTAssertEqual(s.hiddenBuiltIns(for: Formats.gif).map(\.id), ["builtin.gif.small"])
        s.delete(mine.id)
        XCTAssertEqual(titles(s, Formats.gif), ["Smooth · 24 fps · 720 w"])
        XCTAssertTrue(s.allUserPresets().isEmpty)

        s.delete("builtin.jpg.web")
        s.restoreBuiltIns(for: Formats.gif)
        XCTAssertEqual(s.presets(for: Formats.gif).count, 2)
        XCTAssertEqual(s.presets(for: Formats.jpg).map(\.id), ["builtin.jpg.best"], "restore is per format")
    }

    func testMoveReordersWithinItsFormat() {
        let s = PresetStore(fileURL: file)
        let a = s.add("A", format: Formats.gif, values: OptionValues())
        let x = s.add("X", format: Formats.jpg, values: OptionValues())
        let b = s.add("B", format: Formats.gif, values: OptionValues())
        let c = s.add("C", format: Formats.gif, values: OptionValues())
        s.move(c.id, by: -1)
        XCTAssertEqual(s.presets(for: Formats.gif).prefix(3).map(\.title), ["A", "C", "B"])
        s.move(a.id, by: 5)
        XCTAssertEqual(s.presets(for: Formats.gif).prefix(3).map(\.title), ["C", "B", "A"], "clamped to the end")
        s.move(c.id, by: -3)
        XCTAssertEqual(s.presets(for: Formats.gif).prefix(3).map(\.title), ["C", "B", "A"], "clamped at the top")
        XCTAssertEqual(s.presets(for: Formats.jpg).first?.id, x.id, "other formats untouched")
        s.move("builtin.gif.small", by: -1)
        XCTAssertEqual(s.presets(for: Formats.gif).map(\.title).suffix(2), ["Small · 10 fps · 480 w", "Smooth · 24 fps · 720 w"])
        _ = b
    }

    func testOnChangeFiresOnRealChangesOnly() {
        let s = PresetStore(fileURL: file)
        let count = Counter()
        s.onChange = { count.bump() }
        let p = s.add("A", format: Formats.gif, values: OptionValues())
        s.rename(p.id, to: "A")          // same title
        s.move(p.id, by: 1)              // only one
        s.delete("builtin.unknown.x")    // not a preset
        XCTAssertEqual(count.value, 1)
        s.recordLastUsed(OptionValues([OptionKey.fps: .string("10")]), for: Formats.gif)
        s.recordLastUsed(OptionValues([OptionKey.fps: .string("10")]), for: Formats.gif)
        XCTAssertEqual(count.value, 2)
    }

    // MARK: Validation

    func testValidationDropsUnknownAndWrongTypesAndClamps() {
        let schema = OptionsSchema("t", [
            OptionSpec("q", "Q", .slider(min: 1, max: 100, step: 1, unit: nil), default: .int(50)),
            OptionSpec("n", "N", .integer(min: 0, max: 10, unit: nil), default: .int(0)),
            OptionSpec("d", "D", .decimal(min: 0, max: 1, step: 0.1), default: .double(0.5)),
            OptionSpec("b", "B", .toggle, default: .bool(false)),
            OptionSpec("c", "C", .choice([OptionChoice("72", "72"), OptionChoice("300", "300")]), default: .string("300")),
            OptionSpec("s", "S", .fileSize, default: .int(0)),
            OptionSpec("t", "T", .text, default: .string("")),
        ])
        let v = PresetStore.validated(OptionValues([
            "q": .int(500), "n": .double(-3), "d": .int(4), "b": .string("true"), "c": .int(72),
            "s": .int(-1), "t": .string("hi"), "zzz": .int(1),
        ]), against: schema)
        XCTAssertEqual(v.values, ["q": .int(100), "n": .int(0), "d": .double(1), "c": .string("72"), "s": .int(0), "t": .string("hi")])
        let bad = PresetStore.validated(OptionValues(["c": .string("150"), "q": .string("80"), "b": .bool(true), "t": .int(3)]), against: schema)
        XCTAssertEqual(bad.values, ["b": .bool(true)])
    }

    func testAddValidatesAgainstTheFormat() {
        let s = PresetStore(fileURL: file)
        let p = s.add("x", format: Formats.jpg, values: OptionValues([OptionKey.quality: .int(150), OptionKey.gifWidth: .string("480")]))
        XCTAssertEqual(p.values.values, [OptionKey.quality: .int(100)])
    }

    // MARK: Last used, persistence, sync

    func testLastUsed() {
        let s = PresetStore(fileURL: file)
        XCTAssertNil(s.lastUsed(for: Formats.gif))
        s.recordLastUsed(OptionValues([OptionKey.fps: .string("24"), "bogus": .int(1)]), for: Formats.gif)
        XCTAssertEqual(s.lastUsed(for: Formats.gif)?.values, [OptionKey.fps: .string("24")])
        XCTAssertNil(s.lastUsed(for: Formats.jpg))
        XCTAssertEqual(PresetStore(fileURL: file).lastUsed(for: Formats.gif)?.values, [OptionKey.fps: .string("24")], "persisted")
    }

    func testPersistenceRoundTrip() {
        let s = PresetStore(fileURL: file)
        let a = s.add("A", format: Formats.gif, values: OptionValues([OptionKey.fps: .string("24")]))
        let b = s.add("B", format: Formats.gif, values: OptionValues())
        s.move(b.id, by: -1)
        s.delete("builtin.gif.smooth")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        let reloaded = PresetStore(fileURL: file)
        XCTAssertEqual(reloaded.presets(for: Formats.gif).map(\.id), [b.id, a.id, "builtin.gif.small"])
        XCTAssertEqual(reloaded.allUserPresets(), s.allUserPresets())
        XCTAssertEqual(reloaded.allUserPresets().last?.values.values, [OptionKey.fps: .string("24")])
    }

    func testCorruptFileIsMovedAsideAndStartsEmpty() throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: file)
        let s = PresetStore(fileURL: file)
        XCTAssertEqual(s.presets(for: Formats.gif).count, 2, "built-ins still there")
        XCTAssertTrue(s.allUserPresets().isEmpty)
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("presets.corrupt-") }, "\(names)")
        s.add("A", format: Formats.gif, values: OptionValues())
        XCTAssertEqual(PresetStore(fileURL: file).allUserPresets().map(\.title), ["A"], "writes a fresh file")
    }

    func testSyncDocumentRoundTrip() throws {
        let s = PresetStore(fileURL: file)
        XCTAssertNil(s.syncDocument(), "nothing user-made")
        let a = s.add("A", format: Formats.mp4, values: OptionValues([OptionKey.resolution: .string("720")]))
        s.delete("builtin.mp3.voice")
        s.recordLastUsed(OptionValues([OptionKey.quality: .int(70)]), for: Formats.jpg)
        let doc = try XCTUnwrap(s.syncDocument())

        let other = PresetStore(fileURL: dir.appendingPathComponent("other.json"))
        other.add("Old", format: Formats.gif, values: OptionValues())
        let fired = Counter()
        other.onChange = { fired.bump() }
        try other.applySyncDocument(doc)
        XCTAssertEqual(fired.value, 1)
        XCTAssertEqual(other.allUserPresets(), [a], "replaces local data")
        XCTAssertEqual(other.presets(for: Formats.mp3).map(\.id), ["builtin.mp3.music"])
        XCTAssertEqual(other.lastUsed(for: Formats.jpg)?.values, [OptionKey.quality: .int(70)])
        XCTAssertEqual(other.syncDocument(), doc)
        try other.applySyncDocument(doc)
        XCTAssertEqual(fired.value, 1, "same document: no change")

        XCTAssertThrowsError(try other.applySyncDocument(Data("[1,2]".utf8)))
        XCTAssertEqual(other.allUserPresets(), [a], "a bad document changes nothing")
    }

    func testSyncDocumentIsSanitised() throws {
        let json = """
        {"version":1,"user":[
          {"id":"u1","format":"jpg","title":"ok","values":{"values":{"quality":{"int":{"_0":400}}}},"isBuiltIn":true},
          {"id":"u1","format":"jpg","title":"dup","values":{"values":{}},"isBuiltIn":false},
          {"id":"builtin.jpg.web","format":"jpg","title":"fake","values":{"values":{}},"isBuiltIn":true}
        ],"hidden":["builtin.gif.small","nope"],"future":"ignored"}
        """
        let s = PresetStore(fileURL: file)
        try s.applySyncDocument(Data(json.utf8))
        let user = s.allUserPresets()
        XCTAssertEqual(user.map(\.title), ["ok"])
        XCTAssertEqual(user.first?.isBuiltIn, false)
        XCTAssertEqual(user.first?.values.values, [OptionKey.quality: .int(100)])
        XCTAssertEqual(s.hiddenBuiltIns(for: Formats.gif).map(\.id), ["builtin.gif.small"])
    }

    /// The app and the CLI share presets.json: one process's edit must show up in the other.
    func testAnotherProcessesEditIsPickedUp() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("anyfmt-presets-shared-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let app = PresetStore(fileURL: url)
        let cli = PresetStore(fileURL: url)
        XCTAssertTrue(app.allUserPresets().isEmpty)
        cli.add("From the CLI", format: "gif", values: OptionValues([OptionKey.fps: .int(15)]))
        XCTAssertEqual(app.allUserPresets().map(\.title), ["From the CLI"], "seen without relaunching")
        app.add("From the app", format: "gif", values: OptionValues())
        XCTAssertEqual(Set(cli.allUserPresets().map(\.title)), ["From the CLI", "From the app"], "neither overwrote the other")
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var n = 0
    var value: Int { lock.withLock { n } }
    func bump() { lock.withLock { n += 1 } }

}
