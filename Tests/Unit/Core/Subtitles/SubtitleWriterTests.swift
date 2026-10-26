import XCTest
@testable import AnyfmtCore

final class SubtitleWriterTests: XCTestCase {
    private func text(_ d: Data) -> String { String(decoding: d, as: UTF8.self) }

    // MARK: SRT → VTT

    func testSRTToVTTBasic() {
        let doc = SRTParser.parse(text: "1\n00:00:01,000 --> 00:00:02,500\nHello <i>world</i>\n\n2\n00:00:03,000 --> 00:00:04,000\nBye\n")
        XCTAssertEqual(text(VTTWriter.write(doc)), """
        WEBVTT

        00:00:01.000 --> 00:00:02.500
        Hello <i>world</i>

        00:00:03.000 --> 00:00:04.000
        Bye

        """)
    }

    func testSRTToVTTEscapesAndTags() {
        var styles = VTTStyleSheet()
        let c = SubtitleMarkup.srtToVTT(["a < b & c > d <3 --> x"], styles: &styles)
        XCTAssertEqual(c.lines, ["a &lt; b &amp; c &gt; d &lt;3 --&gt; x"])
        let tags = SubtitleMarkup.srtToVTT(["<I>up</I> <b>b</b> <u>u</u> <s>struck</s>"], styles: &styles)
        XCTAssertEqual(tags.lines, ["<i>up</i> <b>b</b> <u>u</u> struck"])
    }

    func testFontColoursBecomeClasses() {
        let doc = SRTParser.parse(text: "1\n00:00:01,000 --> 00:00:02,000\n<font color=\"red\">Red</font> <font color=\"#FF8800\">Orange</font> <font color='f80'>Same</font> <font face=\"Arial\">Face</font>\n")
        let out = text(VTTWriter.write(doc))
        XCTAssertTrue(out.contains("<c.red>Red</c> <c.c_ff8800>Orange</c> <c.c_ff8800>Same</c> Face"), out)
        XCTAssertTrue(out.contains("STYLE\n::cue(.c_ff8800) { color: #ff8800; }\n"), "one rule per colour, before the first cue")
        XCTAssertLessThan(out.range(of: "STYLE")?.lowerBound ?? out.endIndex, out.range(of: "-->")?.lowerBound ?? out.startIndex)
    }

    func testASSOverridesBecomeSettingsAndTags() {
        var styles = VTTStyleSheet()
        XCTAssertEqual(SubtitleMarkup.srtToVTT(["{\\an8}Top"], styles: &styles), .init(lines: ["Top"], settings: "line:0"))
        XCTAssertEqual(SubtitleMarkup.srtToVTT(["{\\an7}Top left"], styles: &styles).settings, "line:0 align:start")
        XCTAssertEqual(SubtitleMarkup.srtToVTT(["{\\an3}Bottom right"], styles: &styles).settings, "line:-1 align:end")
        XCTAssertEqual(SubtitleMarkup.srtToVTT(["{\\an5}Middle"], styles: &styles).settings, "line:50%")
        XCTAssertNil(SubtitleMarkup.srtToVTT(["{\\an2}Default"], styles: &styles).settings)
        XCTAssertEqual(SubtitleMarkup.srtToVTT(["{\\a6}Legacy top"], styles: &styles).settings, "line:0", "SSA a6 = numpad 8")
        XCTAssertEqual(SubtitleMarkup.srtToVTT(["{\\i1}it{\\i0} {\\b1}bo{\\b0} {\\pos(10,20)\\fs20}plain"], styles: &styles).lines,
                       ["<i>it</i> <b>bo</b> plain"])
        XCTAssertEqual(SubtitleMarkup.srtToVTT(["{not an override}"], styles: &styles).lines, ["{not an override}"])
    }

    func testSRTToVTTSortsByStartAndKeepsOverlaps() {
        let doc = SRTParser.parse(text: "1\n00:00:05,000 --> 00:00:08,000\nLater\n\n2\n00:00:01,000 --> 00:00:04,000\nA\n\n3\n00:00:02,000 --> 00:00:03,500\nB\n")
        let back = VTTParser.parse(VTTWriter.write(doc))
        XCTAssertEqual(back.cues.map { $0.lines[0] }, ["A", "B", "Later"])
        XCTAssertEqual(back.cues.map(\.start), [1000, 2000, 5000])
    }

    // MARK: VTT → SRT

