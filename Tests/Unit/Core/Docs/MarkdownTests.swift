import XCTest
@testable import HaloCore

final class MarkdownTests: XCTestCase {
    private func blocks(_ md: String) -> [DocBlock] { MarkdownReader.parse(md).blocks }
    private func inlines(_ md: String) -> [DocInline] {
        guard case .paragraph(let i)? = blocks(md).first else { XCTFail("no paragraph for \(md)"); return [] }
        return i
    }

    func testATXAndSetextHeadings() {
        let b = blocks("# One\n## Two ##\n###### Six\n####### seven\n\nSetext 1\n===\n\nSetext 2\n---\n")
        XCTAssertEqual(b[0], .heading(level: 1, [.text("One")]))
        XCTAssertEqual(b[1], .heading(level: 2, [.text("Two")]))
        XCTAssertEqual(b[2], .heading(level: 6, [.text("Six")]))
        XCTAssertEqual(b[3], .paragraph([.text("####### seven")]))
        XCTAssertEqual(b[4], .heading(level: 1, [.text("Setext 1")]))
        XCTAssertEqual(b[5], .heading(level: 2, [.text("Setext 2")]))
        XCTAssertEqual(blocks("#notaheading"), [.paragraph([.text("#notaheading")])])
    }

    func testEmphasisStrongAndDelimiterRules() {
        XCTAssertEqual(inlines("*a* **b** ***c***"), [.emphasis([.text("a")]), .text(" "), .strong([.text("b")]), .text(" "), .emphasis([.strong([.text("c")])])], "CommonMark: ***x*** is <em><strong>")
        XCTAssertEqual(inlines("_a_ __b__"), [.emphasis([.text("a")]), .text(" "), .strong([.text("b")])])
        // Intraword underscores stay literal; intraword asterisks emphasise.
        XCTAssertEqual(inlines("snake_case_name"), [.text("snake_case_name")])
        XCTAssertEqual(inlines("un*frigging*believable"), [.text("un"), .emphasis([.text("frigging")]), .text("believable")])
        XCTAssertEqual(inlines("*a **b** c*"), [.emphasis([.text("a "), .strong([.text("b")]), .text(" c")])])
        XCTAssertEqual(inlines("2 * 3 * 4"), [.text("2 * 3 * 4")], "spaced asterisks aren't emphasis")
        XCTAssertEqual(inlines("~~gone~~"), [.strikethrough([.text("gone")])])
        XCTAssertEqual(inlines("**unclosed"), [.text("**unclosed")])
    }

    func testCodeSpansLinksImagesAutolinks() {
        XCTAssertEqual(inlines("`a*b*`"), [.code("a*b*")])
        XCTAssertEqual(inlines("`` a ` b ``"), [.code("a ` b")])
        XCTAssertEqual(inlines("[x](https://e.org \"t\")"), [.link(url: "https://e.org", [.text("x")])])
        XCTAssertEqual(inlines("[x](<a b.html>)"), [.link(url: "a b.html", [.text("x")])])
        XCTAssertEqual(inlines("[x](u(1))"), [.link(url: "u(1)", [.text("x")])])
        XCTAssertEqual(inlines("<https://halo.example/a>"), [.link(url: "https://halo.example/a", [.text("https://halo.example/a")])])
        XCTAssertEqual(inlines("<me@example.com>"), [.link(url: "mailto:me@example.com", [.text("me@example.com")])])
        XCTAssertEqual(inlines("see https://example.org/x."), [.text("see "), .link(url: "https://example.org/x", [.text("https://example.org/x")]), .text(".")])
        XCTAssertEqual(inlines("[*em* link](/u)"), [.link(url: "/u", [.emphasis([.text("em")]), .text(" link")])])
        guard case .image(let im)? = blocks("![alt text](https://remote/x.png)").first else { return XCTFail("image block") }
        XCTAssertEqual(im.alt, "alt text")
        XCTAssertNil(im.data, "remote images are never fetched")
        XCTAssertEqual(im.source, "https://remote/x.png")
        XCTAssertEqual(inlines("[not a link]"), [.text("[not a link]")])
    }

