import AppKit
import SwiftUI
import XCTest
@testable import AnyfmtApp
import AnyfmtCore

@MainActor
final class ImageEditorsTests: XCTestCase {
    private var dir: URL!
    private var photo: URL!
    private var screen: URL!
    private var more: [URL] = []

    override func setUp() async throws {
        dir = try EditorSamples.dir(name)
        let set = EditorSamples.standardSet(in: dir)
        photo = set.photo
        screen = set.screen
        more = set.more
    }

    override func tearDown() async throws {
        for w in NSApp.windows where w.title.contains("—") { w.close() }
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: Factory

    func testOpenReturnsTrueForEveryEditorTool() {
        for id in ImageEditors.tools {
            let spec = EditorSamples.spec(id)
            XCTAssertTrue(spec.needsEditor, "\(id) should be an editor tool")
            let inputs: [URL] = {
                if case .combine = spec.arity { return [photo] + more }
                return [photo]
            }()
            XCTAssertTrue(ImageEditors.open(spec, inputs: inputs) { _ in }, "\(id)")
            XCTAssertTrue(EditorFactory.open(spec, inputs: inputs) { _ in }, "\(id) via EditorFactory")
        }
        // Every image/metadata tool with needsEditor in the catalogue is covered.
        let editorTools = ToolCatalog.local.filter { $0.needsEditor && ($0.kinds.contains(.image) || $0.id == ToolIDs.editMetadata) }.map(\.id)
        XCTAssertEqual(Set(editorTools), Set(ImageEditors.tools))
    }

    func testOpenRejectsOtherToolsAndInputs() {
        XCTAssertFalse(ImageEditors.open(EditorSamples.spec(ToolIDs.compressImage), inputs: [photo]) { _ in })
        XCTAssertFalse(ImageEditors.open(EditorSamples.spec(ToolIDs.trimVideo), inputs: [photo]) { _ in })
        XCTAssertFalse(ImageEditors.open(EditorSamples.spec(ToolIDs.cropImage), inputs: []) { _ in })
        XCTAssertFalse(ImageEditors.open(EditorSamples.spec(ToolIDs.collage), inputs: [photo]) { _ in }, "collage needs two")
        let txt = dir.appendingPathComponent("notes.txt")
        try? "x".write(to: txt, atomically: true, encoding: .utf8)
        XCTAssertFalse(ImageEditors.open(EditorSamples.spec(ToolIDs.cropImage), inputs: [txt]) { _ in })
    }

    func testEscapeAndSaveCloseTheWindow() throws {
        var saved: EditorResult?
        XCTAssertTrue(ImageEditors.open(EditorSamples.spec(ToolIDs.adjustImage), inputs: [photo]) { saved = $0 })
        let window = try XCTUnwrap(NSApp.windows.first { $0.title.hasPrefix(EditorSamples.spec(ToolIDs.adjustImage).title) && $0.isVisible })
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let esc = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                                 context: nil, characters: "\u{1B}", charactersIgnoringModifiers: "\u{1B}", isARepeat: false, keyCode: 53))
        NSApp.sendEvent(esc)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertFalse(window.isVisible, "Esc closes the editor")
        XCTAssertNil(saved)
    }

    // MARK: Models → options

    func testCropModel() {
        let m = ImageCropModel(tool: EditorSamples.spec(ToolIDs.cropImage), inputs: [photo])
        XCTAssertEqual(m.pixelSize, CGSize(width: 1600, height: 1067))
        XCTAssertTrue(m.isFullFrame)
        m.aspect = "1:1"
        let px = CropGeometry.pixelRect(m.rect, aspect: "free", imageSize: m.pixelSize)
        XCTAssertEqual(px.width, px.height, accuracy: 1.5, "switching aspect makes the frame square in pixels")
        // Corner drag keeps the ratio.
        let r = m.dragged(.bottomRight, start: m.rect, to: CGPoint(x: 0.5, y: 0.9), translation: .zero)
        let rp = CropGeometry.pixelRect(r, aspect: "free", imageSize: m.pixelSize)
        XCTAssertEqual(rp.width / rp.height, 1, accuracy: 0.02)
        m.aspect = "free"
        m.rect = CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
        let moved = m.dragged(.move, start: m.rect, to: .zero, translation: CGSize(width: 0.9, height: 0))
        XCTAssertEqual(moved.maxX, 1, accuracy: 0.0001, "moves stay inside the image")
        let left = m.dragged(.left, start: m.rect, to: CGPoint(x: 0.3, y: 0.5), translation: .zero)
        XCTAssertEqual(left.minX, 0.3, accuracy: 0.0001); XCTAssertEqual(left.maxX, 0.6, accuracy: 0.0001)
        m.nudge(dx: 16, dy: 0)
        XCTAssertEqual(m.rect.minX, 0.1 + 16 / 1600, accuracy: 0.0001)
        XCTAssertEqual(m.options.string("aspect", default: ""), "free")
        XCTAssertEqual(CropGeometry.parseRect(m.options.string("rect", default: ""))?.width ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(m.statusLine, "1600 × 1067 px → 800 × 533 px")
    }

    func testAdjustModelAndPreviewBudget() {
        let m = ImageAdjustModel(tool: EditorSamples.spec(ToolIDs.adjustImage), inputs: [photo])
        XCTAssertFalse(m.canSave, "nothing to save until something changes")
        m.adjustments.exposure = 0.5 // warm-up render
        var worst = 0.0
        for i in 0..<6 {
            m.adjustments.saturation = 1 + Double(i) * 0.1
            worst = max(worst, m.lastRenderSeconds)
        }
        print("G1 adjust preview worst re-render: \(Int((worst * 1000).rounded())) ms")
        XCTAssertLessThan(worst, 0.05, "live preview re-render must stay under 50 ms (worst \(Int(worst * 1000)) ms)")
        XCTAssertTrue(m.canSave)
        XCTAssertEqual(m.options.double("exposure", default: 0), 0.5)
        XCTAssertEqual(ImageAdjustments(options: m.options), m.adjustments)
        m.resetAll()
        XCTAssertTrue(m.adjustments.isNeutral)
    }

    func testAnnotateModelUndoRedoAndOptions() {
        let m = ImageAnnotateModel(tool: EditorSamples.spec(ToolIDs.annotateImage), inputs: [photo])
        XCTAssertFalse(m.canSave)
        m.add(Annotation(kind: .arrow, points: [CGPoint(x: 0.1, y: 0.1), CGPoint(x: 0.5, y: 0.5)]))
        m.add(m.newAnnotation(.text, at: CGPoint(x: 0.2, y: 0.7)))
        XCTAssertEqual(m.annotations.count, 2)
        m.setColor("#0A84FF")
        XCTAssertEqual(m.annotations.last?.color, "#0A84FF", "colour applies to the selection")
        m.undo()
        XCTAssertNotEqual(m.annotations.last?.color, "#0A84FF")
        m.redo()
        XCTAssertEqual(m.annotations.last?.color, "#0A84FF")
        m.deleteSelection()
        XCTAssertEqual(m.annotations.count, 1)
        m.undo()
        XCTAssertEqual(m.annotations.count, 2)
        let decoded = Annotation.decodeList(m.options.string("annotations", default: ""))
        XCTAssertEqual(decoded, m.annotations)
        // Hit testing on a segment, not its bounding box.
        let arrowID = m.annotations[0].id
        XCTAssertEqual(m.hit(CGPoint(x: 0.3, y: 0.3), viewSize: CGSize(width: 800, height: 600)), arrowID)
        XCTAssertNil(m.hit(CGPoint(x: 0.45, y: 0.15), viewSize: CGSize(width: 800, height: 600)))
    }

    func testRedactModel() {
        let m = ImageRedactModel(tool: EditorSamples.spec(ToolIDs.redactImage), inputs: [screen])
        XCTAssertFalse(m.canSave)
        m.regions = [.init(rect: CGRect(x: 0.04, y: 0.03, width: 0.25, height: 0.04)), .init(rect: CGRect(x: 0.05, y: 0.2, width: 0.6, height: 0.1))]
        m.style = .blur
        XCTAssertTrue(m.canSave)
        XCTAssertEqual(Redactor.parseRegions(m.options.string("regions", default: "")).count, 2)
        XCTAssertEqual(m.options.string("style", default: ""), "blur")
        XCTAssertNotNil(m.rendered)
        XCTAssertFalse(m.rendered === m.preview, "preview shows the redaction")
        m.selection = m.regions[0].id
        m.deleteSelection()
        XCTAssertEqual(m.regions.count, 1)
        m.undo()
        XCTAssertEqual(m.regions.count, 2)
    }

    func testBackgroundModel() {
        let m = ImageBackgroundModel(tool: EditorSamples.spec(ToolIDs.addBackground), inputs: [photo])
        m.style.padding = 20
        m.applyPreset(ImageBackgroundModel.presets[2])
        XCTAssertEqual(m.options.string("fill", default: ""), "gradient")
        XCTAssertEqual(m.options.int("padding", default: 0), 20)
        XCTAssertEqual(m.outputSize, CGSize(width: 1600 + 640, height: 1067 + 640))
        XCTAssertNotNil(m.rendered)
        m.style.fill = .image
        XCTAssertFalse(m.canSave, "image fill needs an image")
    }

    func testCollageModel() {
        let m = ImageCollageModel(tool: EditorSamples.spec(ToolIDs.collage), inputs: more)
        m.move(from: 0, to: 2)
        XCTAssertEqual(m.order, [1, 2, 0, 3])
        XCTAssertEqual(m.options.string("order", default: ""), "2,3,1,4")
        m.layoutKind = .row
        m.width = 2048
        XCTAssertEqual(m.layout.canvas.width, 2048)
        XCTAssertEqual(OrderOption.apply(m.options.string("order", default: ""), to: more), [more[1], more[2], more[0], more[3]])
    }

    func testImagesToPDFModel() {
        let m = ImagesPDFModel(tool: EditorSamples.spec(ToolIDs.imagesToPDF), inputs: more)
        XCTAssertEqual(m.pageCountText, "4 pages")
        m.sortByName()
        XCTAssertEqual(m.order.map { m.items[$0].name }, ["Bay.jpg", "Peak.jpg", "Ridge.jpg", "Valley.jpg"])
        m.reverse()
        m.pageSize = "a4"
        XCTAssertEqual(m.options.string(OptionKey.pageSize, default: ""), "a4")
        XCTAssertEqual(m.options.string("order", default: ""), OrderOption.format(m.order))
        let portrait = m.page(m.items[0]) // Ridge 900×1200
        XCTAssertEqual(portrait.media.size, PDFPagePlan.a4)
    }

    func testMetadataModel() async {
        let m = MetadataEditorModel(tool: EditorSamples.spec(ToolIDs.editMetadata), inputs: [photo], autoload: false)
        await m.load()
        XCTAssertEqual(m.snapshot?.value("title"), "Dusk over the lake")
        XCTAssertFalse(m.canSave)
        m.edited["title"] = "Evening"
        m.removeLocation()
        XCTAssertTrue(m.canSave)
        let changes = (try? MetadataChanges.parse(m.options.string("fields", default: ""))) ?? [:]
        XCTAssertEqual(changes["title"], "Evening")
        XCTAssertEqual(changes["gpsLatitude"], .some(nil))
        XCTAssertEqual(changes.count, 3)
        m.revert()
        XCTAssertFalse(m.canSave)
    }

    func testTypingBInMetadataFieldIsNotSwallowed() async throws {
        // The shell binds a bare "B" to Before / After; text fields must still get the letter.
        let m = MetadataEditorModel(tool: EditorSamples.spec(ToolIDs.editMetadata), inputs: [photo], autoload: false)
        await m.load()
        let view = MetadataEditor(model: m, onSave: { _ in }, onClose: {})
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 940, height: 660), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.makeKeyAndOrderFront(nil)
        defer { window.close() }
        try await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))
        let field = try XCTUnwrap(Self.textFields(in: window.contentView).first, "no text field found")
        window.makeFirstResponder(field)
        try await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
        for (ch, code) in [("a", UInt16(0)), ("b", UInt16(11)), ("c", UInt16(8))] {
            let e = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                                   context: nil, characters: ch, charactersIgnoringModifiers: ch, isARepeat: false, keyCode: code))
            NSApp.sendEvent(e)
        }
        try await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
        let typed = (window.firstResponder as? NSTextView)?.string ?? field.stringValue
        XCTAssertTrue(typed.hasSuffix("abc") || typed.contains("abc"), "typed text was “\(typed)”")
    }

    static func textFields(in view: NSView?) -> [NSTextField] {
        guard let view else { return [] }
        var out: [NSTextField] = []
        if let f = view as? NSTextField, f.isEditable { out.append(f) }
        for s in view.subviews { out += textFields(in: s) }
        return out
    }

    // MARK: Options popovers and code results

    func testOptionViewsEditBindings() {
        var compress = ToolSchemas.compress.defaults
        let binding = Binding(get: { compress }, set: { compress = $0 })
        _ = ImageCompressOptionsView(options: binding, originalBytes: 2_000_000).body
        binding.wrappedValue[OptionKey.sizeMode] = .string("percent")
        XCTAssertEqual(compress.string(OptionKey.sizeMode, default: ""), "percent")
        var resize = ToolSchemas.resize.defaults
        let rb = Binding(get: { resize }, set: { resize = $0 })
        _ = ImageResizeOptionsView(options: rb, sourceSize: CGSize(width: 4032, height: 3024)).body
        rb.wrappedValue["mode"] = .string("preset")
        XCTAssertEqual(ResizePlan.targetSize(for: CGSize(width: 4032, height: 3024), options: resize), CGSize(width: 1920, height: 1440))
    }

    func testPresentResultOnlyForReadCodes() throws {
        let txt = dir.appendingPathComponent("menu-codes.txt")
        try CodeReader.text(for: [CodeReadResult(payload: "hello", symbology: "QR")]).write(to: txt, atomically: true, encoding: .utf8)
        CodeResultPresenter.pasteboard = NSPasteboard(name: NSPasteboard.Name("anyfmt-test-\(UUID().uuidString)"))
        defer { CodeResultPresenter.pasteboard = .general }
        XCTAssertFalse(ImageEditors.presentResult(EditorSamples.spec(ToolIDs.compressImage), outputs: [photo]))
        XCTAssertTrue(ImageEditors.presentResult(EditorSamples.spec(ToolIDs.readCodes), outputs: [txt]))
        XCTAssertEqual(CodeResultPresenter.pasteboard.string(forType: .string), "hello", "results are copied")
        for w in NSApp.windows where w.title == "1 code found" { w.close() }
    }

    func testCodeResultPresenter() {
        let results = [CodeReadResult(payload: "https://example.com/menu", symbology: "QR"), CodeReadResult(payload: "4006381333931", symbology: "EAN13")]
        let panel = CodeResultPresenter.present(results: results, source: "menu.jpg", copyToClipboard: false)
        XCTAssertTrue(panel.isVisible)
        XCTAssertEqual(panel.title, "2 codes found")
        panel.close()
        XCTAssertEqual(results[0].link?.host, "example.com")
        XCTAssertNil(results[1].link)
    }
}
