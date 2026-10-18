import XCTest
import HaloCore
@testable import HaloApp

final class DemoHitTestTests: XCTestCase {
    func testAngularSegments() {
        let n = 8
        // Straight up = segment 0, right = 2, down = 4, left = 6 (clockwise).
        XCTAssertEqual(DemoHitTest.index(of: CGPoint(x: 0, y: -80), count: n, deadZone: 30), 0)
        XCTAssertEqual(DemoHitTest.index(of: CGPoint(x: 80, y: 0), count: n, deadZone: 30), 2)
        XCTAssertEqual(DemoHitTest.index(of: CGPoint(x: 0, y: 80), count: n, deadZone: 30), 4)
        XCTAssertEqual(DemoHitTest.index(of: CGPoint(x: -80, y: 0), count: n, deadZone: 30), 6)
        // The whole wedge is the target, even far outside the ring.
        XCTAssertEqual(DemoHitTest.index(of: CGPoint(x: 600, y: 10), count: n, deadZone: 30), 2)
        // Just left of 12 o'clock still belongs to segment 0 (it straddles the top).
        XCTAssertEqual(DemoHitTest.index(of: CGPoint(x: -10, y: -80), count: n, deadZone: 30), 0)
    }

    func testHubIsADeadZone() {
        XCTAssertNil(DemoHitTest.index(of: CGPoint(x: 10, y: 10), count: 8, deadZone: 30))
        XCTAssertNil(DemoHitTest.index(of: .zero, count: 8, deadZone: 30))
        XCTAssertNil(DemoHitTest.index(of: CGPoint(x: 80, y: 0), count: 0, deadZone: 30))
    }

    func testMidAngleMatchesIndex() {
        for n in [1, 3, 6, 8, 12] {
            for i in 0..<n {
                let a = DemoHitTest.midAngle(i, count: n)
                let p = CGPoint(x: cos(a) * 90, y: sin(a) * 90)
                XCTAssertEqual(DemoHitTest.index(of: p, count: n, deadZone: 30), i, "n=\(n) i=\(i)")
            }
        }
    }
}

@MainActor
final class DemoModelTests: XCTestCase {
    private func makeDemo() throws -> (DemoModel, AppSettings, () -> Void) {
        let (settings, cleanup) = try makeSettings()
        return (DemoModel(settings: settings), settings, cleanup)
    }

    func testDragTapAndDropConverts() throws {
        let (demo, _, cleanup) = try makeDemo()
        defer { cleanup() }
        let home = DemoModel.homeCenter
        demo.dragChanged(start: home, location: CGPoint(x: home.x + 150, y: home.y))
        XCTAssertEqual(demo.phase, .dragging)
        XCTAssertEqual(demo.hint, .tapNow)

        // Tap Shift (the default Convert key) mid-drag.
        demo.flagsChanged([.shift], at: 1)
        demo.flagsChanged([], at: 1.1)
        XCTAssertEqual(demo.openKind, .convert)
        let centre = demo.wheelCenter

        // Move straight up from the wheel centre: segment 0 (JPG), then drop.
        let up = CGPoint(x: centre.x, y: centre.y - 80)
        demo.dragChanged(start: home, location: up)
        XCTAssertEqual(demo.highlighted, "jpg")
        demo.dragEnded(location: up)
        let result = try XCTUnwrap(demo.result)
        XCTAssertEqual(result.outputName, "Sample.jpg")
        XCTAssertTrue(result.title.contains("Sample.jpg"))
        XCTAssertEqual(demo.hint, .done)
    }

    func testWheelStaysOpenAfterKeyReleaseAndSwitchesKinds() throws {
        let (demo, _, cleanup) = try makeDemo()
        defer { cleanup() }
        let home = DemoModel.homeCenter
        demo.dragChanged(start: home, location: CGPoint(x: home.x + 120, y: home.y))
        demo.flagsChanged([.shift], at: 0)
        demo.flagsChanged([], at: 0.1)
        XCTAssertEqual(demo.openKind, .convert)
        demo.flagsChanged([.command], at: 1)
        demo.flagsChanged([], at: 1.1)
        XCTAssertEqual(demo.openKind, .tools, "tapping another key morphs the wheel in place")
        demo.flagsChanged([.control], at: 2)
        demo.flagsChanged([], at: 2.1)
        XCTAssertEqual(demo.openKind, .actions)
    }

    func testHoldAndChordDoNotOpenAWheel() throws {
        let (demo, _, cleanup) = try makeDemo()
        defer { cleanup() }
        let home = DemoModel.homeCenter
        demo.dragChanged(start: home, location: CGPoint(x: home.x + 100, y: home.y))
        demo.flagsChanged([.shift], at: 0)
        demo.flagsChanged([], at: 0.9)
        XCTAssertNil(demo.openKind)
        XCTAssertEqual(demo.hint, .held)
        demo.flagsChanged([.shift, .option], at: 2)
        demo.flagsChanged([], at: 2.1)
        XCTAssertNil(demo.openKind)
        XCTAssertEqual(demo.hint, .chord)
    }