    func testReferenceLinks() {
        let b = blocks("A [full][r], [collapsed][], and [shortcut].\n\n[r]: https://r.example\n[collapsed]: /c\n[SHORTCUT]: /s \"T\"\n")
        XCTAssertEqual(b.count, 1)
        XCTAssertEqual(b[0], .paragraph([.text("A "), .link(url: "https://r.example", [.text("full")]), .text(", "),
                                          .link(url: "/c", [.text("collapsed")]), .text(", and "), .link(url: "/s", [.text("shortcut")]), .text(".")]))
    }

    func testEscapesEntitiesAndBreaks() {
        XCTAssertEqual(inlines("\\*not\\* &amp; &copy; &#65; &#x42;"), [.text("*not* & © A B")])
        XCTAssertEqual(inlines("line one  \nline two"), [.text("line one"), .lineBreak, .text("line two")])
        XCTAssertEqual(inlines("line one\\\nline two"), [.text("line one"), .lineBreak, .text("line two")])
        XCTAssertEqual(inlines("soft\nbreak"), [.text("soft break")])
        XCTAssertEqual(inlines("a<br>b"), [.text("a"), .lineBreak, .text("b")])
    }

    func testListsNestedOrderedTasks() {
        let b = blocks("- a\n- b\n  - b1\n    1. deep\n- c\n\n7. seven\n8. eight\n\n- [x] done\n- [ ] todo\n")
        guard case .list(let ul) = b[0] else { return XCTFail("bullet list") }
        XCTAssertFalse(ul.ordered)
        XCTAssertEqual(ul.items.count, 3)
        guard case .list(let nested) = ul.items[1].blocks[1] else { return XCTFail("nested list") }
        XCTAssertEqual(nested.items[0].blocks[0], .paragraph([.text("b1")]))
        guard case .list(let deep) = nested.items[0].blocks[1] else { return XCTFail("deep list") }
        XCTAssertTrue(deep.ordered)
        guard case .list(let ol) = b[1] else { return XCTFail("ordered list") }
        XCTAssertEqual(ol.start, 7)
        XCTAssertEqual(ol.items.count, 2)
        guard case .list(let tasks) = b[2] else { return XCTFail("task list") }
        XCTAssertEqual(tasks.items.map(\.checked), [true, false])
        XCTAssertEqual(tasks.items[0].blocks, [.paragraph([.text("done")])])
        // Different bullet characters start a new list.
        XCTAssertEqual(blocks("- a\n+ b\n").count, 2)
        // A number other than 1 can't interrupt a paragraph.
        XCTAssertEqual(blocks("text\n2. not a list\n"), [.paragraph([.text("text 2. not a list")])])
    }

    func testCodeBlocksQuotesRulesTables() {
        let b = blocks("```swift\nlet x = 1\n\n  indented\n```\n\n    four spaces\n    more\n\n> quote **b**\n> > nested\n\n***\n\n| A | B |\n|:--|--:|\n| 1 | `x\\|y` |\n| 2 |\n")
        XCTAssertEqual(b[0], .codeBlock(language: "swift", "let x = 1\n\n  indented"))
        XCTAssertEqual(b[1], .codeBlock(language: nil, "four spaces\nmore"))
        guard case .blockquote(let q) = b[2] else { return XCTFail("quote") }
        XCTAssertEqual(q[0], .paragraph([.text("quote "), .strong([.text("b")])]))
        guard case .blockquote = q[1] else { return XCTFail("nested quote") }
        XCTAssertEqual(b[3], .horizontalRule)
        guard case .table(let t) = b[4] else { return XCTFail("table") }
        XCTAssertEqual(t.alignments, [.left, .right])
        XCTAssertEqual(t.rows.count, 3)
        XCTAssertTrue(t.rows[0].isHeader)
        XCTAssertEqual(t.rows[1].cells[1].blocks, [.paragraph([.code("x|y")])])
        XCTAssertEqual(t.rows[2].cells.count, 2, "short rows are padded")
    }

