import XCTest
import AnyfmtCore
@testable import AnyfmtApp

final class OptionsFormLogicTests: XCTestCase {
    typealias L = OptionsFormLogic

    // MARK: visibleWhen

    func testVisibleWhenFollowsControllerValue() {
        let schema = ToolSchemas.compress
        var values = schema.defaults
        func visible() -> [String] { L.visibleSpecs(schema, values).map(\.id) }

        XCTAssertEqual(visible(), [OptionKey.sizeMode, OptionKey.quality])
        values[OptionKey.sizeMode] = .string("size")
        XCTAssertEqual(visible(), [OptionKey.sizeMode, OptionKey.targetSize])
        values[OptionKey.sizeMode] = .string("percent")
        XCTAssertEqual(visible(), [OptionKey.sizeMode, OptionKey.percent])
    }

    func testVisibleWhenUsesDefaultWhenControllerMissing() {
        let schema = ToolSchemas.resize // mode defaults to "percent"
        let visible = L.visibleSpecs(schema, OptionValues()).map(\.id)
        XCTAssertEqual(visible, ["mode", OptionKey.percent])
    }

    func testVisibleWhenMatchesLooselyTypedValues() {
        let schema = OptionsSchema("t", [
            OptionSpec("n", "N", .integer(min: 0, max: 10, unit: nil), default: .int(0)),
            OptionSpec("b", "B", .toggle, default: .bool(false)),
            OptionSpec("onlyThree", "x", .text, default: .string(""), visibleWhen: ["n": .int(3)]),
            OptionSpec("onlyOn", "y", .text, default: .string(""), visibleWhen: ["b": .bool(true)]),
        ])
        var v = OptionValues(["n": .string("3"), "b": .string("true")])
        XCTAssertEqual(L.visibleSpecs(schema, v).map(\.id), ["n", "b", "onlyThree", "onlyOn"])
        v["n"] = .double(3.0)
        v["b"] = .int(0)
        XCTAssertEqual(L.visibleSpecs(schema, v).map(\.id), ["n", "b", "onlyThree"])
    }

    func testHiddenControllerHidesItsDependants() {
        let schema = OptionsSchema("chain", [
            OptionSpec("a", "A", .choice([OptionChoice("x", "X"), OptionChoice("y", "Y")]), default: .string("x")),
            OptionSpec("b", "B", .toggle, default: .bool(true), visibleWhen: ["a": .string("y")]),
            OptionSpec("c", "C", .text, default: .string(""), visibleWhen: ["b": .bool(true)]),
        ])
        // b defaults to true, but b itself is hidden while a == x, so c hides too.
        XCTAssertEqual(L.visibleSpecs(schema, OptionValues()).map(\.id), ["a"])
        XCTAssertEqual(L.visibleSpecs(schema, OptionValues(["a": .string("y")])).map(\.id), ["a", "b", "c"])
    }

    func testVisibleWhenOnUnknownKeyNeedsTheValue() {
        let schema = OptionsSchema("t", [OptionSpec("z", "Z", .text, default: .string(""), visibleWhen: ["other": .string("on")])])
        XCTAssertTrue(L.visibleSpecs(schema, OptionValues()).isEmpty)
        XCTAssertEqual(L.visibleSpecs(schema, OptionValues(["other": .string("on")])).count, 1)
    }

    // MARK: Coercion

    func testSliderClampsAndSnapsToStep() {
        let kind = OptionKind.slider(min: 5, max: 95, step: 5, unit: "%")
        XCTAssertEqual(L.coerce(.int(52), to: kind, default: .int(50)), .int(50))
        XCTAssertEqual(L.coerce(.int(53), to: kind, default: .int(50)), .int(55))
        XCTAssertEqual(L.coerce(.double(400), to: kind, default: .int(50)), .int(95))
        XCTAssertEqual(L.coerce(.string("1"), to: kind, default: .int(50)), .int(5))
        XCTAssertEqual(L.coerce(.string("nope"), to: kind, default: .int(50)), .int(50))
        XCTAssertEqual(L.coerce(nil, to: kind, default: .int(50)), .int(50))
    }

    func testIntegerAndFileSize() {
        XCTAssertEqual(L.coerce(.double(99.6), to: .integer(min: 0, max: 50, unit: "px"), default: .int(0)), .int(50))
        XCTAssertEqual(L.coerce(.int(-3), to: .integer(min: 0, max: 50, unit: nil), default: .int(0)), .int(0))
        XCTAssertEqual(L.coerce(.string("2500000"), to: .fileSize, default: .int(1)), .int(2_500_000))
        XCTAssertEqual(L.coerce(.int(-1), to: .fileSize, default: .int(1)), .int(0))
    }

    func testDecimalSnapsWithoutFloatNoise() {
        let kind = OptionKind.decimal(min: -2, max: 2, step: 0.05)
        XCTAssertEqual(L.coerce(.double(0.3000000004), to: kind, default: .double(0)), .double(0.3))
        XCTAssertEqual(L.coerce(.double(0.33), to: kind, default: .double(0)), .double(0.35))
        XCTAssertEqual(L.coerce(.int(9), to: kind, default: .double(0)), .double(2))
        XCTAssertEqual(L.decimals(for: 0.05), 2)
        XCTAssertEqual(L.decimals(for: 1), 0)
        XCTAssertEqual(L.decimals(for: 0.5), 1)
    }

