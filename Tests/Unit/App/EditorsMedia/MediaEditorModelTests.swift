import AppKit
import XCTest
@testable import HaloApp
import HaloCore

/// Editor models turn user edits into the options the runners expect.
@MainActor
final class MediaEditorModelTests: XCTestCase {
    private func spec(_ id: ToolID) throws -> ToolSpec { try XCTUnwrap(ToolCatalog.spec(id)) }

    func testTrimVideoOptions() async throws {
        let clip = try await EditorSamples.url("Intro.mp4")
        let m = TrimVideoModel(tool: try spec(ToolIDs.trimVideo), inputs: [clip], options: try spec(ToolIDs.trimVideo).defaultOptions)
        m.start()
        await m.settle()
        XCTAssertEqual(m.range.upperBound, 4, accuracy: 0.05, "starts as the whole clip")
        XCTAssertFalse(m.canSave, "nothing to save until the range changes")
        m.session.player.seek(to: 1.0)
        m.setIn()
        m.session.player.seek(to: 2.5)
        m.setOut()
        XCTAssertEqual(m.range.lowerBound, 1.0, accuracy: 0.001)
        XCTAssertEqual(m.range.upperBound, 2.5 + 1.0 / 30, accuracy: 0.001, "out includes the frame under the playhead")
        m.lossless = false
        XCTAssertTrue(m.canSave)
        XCTAssertEqual(m.options.string("range", default: ""), "1-2.533")
        XCTAssertFalse(m.options.bool(OptionKey.lossless, default: true))
        XCTAssertFalse(m.plan.isLossless)
        m.lossless = true
        XCTAssertTrue(m.plan.isLossless, "Intro.mp4 has a keyframe every second")
        XCTAssertTrue(m.handle(.character("i")))
        XCTAssertFalse(m.handle(.character("q")))
        m.teardown()
    }

    func testFormatsAVFoundationCantPlayGetAPreviewProxy() async throws {
        let mkv = try await EditorSamples.url("Clip.mkv")
        let tool = try spec(ToolIDs.trimVideo)
        let m = TrimVideoModel(tool: tool, inputs: [mkv], options: tool.defaultOptions)
        m.start()
        await m.settle()
        XCTAssertEqual(m.session.state, .ready)
        let proxy = try XCTUnwrap(m.session.asset?.url)
        XCTAssertNotEqual(proxy, mkv, "MKV previews through an MP4 proxy")
        XCTAssertEqual(proxy.pathExtension, "mp4")
        XCTAssertEqual(m.duration, 3, accuracy: 0.05)
        XCTAssertTrue(m.session.player.stillIsCurrent, "exact still rendered from the proxy")
        XCTAssertEqual(m.inputs, [mkv], "the editor still saves against the original")
        m.teardown()
    }

    func testCropOptionsRoundTripToExactPixels() async throws {
        let clip = try await EditorSamples.url("Intro.mp4")
        let tool = try spec(ToolIDs.cropVideo)
        let m = CropVideoModel(tool: tool, inputs: [clip], options: tool.defaultOptions)
        m.start()
        await m.settle()
        XCTAssertFalse(m.canSave, "full frame")
        m.aspect = "4:3"
        let p = m.pixels
        XCTAssertEqual(p.width * 3, p.height * 4, "exactly 4:3")
        XCTAssertEqual(p.width % 2, 0)
        XCTAssertEqual(p.height, 540, "the largest 4:3 crop of 960×540 is full height")
        XCTAssertTrue(m.canSave)
        // The runner turns the saved rect back into the same pixels.
        let rect = try XCTUnwrap(PixelCrop.parse(m.options.string("rect", default: "")))
        XCTAssertEqual(PixelCrop.make(rect, frameWidth: 960, frameHeight: 540), p)
        m.setPixelSize(width: 400)
        XCTAssertEqual(m.pixels.width, 400)
        XCTAssertEqual(m.pixels.height, 300)
        m.reset()
        XCTAssertEqual(m.rect, .full)
        XCTAssertEqual(m.options.string("aspect", default: ""), "free")
        m.teardown()
    }

