import AppKit
import AnyfmtCore
import XCTest
@testable import AnyfmtApp

/// Main-thread cost of opening the wheel with the shipping provider, stage by
/// stage. The key → visible budget is 50 ms and the window server takes
/// 12–26 ms of it, so the main-thread part must stay well under 20 ms.
@MainActor
final class WheelShowPerfTests: XCTestCase {
    private func ms(_ block: () -> Void) -> Double {
        let start = ProcessInfo.processInfo.systemUptime
        block()
        return (ProcessInfo.processInfo.systemUptime - start) * 1000
    }

    func testShowStagesWithTheLiveProvider() throws {
        let pdf = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../Fixtures/generated/sample.pdf").standardized
        try XCTSkipUnless(FileManager.default.fileExists(atPath: pdf.path), "run make fixtures")
        let provider = WheelContentProvider.live()
        let input = WheelInput(urls: [pdf])

        Router.invalidateLive()
        let availability = ms { _ = Router.live() }
        let availabilityWarm = ms { _ = Router.live() }
        var entries: [WheelEntry] = []
        let resolve = ms { entries = provider.resolve(input, kind: .convert, preferences: .standard).entries }
        let hubIcon = ms { _ = WheelHub.icon(for: input) }
        let hubText = ms { _ = WheelHub.idleText(for: input) }
        let items = ms { _ = WheelContentProvider.items(for: entries, cloud: CloudSegments()) }

        let controller = WheelController(provider: provider)
        let prewarm = ms { controller.prewarm() }
        print(String(format: "PERF wheel stages resolve=%.2f hubIcon=%.2f hubText=%.2f items=%.2f prewarm=%.2f ms",
                     resolve, hubIcon, hubText, items, prewarm))
        let firstShow = ms { controller.show(kind: .convert, urls: [pdf], at: CGPoint(x: 600, y: 500)) }
        controller.hide(animated: false)
        let warmShow = ms { controller.show(kind: .convert, urls: [pdf], at: CGPoint(x: 600, y: 500)) }
        controller.hide(animated: false)

        print(String(format: "PERF wheel availability cold=%.2f ms cached=%.3f ms show first=%.2f warm=%.2f ms",
                     availability, availabilityWarm, firstShow, warmShow))
        XCTAssertLessThan(warmShow, 50, "a show alone would blow the 50 ms key → visible budget")
    }
}