    func testVTTToSRTDropsBlocksAndSettings() {
        let doc = VTTParser.parse(text: "WEBVTT - t\n\nSTYLE\n::cue(.loud) { color: #ff0000; background-color: black; }\n\nNOTE hi\n\nid1\n00:00:01.000 --> 00:00:02.000 region:fred align:left\n<c.loud>Loud</c> and <v Bob>Bob</v>\n")
        let out = text(SRTWriter.write(doc))
        XCTAssertEqual(out, "1\n00:00:01,000 --> 00:00:02,000\n<font color=\"#ff0000\">Loud</font> and Bob\n")
    }

    func testVTTEntitiesAndExoticTags() {
        let lines = SubtitleMarkup.vttToSRT(["Tom &amp; Jerry &lt;3 &gt; x&nbsp;y &#x2014; &#169; &bogus;",
                                             "<ruby>漢<rt>kan</rt></ruby> <00:00:02.500>karaoke <c.yellow.big>yellow</c>",
                                             "<lang en>Lang</lang> <b.loud>bold</b> <v.loud Ann>Ann</v>"],
                                            settings: nil, classColors: [:])
        XCTAssertEqual(lines, ["Tom & Jerry <3 > x\u{00A0}y — © &bogus;",
                               "漢 karaoke <font color=\"yellow\">yellow</font>",
                               "Lang <b>bold</b> Ann"])
    }

    func testSettingsToNumpad() {
        XCTAssertEqual(SubtitleMarkup.srtAlignment(fromSettings: "line:0"), 8)
        XCTAssertEqual(SubtitleMarkup.srtAlignment(fromSettings: "line:10%,start align:left"), 7)
        XCTAssertEqual(SubtitleMarkup.srtAlignment(fromSettings: "align:end line:50%"), 6)
        XCTAssertEqual(SubtitleMarkup.srtAlignment(fromSettings: "line:-1 align:start"), 1)
        XCTAssertEqual(SubtitleMarkup.srtAlignment(fromSettings: "line:90%"), 2)
        XCTAssertNil(SubtitleMarkup.srtAlignment(fromSettings: "align:start position:0%"), "no explicit line: no tag")
        XCTAssertNil(SubtitleMarkup.srtAlignment(fromSettings: nil))
        let top = SubtitleMarkup.vttToSRT(["Top"], settings: "line:0", classColors: [:])
        XCTAssertEqual(top, ["{\\an8}Top"])
        XCTAssertEqual(SubtitleMarkup.vttToSRT(["Bottom"], settings: "line:90%", classColors: [:]), ["Bottom"])
    }

    func testVTTToSRTKeepsLineEndingAndBOM() {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(Data("WEBVTT\r\n\r\n00:00:01.000 --> 00:00:02.000\r\nA\r\n\r\n00:00:02.000 --> 00:00:03.000\r\nB\r\n".utf8))
        let out = SRTWriter.write(VTTParser.parse(data))
        XCTAssertEqual([UInt8](out.prefix(3)), [0xEF, 0xBB, 0xBF])
        XCTAssertEqual(text(out.dropFirst(3)), "1\r\n00:00:01,000 --> 00:00:02,000\r\nA\r\n\r\n2\r\n00:00:02,000 --> 00:00:03,000\r\nB\r\n")
    }

    func testCueThatBecomesEmptyStaysWellFormed() {
        let doc = VTTParser.parse(text: "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n<v Bob></v>\n\n00:00:03.000 --> 00:00:04.000\nNext\n")
        let srt = SRTWriter.write(doc)
        let back = SRTParser.parse(srt)
        XCTAssertEqual(back.cues.count, 2)
        XCTAssertEqual(back.cues[1].lines, ["Next"])
    }

    // MARK: VTT → VTT is lossless

    func testVTTRoundTripIsVerbatim() {
        let src = "WEBVTT - Title\nKind: captions\n\nSTYLE\n::cue(.a) { color: lime; }\n\nREGION\nid:r\n\nNOTE one\n\nintro\n00:00:01.000 --> 00:00:02.000 line:0 align:start\n<c.a>Hi</c> &amp; <v Bob>yo</v>\n\n00:00:02.000 --> 00:00:03.000\nSecond\n\nNOTE end\n"
        XCTAssertEqual(text(VTTWriter.write(VTTParser.parse(text: src))), src)
    }

    // MARK: Round trips