    func testCropGeometryKeepsRatioAndBounds() {
        let rn = CropGeometry.normalisedRatio(1, frame: CGSize(width: 960, height: 540))
        let start = CGRectValue(x: 0.3, y: 0.2, width: 0.3, height: 0.3 / rn)
        for h in CropGeometry.Handle.allCases {
            let r = CropGeometry.resize(start, handle: h, to: CGPoint(x: 1.4, y: 1.3), ratio: rn)
            XCTAssertEqual(r.width / r.height, rn, accuracy: 1e-6, "\(h)")
            XCTAssertGreaterThanOrEqual(r.x, 0)
            XCTAssertGreaterThanOrEqual(r.y, 0)
            XCTAssertLessThanOrEqual(r.x + r.width, 1 + 1e-9, "\(h)")
            XCTAssertLessThanOrEqual(r.y + r.height, 1 + 1e-9, "\(h)")
        }
        let free = CropGeometry.resize(start, handle: .bottomRight, to: CGPoint(x: 0.9, y: 0.95), ratio: nil)
        XCTAssertEqual(free.x + free.width, 0.9, accuracy: 1e-9)
        XCTAssertEqual(free.y + free.height, 0.95, accuracy: 1e-9)
        let moved = CropGeometry.move(start, dx: 5, dy: -5)
        XCTAssertEqual(moved.x + moved.width, 1, accuracy: 1e-9)
        XCTAssertEqual(moved.y, 0)
        XCTAssertEqual(CropGeometry.maximal(rn).height, 1, accuracy: 1e-9)
    }

    func testSplitOptions() async throws {
        let clip = try await EditorSamples.url("Intro.mp4")
        let tool = try spec(ToolIDs.splitVideo)
        let m = SplitVideoModel(tool: tool, inputs: [clip], options: tool.defaultOptions)
        m.start()
        await m.settle()
        XCTAssertEqual(m.mode, "every")
        XCTAssertEqual(m.every, 1, "short clips default to about four parts")
        XCTAssertEqual(m.plan.segmentCount, 4)
        XCTAssertTrue(m.plan.lossless)
        m.session.player.seek(to: 1.5)
        m.addMarker()
        m.session.player.seek(to: 3.0)
        m.addMarker()
        XCTAssertEqual(m.mode, "at")
        XCTAssertEqual(m.options.string("at", default: ""), "1.5,3")
        XCTAssertEqual(m.options.string("mode", default: ""), "at")
        m.removeNearestMarker()
        XCTAssertEqual(m.markers, [1.5])
        XCTAssertTrue(m.canSave)
        m.teardown()
    }

    func testJoinOrderIsTheInputOrder() async throws {
        let a = try await EditorSamples.url("Intro.mp4"), b = try await EditorSamples.url("Sunset.mov")
        let tool = try spec(ToolIDs.joinVideo)
        let m = JoinVideoModel(tool: tool, inputs: [a, b], options: tool.defaultOptions)
        m.start()
        await m.settle()
        XCTAssertEqual(m.verdict?.lossless, false)
        XCTAssertEqual(m.mismatch(for: m.clips[1]), "Different size")
        m.move(from: IndexSet(integer: 1), to: 0)
        XCTAssertEqual(m.inputs, [b, a])
        XCTAssertTrue(m.canSave)
        XCTAssertEqual(m.options.string("order", default: "x"), "")
        let reordered = JoinVideoModel(tool: tool, inputs: [a, b], options: OptionValues(["order": .string("2,1")]))
        XCTAssertEqual(reordered.inputs, [b, a])
        m.teardown()
    }

    func testSnapshotOptions() async throws {
        let clip = try await EditorSamples.url("Intro.mp4")
        let tool = try spec(ToolIDs.snapshotVideo)
        let m = SnapshotVideoModel(tool: tool, inputs: [clip], options: tool.defaultOptions)
        m.start()
        await m.settle()
        XCTAssertTrue(m.canSave, "the middle frame needs no captures")
        XCTAssertEqual(m.options.string("times", default: "x"), "")
        m.add(at: 2.51)   // inside frame 75 (2.5 s at 30 fps)
        m.add(at: 1)
        m.add(at: 1.01)   // same frame: ignored
        m.format = "jpg"
        XCTAssertEqual(m.options.string("times", default: ""), "1,2.5")
        XCTAssertEqual(m.options.string("format", default: ""), "jpg")
        m.teardown()
    }