    func testToggleAndChoiceCoercion() {
        XCTAssertEqual(L.coerce(.string("yes"), to: .toggle, default: .bool(false)), .bool(true))
        XCTAssertEqual(L.coerce(.int(0), to: .toggle, default: .bool(true)), .bool(false))
        XCTAssertEqual(L.coerce(.string("maybe"), to: .toggle, default: .bool(true)), .bool(true))

        let dpi = OptionKind.choice([OptionChoice("72", "72"), OptionChoice("300", "300")])
        XCTAssertEqual(L.coerce(.int(300), to: dpi, default: .string("72")), .string("300"))
        XCTAssertEqual(L.coerce(.double(72), to: dpi, default: .string("300")), .string("72"))
        XCTAssertEqual(L.coerce(.string("150"), to: dpi, default: .string("300")), .string("300"))
        // A default that isn't a valid choice falls back to the first choice.
        XCTAssertEqual(L.coerce(nil, to: dpi, default: .string("9")), .string("72"))
    }

    func testEffectiveValueUsesSpecDefault() {
        let spec = OptionSpec(OptionKey.quality, "Q", .slider(min: 1, max: 100, step: 1, unit: "%"), default: .int(85))
        XCTAssertEqual(L.effectiveValue(spec, in: OptionValues()), .int(85))
        XCTAssertEqual(L.effectiveValue(spec, in: OptionValues([OptionKey.quality: .string("70")])), .int(70))
    }

    func testNonDefaultKeepsOnlyChangesAndUnknownKeys() {
        let schema = StandardSchemas.imageLossy
        let values = schema.defaults.merging(OptionValues([OptionKey.quality: .int(70), "engineOnly": .bool(true)]))
        let diff = L.nonDefault(values, schema: schema)
        XCTAssertEqual(diff.values, [OptionKey.quality: .int(70), "engineOnly": .bool(true)])
        XCTAssertTrue(L.nonDefault(schema.defaults, schema: schema).values.isEmpty)
    }

    // MARK: Presentation helpers

    func testChoiceStyle() {
        XCTAssertEqual(L.choiceStyle([OptionChoice("a", "One"), OptionChoice("b", "Two")]), .segmented)
        let five = (1...5).map { OptionChoice("\($0)", "\($0)") }
        XCTAssertEqual(L.choiceStyle(five), .menu)
        XCTAssertEqual(L.choiceStyle([OptionChoice("a", "A very long label indeed")]), .menu)
    }

    func testFileSizeSplitAndJoin() {
        XCTAssertEqual(L.split(bytes: 1_500_000).value, 1.5)
        XCTAssertEqual(L.split(bytes: 1_500_000).unit, .mb)
        XCTAssertEqual(L.split(bytes: 640_000).unit, .kb)
        XCTAssertEqual(L.split(bytes: 3_000_000_000).unit, .gb)
        XCTAssertEqual(L.bytes(2.5, .mb), 2_500_000)
        XCTAssertEqual(L.bytes(-1, .kb), 0)
    }

    func testHexColourRoundTrip() throws {
        let c = try XCTUnwrap(L.parseHex("#6E56F8"))
        XCTAssertEqual(L.hex(c), "#6E56F8")
        XCTAssertEqual(L.hex(try XCTUnwrap(L.parseHex("6e56f880"))), "#6E56F880")
        XCTAssertEqual(L.hex(try XCTUnwrap(L.parseHex("#fff"))), "#FFFFFF")
        XCTAssertNil(L.parseHex("#12345"))
        XCTAssertNil(L.parseHex("purple"))
        XCTAssertNotNil(L.validateHex("#GG0000"))
        XCTAssertNil(L.validateHex("#00FF00"))
    }

    func testRectParseFormatValidate() {
        XCTAssertEqual(L.parseRect("0, 0.25,0.5 ,1"), [0, 0.25, 0.5, 1])
        XCTAssertNil(L.parseRect("1,2,3"))
        XCTAssertEqual(L.formatRect([0, 0.25, 0.5, 1]), "0,0.25,0.5,1")
        XCTAssertNil(L.validateRect("0,0,1,1"))
        XCTAssertNotNil(L.validateRect("0.5,0,0.6,1"))   // past the right edge
        XCTAssertNotNil(L.validateRect("0,0,0,1"))       // zero width
        XCTAssertNotNil(L.validateRect("0,0,2,1"))       // out of 0…1
    }

    func testPageAndTimeRangeValidation() {
        for ok in ["", "1", "1-3", "1-3,5", " 2 - 4 , 7 "] { XCTAssertNil(L.validatePageRange(ok), ok) }
        for bad in ["0", "a", "3-1", "1--2", "1,,2", "-3"] { XCTAssertNotNil(L.validatePageRange(bad), bad) }
        for ok in ["", "1.5-9.25", "0-10"] { XCTAssertNil(L.validateTimeRange(ok), ok) }
        for bad in ["9-2", "5", "a-b", "-1-4", "3-3"] { XCTAssertNotNil(L.validateTimeRange(bad), bad) }
    }

    func testDisplay() {
        XCTAssertEqual(L.display(85, decimals: 0, unit: "%"), "85%")
        XCTAssertEqual(L.display(16, decimals: 0, unit: "px"), "16 px")
        XCTAssertEqual(L.display(6, decimals: 0, unit: nil), "6")
    }
}