    func testSRTToVTTToSRTPreservesTimingAndText() {
        let src = """
        1
        00:00:00,001 --> 00:00:01,999
        <i>Italic</i>, <b>bold</b>, <u>under</u>

        2
        00:00:02,000 --> 00:00:03,000
        <font color="red">Red</font> & <font color="#ff8800">orange</font>

        3
        00:00:03,000 --> 00:00:04,000
        {\\an8}Top of the screen

        4
        00:00:03,500 --> 00:00:05,000
        Overlap a < b
        second line

        5
        123:45:06,789 --> 123:45:07,000
        Hundred hours

        """
        let srt = SRTParser.parse(text: src)
        let vtt = VTTParser.parse(VTTWriter.write(srt))
        let again = SRTParser.parse(SRTWriter.write(vtt))
        XCTAssertEqual(again.cues.map(\.start), srt.cues.map(\.start))
        XCTAssertEqual(again.cues.map(\.end), srt.cues.map(\.end))
        XCTAssertEqual(again.cues.map(\.lines), srt.cues.map(\.lines))
        XCTAssertTrue(vtt.warnings.isEmpty && again.warnings.isEmpty)
    }

    func testVTTToSRTToVTTPreservesTiming() {
        let src = "WEBVTT\n\n00:00:01.000 --> 00:00:02.000 line:0\nTop\n\n01:00:00.010 --> 01:00:00.020\nA &amp; B\n"
        let vtt = VTTParser.parse(text: src)
        let back = VTTParser.parse(VTTWriter.write(SRTParser.parse(SRTWriter.write(vtt))))
        XCTAssertEqual(back.cues.map(\.start), [1000, 3_600_010])
        XCTAssertEqual(back.cues.map(\.end), [2000, 3_600_020])
        XCTAssertEqual(back.cues.map(\.lines), [["Top"], ["A &amp; B"]])
        XCTAssertEqual(back.cues[0].settings, "line:0", "top placement survives via {\\an8}")
    }

    // MARK: TXT

    func testTranscriptStripsMarkup() {
        let doc = SRTParser.parse(text: "1\n00:00:01,000 --> 00:00:02,000\n{\\an8}<i>Hello</i> <font color=\"red\">there</font>,\nfriend\n\n2\n00:00:03,000 --> 00:00:04,000\na < b <3\n")
        XCTAssertEqual(text(SubtitleTextWriter.write(doc, timestamps: false)), "Hello there, friend\na < b <3\n")
        XCTAssertEqual(text(SubtitleTextWriter.write(doc, timestamps: true)), "[00:00:01] Hello there, friend\n[00:00:03] a < b <3\n")
    }

    func testTranscriptFromVTTDecodesAndDedupesRollingCaptions() {
        let doc = VTTParser.parse(text: "WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nso today we are going\n\n00:00:02.000 --> 00:00:04.000\nso today we are going\nto talk &amp; <c>chat</c>\n\n00:00:04.000 --> 00:00:06.000\nto talk &amp; <c>chat</c>\nand why\n\n00:00:06.000 --> 00:00:07.000\nand why\n")
        XCTAssertEqual(text(SubtitleTextWriter.write(doc, timestamps: false)), "so today we are going\nto talk & chat\nand why\n")
    }

    func testOverlapHelper() {
        XCTAssertEqual(SubtitleTextWriter.overlap(["a", "b"], ["b", "c"]), 1)
        XCTAssertEqual(SubtitleTextWriter.overlap(["a", "b"], ["a", "b"]), 2)
        XCTAssertEqual(SubtitleTextWriter.overlap(["a"], ["b"]), 0)
        XCTAssertEqual(SubtitleTextWriter.overlap([], ["b"]), 0)
    }

    func testStyleSheetColourParsing() {
        var s = VTTStyleSheet()
        XCTAssertEqual(s.className(forColor: "Yellow"), "yellow")
        XCTAssertEqual(s.className(forColor: "#ABC"), "c_aabbcc")
        XCTAssertEqual(s.className(forColor: "orange"), "c_orange")
        XCTAssertNil(s.className(forColor: "rgb(1,2,3)"))
        XCTAssertNil(s.className(forColor: "#12345"))
        XCTAssertEqual(s.styleBlock, ["STYLE", "::cue(.c_aabbcc) { color: #aabbcc; }", "::cue(.c_orange) { color: orange; }"])
    }

    func testClassColoursFromStyleBlocksIgnoreBackground() {
        let blocks = [SubtitleBlock(kind: .style, lines: ["STYLE", "::cue(.x) { background-color: black; color: #00ff00; }", "::cue(.y) { background-color: red }"], beforeCue: 0)]
        XCTAssertEqual(SubtitleMarkup.classColors(from: blocks), ["x": "#00ff00"])
    }
}