    func testTrimAudioOptions() async throws {
        let audio = try await EditorSamples.url("Interview.m4a")
        let tool = try spec(ToolIDs.trimAudio)
        let m = TrimAudioModel(tool: tool, inputs: [audio], options: OptionValues(["range": .string("1.25-3.5")]))
        m.start()
        await m.settle()
        XCTAssertEqual(m.range, 1.25...3.5)
        XCTAssertTrue(m.copyPossible, "AAC in M4A copies losslessly")
        XCTAssertTrue(m.canSave)
        m.player.seek(to: 2)
        m.setOut()
        XCTAssertEqual(m.options.string("range", default: ""), "1.25-2")
        XCTAssertNotNil(m.audio.wave.envelope)
        m.teardown()
    }

    func testBleepOptionsMergeOverlaps() async throws {
        let audio = try await EditorSamples.url("Interview.m4a")
        let tool = try spec(ToolIDs.bleepAudio)
        let m = BleepAudioModel(tool: tool, inputs: [audio], options: tool.defaultOptions)
        m.start()
        await m.settle()
        XCTAssertFalse(m.canSave)
        m.ranges = [MarkedRange(4...5), MarkedRange(1...2), MarkedRange(1.5...2.5)]
        m.style = "silence"
        XCTAssertEqual(m.options.string("ranges", default: ""), "1-2.5;4-5")
        XCTAssertEqual(m.options.string("style", default: ""), "silence")
        XCTAssertEqual(m.total, 2.5, accuracy: 1e-9)
        m.selected = m.ranges[0].id
        XCTAssertTrue(m.handle(.delete))
        XCTAssertEqual(m.ranges.count, 2)
        m.player.seek(to: 8)
        m.addAtPlayhead()
        XCTAssertEqual(m.ranges.last?.range.lowerBound ?? 0, 7.9, accuracy: 0.01)
        m.teardown()
    }

    func testOrganizePDFOptions() async throws {
        let a = try await EditorSamples.url("Report.pdf"), b = try await EditorSamples.url("Appendix.pdf")
        let tool = try spec(ToolIDs.organizePDF)
        let single = OrganizePDFModel(tool: tool, inputs: [a], options: tool.defaultOptions)
        XCTAssertEqual(single.pages.count, 5)
        XCTAssertFalse(single.canSave, "one untouched PDF: nothing to do")
        single.split = true
        XCTAssertTrue(single.canSave)
        XCTAssertEqual(single.options.string("order", default: "x"), "", "unchanged order stays implicit")

        let m = OrganizePDFModel(tool: tool, inputs: [a, b], options: tool.defaultOptions)
        XCTAssertTrue(m.canSave, "merging two files")
        m.selection = [m.pages[1].id]
        m.rotate(90)
        m.selection = [m.pages[0].id]
        m.delete()
        m.movePage(m.pages[m.pages.count - 1], by: -10)
        XCTAssertEqual(m.pages.count, 7)
        let refs = try XCTUnwrap(PDFPageRef.parse(m.options.string("order", default: ""), pageCounts: [5, 3]))
        XCTAssertEqual(refs.first, PDFPageRef(input: 1, page: 2), "Appendix page 3 moved to the front")
        XCTAssertEqual(refs[1], PDFPageRef(input: 0, page: 1, rotation: 90))
        m.selectAll()
        m.delete()
        XCTAssertEqual(m.pages.count, 7, "never deletes every page")
        m.reset()
        XCTAssertFalse(m.isChanged)
        let restored = OrganizePDFModel(tool: tool, inputs: [a, b], options: OptionValues(["order": .string("2:1:180,1:2")]))
        XCTAssertEqual(restored.pages.map(\.ref), [PDFPageRef(input: 1, page: 0, rotation: 180), PDFPageRef(input: 0, page: 1)])
    }
}
