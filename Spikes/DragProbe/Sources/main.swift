// DragProbe — Phase 0 spike. Runs every candidate detection approach side by
// side and logs which one sees the drag / modifier tap first.
//
//   swift run -c release DragProbe                 interactive probe (drag files from Finder, tap Shift/Cmd/Ctrl)
//   swift run -c release DragProbe --selftest      overlay show→visible latency, no input needed
//   swift run -c release DragProbe --idle-cpu 20   CPU cost of the idle watcher over N seconds
//   swift run -c release DragProbe --request-listen  ask for Input Monitoring (CGEventTap test)
//   swift run -c release DragProbe --finder-selection  read Finder selection via Apple Events
//
// Spike code: prints are intentional here (this target never ships).
import AppKit
import ApplicationServices
import Darwin

// MARK: - Logging

@MainActor
enum Log {
    static let start = ProcessInfo.processInfo.systemUptime
    static var fileHandle: FileHandle? = {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DragProbe.log")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        return try? FileHandle(forWritingTo: url)
    }()

    static func line(_ s: String) {
        let t = (ProcessInfo.processInfo.systemUptime - start) * 1000
        let l = String(format: "%9.2fms  ", t) + s
        print(l)
        fileHandle?.write(Data((l + "\n").utf8))
    }
}

func ms(_ seconds: TimeInterval) -> String { String(format: "%.2fms", seconds * 1000) }

// MARK: - Tap detector (shared by both sources)

/// Distinguishes a *tap* (press + release within `threshold`, no other
/// modifier joined in) from a hold. Fed by either source.
struct TapDetector {
    var threshold: TimeInterval = 0.35
    private var downAt: [UInt: TimeInterval] = [:]
    private var spoiled: Set<UInt> = []
    private var last: NSEvent.ModifierFlags = []

    static let watched: [(NSEvent.ModifierFlags, String)] = [
        (.shift, "shift"), (.command, "command"), (.control, "control"), (.option, "option"),
    ]

    /// Returns names of modifiers that completed a tap at `time`.
    mutating func feed(_ flags: NSEvent.ModifierFlags, at time: TimeInterval) -> [String] {
        let flags = flags.intersection([.shift, .command, .control, .option])
        var taps: [String] = []
        for (flag, name) in Self.watched {
            let was = last.contains(flag), now = flags.contains(flag)
            if !was && now {
                downAt[flag.rawValue] = time
                // Another modifier already held: this is a chord, not a tap.
                if !last.isEmpty { spoiled.insert(flag.rawValue) }
                for other in downAt.keys where other != flag.rawValue { spoiled.insert(other) }
            } else if was && !now {
                if let t0 = downAt.removeValue(forKey: flag.rawValue),
                   !spoiled.contains(flag.rawValue), time - t0 <= threshold {
                    taps.append(name)
                }
                spoiled.remove(flag.rawValue)
            }
        }
        last = flags
        return taps
    }
}

// MARK: - Overlay

final class DropView: NSView {
    var onDrop: (([URL], Int) -> Void)?
    var onHover: ((Int) -> Void)?
    private var hover = -1
    let segments = 6

