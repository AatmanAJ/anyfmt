import AppKit
import HaloCore
import RadialMenu
import XCTest
@testable import HaloApp

private struct FakeEntitlements: Entitlements {
    var isSignedIn: Bool
    var plan: Plan
    var features: Set<CloudFeature>
    func can(_ feature: CloudFeature) -> Bool { features.contains(feature) }
}

@MainActor
final class CloudSegmentsTests: XCTestCase {
    private let provider = WheelTestTable.provider

    private func entries(_ kind: WheelKind) -> [WheelEntry] {
        provider.entries(for: WheelInput(urls: [WheelTestTable.url("a.jpg")]), kind: kind, preferences: .standard)
    }

    func testProDecorationOnlyOnCloudItems() {
        let cloud = CloudSegments()
        for kind in WheelKind.allCases {
            let es = entries(kind)
            let items = WheelContentProvider.items(for: es, cloud: cloud)
            XCTAssertEqual(items.count, es.count)
            for (entry, item) in zip(es, items) {
                let isCloud: Bool
                switch entry {
                case .convert: isCloud = false
                case .tool(let t): isCloud = t.cloudFeature != nil
                case .action(let a): isCloud = a.cloudFeature != nil
                }
                XCTAssertEqual(item.badge != nil, isCloud, entry.id)
                XCTAssertEqual(item.accessory != nil, isCloud, entry.id)
                if isCloud { XCTAssertTrue(item.accessibilityHint?.contains("cloud") == true, entry.id) }
            }
        }
        let actions = WheelContentProvider.items(for: entries(.actions), cloud: cloud)
        XCTAssertEqual(actions.filter { $0.badge != nil }.map(\.id), ["action.\(ActionIDs.shareLink.rawValue)"])
    }

    func testSignedOutProTapRoutesToExplainer() {
        let cloud = CloudSegments()
        var shown: [CloudFeature] = []
        cloud.onProTapWhileSignedOut = { shown.append($0) }
        guard let upscale = entries(.tools).first(where: { $0.id == "tool.\(ToolIDs.upscale.rawValue)" }),
              let copy = entries(.actions).first(where: { $0.id == "action.copy" }),
              let png = entries(.convert).first else { return XCTFail("missing entries") }
        XCTAssertTrue(cloud.intercept(upscale))
        XCTAssertEqual(shown, [.upscale])
        XCTAssertFalse(cloud.intercept(copy), "local actions never consult entitlements")
        XCTAssertFalse(cloud.intercept(png))
        XCTAssertEqual(shown, [.upscale])
    }

    func testSignedInWithAndWithoutPlan() {
        let cloud = CloudSegments(entitlements: FakeEntitlements(isSignedIn: true, plan: .pro, features: [.upscale, .cloudJobs]))
        var noPlan: [CloudFeature] = []
        cloud.onProTapWithoutPlan = { noPlan.append($0) }
        guard let upscale = entries(.tools).first(where: { $0.id == "tool.\(ToolIDs.upscale.rawValue)" }),
              let share = entries(.actions).first(where: { $0.id == "action.\(ActionIDs.shareLink.rawValue)" })
        else { return XCTFail("missing entries") }
        XCTAssertFalse(cloud.intercept(upscale))
        XCTAssertTrue(cloud.intercept(share))
        XCTAssertEqual(noPlan, [.shareLink])
        XCTAssertTrue(cloud.allowsCloudJobs())
        let free = CloudSegments(entitlements: FakeEntitlements(isSignedIn: true, plan: .free, features: []))
        var fallback: [CloudFeature] = []
        free.onProTapWhileSignedOut = { fallback.append($0) }
        XCTAssertFalse(free.allowsCloudJobs())
        XCTAssertEqual(fallback, [.cloudJobs], "without a plan callback the explainer is used")
    }
}

@MainActor
final class WheelControllerTests: XCTestCase {
    private var controller: WheelController!
    private var selections: [(WheelSelection, [URL], CGPoint)] = []

    override func setUp() async throws {
        controller = WheelController(provider: WheelTestTable.provider)
        selections = []
        controller.onSelect = { [weak self] selection, urls, _, point in self?.selections.append((selection, urls, point)) }
    }

    override func tearDown() async throws {
        controller.hide(animated: false)
        controller = nil
    }

    private let jpg = WheelTestTable.url("photo.jpg")
    private let txt = WheelTestTable.url("notes.txt")

    func testShowSwitchAndHide() {
        controller.show(kind: .convert, urls: [jpg], at: CGPoint(x: 400, y: 400))
        XCTAssertTrue(controller.isVisible)
        XCTAssertEqual(controller.kind, .convert)
        XCTAssertEqual(controller.menuView.items.count, controller.entries.count)
        XCTAssertFalse(controller.panel.canBecomeKey, "drag mode never takes focus")
        XCTAssertEqual(controller.menuView.menuTitle, WheelKind.convert.title)
        controller.switchKind(.tools)
        XCTAssertEqual(controller.kind, .tools)
        XCTAssertTrue(controller.menuView.items.allSatisfy { $0.id.hasPrefix("tool.") })
        controller.switchKind(.actions)
        XCTAssertEqual(controller.menuView.items.count, ActionCatalog.all.count)
        controller.hide(animated: false)
        XCTAssertFalse(controller.isVisible)
        XCTAssertNil(controller.kind)
    }

