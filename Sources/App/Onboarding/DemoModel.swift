import AppKit
import SwiftUI
import HaloCore

/// The three wheels of the demo.
enum DemoWheelKind: String, CaseIterable, Sendable {
    case convert, tools, actions

    init(_ role: TriggerRole) {
        switch role {
        case .convert: self = .convert
        case .tools: self = .tools
        case .actions: self = .actions
        }
    }

    var role: TriggerRole {
        switch self {
        case .convert: .convert
        case .tools: .tools
        case .actions: .actions
        }
    }
}

struct DemoSegment: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let glyph: String
}

/// What a demo wheel view needs to draw itself.
struct DemoWheelContext {
    let kind: DemoWheelKind
    let segments: [DemoSegment]
    let highlighted: DemoSegment.ID?
    /// Pointer relative to the wheel centre, in points.
    let pointer: CGPoint
    let thumbnail: NSImage
    let reduceMotion: Bool
    /// Ring radii the demo hit-tests against.
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    /// Called when VoiceOver (or a click) picks a segment directly.
    let select: (DemoSegment.ID) -> Void
}

/// Angular hit testing, the same rule as the real wheel: the whole wedge is
/// the target, and the hub is a dead zone that cancels.
enum DemoHitTest {
    /// Segment 0 is centred at 12 o'clock; segments run clockwise.
    static func index(of point: CGPoint, count: Int, deadZone: CGFloat) -> Int? {
        guard count > 0, hypot(point.x, point.y) > deadZone else { return nil }
        // atan2 with y pointing down (SwiftUI): 0 at 3 o'clock, clockwise positive.
        var a = atan2(point.y, point.x) + .pi / 2      // 0 at 12 o'clock
        let slice = 2 * .pi / CGFloat(count)
        a += slice / 2                                  // segment 0 straddles 12 o'clock
        a = a.truncatingRemainder(dividingBy: 2 * .pi)
        if a < 0 { a += 2 * .pi }
        return min(count - 1, Int(a / slice))
    }

    /// Centre angle of segment `i` (radians, SwiftUI orientation).
    static func midAngle(_ i: Int, count: Int) -> CGFloat {
        -.pi / 2 + 2 * .pi * CGFloat(i) / CGFloat(max(count, 1))
    }
}

