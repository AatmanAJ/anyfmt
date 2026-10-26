import XCTest
@testable import AnyfmtCore

final class SubtitleTimeTests: XCTestCase {
    func testParsesBothSeparatorsAndHourForms() {
        XCTAssertEqual(SubtitleTime.parse("00:00:01,000"), 1000)
        XCTAssertEqual(SubtitleTime.parse("00:00:01.000"), 1000)
        XCTAssertEqual(SubtitleTime.parse("01:02:03,456"), 3_723_456)
        XCTAssertEqual(SubtitleTime.parse("02:03.456"), 123_456, "MM:SS.mmm (WebVTT short form)")
        XCTAssertEqual(SubtitleTime.parse("123:45:06,789"), ((123 * 60 + 45) * 60 + 6) * 1000 + 789, "hours ≥ 100")
        XCTAssertEqual(SubtitleTime.parse(" 00:00:02,500 "), 2500, "surrounding spaces")
    }

    func testShortFractionsAreDecimal() {
        XCTAssertEqual(SubtitleTime.parse("00:00:03,5"), 3500)
        XCTAssertEqual(SubtitleTime.parse("00:00:03,25"), 3250)
        XCTAssertEqual(SubtitleTime.parse("00:00:03,0251"), 3025, "extra digits truncate")
        XCTAssertEqual(SubtitleTime.parse("00:00:03"), 3000, "missing fraction")
    }

    func testRejectsMalformed() {
        for bad in ["", "abc", "00:00:0x,000", "00:60:00,000", "00:00:60,000", "1:2:3:4,000", "00:00:01,-10", "-00:00:01,000"] {
            XCTAssertNil(SubtitleTime.parse(bad), bad)
        }
    }

    func testFormatPadsAndKeepsLargeHours() {
        XCTAssertEqual(SubtitleTime.format(0, separator: ","), "00:00:00,000")
        XCTAssertEqual(SubtitleTime.format(3_723_456, separator: "."), "01:02:03.456")
        XCTAssertEqual(SubtitleTime.format(360_000_000 + 1, separator: ","), "100:00:00,001")
        XCTAssertEqual(SubtitleTime.formatClock(3_723_999), "01:02:03")
    }

    func testRoundTripEveryMillisecondBoundary() {
        for ms in [0, 1, 999, 1000, 59_999, 60_000, 3_599_999, 3_600_000, 359_999_999, 360_000_000, 1_000_000_000] {
            XCTAssertEqual(SubtitleTime.parse(SubtitleTime.format(ms, separator: ",")), ms)
            XCTAssertEqual(SubtitleTime.parse(SubtitleTime.format(ms, separator: ".")), ms)
        }
    }
}

final class SRTParserTests: XCTestCase {
    private func parse(_ s: String) -> SubtitleDocument { SRTParser.parse(text: s) }

    func testBasicCues() {
        let doc = parse("1\n00:00:01,000 --> 00:00:02,500\nHello\nWorld\n\n2\n00:00:03,000 --> 00:00:04,000\nBye\n")
        XCTAssertEqual(doc.cues.count, 2)
        XCTAssertEqual(doc.cues[0], SubtitleCue(identifier: "1", start: 1000, end: 2500, lines: ["Hello", "World"]))
        XCTAssertEqual(doc.cues[1].lines, ["Bye"])
        XCTAssertEqual(doc.lineEnding, .lf)
        XCTAssertTrue(doc.warnings.isEmpty)
    }