    func testUsesRemappedKeysAndThreshold() throws {
        let (demo, settings, cleanup) = try makeDemo()
        defer { cleanup() }
        settings.convertKey = "option"
        settings.tapThreshold = 0.8
        let home = DemoModel.homeCenter
        demo.dragChanged(start: home, location: CGPoint(x: home.x + 100, y: home.y))
        demo.flagsChanged([.shift], at: 0)
        demo.flagsChanged([], at: 0.1)
        XCTAssertNil(demo.openKind)
        XCTAssertEqual(demo.hint, .unassigned(.shift))
        demo.flagsChanged([.option], at: 1)
        demo.flagsChanged([], at: 1.6) // under the relaxed 0.8 s threshold
        XCTAssertEqual(demo.openKind, .convert)
    }

    func testTapBeforeDraggingExplains() throws {
        let (demo, _, cleanup) = try makeDemo()
        defer { cleanup() }
        demo.flagsChanged([.shift], at: 0)
        demo.flagsChanged([], at: 0.1)
        XCTAssertNil(demo.openKind)
        XCTAssertEqual(demo.hint, .dragFirst)
    }

    func testDropInTheHubCancels() throws {
        let (demo, _, cleanup) = try makeDemo()
        defer { cleanup() }
        let home = DemoModel.homeCenter
        demo.dragChanged(start: home, location: CGPoint(x: home.x + 150, y: home.y))
        demo.flagsChanged([.control], at: 0)
        demo.flagsChanged([], at: 0.1)
        demo.dragEnded(location: demo.wheelCenter)
        XCTAssertNil(demo.result)
        XCTAssertEqual(demo.phase, .idle)
        XCTAssertEqual(demo.hint, .cancelled)
        XCTAssertEqual(demo.tileCenter, DemoModel.homeCenter)
    }

    func testDragThatMissesTheTileIsIgnored() throws {
        let (demo, _, cleanup) = try makeDemo()
        defer { cleanup() }
        demo.dragChanged(start: CGPoint(x: 600, y: 20), location: CGPoint(x: 620, y: 30))
        XCTAssertEqual(demo.phase, .idle)
    }

    func testAccessibilityPathAndActions() throws {
        let (demo, _, cleanup) = try makeDemo()
        defer { cleanup() }
        demo.openForAccessibility(.actions)
        XCTAssertEqual(demo.openKind, .actions)
        demo.select(ActionIDs.copyPath.rawValue)
        let r = try XCTUnwrap(demo.result)
        XCTAssertNil(r.outputName, "actions don't create files")
        XCTAssertEqual(r.segment.id, ActionIDs.copyPath.rawValue)
    }

    func testToolResultNamesUseTheToolSuffix() throws {
        let (demo, _, cleanup) = try makeDemo()
        defer { cleanup() }
        demo.openForAccessibility(.tools)
        demo.select(ToolIDs.compressImage.rawValue)
        XCTAssertEqual(demo.result?.outputName, "Sample-compressed.heic")
    }

    func testSegmentsAreLocalOnly() {
        XCTAssertEqual(DemoModel.segments(.actions).count, ActionCatalog.local.count)
        XCTAssertFalse(DemoModel.segments(.actions).contains { $0.id == ActionIDs.shareLink.rawValue })
        XCTAssertEqual(DemoModel.segments(.tools).count, 8)
        XCTAssertEqual(DemoModel.segments(.convert).first?.title, "JPG")
    }
}

@MainActor
final class OnboardingModelTests: XCTestCase {
    func testNavigationAndFinish() throws {
        let (settings, cleanup) = try makeSettings()
        defer { cleanup() }
        var finished = 0
        var updates: [Bool] = []
        let model = OnboardingModel(settings: settings, loginItem: LaunchAtLogin(service: .fake()),
                                    coach: PermissionsCoach(probe: .granted), info: SampleState.info,
                                    hooks: OnboardingHooks(onFinish: { finished += 1 }, onUpdateChecksChanged: { updates.append($0) }))
        var closed = false
        model.close = { closed = true }
        XCTAssertEqual(model.page, .demo)
        model.goBack()
        XCTAssertEqual(model.page, .demo)
        model.goNext(); model.goNext(); model.goNext()
        XCTAssertEqual(model.page, .updates)
        XCTAssertTrue(model.page.isLast)
        XCTAssertFalse(settings.updateChecksEnabled, "update checks stay off unless chosen")
        model.setUpdateChecks(true)
        XCTAssertEqual(updates, [true])
        model.goNext() // "Start Using Halo"
        XCTAssertTrue(settings.onboardingCompleted)
        XCTAssertTrue(closed)
        model.finish()
        XCTAssertEqual(finished, 1, "finish runs once")
    }

    func testSkipMarksCompleted() throws {
        let (settings, cleanup) = try makeSettings()
        defer { cleanup() }
        let model = OnboardingModel(settings: settings, loginItem: LaunchAtLogin(service: .fake()),
                                    coach: PermissionsCoach(probe: .granted), info: SampleState.info)
        model.finish()
        XCTAssertTrue(settings.onboardingCompleted)
        XCTAssertFalse(settings.updateChecksEnabled)
    }

    func testLaunchArgumentsResetOnboarding() throws {
        let (settings, cleanup) = try makeSettings()
        defer { cleanup() }
        settings.onboardingCompleted = true
        XCTAssertFalse(AppShellUI.handleLaunchArguments(["Halo", "--reset-onboarding"], settings: settings))
        XCTAssertFalse(settings.onboardingCompleted)
    }
}
