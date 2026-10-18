// DragSense: MIT licence, see LICENSE.
import XCTest
@testable import DragSense

/// Drag detection from the drag pasteboard: baselines, stale contents,
/// types, promises and slow reads.
@MainActor
final class PasteboardTests: XCTestCase {
    func testLateWakeUpStillDetectsDragViaIdleBaseline() {
        let h = Harness()
        // No mouse-down event reaches us (missed wake-up). The drag starts and
        // Finder writes the pasteboard between two idle polls.
        h.mouseDown(wake: false)
        h.move(40)
        h.writeFileDrag()
        XCTAssertEqual(h.sense.state, .idle)
        h.run(0.25) // the next idle poll
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
        h.tap(.shift)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "convert"))
    }

    func testLateWakeUpWaivesMinimumDistanceBecausePressPointIsUnknown() {
        let h = Harness()
        h.mouseDown(wake: false)
        h.writeFileDrag() // pointer stopped by the time we look
        h.run(0.25)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
    }

    func testStalePasteboardWithUnchangedChangeCountNeverTriggers() {
        let h = Harness()
        // The drag pasteboard still holds a previous drag's file URLs.
        h.sys.types = [DragPasteboardType.fileURL]
        h.sys.contents = DragPasteboardContents(fileURLs: Harness.sampleURLs, itemCount: 2)
        h.run(0.5)
        h.mouseDown()
        h.move(50)
        h.ticks(20)
        h.tap(.shift)
        XCTAssertTrue(h.events.isEmpty, "\(h.events)")
        XCTAssertEqual(h.sense.state, .idle)
        XCTAssertEqual(h.sys.readCount, 0, "contents never read for a stale pasteboard")
    }

    func testPasteboardChangeWithButtonUpIsIgnoredAndBecomesTheBaseline() {
        let h = Harness()
        h.writeFileDrag() // e.g. a drag that ended, or a programmatic write
        h.run(0.25)
        XCTAssertEqual(h.sense.state, .idle)
        h.mouseDown()
        h.move(20)
        h.ticks(10)
        XCTAssertEqual(h.sense.state, .idle, "the change happened with the button up")
        XCTAssertTrue(h.events.isEmpty)
    }

    func testNonFileDragIsIgnored() {
        let h = Harness()
        h.mouseDown()
        h.move(10)
        h.sys.changeCount += 1
        h.sys.types = ["public.utf8-plain-text", "public.rtf"]
        h.ticks(30)
        h.tap(.shift)
        XCTAssertTrue(h.events.isEmpty)
        XCTAssertEqual(h.sys.readCount, 0)
    }

    func testNonFileDragTypesAreNotRecheckedForever() {
        let h = Harness()
        h.mouseDown()
        h.move(10)
        h.sys.changeCount += 1
        h.sys.types = ["public.utf8-plain-text"]
        h.ticks(100) // one second of text drag
        XCTAssertLessThanOrEqual(h.sys.typesReadCount, 20, "types re-read only during the settle window")
    }

    func testNonFileDragAcceptedWhenFileTypesNotRequired() {
        let h = Harness(Harness.configuration { $0.requireFileTypes = false })
        h.mouseDown()
        h.move(10)
        h.sys.changeCount += 1
        h.sys.types = ["public.utf8-plain-text"]
        h.ticks(1)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
        XCTAssertEqual(h.dragBeganInfos.first?.fileURLs, [])
    }

    func testPromiseOnlyDragIsAcceptedWithPromisedTypes() throws {
        let h = Harness()
        h.mouseDown()
        h.move(10)
        h.sys.changeCount += 1
        h.sys.types = [DragPasteboardType.promisedFileURL, DragPasteboardType.promisedContentType]
        h.sys.contents = DragPasteboardContents(fileURLs: [], promisedTypes: ["public.jpeg"], itemCount: 3)
        h.ticks(1)
        let info = try XCTUnwrap(h.dragBeganInfos.first)
        XCTAssertTrue(info.isPromiseOnly)
        XCTAssertEqual(info.promisedTypes, ["public.jpeg"])
        XCTAssertEqual(info.itemCount, 3)
        h.tap(.control)
        XCTAssertEqual(h.sense.state, .wheelOpen(triggerID: "actions"))
    }

    func testTypesWrittenJustAfterTheBumpAreStillDetected() {
        let h = Harness()
        h.mouseDown()
        h.move(10)
        h.sys.changeCount += 1 // clearContents first...
        h.sys.types = []
        h.ticks(3)
        XCTAssertEqual(h.sense.state, .idle)
        h.sys.types = [DragPasteboardType.fileURL] // ...then the write
        h.sys.contents = DragPasteboardContents(fileURLs: Harness.sampleURLs, itemCount: 2)
        h.ticks(1)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
    }

    func testSecondBumpAfterRejectionIsReevaluated() {
        let h = Harness()
        h.mouseDown()
        h.move(10)
        h.sys.changeCount += 1
        h.sys.types = ["public.utf8-plain-text"]
        h.ticks(50)
        h.writeFileDrag()
        h.ticks(1)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 52))
    }

    func testMinimumDragDistanceIsRequired() {
        let h = Harness()
        h.mouseDown()
        h.move(2) // an app that writes the drag pasteboard on mouse-down
        h.writeFileDrag()
        h.ticks(10)
        XCTAssertEqual(h.sense.state, .idle)
        h.move(2) // now 4 pt from the press point
        h.ticks(1)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
    }

    func testUnavailableChangeCountIsSkippedNotGuessed() {
        let h = Harness()
        h.mouseDown()
        h.move(10)
        h.sys.changeCountAvailable = false
        h.writeFileDrag()
        h.ticks(10)
        XCTAssertEqual(h.sense.state, .idle)
        h.sys.changeCountAvailable = true
        h.ticks(1)
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))
    }

    // MARK: Slow reads

    func testSlowReadHoldsTapUntilContentsArrive() {
        let h = Harness()
        h.sys.readsAreManual = true
        h.beginFileDrag()
        XCTAssertEqual(h.sense.state, .idle, "not announced until the contents are in")
        h.tap(.shift, ticksHeld: 5)
        XCTAssertTrue(h.events.isEmpty)
        h.sys.completePendingReads()
        XCTAssertEqual(h.states, [.dragging(dragID: 51), .wheelOpen(triggerID: "convert")])
        XCTAssertEqual(h.dragBeganInfos.first?.fileURLs, Harness.sampleURLs)
        guard case .triggerTapped(_, let info, _)? = h.events.last else { return XCTFail() }
        XCTAssertEqual(info.fileURLs, Harness.sampleURLs)
    }

    func testReadTimeoutContinuesWithPartialInfoAndLateResultFillsIn() throws {
        let h = Harness(Harness.configuration { $0.pasteboardReadTimeout = 0.1 })
        h.sys.readsAreManual = true
        h.beginFileDrag()
        h.ticks(10)
        let info = try XCTUnwrap(h.dragBeganInfos.first)
        XCTAssertTrue(info.isPartial)
        XCTAssertEqual(info.fileURLs, [])
        XCTAssertEqual(h.sense.state, .dragging(dragID: 51))

        h.sys.completePendingReads()
        XCTAssertEqual(h.sense.currentDrag?.fileURLs, Harness.sampleURLs)
        XCTAssertEqual(h.sense.currentDrag?.isPartial, false)
        h.tap(.shift)
        guard case .triggerTapped(_, let tapped, _)? = h.events.last else { return XCTFail() }
        XCTAssertEqual(tapped.fileURLs, Harness.sampleURLs)
    }

    func testDragEndingBeforeReadCompletesIsSilentAndLateResultIgnored() {
        let h = Harness()
        h.sys.readsAreManual = true
        h.beginFileDrag()
        h.mouseUp()
        h.ticks(1)
        h.sys.completePendingReads()
        XCTAssertTrue(h.events.isEmpty)
        XCTAssertEqual(h.sense.state, .idle)
    }

    func testContentsAreReadOncePerDrag() {
        let h = Harness()
        h.openWheel()
        h.ticks(100)
        h.tap(.command)
        XCTAssertEqual(h.sys.readCount, 1)
    }

    func testFileDragClassifier() {
        XCTAssertTrue(DragPasteboardType.isFileDrag(["public.file-url"]))
        XCTAssertTrue(DragPasteboardType.isFileDrag(["com.apple.pasteboard.promised-file-content-type"]))
        XCTAssertTrue(DragPasteboardType.isFileDrag(["NSFilenamesPboardType"]))
        XCTAssertFalse(DragPasteboardType.isFileDrag(["public.url", "public.utf8-plain-text", "public.jpeg"]))
        XCTAssertFalse(DragPasteboardType.isFileDrag([]))
    }
}
