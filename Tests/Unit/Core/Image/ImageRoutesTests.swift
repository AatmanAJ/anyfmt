import XCTest
@testable import HaloCore

final class ImageRoutesTests: XCTestCase {
    let rows = ImageRoutes.rows
    let registry = EngineRegistry(ImageEngines.all)

    func testLaneTableIsHealthy() {
        let issues = CapabilityTable(rows).integrityIssues(registry: registry)
        XCTAssertEqual(issues, [], issues.joined(separator: "\n"))
    }

    func testEveryInputAndOutputIsCovered() {
        let pairs = Set(rows.map { "\($0.from)>\($0.to)" })
        for from in ImageRoutes.rasterInputs {
            for to in ImageRoutes.primaryOutputs + ImageRoutes.extraOutputs where to != from {
                XCTAssertTrue(pairs.contains("\(from)>\(to)"), "missing \(from) → \(to)")
            }
        }
        XCTAssertTrue(pairs.contains("svg>png"))
        for to in ImageRoutes.pdfImageOutputs + [Formats.txt] { XCTAssertTrue(pairs.contains("pdf>\(to)"), "pdf → \(to)") }
        XCTAssertFalse(rows.contains { $0.from == Formats.pdf && [Formats.docx, Formats.pptx, Formats.xlsx, Formats.epub, Formats.md].contains($0.to) },
                       "PDF → documents belong to lane F")
    }

    func testFlagsAndSchemas() throws {
        for r in rows where r.from == Formats.pdf && r.to != Formats.txt {
            XCTAssertTrue(r.flags.contains(.multiOutput), "\(r)")
            let lossless = [Formats.png, Formats.tiff, Formats.bmp].contains(r.to)
            XCTAssertEqual(r.schema, lossless ? StandardSchemas.pdfRenderLossless : StandardSchemas.pdfRender, "\(r)")
        }
        let txt = try XCTUnwrap(rows.first { $0.from == Formats.pdf && $0.to == Formats.txt })
        XCTAssertTrue(txt.flags.contains(.terminalOnly) && txt.flags.contains(.lossyStructure))
        for r in rows where r.engine == EngineIDs.imageIO {
            switch r.to {
            case Formats.png, Formats.tiff: XCTAssertTrue(r.flags.contains(.lossless), "\(r)")
            case Formats.jpg: XCTAssertEqual(r.schema, StandardSchemas.imageOpaque)
            case Formats.heic, Formats.avif: XCTAssertEqual(r.schema, StandardSchemas.imageLossy)
            case Formats.pdf: XCTAssertEqual(r.schema, StandardSchemas.toPDF)
            default: break
            }
            XCTAssertEqual(r.priority, r.to == Formats.gif ? 40 : 100, "native rows 100; ImageIO GIF is the fallback")
            XCTAssertEqual(r.flags.contains(.hiddenByDefault), ImageRoutes.extraOutputs.contains(r.to) || r.to == Formats.txt, "\(r)")
            if r.to == Formats.txt { XCTAssertTrue(r.flags.contains(.terminalOnly) && r.flags.contains(.lossyStructure), "\(r)") }
        }
        for r in rows where r.engine == EngineIDs.ffmpegImage {
            XCTAssertEqual(r.priority, r.to == Formats.gif ? 90 : 60)
            if r.to == Formats.webp { XCTAssertEqual(r.schema, StandardSchemas.imageLosslessCapable) }
        }
    }

    func testAVIFRowsFollowTheOSEncoder() {
        let ioAVIF = Capability(Formats.png, Formats.avif, EngineIDs.imageIO)
        XCTAssertEqual(ImageIOEngine().isAvailable(ioAVIF), ImageIOSupport.canEncode("public.avif"))
        // When ImageIO can encode AVIF its row wins; otherwise the ffmpeg fallback does.
        let available = CapabilityTable(rows.filter { r in
            r.engine == EngineIDs.ffmpegImage ? ImageTestSupport.hasFFmpeg : registry.isAvailable(r)
        })
        let route = Router(table: available).route(from: Formats.png, to: Formats.avif)
        XCTAssertEqual(route?.hops.first?.engine, ImageIOSupport.canEncodeAVIF ? EngineIDs.imageIO : EngineIDs.ffmpegImage)
    }

    func testRouterPlansNoSillyPaths() throws {
        let router = Router(table: CapabilityTable(rows))
        // Direct rows for every raster pair.
        XCTAssertEqual(router.route(from: Formats.heic, to: Formats.jpg)?.hops.count, 1)
        XCTAssertEqual(router.route(from: Formats.gif, to: Formats.webp)?.hops.first?.engine, EngineIDs.ffmpegImage)
        XCTAssertEqual(router.route(from: Formats.png, to: Formats.gif)?.hops.first?.engine, EngineIDs.ffmpegImage, "palette GIF preferred")
        // PDF page renders never chain, and text is terminal.
        XCTAssertNil(router.route(from: Formats.pdf, to: Formats.ico))
        XCTAssertNil(router.route(from: Formats.pdf, to: Formats.gif))
        // SVG goes through PNG (lossless) for everything.
        let svgTargets = Set(router.allRoutes(from: Formats.svg).keys)
        XCTAssertTrue(svgTargets.isSuperset(of: Set(ImageRoutes.primaryOutputs)))
    }

    func testOptionCount() {
        let router = Router(table: CapabilityTable(rows))
        let inputs = ImageRoutes.rasterInputs + [Formats.svg, Formats.pdf]
        let count = router.optionCount(inputs: inputs)
        // 15 raster inputs × 16 targets (15 images + OCR text), SVG → 17, PDF → 8.
        XCTAssertEqual(count, 15 * 16 + 17 + 8)
        let visible = inputs.reduce(0) { n, from in
            n + router.allRoutes(from: from).values.filter { !$0.hops.contains { $0.flags.contains(.hiddenByDefault) } }.count
        }
        print("lane D: \(rows.count) rows, \(count) options (\(visible) on the wheel by default)")
    }
}