    override init(frame: NSRect) {
        super.init(frame: frame)
        let promiseTypes = NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) }
        registerForDraggedTypes([.fileURL, .URL] + promiseTypes)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError("spike") }

    private func segment(at p: NSPoint) -> Int {
        let c = NSPoint(x: bounds.midX, y: bounds.midY)
        let dx = p.x - c.x, dy = p.y - c.y
        if hypot(dx, dy) < 40 { return -1 } // hub dead zone = cancel
        var a = atan2(dy, dx) // -pi...pi, 0 = east
        a = (CGFloat.pi / 2 - a) // clockwise from north
        if a < 0 { a += 2 * .pi }
        return Int(a / (2 * .pi / CGFloat(segments))) % segments
    }

    override func draw(_ dirtyRect: NSRect) {
        let c = NSPoint(x: bounds.midX, y: bounds.midY)
        let r = min(bounds.width, bounds.height) / 2 - 4
        for i in 0..<segments {
            let span = 360.0 / CGFloat(segments)
            let start = 90 - CGFloat(i) * span, end = start - span
            let p = NSBezierPath()
            p.appendArc(withCenter: c, radius: r, startAngle: start - 1, endAngle: end + 1, clockwise: true)
            p.appendArc(withCenter: c, radius: 40, startAngle: end + 1, endAngle: start - 1, clockwise: false)
            p.close()
            (i == hover ? NSColor.controlAccentColor : NSColor.windowBackgroundColor.withAlphaComponent(0.85)).setFill()
            p.fill()
            NSColor.separatorColor.setStroke()
            p.stroke()
        }
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        Log.line("overlay: draggingEntered (source app owns session; destination works)")
        return draggingUpdated(sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let s = segment(at: convert(sender.draggingLocation, from: nil))
        if s != hover { hover = s; needsDisplay = true; onHover?(s) }
        return s < 0 ? [] : .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        Log.line("overlay: draggingExited")
        hover = -1; needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pb = sender.draggingPasteboard
        let urls = (pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        let promises = (pb.readObjects(forClasses: [NSFilePromiseReceiver.self], options: nil) as? [NSFilePromiseReceiver]) ?? []
        Log.line("overlay: DROP segment=\(hover) urls=\(urls.map(\.lastPathComponent)) promises=\(promises.count) types=\(pb.types?.map(\.rawValue) ?? [])")
        if !promises.isEmpty {
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent("DragProbePromises", isDirectory: true)
            try? FileManager.default.createDirectory(at: dest, withIntermediateDirectories: true)
            for p in promises {
                p.receivePromisedFiles(atDestination: dest, options: [:], operationQueue: .main) { url, err in
                    Log.line("overlay: promise resolved -> \(url.path) err=\(String(describing: err))")
                }
            }
        }
        onDrop?(urls, hover)
        return hover >= 0
    }
}

final class OverlayPanel: NSPanel {
    init(size: CGFloat) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: size, height: size),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        let v = DropView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        contentView = v
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    var dropView: DropView? { contentView as? DropView }
}

// MARK: - Probe

@MainActor
final class Probe: NSObject, NSApplicationDelegate {
    let args: [String]
    let overlay = OverlayPanel(size: 320)

    // Approach A: polling
    private var pollTimer: DispatchSourceTimer?
    private var pollHz: Double = 0
    private var pollTaps = TapDetector()
    private var buttonDown = false
    private var baselineChange = 0
    private var dragging = false
    private var dragStartedAt: TimeInterval = 0
    // Approach B: global monitors
    private var monitors: [Any] = []
    private var monitorTaps = TapDetector()
    private var draggedEventsThisPress = 0
    // Latency bookkeeping
    private var pendingShowAt: TimeInterval?
    private var pendingTrigger: TimeInterval?
    private var latencies: [TimeInterval] = []

    init(args: [String]) { self.args = args }

