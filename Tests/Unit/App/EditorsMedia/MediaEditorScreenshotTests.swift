import AppKit
import XCTest
@testable import HaloApp
import HaloCore

/// Renders every lane G2 editor offscreen with sample media, light and dark,
/// into docs/screens/editor-<tool>.png (with HALO_EDITOR_SCREENS set).
@MainActor
final class MediaEditorScreenshotTests: XCTestCase {
    private func spec(_ id: ToolID) throws -> ToolSpec { try XCTUnwrap(ToolCatalog.spec(id)) }

    private func shoot(_ id: ToolID, name: String, inputs: [URL], options: [String: OptionValue] = [:],
                       prepare: (@MainActor (any MediaEditorModel) async -> Void)? = nil) async throws {
        let tool = try spec(id)
        let opts = tool.defaultOptions.merging(OptionValues(options))
        for dark in [false, true] {
            let editor = try XCTUnwrap(MediaEditors.makeEditor(tool, inputs: inputs, options: opts, onSave: { _ in }, onClose: {}))
            editor.start()
            await editor.model.settle()
            if let prepare { await prepare(editor.model); await editor.model.settle() }
            let model = editor.model
            let image = await EditorRender.image(editor.view, dark: dark, settle: { await model.settle() })
            let rep = try XCTUnwrap(image)
            let url = try EditorRender.save(rep, name: dark ? "editor-\(name)-dark" : "editor-\(name)")
            XCTAssertGreaterThan(rep.pixelsWide, 900, url.path)
            editor.teardown()
        }
    }

    func testCropVideoScreenshot() async throws {
        let clip = try await MediaEditorSamples.url("Beach day.mp4")
        try await shoot(ToolIDs.cropVideo, name: "crop-video", inputs: [clip]) { model in
            guard let m = model as? CropVideoModel else { return }
            m.aspect = "4:3"
            m.rect = VideoCropGeometry.fit(m.lockedRatio ?? 1, around: CGRectValue(x: 0.3, y: 0.08, width: 0.5, height: 0.8))
            m.session.player.seek(to: 5.2)
        }
    }

    func testSplitVideoScreenshot() async throws {
        let clip = try await MediaEditorSamples.url("Beach day.mp4")
        try await shoot(ToolIDs.splitVideo, name: "split", inputs: [clip], options: ["mode": .string("at"), "at": .string("3,6.5,9.2")]) { model in
            (model as? SplitVideoModel)?.session.player.seek(to: 6.5)
        }
    }

    func testJoinVideoScreenshot() async throws {
        let a = try await MediaEditorSamples.url("Beach day.mp4"), b = try await MediaEditorSamples.url("Sunset.mov"), c = try await MediaEditorSamples.url("Intro.mp4")
        try await shoot(ToolIDs.joinVideo, name: "join", inputs: [a, b, c])
    }

    func testSnapshotScreenshot() async throws {
        let clip = try await MediaEditorSamples.url("Beach day.mp4")
        try await shoot(ToolIDs.snapshotVideo, name: "snapshot", inputs: [clip], options: ["times": .string("2,5.5,9")]) { model in
            (model as? SnapshotVideoModel)?.session.player.seek(to: 5.5)
        }
    }

    func testTrimAudioScreenshot() async throws {
        let audio = try await MediaEditorSamples.url("Interview.m4a")
        try await shoot(ToolIDs.trimAudio, name: "trim-audio", inputs: [audio], options: ["range": .string("2.4-8.3")]) { model in
            (model as? TrimAudioModel)?.player.seek(to: 4.1)
        }
    }

    func testBleepScreenshot() async throws {
        let audio = try await MediaEditorSamples.url("Interview.m4a")
        try await shoot(ToolIDs.bleepAudio, name: "bleep", inputs: [audio], options: ["ranges": .string("2.1-2.8;5-5.6;8.3-9.1")]) { model in
            guard let m = model as? BleepAudioModel else { return }
            m.selected = m.ranges.dropFirst().first?.id
            m.player.seek(to: 5.3)
        }
    }

    func testOrganizePDFScreenshot() async throws {
        let a = try await MediaEditorSamples.url("Report.pdf"), b = try await MediaEditorSamples.url("Appendix.pdf")
        try await shoot(ToolIDs.organizePDF, name: "organize-pdf", inputs: [a, b], options: ["order": .string("1:1,1:2,2:1:90,1:4,1:5,2:2,2:3")]) { model in
            guard let m = model as? OrganizePDFModel else { return }
            m.selection = Set(m.pages.dropFirst(2).prefix(1).map(\.id))
        }
    }

    func testTrimVideoScreenshot() async throws {
        let clip = try await MediaEditorSamples.url("Beach day.mp4")
        try await shoot(ToolIDs.trimVideo, name: "trim", inputs: [clip], options: ["range": .string("2.4-8.6")]) { model in
            (model as? TrimVideoModel)?.session.player.seek(to: 5.2)
        }
    }
}
