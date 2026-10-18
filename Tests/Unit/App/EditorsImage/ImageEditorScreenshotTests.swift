import AppKit
import SwiftUI
import XCTest
@testable import HaloApp
import HaloCore

/// Renders every lane G1 editor offscreen with sample content (light and dark).
/// With HALO_SCREENSHOTS=1 the images go to docs/screens/editor-<tool>.png so
/// regressions are visible in review; otherwise this is a rendering smoke test.
@MainActor
final class ImageEditorScreenshotTests: XCTestCase {
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

    override func tearDown() async throws { try? FileManager.default.removeItem(at: dir) }

    private func shoot(_ id: ToolID, inputs: [URL], name: String, prepare: @MainActor (any ToolEditorModel) async -> Void = { _ in }) async throws {
        let built = try XCTUnwrap(ImageEditors.make(EditorSamples.spec(id), inputs: inputs))
        await prepare(built.model)
        for dark in [false, true] {
            if let url = try EditorSnapshot.write(built.makeView({ _ in }, {}), size: built.size, name: "editor-\(name)", dark: dark) {
                XCTAssertGreaterThan((try? Data(contentsOf: url))?.count ?? 0, 10_000)
            }
        }
    }

    func testCropScreenshot() async throws {
        try await shoot(ToolIDs.cropImage, inputs: [photo], name: "crop") { m in
            guard let m = m as? ImageCropModel else { return }
            m.aspect = "4:3"
            m.rect = m.fitted(CGRect(x: 0.3, y: 0.18, width: 0.6, height: 0.62), toAspect: "4:3")
        }
    }

    func testAdjustScreenshot() async throws {
        try await shoot(ToolIDs.adjustImage, inputs: [photo], name: "adjust") { m in
            (m as? ImageAdjustModel)?.adjustments = ImageAdjustments(exposure: 0.35, contrast: 1.12, saturation: 1.25, warmth: 0.3)
        }
    }

    func testAnnotateScreenshot() async throws {
        try await shoot(ToolIDs.annotateImage, inputs: [photo], name: "annotate") { m in
            guard let m = m as? ImageAnnotateModel else { return }
            m.add(Annotation(kind: .ellipse, points: [CGPoint(x: 0.6, y: 0.33), CGPoint(x: 0.76, y: 0.6)], color: "#FFCC00", width: 0.007))
            m.add(Annotation(kind: .arrow, points: [CGPoint(x: 0.3, y: 0.3), CGPoint(x: 0.57, y: 0.44)], color: "#FF3B30", width: 0.01))
            m.add(Annotation(kind: .text, points: [CGPoint(x: 0.08, y: 0.17)], color: "#FFFFFF", text: "Sun sets at 20:41", fontSize: 0.055))
            m.add(Annotation(kind: .highlight, points: [CGPoint(x: 0.05, y: 0.8), CGPoint(x: 0.5, y: 0.88)], color: "#FFCC00"))
            m.add(Annotation(kind: .freehand, points: (0...24).map { i in
                let t = Double(i) / 24
                return CGPoint(x: 0.12 + t * 0.3, y: 0.62 + sin(t * .pi * 3) * 0.04)
            }, color: "#34C759", width: 0.006))
            m.selection = m.annotations[1].id
            m.mode = .arrow
        }
    }

    func testRedactScreenshot() async throws {
        try await shoot(ToolIDs.redactImage, inputs: [screen], name: "redact") { m in
            guard let m = m as? ImageRedactModel else { return }
            m.regions = [.init(rect: CGRect(x: 0.04, y: 0.03, width: 0.25, height: 0.035)),
                         .init(rect: CGRect(x: 0.04, y: 0.18, width: 0.55, height: 0.1)),
                         .init(rect: CGRect(x: 0.6, y: 0.5, width: 0.33, height: 0.2))]
            m.selection = m.regions[1].id
        }
    }

    func testAddBackgroundScreenshot() async throws {
        try await shoot(ToolIDs.addBackground, inputs: [photo], name: "addbackground") { m in
            guard let m = m as? ImageBackgroundModel else { return }
            m.style.padding = 12
            m.style.cornerRadius = 5
        }
    }

    func testCollageScreenshot() async throws {
        try await shoot(ToolIDs.collage, inputs: [photo] + more, name: "collage") { m in
            (m as? ImageCollageModel)?.gap = 24
        }
    }

    func testImagesToPDFScreenshot() async throws {
        try await shoot(ToolIDs.imagesToPDF, inputs: [photo] + more, name: "imagestopdf") { m in
            guard let m = m as? ImagesPDFModel else { return }
            m.pageSize = "a4"
            m.selection = 0
        }
    }

    func testMetadataScreenshot() async throws {
        try await shoot(ToolIDs.editMetadata, inputs: [photo], name: "metadata") { m in
            guard let m = m as? MetadataEditorModel else { return }
            await m.load()
            m.edited["title"] = "Dusk over Lake Brienz"
            m.edited["copyright"] = "© 2026 Sam Rivera"
            m.removeLocation()
        }
    }

    func testPopoverAndResultScreenshots() throws {
        var compress = ToolSchemas.compress.defaults
        compress[OptionKey.sizeMode] = .string("size")
        compress[OptionKey.targetSize] = .int(800_000)
        let c = Binding(get: { compress }, set: { compress = $0 })
        var resize = ToolSchemas.resize.defaults
        resize["mode"] = .string("preset")
        let r = Binding(get: { resize }, set: { resize = $0 })
        let results = [CodeReadResult(payload: "https://example.com/menu?table=12", symbology: "QR"),
                       CodeReadResult(payload: "4006381333931", symbology: "EAN13")]
        for dark in [false, true] {
            try EditorSnapshot.write(ImageCompressOptionsView(options: c, originalBytes: 3_400_000).background(Color(nsColor: .windowBackgroundColor)),
                                     size: NSSize(width: 300, height: 170), name: "popover-compress", dark: dark)
            try EditorSnapshot.write(ImageResizeOptionsView(options: r, sourceSize: CGSize(width: 4032, height: 3024)).background(Color(nsColor: .windowBackgroundColor)),
                                     size: NSSize(width: 300, height: 170), name: "popover-resize", dark: dark)
            try EditorSnapshot.write(CodeResultsView(results: results, source: "menu.jpg", copiedAll: true, onDone: {})
                .background(Color(nsColor: .windowBackgroundColor)), size: NSSize(width: 420, height: 230), name: "editor-readcodes", dark: dark)
        }
    }
}