    func testFootnotesAreKeptNotSwallowed() {
        let doc = MarkdownReader.parse("Claim one[^a] and two[^b].\n\n[^a]: First source.\n[^b]: Second source\n    with a second line.\n\n[^nope] stays literal.\n")
        XCTAssertEqual(doc.blocks[0], .paragraph([.text("Claim one[1] and two[2].")]))
        XCTAssertEqual(doc.blocks[1], .paragraph([.text("[^nope] stays literal.")]))
        XCTAssertEqual(doc.blocks[2], .horizontalRule)
        guard case .list(let notes) = doc.blocks[3] else { return XCTFail("notes list: \(doc.blocks)") }
        XCTAssertTrue(notes.ordered)
        XCTAssertEqual(notes.items.map { $0.blocks.map(\.plainText).joined() }, ["First source.", "Second source with a second line."])
    }

    func testFrontMatterAndHTMLBlock() {
        let doc = MarkdownReader.parse("---\ntitle: \"My: Doc\"\nauthor: Me\n---\n\n<div>\n<p>Raw <b>html</b></p>\n</div>\n\nAfter.\n")
        XCTAssertEqual(doc.metadata.title, "My: Doc")
        XCTAssertEqual(doc.metadata.author, "Me")
        XCTAssertEqual(doc.blocks.first, .paragraph([.text("Raw "), .strong([.text("html")])]))
        XCTAssertEqual(doc.blocks.last, .paragraph([.text("After.")]))
    }

    func testWriterRoundTripsTheModel() {
        let doc = richDoc(image: false)
        let md = MarkdownWriter().write(doc)
        let back = MarkdownReader.parse(md)
        XCTAssertEqual(back.metadata.title, "Rich Doc")
        let expected = doc.blocks.map { b -> DocBlock in if case .table(let t) = b { return .table(t.normalized) }; return b }
        XCTAssertEqual(back.blocks, expected, "\n\(md)")
    }

    func testWriterEscapesAndEmbedsImages() {
        let doc = DocModel(blocks: [
            .paragraph([.text("1. not a list, *not em*, a|b, <tag>")]),
            .paragraph([.image(DocImage(data: samplePNG(), mime: "image/png", alt: "pic"))]),
        ])
        let md = MarkdownWriter().write(doc)
        let back = MarkdownReader.parse(md)
        XCTAssertEqual(back.blocks[0], .paragraph([.text("1. not a list, *not em*, a|b, <tag>")]), md)
        guard case .image(let im) = back.blocks[1] else { return XCTFail("image survives as data URI") }
        XCTAssertEqual(im.mime, "image/png")
        XCTAssertNotNil(im.data)
        XCTAssertFalse(MarkdownWriter(images: .omit).write(doc).contains("data:image"))
    }

    func testFixtureParsesEveryConstruct() throws {
        let url = try DocsFixtures.url("sample.md")
        let doc = try DocumentIO.read(url, format: Formats.md)
        XCTAssertEqual(doc.metadata.title, "Halo Markdown Sample")
        XCTAssertEqual(doc.headings().map(\.1), ["Halo Markdown Sample", "Setext heading", "Lists", "Table"])
        XCTAssertNotNil(doc.firstTable())
        XCTAssertEqual(doc.lists().count, 2)
        XCTAssertEqual(doc.allImages.first?.data != nil, true, "relative image resolved next to the file")
        XCTAssertTrue(doc.blocks.contains { if case .codeBlock("swift", _) = $0 { return true }; return false })
        XCTAssertTrue(doc.blocks.contains(.horizontalRule))
        XCTAssertTrue(doc.text.contains("*not emphasis*"))
        XCTAssertTrue(doc.blocks.contains { b in
            if case .paragraph(let i) = b { return i.contains(.link(url: "https://example.com/ref", [.text("example")])) }
            return false
        })
    }
}
