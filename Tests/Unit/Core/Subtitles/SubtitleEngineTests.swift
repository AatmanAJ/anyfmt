import XCTest
@testable import HaloCore

final class SubtitleEngineTests: XCTestCase {
    private func convert(_ input: URL, to: FormatID, options: [String: OptionValue] = [:]) async throws -> URL {
        let from = Formats.detect(input) ?? FormatID(input.pathExtension)
        let schema = SubtitleRoutes.rows.first { $0.from == from && $0.to == to }?.schema ?? .none
        let req = ConversionRequest(inputs: [input], from: from, to: to,
                                    options: schema.defaults.merging(OptionValues(options)),
                                    outputDirectory: try LaneE.tempDirectory(), baseName: "out", metadata: .keep)
        return try await SubtitleEngine().convert(req, context: EngineContext()).files[0]
    }

    func testRowsAndAvailability() {
        XCTAssertEqual(SubtitleRoutes.rows.count, 4)
        let txt = SubtitleRoutes.rows.filter { $0.to == Formats.txt }
        XCTAssertEqual(txt.count, 2)
        XCTAssertTrue(txt.allSatisfy { $0.flags.contains(.terminalOnly) && $0.schema == StandardSchemas.subtitleText })
        XCTAssertTrue(SubtitleRoutes.rows.allSatisfy { SubtitleEngine().isAvailable($0) })
        let router = Router(table: CapabilityTable(SubtitleRoutes.rows))
        XCTAssertEqual(router.allRoutes(from: Formats.srt).keys.sorted(), [Formats.txt, Formats.vtt])
        XCTAssertEqual(router.allRoutes(from: Formats.vtt).keys.sorted(), [Formats.srt, Formats.txt])
    }

    func testSampleFixturesConvertEveryRow() async throws {
        let srt = try LaneE.fixture("sample.srt"), vtt = try LaneE.fixture("sample.vtt")
        let toVTT = VTTParser.parse(try Data(contentsOf: try await convert(srt, to: Formats.vtt)))
        XCTAssertEqual(toVTT.cues.map(\.start), [500, 1600])
        XCTAssertEqual(toVTT.cues.map(\.end), [1500, 2000])
        let toSRT = SRTParser.parse(try Data(contentsOf: try await convert(vtt, to: Formats.srt)))
        XCTAssertEqual(toSRT.cues.map(\.lines), [["Hello, <i>world</i>!"], ["{\\an7}Second & last"]])
        let txt = String(decoding: try Data(contentsOf: try await convert(srt, to: Formats.txt)), as: UTF8.self)
        XCTAssertEqual(txt, "Hello, world!\nSecond cue on two lines\n")
        let stamped = String(decoding: try Data(contentsOf: try await convert(vtt, to: Formats.txt, options: [OptionKey.timestamps: .bool(true)])), as: UTF8.self)
        XCTAssertEqual(stamped, "[00:00:00] Hello, world!\n[00:00:01] Second & last\n")
    }

    /// Every edge fixture converts to every target without crashing, and the
    /// output re-parses with identical timing.
    func testEveryEdgeFixtureRoundTrips() async throws {
        let dir = try LaneE.fixtures()
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .filter { $0.hasSuffix(".srt") || $0.hasSuffix(".vtt") }.sorted()
        XCTAssertGreaterThanOrEqual(names.count, 20)
        for name in names {
            let url = dir.appendingPathComponent(name)
            let source = name.hasSuffix(".srt") ? SRTParser.parse(try Data(contentsOf: url)) : VTTParser.parse(try Data(contentsOf: url))
            XCTAssertFalse(source.cues.isEmpty, name)
            let other: FormatID = name.hasSuffix(".srt") ? Formats.vtt : Formats.srt
            let out = try await convert(url, to: other)
            let parsed = other == Formats.vtt ? VTTParser.parse(try Data(contentsOf: out)) : SRTParser.parse(try Data(contentsOf: out))
            XCTAssertEqual(parsed.warnings, [], "\(name) → \(other) must be clean")
            XCTAssertEqual(parsed.cues.map(\.start), source.cuesByStart.map(\.start), name)
            XCTAssertEqual(parsed.cues.map(\.end), source.cuesByStart.map(\.end), name)
            XCTAssertEqual(parsed.hasBOM, source.hasBOM, name)
            XCTAssertEqual(parsed.lineEnding, source.lineEnding, name)
            _ = try await convert(url, to: Formats.txt)
        }
    }