    func applicationDidFinishLaunching(_ n: Notification) {
        Log.line("DragProbe on macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        Log.line("permissions: AXIsProcessTrusted=\(AXIsProcessTrusted()) ListenEvent=\(CGPreflightListenEventAccess()) PostEvent=\(CGPreflightPostEventAccess())")
        NotificationCenter.default.addObserver(self, selector: #selector(occlusionChanged),
                                               name: NSWindow.didChangeOcclusionStateNotification, object: overlay)
        overlay.dropView?.onDrop = { [weak self] urls, seg in
            Log.line("probe: dropped \(urls.count) file(s) on segment \(seg)")
            self?.hideOverlay()
        }
        overlay.dropView?.onHover = { seg in Log.line("probe: hover segment \(seg)") }

        if args.contains("--selftest") { runSelfTest(); return }
        if let i = args.firstIndex(of: "--idle-cpu"), i + 1 < args.count, let secs = Double(args[i + 1]) {
            startPolling(); installMonitors(); measureIdleCPU(seconds: secs); return
        }
        if args.contains("--request-listen") {
            Log.line("CGRequestListenEventAccess -> \(CGRequestListenEventAccess())")
        }
        if args.contains("--finder-selection") { readFinderSelection() }
        installMonitors()
        installEventTapIfAllowed()
        startPolling()
        Log.line("ready: drag a file from Finder and tap Shift / Command / Control")
    }

    // MARK: A — polling

    private func startPolling() { setPollRate(20) }

    private func setPollRate(_ hz: Double) {
        guard hz != pollHz else { return }
        pollHz = hz
        pollTimer?.cancel()
        let t = DispatchSource.makeTimerSource(queue: .main)
        let interval = 1.0 / hz
        // Generous leeway while idle lets the OS coalesce wakeups.
        t.schedule(deadline: .now(), repeating: interval, leeway: hz > 60 ? .microseconds(500) : .milliseconds(25))
        t.setEventHandler { [weak self] in MainActor.assumeIsolated { self?.poll() } }
        t.resume()
        pollTimer = t
    }

    private func poll() {
        let now = ProcessInfo.processInfo.systemUptime
        let down = NSEvent.pressedMouseButtons & 1 == 1
        let pb = NSPasteboard(name: .drag)
        if down && !buttonDown {
            buttonDown = true
            baselineChange = pb.changeCount
            setPollRate(240)
        } else if !down && buttonDown {
            buttonDown = false
            if dragging { Log.line("A(poll): drag ended after \(ms(now - dragStartedAt))") }
            dragging = false
            setPollRate(20)
            if overlay.isVisible { Log.line("A(poll): mouse up with overlay open (drop or cancel)") ; hideOverlay() }
        }
        if buttonDown && !dragging && pb.changeCount != baselineChange {
            dragging = true
            dragStartedAt = now
            let t0 = ProcessInfo.processInfo.systemUptime
            let urls = (pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
            let readCost = ProcessInfo.processInfo.systemUptime - t0
            Log.line("A(poll): DRAG START changeCount \(baselineChange)->\(pb.changeCount) files=\(urls.map(\.lastPathComponent)) read=\(ms(readCost)) types=\(pb.types?.map(\.rawValue).prefix(8).joined(separator: ",") ?? "-")")
        }
        guard buttonDown else { return }
        for tap in pollTaps.feed(NSEvent.modifierFlags, at: now) {
            Log.line("A(poll): TAP \(tap) dragging=\(dragging)")
            if dragging { showOverlay(trigger: now, source: "poll") }
        }
    }

    // MARK: B — NSEvent global monitors

    private func installMonitors() {
        let mouse: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        if let m = NSEvent.addGlobalMonitorForEvents(matching: mouse, handler: { [weak self] e in
            MainActor.assumeIsolated { self?.mouseEvent(e) }
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in
            MainActor.assumeIsolated { self?.flagsEvent(e) }
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { e in
            MainActor.assumeIsolated { Log.line("B(monitor): keyDown keyCode=\(e.keyCode) (implies Accessibility granted)") }
        }) { monitors.append(m) }
        Log.line("B(monitor): installed \(monitors.count) global monitors")
    }

    private func mouseEvent(_ e: NSEvent) {
        switch e.type {
        case .leftMouseDown: draggedEventsThisPress = 0; Log.line("B(monitor): leftMouseDown")
        case .leftMouseDragged:
            draggedEventsThisPress += 1
            if draggedEventsThisPress == 1 || draggedEventsThisPress % 60 == 0 {
                Log.line("B(monitor): leftMouseDragged #\(draggedEventsThisPress) (still delivered during drag session)")
            }
        case .leftMouseUp: Log.line("B(monitor): leftMouseUp after \(draggedEventsThisPress) dragged events")
        default: break
        }
    }

    private func flagsEvent(_ e: NSEvent) {
        let now = ProcessInfo.processInfo.systemUptime
        Log.line("B(monitor): flagsChanged flags=0x\(String(e.modifierFlags.rawValue, radix: 16)) eventAge=\(ms(now - e.timestamp))")
        for tap in monitorTaps.feed(e.modifierFlags, at: e.timestamp) {
            Log.line("B(monitor): TAP \(tap) dragging=\(dragging)")
            if dragging { showOverlay(trigger: e.timestamp, source: "monitor") }
        }
    }

    // MARK: C — CGEventTap (listen-only), only if Input Monitoring granted

    private func installEventTapIfAllowed() {
        guard CGPreflightListenEventAccess() else {
            Log.line("C(eventtap): skipped, Input Monitoring not granted (run with --request-listen)")
            return
        }
        let mask = (1 << CGEventType.flagsChanged.rawValue) | (1 << CGEventType.leftMouseDragged.rawValue)
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .listenOnly, eventsOfInterest: CGEventMask(mask),
                                          callback: { _, type, event, _ in
            if type == .flagsChanged {
                let flags = event.flags.rawValue
                DispatchQueue.main.async { MainActor.assumeIsolated { Log.line("C(eventtap): flagsChanged 0x\(String(flags, radix: 16))") } }
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: nil) else {
            Log.line("C(eventtap): tapCreate failed")
            return
        }
        let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        Log.line("C(eventtap): listen-only tap installed")
    }

    // MARK: Overlay timing

    private func showOverlay(trigger: TimeInterval, source: String) {
        guard !overlay.isVisible else {
            Log.line("probe: \(source) tap while open -> would switch wheel")
            return
        }
        var origin = NSEvent.mouseLocation
        origin.x -= overlay.frame.width / 2
        origin.y -= overlay.frame.height / 2
        pendingTrigger = trigger
        pendingShowAt = ProcessInfo.processInfo.systemUptime
        overlay.setFrameOrigin(origin)
        overlay.orderFrontRegardless()
        Log.line("probe: overlay ordered front (\(source)), trigger→orderFront \(ms(pendingShowAt! - trigger))")
    }

    private func hideOverlay() { overlay.orderOut(nil) }

    @objc private func occlusionChanged(_ n: Notification) {
        guard overlay.occlusionState.contains(.visible), let t = pendingTrigger, let s = pendingShowAt else { return }
        let now = ProcessInfo.processInfo.systemUptime
        latencies.append(now - t)
        Log.line("probe: overlay VISIBLE trigger→visible \(ms(now - t)) orderFront→visible \(ms(now - s))")
        pendingTrigger = nil; pendingShowAt = nil
    }

    // MARK: Self test

    private func runSelfTest() {
        Log.line("selftest: 60 show/hide cycles, measuring orderFront → window-server-visible")
        var i = 0
        func step() {
            if i == 60 { report(); NSApp.terminate(nil); return }
            i += 1
            let screen = NSScreen.main?.visibleFrame ?? .init(x: 0, y: 0, width: 1440, height: 900)
            let p = NSPoint(x: screen.minX + CGFloat.random(in: 200...(screen.width - 200)),
                            y: screen.minY + CGFloat.random(in: 200...(screen.height - 200)))
            pendingTrigger = ProcessInfo.processInfo.systemUptime
            pendingShowAt = pendingTrigger
            overlay.setFrameOrigin(NSPoint(x: p.x - 160, y: p.y - 160))
            overlay.orderFrontRegardless()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                self?.overlay.orderOut(nil)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { step() }
            }
        }
        step()
    }

    private func report() {
        let s = latencies.sorted()
        guard !s.isEmpty else { Log.line("selftest: no visibility notifications received"); return }
        func pct(_ p: Double) -> TimeInterval { s[min(s.count - 1, Int(Double(s.count) * p))] }
        Log.line("selftest: n=\(s.count) p50=\(ms(pct(0.5))) p95=\(ms(pct(0.95))) max=\(ms(s.last!))")
    }

    // MARK: Idle CPU

    private func measureIdleCPU(seconds: Double) {
        func cpu() -> Double {
            var u = rusage(); getrusage(RUSAGE_SELF, &u)
            return Double(u.ru_utime.tv_sec + u.ru_stime.tv_sec) + Double(u.ru_utime.tv_usec + u.ru_stime.tv_usec) / 1e6
        }
        let c0 = cpu(), t0 = ProcessInfo.processInfo.systemUptime
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            let used = cpu() - c0, wall = ProcessInfo.processInfo.systemUptime - t0
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)
            _ = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count) }
            }
            Log.line(String(format: "idle-cpu: %.4fs CPU over %.1fs wall = %.3f%% of one core, rss=%.1fMB", used, wall, used / wall * 100, Double(info.resident_size) / 1_048_576))
            NSApp.terminate(nil)
        }
    }

    // MARK: Finder selection (Apple Events; needs Automation consent)

    private func readFinderSelection() {
        let src = """
        tell application "Finder"
          set out to {}
          repeat with i in (get selection)
            set end of out to POSIX path of (i as alias)
          end repeat
          return out
        end tell
        """
        var err: NSDictionary?
        let t0 = ProcessInfo.processInfo.systemUptime
        let result = NSAppleScript(source: src)?.executeAndReturnError(&err)
        let paths = (0..<(result?.numberOfItems ?? 0)).compactMap { result?.atIndex($0 + 1)?.stringValue }
        Log.line("finder-selection: \(paths) err=\(String(describing: err)) in \(ms(ProcessInfo.processInfo.systemUptime - t0))")
    }
}

@MainActor enum Holder { static var delegate: Probe? }

MainActor.assumeIsolated {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    Holder.delegate = Probe(args: CommandLine.arguments)
    app.delegate = Holder.delegate
    app.run()
}