/// State machine of the onboarding mini-demo: drag the sample tile, tap a
/// trigger key, drop on a segment. Uses the same tap rule as the real drag
/// sensor (press + release within the threshold, no other key).
@MainActor
final class DemoModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case dragging
        case wheel(DemoWheelKind)
        case result(Result)
    }

    struct Result: Equatable {
        let kind: DemoWheelKind
        let segment: DemoSegment
        let title: String
        let detail: String
        /// A new file appears beside the original (conversions and tools).
        let outputName: String?
        let outputBadge: String?
    }

    enum Hint: Equatable {
        case start, tapNow, chooseSegment, held, chord, unassigned(TriggerKey), dragFirst, cancelled, done
    }

    enum Staging { case wheel(DemoWheelKind), done }

    static let stageSize = CGSize(width: DesignTokens.Component.Onboarding.stageWidth,
                                  height: DesignTokens.Component.Onboarding.stageHeight)
    static let fileName = "Sample.heic"
    /// The demo ring is a touch smaller than the real one so it fits the window.
    static let scale: CGFloat = 0.9
    static var innerRadius: CGFloat { DesignTokens.Wheel.ringInner * scale }
    static var outerRadius: CGFloat { DesignTokens.Wheel.ringOuter * scale }
    static var deadZone: CGFloat { DesignTokens.Wheel.hubDeadZone * scale }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var hint: Hint = .start
    /// Centre of the sample tile in stage coordinates.
    @Published private(set) var tileCenter: CGPoint
    @Published private(set) var wheelCenter: CGPoint = .zero
    @Published private(set) var pointer: CGPoint = .zero
    @Published private(set) var highlighted: DemoSegment.ID?
    /// Key currently held as a possible tap (lights its legend cap).
    @Published private(set) var pressing: TriggerKey?

    let settings: AppSettings
    let thumbnail: NSImage
    private var detector: ModifierTapDetector
    private var grabOffset: CGSize = .zero
    private var monitor: LocalKeyMonitor?

    init(settings: AppSettings) {
        self.settings = settings
        self.detector = ModifierTapDetector(threshold: settings.tapThreshold)
        self.tileCenter = Self.homeCenter
        self.thumbnail = SampleArtwork.thumbnail(size: 168)
    }

    static var homeCenter: CGPoint { CGPoint(x: stageSize.width * 0.26, y: stageSize.height * 0.4) }
    static var resultCenter: CGPoint { CGPoint(x: stageSize.width * 0.66, y: stageSize.height * 0.4) }

    var triggers: TriggerAssignment {
        TriggerAssignment(convert: TriggerKey.parse(settings.convertKey, fallback: .shift),
                          tools: TriggerKey.parse(settings.toolsKey, fallback: .command),
                          actions: TriggerKey.parse(settings.actionsKey, fallback: .control))
    }

    var openKind: DemoWheelKind? {
        if case .wheel(let k) = phase { return k }
        return nil
    }

    var result: Result? {
        if case .result(let r) = phase { return r }
        return nil
    }

    // MARK: Segments

    static func segments(_ kind: DemoWheelKind) -> [DemoSegment] {
        switch kind {
        case .convert:
            return [
                DemoSegment(id: "jpg", title: "JPG", glyph: "photo"),
                DemoSegment(id: "png", title: "PNG", glyph: "square.on.square.dashed"),
                DemoSegment(id: "webp", title: "WebP", glyph: "globe"),
                DemoSegment(id: "avif", title: "AVIF", glyph: "photo.artframe"),
                DemoSegment(id: "pdf", title: "PDF", glyph: "doc.richtext"),
                DemoSegment(id: "tiff", title: "TIFF", glyph: "printer"),
                DemoSegment(id: "gif", title: "GIF", glyph: "photo.stack"),
                DemoSegment(id: "bmp", title: "BMP", glyph: "square.grid.3x3"),
            ]
        case .tools:
            let ids = [ToolIDs.compressImage, ToolIDs.resizeImage, ToolIDs.cropImage, ToolIDs.adjustImage,
                       ToolIDs.annotateImage, ToolIDs.redactImage, ToolIDs.removeBackground, ToolIDs.stripMetadata]
            return ids.compactMap(ToolCatalog.spec).map { DemoSegment(id: $0.id.rawValue, title: $0.title, glyph: $0.glyph) }
        case .actions:
            return ActionCatalog.local.map { DemoSegment(id: $0.id.rawValue, title: $0.title, glyph: $0.glyph) }
        }
    }

    // MARK: Keys

    func start() {
        guard monitor == nil else { return }
        detector.threshold = settings.tapThreshold
        let m = LocalKeyMonitor(onFlags: { [weak self] keys, time, _ in
            self?.flagsChanged(keys, at: time)
        }, onKeyDown: { [weak self] event in
            guard let self else { return false }
            self.detector.otherKeyPressed()
            if event.keyCode == 53, self.openKind != nil { // Escape cancels an open wheel
                self.cancelWheel()
                return true
            }
            return false
        })
        m.start()
        monitor = m
    }

    func stop() {
        monitor?.stop()
        monitor = nil
        detector.reset()
        pressing = nil
        lastKeys = []
    }

    private var lastKeys: Set<TriggerKey> = []

    func flagsChanged(_ keys: Set<TriggerKey>, at time: TimeInterval) {
        detector.threshold = settings.tapThreshold
        let newlyDown = keys.subtracting(lastKeys)
        lastKeys = keys
        let outcome = detector.flagsChanged(to: keys, at: time)
        pressing = detector.pendingKey
        if settings.opensOnPress {
            // Same rule as the drag sensor: a trigger key going down opens (or switches) the wheel.
            for key in newlyDown.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let role = triggers.role(for: key) else { hint = .unassigned(key); continue }
                tapped(DemoWheelKind(role))
            }
            return
        }
        guard let outcome else { return }
        switch outcome {
        case .tap(let key, _):
            guard let role = triggers.role(for: key) else { hint = .unassigned(key); return }
            tapped(DemoWheelKind(role))
        case .held:
            if phase == .dragging || openKind != nil { hint = .held }
        case .chord:
            if phase == .dragging || openKind != nil { hint = .chord }
        }
    }

    private func tapped(_ kind: DemoWheelKind) {
        switch phase {
        case .dragging:
            wheelCenter = clampedWheelCenter(pointer)
            open(kind)
        case .wheel(let current) where current != kind:
            open(kind) // switch wheels in place
        case .wheel:
            break
        case .idle, .result:
            hint = .dragFirst
        }
    }

    private func open(_ kind: DemoWheelKind) {
        phase = .wheel(kind)
        hint = .chooseSegment
        updateHighlight()
    }

    // MARK: Pointer (stage coordinates)

    func dragChanged(start: CGPoint, location: CGPoint) {
        if phase == .idle || result != nil {
            guard hypot(start.x - tileCenter.x, start.y - tileCenter.y) < 64 || phase == .dragging else { return }
            if result != nil { tileCenter = Self.homeCenter }
            grabOffset = CGSize(width: tileCenter.x - start.x, height: tileCenter.y - start.y)
            phase = .dragging
            hint = .tapNow
        }
        pointer = location
        tileCenter = CGPoint(x: location.x + grabOffset.width, y: location.y + grabOffset.height)
        updateHighlight()
    }

    func dragEnded(location: CGPoint) {
        pointer = location
        switch phase {
        case .wheel(let kind):
            updateHighlight()
            if let id = highlighted, let seg = Self.segments(kind).first(where: { $0.id == id }) {
                complete(kind, seg)
            } else {
                cancelWheel()
            }
        case .dragging:
            phase = .idle
            tileCenter = Self.homeCenter
            hint = .start
        default:
            break
        }
    }

    func cancelWheel() {
        phase = .idle
        highlighted = nil
        tileCenter = Self.homeCenter
        hint = .cancelled
    }

    /// Direct pick (VoiceOver, or clicking a segment).
    func select(_ id: DemoSegment.ID) {
        guard let kind = openKind, let seg = Self.segments(kind).first(where: { $0.id == id }) else { return }
        complete(kind, seg)
    }

    /// VoiceOver path: open a wheel without dragging.
    func openForAccessibility(_ kind: DemoWheelKind) {
        wheelCenter = CGPoint(x: Self.stageSize.width / 2, y: Self.stageSize.height / 2)
        pointer = wheelCenter
        tileCenter = wheelCenter
        open(kind)
    }

    func reset() {
        phase = .idle
        highlighted = nil
        tileCenter = Self.homeCenter
        hint = .start
    }

    /// Screenshot staging.
    func stage(_ staging: Staging) {
        switch staging {
        case .wheel(let kind):
            // Wheel in the middle, pointer just past the 3 o'clock segment.
            wheelCenter = CGPoint(x: Self.stageSize.width * 0.42, y: Self.stageSize.height / 2)
            let n = Self.segments(kind).count
            let a = DemoHitTest.midAngle(n / 4, count: n) + 0.12
            pointer = CGPoint(x: wheelCenter.x + cos(a) * (Self.outerRadius + 34), y: wheelCenter.y + sin(a) * (Self.outerRadius + 34))
            tileCenter = CGPoint(x: pointer.x + 18, y: pointer.y + 14)
            phase = .dragging
            open(kind)
        case .done:
            if let seg = Self.segments(.convert).first { complete(.convert, seg) }
        }
    }

    private func updateHighlight() {
        guard let kind = openKind else { highlighted = nil; return }
        let segs = Self.segments(kind)
        let rel = CGPoint(x: pointer.x - wheelCenter.x, y: pointer.y - wheelCenter.y)
        let i = DemoHitTest.index(of: rel, count: segs.count, deadZone: Self.deadZone)
        let id = i.map { segs[$0].id }
        if id != highlighted { highlighted = id }
    }

    private func clampedWheelCenter(_ p: CGPoint) -> CGPoint {
        let r = Self.outerRadius + 8
        let s = Self.stageSize
        return CGPoint(x: min(max(p.x, r), s.width - r), y: min(max(p.y, min(r, s.height / 2)), max(s.height - r, s.height / 2)))
    }

    private func complete(_ kind: DemoWheelKind, _ seg: DemoSegment) {
        let base = (Self.fileName as NSString).deletingPathExtension
        let r: Result
        switch kind {
        case .convert:
            let ext = Formats.extension(for: FormatID(seg.id))
            let name = "\(base).\(ext)"
            r = Result(kind: kind, segment: seg, title: String(localized: "Saved \(name) beside the original"),
                       detail: String(localized: "In Finder it works exactly like this."), outputName: name, outputBadge: seg.title)
        case .tools:
            let spec = ToolCatalog.spec(ToolID(rawValue: seg.id))
            let name = "\(base)-\(spec?.outputSuffix ?? "edited").heic"
            let title = spec?.needsEditor == true
                ? String(localized: "\(seg.title) opens an editor, then saves \(name)")
                : String(localized: "Saved \(name) beside the original")
            r = Result(kind: kind, segment: seg, title: title,
                       detail: String(localized: "The original is never changed. In Finder it works exactly like this."),
                       outputName: name, outputBadge: nil)
        case .actions:
            r = Result(kind: kind, segment: seg, title: Self.actionLine(seg.id),
                       detail: String(localized: "Actions work on any file or folder, even ones with nothing to convert."),
                       outputName: nil, outputBadge: nil)
        }
        highlighted = seg.id
        phase = .result(r)
        tileCenter = Self.homeCenter
        hint = .done
    }

    private static func actionLine(_ id: String) -> String {
        let f = fileName
        switch ActionID(rawValue: id) {
        case ActionIDs.airDrop: return String(localized: "AirDrop opens with \(f), ready to send")
        case ActionIDs.float: return String(localized: "\(f) floats on a shelf until you drag it out")
        case ActionIDs.copy: return String(localized: "\(f) is copied: paste it into any folder")
        case ActionIDs.move: return String(localized: "Pick a folder and \(f) moves there")
        case ActionIDs.copyPath: return String(localized: "The path of \(f) is on the clipboard")
        case ActionIDs.terminal: return String(localized: "Terminal opens in the folder of \(f)")
        default: return String(localized: "Done")
        }
    }
}
