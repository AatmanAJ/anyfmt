// DragSense: MIT licence, see LICENSE.
import AppKit
import os

/// The real ``InputSource``: public AppKit API only, and no TCC permission.
///
/// - Device state (`NSEvent.pressedMouseButtons`, `.mouseLocation`,
///   `.modifierFlags`) is live system state, documented as independent of
///   which events this app receives, and needs no permission.
/// - The drag pasteboard (`NSPasteboard(name: .drag)`) is readable across
///   processes with no permission; pasteboard privacy (macOS 15.4+) applies
///   to the general pasteboard only.
/// - Wake-ups come from global and local `NSEvent` monitors for left
///   mouse-down/dragged, which need no permission.
///
/// **Pasteboard reads.** The main thread only ever reads `changeCount` and
/// `types` (metadata). File URLs and promised types are read on a private
/// serial queue, because item data may come from a lazy provider in the drag
/// source and a hung source would otherwise freeze the host's main thread.
/// While that read is in flight, ``dragPasteboardChangeCount`` returns nil and
/// the main thread doesn't touch the pasteboard, so the `NSPasteboard` object
/// is only ever used by one thread at a time. A read that hasn't returned
/// after 5 s is treated as stalled: it's logged and the main thread resumes
/// change-count polling.
@MainActor
public final class SystemInputSource: InputSource {
    /// Whether a global `flagsChanged` monitor is also installed as a wake-up
    /// hint. Off by default: reports conflict on whether it needs a TCC grant
    /// on some macOS versions, and polling already catches every tap. When it
    /// works it trims up to one poll interval (~4 ms) off tap detection; it
    /// never feeds tap detection directly, it only triggers an extra poll.
    public let observesModifierEvents: Bool

    /// Pasteboard types that make a drag a file drag: the built-in set plus
    /// `NSFilePromiseReceiver.readableDraggedTypes`.
    public let fileTypes: Set<String>

    private let monitors = MonitorBag()
    private let readQueue = DispatchQueue(label: "DragSense.pasteboard-read", qos: .userInteractive)
    private var readsInFlight = 0
    private var readStartedAt: TimeInterval?
    private var reportedStall = false
    static let stalledReadInterval: TimeInterval = 5

    public init(observesModifierEvents: Bool = false) {
        self.observesModifierEvents = observesModifierEvents
        self.fileTypes = DragPasteboardType.fileTypes.union(NSFilePromiseReceiver.readableDraggedTypes)
    }

    deinit {
        let bag = monitors
        DispatchQueue.main.async { bag.removeAll() }
    }

    public var pressedMouseButtons: Int { NSEvent.pressedMouseButtons }
    public var mouseLocation: CGPoint { NSEvent.mouseLocation }
    public var modifierFlags: NSEvent.ModifierFlags { NSEvent.modifierFlags }

    public var dragPasteboardChangeCount: Int? {
        guard pasteboardIsFree else { return nil }
        return NSPasteboard(name: .drag).changeCount
    }

    public func dragPasteboardTypes() -> [String] {
        guard pasteboardIsFree else { return [] }
        return NSPasteboard(name: .drag).types?.map(\.rawValue) ?? []
    }