    func testEdgeFixtureSpecifics() async throws {
        let styling = VTTParser.parse(try Data(contentsOf: try await convert(try LaneE.fixture("edge-styling.srt"), to: Formats.vtt)))
        XCTAssertEqual(styling.blocks.first?.kind, .style)
        XCTAssertEqual(styling.cues[2].settings, "line:0")
        XCTAssertEqual(styling.cues[2].lines, ["Top of the screen"])
        XCTAssertEqual(styling.cues[3].lines, ["<i>ASS italic</i> and a &lt; b &amp; c &gt; d &lt;3"])
        XCTAssertEqual(styling.cues[4].settings, "line:0 align:start")

        let utf16 = SRTParser.parse(try Data(contentsOf: try await convert(try LaneE.fixture("edge-utf16.srt"), to: Formats.vtt)))
        XCTAssertEqual(utf16.cues.first?.lines.first?.contains("été"), true)

        let header = String(decoding: try Data(contentsOf: try await convert(try LaneE.fixture("edge-header-blocks.vtt"), to: Formats.srt)), as: UTF8.self)
        XCTAssertFalse(header.contains("NOTE") || header.contains("STYLE") || header.contains("REGION") || header.contains("WEBVTT"))
        XCTAssertTrue(header.contains("<font color=\"#ff0000\">Loud</font> and Bob speaks"))

        let survivor = VTTParser.parse(try Data(contentsOf: try await convert(try LaneE.fixture("edge-malformed.srt"), to: Formats.vtt)))
        XCTAssertEqual(survivor.cues.map(\.lines), [["Valid survivor"]])

        let rolling = String(decoding: try Data(contentsOf: try await convert(try LaneE.fixture("edge-rolling.vtt"), to: Formats.txt)), as: UTF8.self)
        XCTAssertEqual(rolling, "so today we are going\nto talk about subtitles\nand why they matter\n")
    }

    func testEmptyOrGarbageInputThrowsReadableError() async throws {
        let dir = try LaneE.tempDirectory()
        let empty = dir.appendingPathComponent("empty.srt")
        try Data().write(to: empty)
        let junk = dir.appendingPathComponent("junk.vtt")
        try Data("WEBVTT\n\nnothing to see\n".utf8).write(to: junk)
        for (url, to) in [(empty, Formats.vtt), (junk, Formats.srt)] {
            do {
                _ = try await convert(url, to: to)
                XCTFail("expected an error for \(url.lastPathComponent)")
            } catch let e as ConversionError {
                guard case .unreadable = e else { return XCTFail("\(e)") }
            }
        }
    }

    func testNeverOverwritesAndHonoursCancellation() async throws {
        let srt = try LaneE.fixture("sample.srt")
        let dir = try LaneE.tempDirectory()
        try Data("keep me".utf8).write(to: dir.appendingPathComponent("out.vtt"))
        let req = ConversionRequest(inputs: [srt], from: Formats.srt, to: Formats.vtt, options: .init(),
                                    outputDirectory: dir, baseName: "out", metadata: .keep)
        do {
            _ = try await SubtitleEngine().convert(req, context: EngineContext())
            XCTFail("must not overwrite")
        } catch {}
        XCTAssertEqual(try String(contentsOf: dir.appendingPathComponent("out.vtt"), encoding: .utf8), "keep me")

        let task = Task { try await SubtitleEngine().convert(req, context: EngineContext()) }
        task.cancel()
        let result = await task.result
        XCTAssertThrowsError(try result.get())
    }
}
