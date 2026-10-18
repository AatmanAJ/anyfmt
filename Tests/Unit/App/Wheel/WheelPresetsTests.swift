import AppKit
import HaloCore
@testable import RadialMenu
import XCTest
@testable import HaloApp

/// Presets on the wheel, configure-after-drop, and the pinned options panel (D-038).
@MainActor
final class WheelPresetsTests: XCTestCase {
    private var controller: WheelController!
    private var store: PresetStore!
    private var selections: [WheelSelection] = []
    private var tuned: [FormatID] = []
    private let mov = URL(fileURLWithPath: "/tmp/halo-wheel-tests/clip.mov")

    override func setUp() async throws {
        let rows = [Capability("mov", "gif", "test", schema: StandardSchemas.gif),
                    Capability("mov", "mp4", "test", schema: StandardSchemas.video),
                    Capability("mov", "webm", "test")]
        controller = WheelController(provider: WheelContentProvider(router: Router(table: CapabilityTable(rows))))
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("halo-presets-\(UUID().uuidString).json")
        store = PresetStore(fileURL: file)
        controller.presetStore = store
        selections = []
        tuned = []
        controller.onSelect = { [weak self] s, _, _, _ in self?.selections.append(s) }
        controller.onTune = { [weak self] target, _, _, _ in self?.tuned.append(target.format) }
        controller.show(kind: .convert, urls: [mov], at: CGPoint(x: 500, y: 500))
    }

    override func tearDown() async throws {
        controller.hide(animated: false)
        controller = nil
    }

    private func item(_ format: String) throws -> RadialItem {
        try XCTUnwrap(controller.menuView.items.first { $0.id == "convert.\(format)" })
    }

    func testChipsComeFromThePresetStore() throws {
        let gif = try item("gif")
        let chips = controller.radialMenu(controller.menuView, presetsFor: gif)
        XCTAssertEqual(chips.map(\.title), store.presets(for: "gif").prefix(2).map(\.title), "two built-ins")
        XCTAssertTrue(controller.radialMenu(controller.menuView, presetsFor: try item("webm")).isEmpty, "no options, no chips")
        store.recordLastUsed(OptionValues([OptionKey.fps: .int(15)]), for: "gif")
        XCTAssertEqual(controller.radialMenu(controller.menuView, presetsFor: gif).last?.id, WheelController.lastUsedPresetID)
    }

    func testPresetDropRunsWithItsValuesAndBecomesLastUsed() throws {
        let gif = try item("gif")
        let preset = try XCTUnwrap(store.presets(for: "gif").first)
        XCTAssertTrue(controller.radialMenu(controller.menuView, didDrop: FakeDragInfo(), on: gif,
                                            target: .preset(item: gif.id, preset: preset.id)))
        guard case .convert(let target, let options)? = selections.first else { return XCTFail("no conversion") }
        XCTAssertEqual(target.format, "gif")
        XCTAssertEqual(options, preset.values)
        XCTAssertEqual(store.lastUsed(for: "gif"), PresetStore.validated(preset.values, against: StandardSchemas.gif))
    }

    func testTuneDropOpensTheHostPanelInsteadOfConverting() throws {
        let gif = try item("gif")
        XCTAssertTrue(controller.radialMenu(controller.menuView, didDrop: FakeDragInfo(), on: gif, target: .tune(gif.id)))
        XCTAssertEqual(tuned, ["gif"])
        XCTAssertTrue(selections.isEmpty, "nothing runs until Convert")
        XCTAssertNil(controller.kind, "the wheel's session ended")
    }

    func testMidDragHoverNeverOpensThePopover() {
        XCTAssertEqual(WheelTheme.configuration.optionsDwell, 0)
        XCTAssertGreaterThan(WheelTheme.configuration.presetBand, 0)
    }