    public func readDragContents(completion: @escaping @MainActor @Sendable (DragPasteboardContents) -> Void) {
        readsInFlight += 1
        if readStartedAt == nil { readStartedAt = ProcessInfo.processInfo.systemUptime }
        readQueue.async { [weak self] in
            let started = ProcessInfo.processInfo.systemUptime
            let contents = Self.readContents()
            let elapsed = ProcessInfo.processInfo.systemUptime - started
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self?.readFinished(elapsed: elapsed, contents: contents)
                    completion(contents)
                }
            }
        }
    }

    public func screens() -> [ScreenInfo] {
        NSScreen.screens.map { screen in
            let menuBarBand = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
            return ScreenInfo(frame: screen.frame, topInset: max(menuBarBand, screen.safeAreaInsets.top))
        }
    }

    public func installWakeUpHandler(_ handler: @escaping @MainActor (WakeUpReason) -> Void) {
        removeWakeUpHandler()
        var mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged]
        if observesModifierEvents { mask.insert(.flagsChanged) }

        // Global monitors see other apps' events; local ones cover drags that
        // start in the host's own windows. Both are called on the main thread.
        if let token = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
            let reason = Self.reason(for: event.type)
            MainActor.assumeIsolated { handler(reason) }
        }) {
            monitors.append(token)
        }
        if let token = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            let reason = Self.reason(for: event.type)
            MainActor.assumeIsolated { handler(reason) }
            return event
        }) {
            monitors.append(token)
        }
        DragSenseLog.input.debug("wake-up monitors installed (flagsChanged hint: \(self.observesModifierEvents, privacy: .public))")
    }

    public func removeWakeUpHandler() {
        monitors.removeAll()
    }

    // MARK: Private

    private var pasteboardIsFree: Bool {
        guard let since = readStartedAt else { return true }
        guard ProcessInfo.processInfo.systemUptime - since > Self.stalledReadInterval else { return false }
        if !reportedStall {
            reportedStall = true
            DragSenseLog.input.error("drag pasteboard read stalled for over \(Self.stalledReadInterval, privacy: .public) s; resuming change-count polling")
        }
        return true
    }

    private func readFinished(elapsed: TimeInterval, contents: DragPasteboardContents) {
        readsInFlight = max(0, readsInFlight - 1)
        readStartedAt = readsInFlight == 0 ? nil : ProcessInfo.processInfo.systemUptime
        if readsInFlight == 0 { reportedStall = false }
        DragSenseLog.input.debug("drag pasteboard read: \(contents.fileURLs.count, privacy: .public) URLs, \(contents.promisedTypes.count, privacy: .public) promised types, \(contents.itemCount, privacy: .public) items in \(elapsed * 1000, format: .fixed(precision: 2), privacy: .public) ms")
    }

    nonisolated private static func reason(for type: NSEvent.EventType) -> WakeUpReason {
        switch type {
        case .leftMouseDown: return .mouseDown
        case .flagsChanged: return .modifiersChanged
        default: return .mouseDragged
        }
    }

    /// Runs on `readQueue`. Reads only `public.file-url` (via NSURL) and the
    /// promised content type, never other item data, so lazy providers for
    /// big payloads (images, rich text) are never called in.
    nonisolated private static func readContents() -> DragPasteboardContents {
        let pasteboard = NSPasteboard(name: .drag)
        let types = pasteboard.types ?? []
        let items = pasteboard.pasteboardItems ?? []

        var urls: [URL] = []
        if types.contains(.fileURL) || types.contains(NSPasteboard.PasteboardType(DragPasteboardType.legacyFilenames)) {
            let objects = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) ?? []
            urls = objects.compactMap { object in
                guard let url = object as? URL, url.isFileURL else { return nil }
                // Finder may write file-reference URLs (file:///.file/id=…).
                return (url as NSURL).filePathURL ?? url
            }
        }

        var promised: [String] = []
        let promiseType = NSPasteboard.PasteboardType(DragPasteboardType.promisedContentType)
        if types.contains(promiseType) {
            // Bounded: the wheel only needs the set of types, not one per item.
            for item in items.prefix(maxPromiseItemsInspected) {
                if let uti = item.string(forType: promiseType), !uti.isEmpty, !promised.contains(uti) {
                    promised.append(uti)
                }
            }
        }
        return DragPasteboardContents(fileURLs: urls, promisedTypes: promised, itemCount: items.count)
    }

    nonisolated static let maxPromiseItemsInspected = 256
}

/// Holds `NSEvent` monitor tokens. Only touched on the main thread; the
/// `@unchecked Sendable` lets `deinit` hand it back to the main queue.
private final class MonitorBag: @unchecked Sendable {
    private var tokens: [Any] = []

    func append(_ token: Any) { tokens.append(token) }

    func removeAll() {
        tokens.forEach(NSEvent.removeMonitor)
        tokens.removeAll()
    }
}