    func testEmptyWheelFallsBackToActionsWithNote() {
        var kinds: [WheelKind] = []
        controller.onKindChange = { kinds.append($0) }
        controller.show(kind: .convert, urls: [txt], at: CGPoint(x: 400, y: 400))
        XCTAssertEqual(controller.kind, .actions)
        XCTAssertEqual(controller.menuView.hub.idleText, String(localized: "No conversions"))
        XCTAssertEqual(kinds, [.actions])
    }

    func testActivationDeliversSelectionWithFiles() {
        controller.show(kind: .convert, urls: [jpg], at: CGPoint(x: 400, y: 400))
        guard let first = controller.menuView.items.first else { return XCTFail("no items") }
        controller.radialMenu(controller.menuView, didActivate: first)
        XCTAssertEqual(selections.count, 1)
        guard case .convert(let target, let options)? = selections.first?.0 else { return XCTFail("not a conversion") }
        XCTAssertEqual("convert.\(target.format.rawValue)", first.id)
        XCTAssertNil(options, "no popover → host uses defaults")
        XCTAssertEqual(selections.first?.1, [jpg])
        XCTAssertNil(controller.kind, "session ended")
    }

    func testRememberedOptionsFlowIntoTheSelection() {
        controller.show(kind: .convert, urls: [jpg], at: CGPoint(x: 400, y: 400))
        guard let first = controller.menuView.items.first, case .convert(let target)? = controller.entry(for: first.id)
        else { return XCTFail("no conversion") }
        controller.rememberedOptions[target.format] = OptionValues([OptionKey.quality: .int(42)])
        controller.radialMenu(controller.menuView, didActivate: first)
        guard case .convert(_, let options)? = selections.first?.0 else { return XCTFail("not a conversion") }
        XCTAssertEqual(options?.int(OptionKey.quality, default: 0), 42)
    }

    func testProTapWhileSignedOutShowsExplainerNotJob() {
        var explained: [CloudFeature] = []
        controller.cloud.onProTapWhileSignedOut = { explained.append($0) }
        controller.show(kind: .tools, urls: [jpg], at: CGPoint(x: 400, y: 400))
        guard let upscale = controller.menuView.items.first(where: { $0.id == "tool.\(ToolIDs.upscale.rawValue)" })
        else { return XCTFail("no upscale segment") }
        controller.radialMenu(controller.menuView, didActivate: upscale)
        XCTAssertEqual(explained, [.upscale])
        XCTAssertTrue(selections.isEmpty)
    }

    func testTabCyclesWheels() {
        controller.showForSelection(urls: [jpg], at: CGPoint(x: 400, y: 400))
        XCTAssertTrue(controller.panel.canBecomeKey, "keyboard mode")
        XCTAssertEqual(controller.mode, .selection)
        XCTAssertEqual(controller.menuView.highlightedItemIndex, 0, "first target preselected for Return")
        controller.radialMenu(controller.menuView, didRequestNextMenu: true)
        XCTAssertEqual(controller.kind, .tools)
        controller.radialMenu(controller.menuView, didRequestNextMenu: false)
        XCTAssertEqual(controller.kind, .convert)
    }

    func testCancelCallsBack() {
        var cancelled = 0
        controller.onCancel = { cancelled += 1 }
        controller.show(kind: .convert, urls: [jpg], at: CGPoint(x: 400, y: 400))
        controller.radialMenuDidCancel(controller.menuView)
        XCTAssertEqual(cancelled, 1)
        XCTAssertNil(controller.kind)
    }

    func testDropRingStartsEmptyAndAcceptsDrops() {
        controller.showDropRing(at: CGPoint(x: 400, y: 400))
        XCTAssertEqual(controller.mode, .dropRing)
        XCTAssertTrue(controller.menuView.items.isEmpty)
        XCTAssertNotNil(controller.menuView.dropZone)
        XCTAssertTrue(controller.isVisible)
    }

    func testOptionsOnlyForConvertSegmentsWithSchema() {
        controller.show(kind: .convert, urls: [jpg], at: CGPoint(x: 400, y: 400))
        guard let first = controller.menuView.items.first else { return XCTFail("no items") }
        // The test table's rows have no schema, so nothing to show.
        XCTAssertFalse(controller.radialMenu(controller.menuView, hasOptionsFor: first))
        controller.switchKind(.actions)
        guard let action = controller.menuView.items.first else { return XCTFail("no actions") }
        XCTAssertFalse(controller.radialMenu(controller.menuView, hasOptionsFor: action))
    }