    func testPanelModelPresetsAndSaving() throws {
        let target = try gifTarget()
        let model = OptionsPanelModel(target: target, values: OptionValues(), input: nil, presetStore: store)
        XCTAssertEqual(model.title, Formats.label("gif"))
        XCTAssertFalse(model.schema.specs.contains { $0.id == OptionKey.cloud })
        let builtIn = try XCTUnwrap(model.presets.first)
        model.apply(builtIn)
        XCTAssertEqual(model.values, PresetStore.validated(builtIn.values, against: model.schema))
        model.saveAsPreset()
        XCTAssertEqual(store.allUserPresets().count, 1)
        XCTAssertEqual(store.allUserPresets().first?.values, model.values)
        XCTAssertNotNil(model.savedPresetTitle)
    }

    private func gifTarget() throws -> RouteTarget {
        let router = Router(table: CapabilityTable([Capability("mov", "gif", "test", schema: StandardSchemas.gif)]))
        return try XCTUnwrap(router.commonTargets(for: ["mov"]).first { $0.format == "gif" })
    }

    func testPanelEstimatesDebounceAndUseTheEstimator() async throws {
        let target = try gifTarget()
        let model = OptionsPanelModel(target: target, values: OptionValues(), input: mov, presetStore: store)
        let calls = Counter()
        model.estimator = { (_: URL, _: FormatID, values: OptionValues) async -> OptionsPanelController.Estimate? in
            await calls.bump()
            return OptionsPanelController.Estimate(bytes: Int64(values.int(OptionKey.fps, default: 10) * 1000), frames: 48)
        }
        model.values[OptionKey.fps] = OptionValue.int(10)
        model.values[OptionKey.fps] = OptionValue.int(24)
        try await Task.sleep(nanoseconds: 600_000_000)
        let n = await calls.value
        XCTAssertEqual(n, 1, "rapid changes collapse into one estimate")
        XCTAssertEqual(model.estimate?.bytes, 24_000)
        XCTAssertEqual(model.estimate?.frames, 48)
    }

    func testPanelStaysOnTheDropScreen() {
        let size = CGSize(width: 520, height: 600)
        let origin = OptionsPanelController.origin(for: size, near: CGPoint(x: -5000, y: -5000), screens: [])
        XCTAssertFalse(origin.x.isNaN)
        if let screen = NSScreen.main {
            let o = OptionsPanelController.origin(for: size, near: CGPoint(x: screen.frame.maxX - 2, y: screen.frame.maxY - 2))
            XCTAssertLessThanOrEqual(o.x + size.width, screen.visibleFrame.maxX)
            XCTAssertLessThanOrEqual(o.y + size.height, screen.visibleFrame.maxY)
        }
    }

    func testPresetSummaryNames() {
        let name = PresetNaming.summary(OptionValues([OptionKey.gifWidth: .int(480), OptionKey.fps: .int(10)]), schema: StandardSchemas.gif)
        XCTAssertNotNil(name)
        XCTAssertTrue(name?.contains("480") == true)
    }
}

private actor Counter {
    var value = 0
    func bump() { value += 1 }
}

/// A drag with nothing on its pasteboard: the controller falls back to the wheel's own files.
@MainActor
final class FakeDragInfo: NSObject, @preconcurrency NSDraggingInfo {
    var draggingLocation: NSPoint = .zero
    var draggingDestinationWindow: NSWindow? { nil }
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggedImageLocation: NSPoint { .zero }
    var draggedImage: NSImage? { nil }
    var draggingPasteboard: NSPasteboard { NSPasteboard(name: NSPasteboard.Name("HaloAppTests.drag.\(ObjectIdentifier(self).hashValue)")) }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    func slideDraggedImage(to screenPoint: NSPoint) {}
    var draggingFormation: NSDraggingFormation = .default
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    func enumerateDraggingItems(options enumOpts: NSDraggingItemEnumerationOptions = [], for view: NSView?,
                                classes classArray: [AnyClass], searchOptions: [NSPasteboard.ReadingOptionKey: Any] = [:],
                                using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void) {}
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }
    func resetSpringLoading() {}
}
