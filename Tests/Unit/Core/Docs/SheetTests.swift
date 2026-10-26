import XCTest
@testable import AnyfmtCore

final class SheetTests: XCTestCase {
    private let date = Cell.isoDate("2024-03-15")!
    private let dateTime = Cell.isoDate("2024-03-15T13:45:30")!

    private var workbook: Workbook {
        Workbook(sheets: [
            Sheet(name: "Data", rows: [
                [.string("Name"), .string("Amount"), .string("When"), .string("OK"), .string("Note")],
                [.string("Smith, Jane"), .number(1234.5), date, .bool(true), .string("Said \"hi\"")],
                [.string("Zoë"), .number(-12), dateTime, .bool(false), .string("Line one\nline two")],
                [.string("007"), .number(0.1), .empty, .empty, .string("  padded  ")],
            ]),
            Sheet(name: "Other/Sheet?", rows: [[.string("x")], [.number(1)]]),
        ])
    }

    func testCellInference() {
        XCTAssertEqual(Cell.infer("42"), .number(42))
        XCTAssertEqual(Cell.infer("-1.5e3"), .number(-1500))
        XCTAssertEqual(Cell.infer("007"), .string("007"), "leading zeros are identifiers")
        XCTAssertEqual(Cell.infer("1234567890123456789"), .string("1234567890123456789"), "beyond double precision stays text")
        XCTAssertEqual(Cell.infer("TRUE"), .bool(true))
        XCTAssertEqual(Cell.infer("2024-03-15"), date)
        XCTAssertEqual(Cell.infer("9,5", decimalComma: true), .number(9.5))
        XCTAssertEqual(Cell.infer("01/02/2024"), .string("01/02/2024"), "ambiguous dates stay text")
        XCTAssertEqual(Cell.number(1.0).text, "1")
        XCTAssertEqual(Cell.number(0.1).text, "0.1")
    }

    func testCSVParsingEdgeCases() {
        let csv = "a,b,c\r\n\"x, y\",\"he said \"\"hi\"\"\",\"multi\nline\"\r\n1,,3\n\n"
        let rows = CSVReader.parse(csv, delimiter: ",")
        XCTAssertEqual(rows, [["a", "b", "c"], ["x, y", "he said \"hi\"", "multi\nline"], ["1", "", "3"]])
        XCTAssertEqual(CSVReader.parse("\u{FEFF}h1;h2\nv1;v2", delimiter: ";"), [["h1", "h2"], ["v1", "v2"]])
        XCTAssertEqual(CSVReader.sniff("a;b;c\n1;2;3\n4;5;6\n"), ";")
        XCTAssertEqual(CSVReader.sniff("a\tb\n1\t2\n"), "\t")
        XCTAssertEqual(CSVReader.sniff("name,desc\n\"a; b\",x\n"), ",", "delimiters inside quotes don't count")
        XCTAssertEqual(CSVReader.parse("a,\"\"\n", delimiter: ","), [["a", ""]])
        XCTAssertEqual(CSVReader.parse("only", delimiter: ","), [["only"]])
    }

