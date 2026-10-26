import XCTest
import ImageIO
@testable import AnyfmtCore

final class ResvgEngineTests: XCTestCase {
    typealias S = ImageTestSupport
    let engine = ResvgEngine()

    private func svg(_ dir: URL, _ body: String = "", attrs: String = #"width="320" height="200" viewBox="0 0 160 100""#) throws -> URL {
        let url = dir.appendingPathComponent("art.svg")
        let doc = """
        <svg xmlns="http://www.w3.org/2000/svg" \(attrs)>
          <rect x="40" y="25" width="80" height="50" fill="#ff0000"/>\(body)
        </svg>
        """
        try Data(doc.utf8).write(to: url)
        return url
    }

    func testDefaultIsTwiceIntrinsicSizeOnTransparent() async throws {
        guard S.hasResvg else { throw XCTSkip("resvg not bundled") }
        let dir = try S.tempDir()
        let out = try await S.convert(engine, try svg(dir), from: Formats.svg, to: Formats.png)
        let img = try XCTUnwrap(S.decode(out[0]))
        XCTAssertEqual([img.width, img.height], [640, 400])
        XCTAssertEqual(S.pixel(img, 5, 5)[3], 0, "background stays transparent")
        S.assertColor(S.pixel(img, 320, 200), [255, 0, 0, 255], tolerance: 2)
        XCTAssertEqual(S.properties(out[0])["DPIWidth"] as? Double ?? 0, 144, accuracy: 0.5, "DPI records the 2× scale")
    }

    func testMaxDimensionSetsLongestEdge() async throws {
        guard S.hasResvg else { throw XCTSkip("resvg not bundled") }
        let dir = try S.tempDir()
        let wide = try await S.convert(engine, try svg(dir), from: Formats.svg, to: Formats.png, options: [OptionKey.maxDimension: .int(1000)])
        XCTAssertEqual([S.decode(wide[0])?.width, S.decode(wide[0])?.height], [1000, 625])
        let tallDir = try S.tempDir("tall")
        let tall = try await S.convert(engine, try svg(tallDir, attrs: #"width="100" height="400""#), from: Formats.svg, to: Formats.png,
                                       options: [OptionKey.maxDimension: .int(200)])
        XCTAssertEqual([S.decode(tall[0])?.width, S.decode(tall[0])?.height], [50, 200])
    }

    func testSVGReachesOtherFormatsThroughPNG() async throws {
        guard S.hasResvg else { throw XCTSkip("resvg not bundled") }
        let router = Router(table: CapabilityTable(ImageRoutes.rows))
        for to in [Formats.jpg, Formats.pdf, Formats.webp, Formats.ico] {
            let route = try XCTUnwrap(router.route(from: Formats.svg, to: to), "svg → \(to)")
            XCTAssertEqual(route.hops.first?.to, Formats.png)
            XCTAssertEqual(route.hops.count, 2)
        }
        // Run svg → pdf end to end: the PDF page is the SVG's own size (320×200 pt).
        let dir = try S.tempDir()
        let route = try XCTUnwrap(router.route(from: Formats.svg, to: Formats.pdf))
        let outs = try await RouteExecutor(registry: EngineRegistry(ImageEngines.all)).execute(
            route, inputs: [try svg(dir)], options: OptionValues(), baseName: "art", metadata: .keep,
            workDirectory: dir.appendingPathComponent("work"), context: S.context)
        let box = try XCTUnwrap(CGPDFDocument(outs[0] as CFURL)?.page(at: 1)).getBoxRect(.mediaBox)
        XCTAssertEqual(box.width, 320, accuracy: 1); XCTAssertEqual(box.height, 200, accuracy: 1)
    }

    func testBrokenSVGIsUnreadable() async throws {
        guard S.hasResvg else { throw XCTSkip("resvg not bundled") }
        let dir = try S.tempDir()
        let bad = dir.appendingPathComponent("bad.svg")
        try Data("<svg><rect".utf8).write(to: bad)
        do {
            _ = try await S.convert(engine, bad, from: Formats.svg, to: Formats.png)
            XCTFail("expected unreadable")
        } catch ConversionError.unreadable {}
    }

    func testIntrinsicSizeParsing() throws {
        let dir = try S.tempDir()
        func size(_ attrs: String) throws -> CGSize? {
            let url = dir.appendingPathComponent("\(UUID().uuidString).svg")
            try Data("<svg xmlns=\"http://www.w3.org/2000/svg\" \(attrs)/>".utf8).write(to: url)
            return SVGSize.read(url)
        }
        XCTAssertEqual(try size(#"width="320" height="200""#), CGSize(width: 320, height: 200))
        XCTAssertEqual(try size(#"viewBox="0 0 50 25""#), CGSize(width: 50, height: 25))
        XCTAssertEqual(try size(#"width="1in" height="72pt""#), CGSize(width: 96, height: 96))
        XCTAssertEqual(try size(#"width="100" viewBox="0 0 200 50""#), CGSize(width: 100, height: 25))
        XCTAssertEqual(try size(#"width="50%" height="100%" viewBox="0 0 200 80""#), CGSize(width: 100, height: 80))
        XCTAssertNil(try size(""))
    }
}