    func testOptionsPopoverEdgePointsAwayFromHub() {
        XCTAssertEqual(WheelOptionsPopover.edge(forClockAngle: 0), .maxY)
        XCTAssertEqual(WheelOptionsPopover.edge(forClockAngle: .pi / 2), .maxX)
        XCTAssertEqual(WheelOptionsPopover.edge(forClockAngle: .pi), .minY)
        XCTAssertEqual(WheelOptionsPopover.edge(forClockAngle: 3 * .pi / 2), .minX)
    }

    func testOptionsModelVisibilityAndCloudGate() {
        let schema = StandardSchemas.video
        let model = WheelOptionsModel(title: "MP4", schema: schema, values: schema.defaults, interactive: true)
        XCTAssertEqual(model.visibleSpecs.count, schema.specs.count)
        var asked = 0
        model.allowCloud = { asked += 1; return false }
        guard let cloudSpec = schema.spec(OptionKey.cloud) else { return XCTFail("no cloud option") }
        model.binding(bool: cloudSpec).wrappedValue = true
        XCTAssertEqual(asked, 1)
        XCTAssertEqual(model.values[OptionKey.cloud], .bool(false), "blocked without Pro")
        let compress = ToolSchemas.compress
        let m2 = WheelOptionsModel(title: "", schema: compress, values: compress.defaults, interactive: true)
        XCTAssertTrue(m2.visibleSpecs.contains { $0.id == OptionKey.quality })
        XCTAssertFalse(m2.visibleSpecs.contains { $0.id == OptionKey.targetSize })
        m2.values[OptionKey.sizeMode] = .string("size")
        XCTAssertTrue(m2.visibleSpecs.contains { $0.id == OptionKey.targetSize })
        m2.binding(megabytes: compress.specs[2]).wrappedValue = 2.5
        XCTAssertEqual(m2.values[OptionKey.targetSize], .int(2_500_000))
    }

    func testHubTextAndColourHex() {
        XCTAssertEqual(WheelHub.idleText(for: WheelInput(urls: [jpg, txt])), String(localized: "2 files"))
        XCTAssertEqual(NSColor(hexString: "#6E56F8")?.hexString, "#6E56F8")
        XCTAssertNil(NSColor(hexString: "nope"))
    }
}

@MainActor
final class WheelGalleryTests: XCTestCase {
    /// Dev hook: `TEST_RUNNER_HALO_GALLERY_OUT=<dir> xcodebuild test …` writes the full-size gallery there.
    func testRenderGalleryToRequestedDirectory() throws {
        guard let out = ProcessInfo.processInfo.environment["HALO_GALLERY_OUT"], !out.isEmpty else {
            throw XCTSkip("set HALO_GALLERY_OUT to render the gallery")
        }
        let files = try WheelGallery.renderAll(to: URL(fileURLWithPath: out), scale: 2)
        XCTAssertFalse(files.isEmpty)
    }

    /// Dev hook: opens the interactive gallery window and captures it into HALO_GALLERY_OUT.
    func testGalleryWindowCapture() async throws {
        guard let out = ProcessInfo.processInfo.environment["HALO_GALLERY_OUT"], !out.isEmpty else {
            throw XCTSkip("set HALO_GALLERY_OUT to capture the gallery window")
        }
        WheelGallery.showWindow()
        try await Task.sleep(nanoseconds: 1_500_000_000)
        guard let window = NSApp.windows.first(where: { $0.title == String(localized: "Wheel Gallery") }) else {
            return XCTFail("no gallery window")
        }
        let id = CGWindowID(window.windowNumber)
        let image = try XCTUnwrap(CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.bestResolution, .boundsIgnoreFraming]))
        let data = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: URL(fileURLWithPath: out).appendingPathComponent("gallery-window.png"))
        window.close()
    }

    func testRenderAllWritesEveryCase() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("wheel-gallery-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let files = try WheelGallery.renderAll(to: dir, scale: 1)
        XCTAssertGreaterThanOrEqual(files.count, WheelGallery.cases().count)
        XCTAssertTrue(files.contains { $0.lastPathComponent == "wheel-options-video-light.png" })
        XCTAssertEqual(Set(files.map(\.lastPathComponent)).count, files.count, "unique names")
        let names = Set(files.map { $0.deletingPathExtension().lastPathComponent })
        XCTAssertTrue(names.contains { $0.hasPrefix("wheel-image-light-") }, "wheel-<kind>-<appearance>-<count>")
        XCTAssertTrue(names.contains("wheel-count-dark-24"))
        for tag in WheelGallery.appearances.map(\.tag) { XCTAssertTrue(names.contains("wheel-appearance-\(tag)"), tag) }
        for n in 1...24 { XCTAssertTrue(names.contains(String(format: "wheel-count-light-%02d", n))) }
        for url in files.prefix(5) {
            let data = try Data(contentsOf: url)
            XCTAssertGreaterThan(data.count, 1000)
            XCTAssertNotNil(NSBitmapImageRep(data: data))
        }
    }
}