    func testCSVWriterQuotesPerRFC4180() {
        let data = DelimitedWriter.write(workbook.sheets[0], delimiter: ",")
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("Name,Amount,When,OK,Note\r\n"))
        XCTAssertTrue(text.contains("\"Smith, Jane\",1234.5,2024-03-15,TRUE,\"Said \"\"hi\"\"\"\r\n"))
        XCTAssertTrue(text.contains("\"Line one\nline two\""))
        XCTAssertTrue(text.contains("\"  padded  \""))
        let back = CSVReader.read(data)
        XCTAssertEqual(back.rows[1][0], .string("Smith, Jane"))
        XCTAssertEqual(back.rows[2][4], .string("Line one\nline two"))
        XCTAssertEqual(back.rows[3][0], .string("007"))
        XCTAssertFalse(data.starts(with: [0xEF, 0xBB, 0xBF]), "no BOM by default")
        XCTAssertTrue(DelimitedWriter.write(workbook.sheets[0], delimiter: ",", bom: true).starts(with: [0xEF, 0xBB, 0xBF]))
    }

    func testXLSXRoundTripKeepsTypesDatesAndSheets() throws {
        let data = try XLSXWriter(zipOptions: .init(deterministic: true)).write(workbook)
        let zip = try ZipReader(data: data)
        for part in ["xl/workbook.xml", "xl/styles.xml", "xl/sharedStrings.xml", "xl/worksheets/sheet1.xml", "xl/worksheets/sheet2.xml", "[Content_Types].xml"] {
            XCTAssertNoThrow(try XMLTree.parse(zip.data(part)), part)
        }
        let wb = try XLSXReader.read(zip)
        XCTAssertEqual(wb.sheets.map(\.name), ["Data", "OtherSheet"], "invalid sheet name characters removed")
        let rows = wb.sheets[0].rows
        XCTAssertEqual(rows[1][1], .number(1234.5))
        XCTAssertEqual(rows[1][2], date)
        XCTAssertEqual(rows[2][2], dateTime)
        XCTAssertEqual(rows[1][3], .bool(true))
        XCTAssertEqual(rows[2][4], .string("Line one\nline two"))
        XCTAssertEqual(rows[3][0], .string("007"))
        XCTAssertEqual(rows[3][4], .string("  padded  "))
        XCTAssertTrue(try zip.text("xl/worksheets/sheet1.xml").contains("state=\"frozen\""), "header row frozen")
    }

    func testXLSXFixture() throws {
        let wb = try SheetIO.read(try DocsFixtures.url("sample.xlsx"), format: Formats.xlsx)
        XCTAssertEqual(wb.sheets.map(\.name), ["Inventory", "Notes"])
        let r = wb.sheets[0].rows
        XCTAssertEqual(r[0].map(\.text), ["Item", "Quantity", "Price", "Date", "In stock"])
        XCTAssertEqual(r[1][0], .string("Widget, large"))
        XCTAssertEqual(r[1][3], .date(Cell.date(fromExcelSerial: 45366), time: false))
        XCTAssertEqual(r[1][3].text, "2024-03-15")
        XCTAssertEqual(r[2][4], .bool(false))
        XCTAssertEqual(r[3][0], .string("Total"), "inline string")
        XCTAssertEqual(r[3][1], .number(15), "cached formula value")
        XCTAssertEqual(wb.sheets[1].rows[2][1], .string("Sparse cell"))
        XCTAssertEqual(wb.sheets[1].rows[1], [], "sparse rows are padded")
    }

    func testXLSFixtureBIFF8() throws {
        let wb = try SheetIO.read(try DocsFixtures.url("sample.xls"), format: Formats.xls)
        XCTAssertEqual(wb.sheets.map(\.name), ["Data", "Notes"])
        let r = wb.sheets[0].rows
        XCTAssertEqual(r.count, 302)
        guard r.count == 302, r[1].count >= 7, r[301].count >= 7 else { return XCTFail("\(r.prefix(3))") }
        XCTAssertEqual(r[0].map(\.text), ["Name", "Amount", "Count", "Date", "Active", "Doubled", "Label"])
        XCTAssertEqual(r[1][0], .string("Item 000"))
        XCTAssertEqual(r[1][1], .number(1.5), "NUMBER")
        XCTAssertEqual(r[1][2], .number(10), "RK integer")
        XCTAssertEqual(r[1][3].text, "2024-03-16", "custom yyyy-mm-dd FORMAT → date")
        XCTAssertEqual(r[1][4], .bool(true), "BOOLERR")
        XCTAssertEqual(r[1][5], .number(3), "cached FORMULA number")
        XCTAssertEqual(r[1][6], .string("from formula"), "FORMULA string result via STRING record")
        XCTAssertEqual(r[2][6], .string("inline label"), "LABEL")
        XCTAssertEqual(r[301][0], .string("Zoë café – ünïcødé"), "UTF-16 shared string")
        XCTAssertEqual(r[301][1], .number(7), "MULRK integer")
        XCTAssertEqual(r[301][2], .number(1), "MULRK float")
        XCTAssertEqual(r[301][6].text.count, 6003, "shared string split across CONTINUE records")
        XCTAssertEqual(wb.sheets[1].rows.map { $0.map(\.text) }, [["Notes sheet"], ["Ünïcødé note"]])
        // An HTML table saved as .xls (common web-app export) reads as a table.
        let html = try SheetIO.read(try DocsFixtures.url("edge-html-table.xls"), format: Formats.xls)
        XCTAssertEqual(html.sheets.first?.rows, [[.string("City"), .string("Pop")], [.string("Oslo"), .number(709000)]])
        XCTAssertThrowsError(try XLSReader.parse(Data([1, 2, 3, 4])))
        XCTAssertThrowsError(try CompoundFile(data: Data(count: 1024)))
    }

    func testRKDecoding() {
        XCTAssertEqual(XLSReader.rk(UInt32(bitPattern: (-5 << 2) | 0x02)), -5)
        XCTAssertEqual(XLSReader.rk((1234 << 2) | 0x03), 12.34, "integer ÷ 100")
        XCTAssertEqual(XLSReader.rk(0x3FF0_0000), 1.0)
        XCTAssertEqual(XLSReader.rk(0x3FF0_0001), 0.01, "float ÷ 100")
    }

    func testODSRoundTripAndFixtureRepeats() throws {
        let data = try ODSWriter(zipOptions: .init(deterministic: true)).write(workbook)
        let zip = try ZipReader(data: data)
        XCTAssertEqual(zip.entries.first?.path, "mimetype")
        let wb = try ODSReader.read(zip)
        XCTAssertEqual(wb.sheets[0].rows[1][1], .number(1234.5))
        XCTAssertEqual(wb.sheets[0].rows[1][2], date)
        XCTAssertEqual(wb.sheets[0].rows[2][2], dateTime)
        XCTAssertEqual(wb.sheets[0].rows[1][3], .bool(true))
        XCTAssertEqual(wb.sheets[0].rows[2][4], .string("Line one\nline two"))
        XCTAssertEqual(wb.sheets[0].rows[3][4], .string("  padded  "))
        let fx = try SheetIO.read(try DocsFixtures.url("sample.ods"), format: Formats.ods)
        XCTAssertEqual(fx.sheets.map(\.name), ["Scores", "Other"])
        XCTAssertEqual(fx.sheets[0].rows.count, 3, "a million repeated empty rows are trimmed")
        XCTAssertEqual(fx.sheets[0].columnCount, 4)
        XCTAssertEqual(fx.sheets[0].rows[1][1], .number(9.5))
        XCTAssertEqual(fx.sheets[0].rows[1][2], Cell.isoDate("2023-05-01"))
        XCTAssertEqual(fx.sheets[1].rows[0], [.number(0.25), .empty, .string("after covered")])
    }

    func testJSONReadWritePreservesKeyOrder() throws {
        let fx = try SheetIO.read(try DocsFixtures.url("sample.json"), format: Formats.json)
        let rows = fx.sheets[0].rows
        XCTAssertEqual(rows[0].map(\.text), ["name", "score", "active", "joined", "tags", "extra", "address"])
        XCTAssertEqual(rows.count, 4)
        guard rows.count == 4, rows[1].count > 4, rows[3].count > 6 else { return XCTFail("\(rows)") }
        XCTAssertEqual(rows[1][4], .string("[\"math\",\"engines\"]"))
        XCTAssertEqual(rows[2].count > 5 ? rows[2][5] : .empty, .empty, "null → empty (trailing empties trimmed)")
        XCTAssertEqual(rows[3][6], .string("{\"city\":\"Helsinki\"}"))
        XCTAssertEqual(rows[1][3], Cell.isoDate("2023-05-01"))
        let out = JSONTableWriter.write(workbook.sheets[0])
        let parsed = try JSONValue.parse(out)
        guard case .array(let items) = parsed, case .object(let first) = items[0] else { return XCTFail("array of objects") }
        XCTAssertEqual(first.map(\.0), ["Name", "Amount", "When", "OK", "Note"])
        XCTAssertEqual(first[1].1, .number(1234.5))
        XCTAssertEqual(first[3].1, .bool(true))
        // JSON parser handles escapes and surrogate pairs.
        XCTAssertEqual(try JSONValue.parse(Data(#"{"a":"é😀\n"}"#.utf8)), .object([("a", .string("é😀\n"))]))
        XCTAssertThrowsError(try JSONValue.parse(Data("{\"a\":}".utf8)))
    }

    func testHTMLAndPDFTables() async throws {
        let html = SheetHTMLWriter.html(workbook, print: false)
        XCTAssertTrue(html.contains("<thead>"))
        XCTAssertTrue(html.contains("<h2>Data</h2>"))
        XCTAssertTrue(html.contains("class=\"n\">1234.5"))
        let wide = Workbook(sheets: [Sheet(name: "W", rows: [Array(repeating: .string("column"), count: 12)])])
        XCTAssertTrue(SheetHTMLWriter.needsLandscape(wide))
        XCTAssertFalse(SheetHTMLWriter.needsLandscape(Workbook(sheets: [Sheet(name: "N", rows: [[.string("a"), .string("b")]])])))
        let out = try await runEngine(SheetsEngine(), try DocsFixtures.url("sample.xlsx"), from: Formats.xlsx, to: Formats.pdf)
        XCTAssertGreaterThanOrEqual(PDFKitPageCount(out[0]), 2, "each sheet starts a page")
    }

    func testSheetOptionAllWritesOneFilePerSheet() async throws {
        let url = try DocsFixtures.url("sample.xlsx")
        let first = try await runEngine(SheetsEngine(), url, from: Formats.xlsx, to: Formats.csv)
        XCTAssertEqual(first.count, 1)
        let all = try await runEngine(SheetsEngine(), url, from: Formats.xlsx, to: Formats.csv, options: OptionValues([OptionKey.sheet: .string("all")]))
        XCTAssertEqual(all.map(\.lastPathComponent), ["out - Inventory.csv", "out - Notes.csv"])
        let semicolon = try SheetIO.read(try DocsFixtures.url("edge-semicolon.csv"), format: Formats.csv)
        XCTAssertEqual(semicolon.sheets[0].rows[1], [.string("Ada"), .number(9.5)])
    }
}

func PDFKitPageCount(_ url: URL) -> Int {
    CGPDFDocument(url as CFURL)?.numberOfPages ?? 0
}