    func testBOMAndCRLF() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("1\r\n00:00:01,000 --> 00:00:02,000\r\nA\r\n\r\n2\r\n00:00:02,000 --> 00:00:03,000\r\nB\r\n".utf8))
        let doc = SRTParser.parse(data)
        XCTAssertTrue(doc.hasBOM)
        XCTAssertEqual(doc.lineEnding, .crlf)
        XCTAssertEqual(doc.cues.map(\.lines), [["A"], ["B"]])
        XCTAssertEqual(doc.cues.first?.identifier, "1", "BOM must not stick to the first index")
    }

    func testClassicMacCR() {
        let doc = parse("1\r00:00:01,000 --> 00:00:02,000\rCR only\r\r2\r00:00:02,000 --> 00:00:03,000\rTwo\r")
        XCTAssertEqual(doc.lineEnding, .cr)
        XCTAssertEqual(doc.cues.count, 2)
    }

    func testUTF16AndWindows1252() {
        var utf16 = Data([0xFF, 0xFE])
        utf16.append("1\r\n00:00:01,000 --> 00:00:02,000\r\nété\r\n".data(using: .utf16LittleEndian) ?? Data())
        let a = SRTParser.parse(utf16)
        XCTAssertTrue(a.hasBOM)
        XCTAssertEqual(a.cues.first?.lines, ["été"])

        let cp1252 = Data("1\n00:00:01,000 --> 00:00:02,000\ncaf".utf8) + Data([0xE9]) + Data(" cr".utf8) + Data([0xE8]) + Data("me\n".utf8)
        XCTAssertEqual(SRTParser.parse(cp1252).cues.first?.lines, ["café crème"])
    }

    func testMissingTrailingNewline() {
        let doc = parse("1\n00:00:01,000 --> 00:00:02,000\nLast line")
        XCTAssertFalse(doc.endsWithNewline)
        XCTAssertEqual(doc.cues.first?.lines, ["Last line"])
    }

    func testMissingAndOddIndexes() {
        let doc = parse("00:00:01,000 --> 00:00:02,000\nNo index\n\nseven\n00:00:02,000 --> 00:00:03,000\nWord index\n\n42\n00:00:03,000 --> 00:00:04,000\nJump\n")
        XCTAssertEqual(doc.cues.map(\.identifier), [nil, "seven", "42"])
        XCTAssertEqual(doc.cues.map(\.start), [1000, 2000, 3000])
    }

    func testExtraBlankAndWhitespaceLines() {
        let doc = parse("\n\n  \n1\n00:00:01,000 --> 00:00:02,000\nA\n\n\n\n \t \n2\n00:00:02,000 --> 00:00:03,000\nB\n\n\n")
        XCTAssertEqual(doc.cues.map(\.lines), [["A"], ["B"]])
        XCTAssertTrue(doc.warnings.isEmpty)
    }

    func testGluedCuesWithoutBlankLine() {
        let doc = parse("1\n00:00:01,000 --> 00:00:02,000\nFirst\n2\n00:00:02,000 --> 00:00:03,000\nSecond\n")
        XCTAssertEqual(doc.cues.count, 2)
        XCTAssertEqual(doc.cues[0].lines, ["First"], "the next index must not leak into the text")
        XCTAssertEqual(doc.cues[1].identifier, "2")
        XCTAssertEqual(doc.cues[1].lines, ["Second"])
    }

    func testDotSeparatorAndShortFractions() {
        let doc = parse("1\n00:00:01.000 --> 00:00:02.500\nDots\n\n2\n00:00:03,25 --> 00:00:04,5\nShort\n")
        XCTAssertEqual(doc.cues.map(\.start), [1000, 3250])
        XCTAssertEqual(doc.cues.map(\.end), [2500, 4500])
    }

    func testHoursPastHundred() {
        let doc = parse("1\n99:59:59,999 --> 100:00:00,000\nA\n\n2\n123:45:06,789 --> 123:45:07,000\nB\n")
        XCTAssertEqual(doc.cues[0].start, 359_999_999)
        XCTAssertEqual(doc.cues[0].end, 360_000_000)
        XCTAssertEqual(doc.cues[1].start, 445_506_789)
    }

    func testOverlappingAndUnorderedCuesAreKept() {
        let doc = parse("1\n00:00:05,000 --> 00:00:08,000\nLater\n\n2\n00:00:01,000 --> 00:00:04,000\nA\n\n3\n00:00:02,000 --> 00:00:03,500\nB\n\n4\n00:00:02,000 --> 00:00:03,000\nC\n")
        XCTAssertEqual(doc.cues.count, 4, "never merged")
        XCTAssertEqual(doc.cues.map { $0.lines[0] }, ["Later", "A", "B", "C"], "source order kept in the model")
        XCTAssertEqual(doc.cuesByStart.map { $0.lines[0] }, ["A", "B", "C", "Later"], "stable start order: B before C")
    }

    func testMalformedCuesSkippedWithWarnings() {
        let doc = parse("1\n00:00:01,000 --> 00:00:0x,000\nBroken\n\n2\nNo timing here\n\n3\n00:00:05,000 --> 00:00:04,000\nBackwards\n\n4\n00:00:06,000 --> 00:00:07,000\nSurvivor\n")
        XCTAssertEqual(doc.cues.map(\.lines), [["Survivor"]])
        XCTAssertEqual(doc.warnings.count, 3, doc.warnings.map(\.description).joined(separator: "\n"))
        XCTAssertEqual(doc.warnings.first?.line, 2, "points at the broken timing line")
    }

    func testPositionSuffixIgnoredAndStylingKeptVerbatim() {
        let doc = parse("1\n00:00:01,000 --> 00:00:02,000  X1:100 X2:200 Y1:10 Y2:50\n{\\an8}<i>Top</i> <font color=\"red\">red</font>\n")
        XCTAssertEqual(doc.cues.first?.lines, ["{\\an8}<i>Top</i> <font color=\"red\">red</font>"])
        XCTAssertNil(doc.cues.first?.settings)
    }

    func testGarbageNeverCrashes() {
        let inputs = ["", "\n\n\n", "-->", "1\n-->\n", "\u{0}\u{1}\u{2}", String(repeating: "00:00:01,000 --> ", count: 50),
                      "1\n00:00:01,000 --> 00:00:02,000", "1\n00:00:01,000 -->\nx\n", "{\\an8", "<i", "&amp"]
        for s in inputs { _ = parse(s); _ = VTTParser.parse(text: s) }
        let random = Data((0..<4096).map { _ in UInt8.random(in: 0...255) })
        _ = SRTParser.parse(random)
        _ = VTTParser.parse(random)
    }
}

