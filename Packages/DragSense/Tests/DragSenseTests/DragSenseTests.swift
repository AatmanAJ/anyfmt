import XCTest
@testable import DragSense

final class DragSensePlaceholderTests: XCTestCase {
    func testVersion() { XCTAssertFalse(DragSenseVersion.string.isEmpty) }
}
