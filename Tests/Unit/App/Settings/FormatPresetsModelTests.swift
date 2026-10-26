import XCTest
import AnyfmtCore
@testable import AnyfmtApp

@MainActor
final class FormatPresetsModelTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("pane-presets-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func model(_ format: FormatID = Formats.gif) throws -> FormatPresetsModel {
        let schema = try XCTUnwrap(OptionsSchema.forTarget(format))
        return FormatPresetsModel(format: format, schema: schema, store: PresetStore(fileURL: dir.appendingPathComponent("presets.json")))
    }

    func testSaveRenameMoveDeleteAndRestore() throws {
        let m = try model()
        XCTAssertEqual(m.presets.map(\.id), ["builtin.gif.small", "builtin.gif.smooth"])
        XCTAssertFalse(m.hasHiddenBuiltIns)
        XCTAssertFalse(m.canMove("builtin.gif.small", by: 1), "built-ins don't move")

        let defaults = m.schema.defaults.merging(OptionValues([OptionKey.fps: .string("24")]))
        let a = m.saveAsPreset(defaults)
        let b = m.saveAsPreset(defaults)
        XCTAssertEqual([a.title, b.title], ["Preset 1", "Preset 2"])
        XCTAssertEqual(a.values[OptionKey.fps], .string("24"))
        XCTAssertEqual(a.values[OptionKey.gifWidth], .string("640"), "saves the defaults as shown, not just the changes")
        XCTAssertEqual(m.presets.map(\.id).prefix(2), [a.id, b.id])

        XCTAssertFalse(m.canMove(a.id, by: -1))
        XCTAssertTrue(m.canMove(a.id, by: 1))
        XCTAssertFalse(m.canMove(b.id, by: 1), "last user preset stays above the built-ins")
        m.move(b.id, by: -1)
        XCTAssertEqual(m.presets.map(\.id).prefix(2), [b.id, a.id])

        m.rename(a.id, to: "Loop")
        XCTAssertEqual(m.presets.first { $0.id == a.id }?.title, "Loop")
        XCTAssertEqual(m.saveAsPreset(defaults).title, "Preset 3")

        m.delete("builtin.gif.small")
        XCTAssertTrue(m.hasHiddenBuiltIns)
        XCTAssertFalse(m.presets.contains { $0.id == "builtin.gif.small" })
        m.restoreBuiltIns()
        XCTAssertFalse(m.hasHiddenBuiltIns)
        XCTAssertEqual(m.presets.suffix(2).map(\.id), ["builtin.gif.small", "builtin.gif.smooth"])
        m.delete(a.id)
        XCTAssertFalse(m.presets.contains { $0.id == a.id })
    }

    func testSummaryUsesChoiceLabelsInSchemaOrder() throws {
        let m = try model()
        let small = try XCTUnwrap(m.presets.first)
        XCTAssertEqual(m.summary(of: small), "480 px · 10 fps")
        let flat = ConversionPreset(id: "x", format: Formats.gif, title: "x",
                                    values: OptionValues([OptionKey.gifDither: .bool(false), OptionKey.gifLoop: .string("once")]), isBuiltIn: false)
        XCTAssertEqual(m.summary(of: flat), "Play once · Dither off")
        let jpg = try model(Formats.jpg)
        XCTAssertEqual(jpg.summary(of: try XCTUnwrap(jpg.presets.first)), "Quality 80 %")
    }

    func testDefaultsSchemaUsesTheSharedTargetHelper() throws {
        let sample = try SampleState()
        defer { sample.tearDown() }
        let model = sample.model
        guard !model.router.table.rows.isEmpty else { return }
        XCTAssertEqual(model.defaultsSchema(for: Formats.gif), OptionsSchema.forTarget(Formats.gif, table: model.router.table))
        XCTAssertNotNil(model.defaultsSchema(for: Formats.gif).spec(OptionKey.gifColors))
    }
}