final class VTTParserTests: XCTestCase {
    private func parse(_ s: String) -> SubtitleDocument { VTTParser.parse(text: s) }

    func testHeaderBlocksAndCue() {
        let src = """
        WEBVTT - anyfmt edge cases
        Kind: captions
        Language: en

        STYLE
        ::cue(.loud) { color: #ff0000; }

        REGION
        id:fred
        width:40%

        NOTE This is a comment
        spanning two lines

        1
        00:00:01.000 --> 00:00:02.000 region:fred align:left
        <c.loud>Loud</c> and <v Bob>Bob</v>

        NOTE trailing note

        """
        let doc = parse(src)
        XCTAssertEqual(doc.header, ["WEBVTT - anyfmt edge cases", "Kind: captions", "Language: en"])
        XCTAssertEqual(doc.blocks.map(\.kind), [.style, .region, .note, .note])
        XCTAssertEqual(doc.blocks.map(\.beforeCue), [0, 0, 0, 1])
        XCTAssertEqual(doc.blocks[2].lines, ["NOTE This is a comment", "spanning two lines"])
        XCTAssertEqual(doc.cues.count, 1)
        XCTAssertEqual(doc.cues[0].identifier, "1")
        XCTAssertEqual(doc.cues[0].settings, "region:fred align:left")
        XCTAssertEqual(doc.cues[0].lines, ["<c.loud>Loud</c> and <v Bob>Bob</v>"])
        XCTAssertTrue(doc.warnings.isEmpty)
    }

    func testShortTimestampsAndLargeHours() {
        let doc = parse("WEBVTT\n\n01:02.003 --> 01:04.500\nA\n\n100:00:00.000 --> 100:00:01.000\nB\n")
        XCTAssertEqual(doc.cues.map(\.start), [62_003, 360_000_000])
        XCTAssertEqual(doc.cues.map(\.end), [64_500, 360_001_000])
    }

    func testCueWithoutBlankLineBefore() {
        let doc = parse("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nFirst\n00:00:02.000 --> 00:00:03.000\nSecond\n")
        XCTAssertEqual(doc.cues.map(\.lines), [["First"], ["Second"]])
    }

    func testHeaderDirectlyFollowedByCue() {
        let doc = parse("WEBVTT\n00:00:01.000 --> 00:00:02.000\nNo blank after header\n")
        XCTAssertEqual(doc.header, ["WEBVTT"])
        XCTAssertEqual(doc.cues.count, 1)
    }

    func testMissingSignatureWarnsButParses() {
        let doc = parse("00:00:01.000 --> 00:00:02.000\nNo signature\n")
        XCTAssertEqual(doc.cues.count, 1)
        XCTAssertEqual(doc.warnings.count, 1)
    }

    func testSignatureRules() {
        XCTAssertTrue(VTTParser.isSignature("WEBVTT"))
        XCTAssertTrue(VTTParser.isSignature("WEBVTT - title"))
        XCTAssertTrue(VTTParser.isSignature("WEBVTT\ttitle"))
        XCTAssertFalse(VTTParser.isSignature("WEBVTTX"))
        XCTAssertFalse(VTTParser.isSignature("webvtt"))
    }

    func testMalformedSkippedSurvivorKept() {
        let doc = parse("WEBVTT\n\n00:00:01.000 --> 00:00:xx.000\nBroken\n\njust some orphan text\n\n00:00:03.000 --> 00:00:04.000\nValid survivor\n")
        XCTAssertEqual(doc.cues.map(\.lines), [["Valid survivor"]])
        XCTAssertEqual(doc.warnings.count, 2)
    }

    func testBOMCRLFAndSettings() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("WEBVTT\r\n\r\n00:00:01.000 --> 00:00:02.000 line:0 align:start\r\nTop\r\n".utf8))
        let doc = VTTParser.parse(data)
        XCTAssertTrue(doc.hasBOM)
        XCTAssertEqual(doc.lineEnding, .crlf)
        XCTAssertEqual(doc.cues.first?.settings, "line:0 align:start")
    }

    func testNoteKeywordNeedsSeparator() {
        let doc = parse("WEBVTT\n\nNOTES\n00:00:01.000 --> 00:00:02.000\nText\n")
        XCTAssertTrue(doc.blocks.isEmpty, "NOTES is a cue identifier, not a NOTE block")
        XCTAssertEqual(doc.cues.first?.identifier, "NOTES")
    }
}
