import AppKit
import SwiftUI
import HaloCore

/// Envelope + zoom/pan state for a waveform view.
@MainActor
final class WaveformModel: ObservableObject {
    @Published private(set) var envelope: WaveformEnvelope?
    @Published private(set) var isComplete = false
    /// Loudest sample so far, for display gain.
    @Published private(set) var peak: Float = 0
    @Published private(set) var viewStart: Double = 0
    @Published private(set) var viewSpan: Double = 1
    private(set) var duration: Double = 1
    private var task: Task<Void, Never>?

    /// Shortest visible span when fully zoomed in.
    static let minimumSpan = 0.25

    func load(url: URL, duration: Double) {
        self.duration = max(0.01, duration)
        viewStart = 0
        viewSpan = self.duration
        task?.cancel()
        // The task holds the model until decoding ends or `cancel()` (teardown) stops it.
        task = Task.detached(priority: .userInitiated) { [self] in
            do {
                try await WaveformLoader.load(url) { env, done in
                    Task { @MainActor in self.apply(env, done: done) }
                }
            } catch {
                Log.tools.error("waveform failed: \(String(describing: error), privacy: .public)")
                await self.apply(nil, done: true)
            }
        }
    }

    private func apply(_ env: WaveformEnvelope?, done: Bool) {
        if let env {
            envelope = env
            peak = max(env.maxs.max() ?? 0, -(env.mins.min() ?? 0))
        }
        if done { isComplete = true }
    }

    /// Quiet recordings are drawn larger (up to 4×) so their shape stays readable.
    var displayGain: CGFloat { peak > 0.0001 ? CGFloat(min(4, max(1, 0.92 / peak))) : 1 }

    func cancel() { task?.cancel() }

    var zoom: Double { duration / viewSpan }
    var viewEnd: Double { viewStart + viewSpan }

    /// Zoom by `factor` (> 1 zooms in) keeping time `t` under the same x.
    func zoom(by factor: Double, around t: Double) {
        let newSpan = min(duration, max(Self.minimumSpan, viewSpan / factor))
        let ratio = (t - viewStart) / viewSpan
        viewSpan = newSpan
        setStart(t - ratio * newSpan)
    }

    func setZoom(_ z: Double) {
        let center = viewStart + viewSpan / 2
        viewSpan = min(duration, max(Self.minimumSpan, duration / max(1, z)))
        setStart(center - viewSpan / 2)
    }

    func pan(by seconds: Double) { setStart(viewStart + seconds) }

    /// Keeps `t` on screen (follows the playhead while playing).
    func reveal(_ t: Double) {
        if t < viewStart || t > viewEnd { setStart(t - viewSpan * 0.1) }
    }

    func setStart(_ s: Double) { viewStart = min(max(0, s), max(0, duration - viewSpan)) }

    func waitUntilComplete(timeout: Double = 8) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !isComplete && Date() < deadline { try? await Task.sleep(nanoseconds: 30_000_000) }
    }
}

/// A bleep range with a stable identity for selection.
struct MarkedRange: Identifiable, Equatable {
    let id: UUID
    var range: ClosedRange<Double>
    init(id: UUID = UUID(), _ range: ClosedRange<Double>) {
        self.id = id
        self.range = range
    }
}

/// Zoomable waveform with a playhead, and either a trim selection with
/// handles or a set of marked (bleep) ranges you create by dragging.
struct WaveformTimeline: View {
    @ObservedObject var wave: WaveformModel
    @ObservedObject var player: PlayerController
    let duration: Double
    var selection: Binding<ClosedRange<Double>>?
    var ranges: Binding<[MarkedRange]>?
    var selectedRange: Binding<UUID?>?
    var showsEdits = true
    /// "tone" or "silence": marked ranges are drawn as the result (tone band or flat line).
    var bleepStyle: String? = nil

    @Environment(\.colorSchemeContrast) private var contrast
    @State private var drag: Drag?

    private enum Drag: Equatable {
        case scrub
        case selectionIn, selectionOut
        case rangeLower(UUID), rangeUpper(UUID)
        case creating(UUID, anchor: Double)
        case pending(start: Double)
    }

    private let minRange = 0.05

    var body: some View {
        VStack(spacing: DesignTokens.Space.xs) {
            if showsEdits, let sel = selection?.wrappedValue {
                GeometryReader { geo in
                    HandleLabels(selection: sel, axis: TimeAxis(start: wave.viewStart, end: wave.viewEnd, width: geo.size.width),
                                 handleWidth: MediaStyle.handleWidth,
                                 inTitle: String(localized: "Start"), outTitle: String(localized: "End"))
                }
                .frame(height: EditorTokens.Timeline.labelHeight)
            }
            GeometryReader { geo in
                let axis = TimeAxis(start: wave.viewStart, end: wave.viewEnd, width: geo.size.width)
                ZStack(alignment: .topLeading) {
                    waveform(axis: axis, size: geo.size)
                    if showsEdits { editsOverlay(axis: axis, height: geo.size.height) }
                    playhead(axis: axis, height: geo.size.height)
                }
                .contentShape(Rectangle())
                .gesture(gesture(axis: axis))
                .background(ScrollMonitor { event, x in handleScroll(event, x: x, axis: axis) })
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous))
            }
            .frame(minHeight: EditorTokens.Timeline.waveformMinHeight, maxHeight: EditorTokens.Timeline.waveformMaxHeight)
            GeometryReader { geo in TimeRuler(axis: TimeAxis(start: wave.viewStart, end: wave.viewEnd, width: geo.size.width)) }
                .frame(height: MediaStyle.rulerHeight)
            overview
        }
        .onChange(of: player.currentTime) { t in if player.isPlaying { wave.reveal(t) } }
    }

    // MARK: Drawing

    private func waveform(axis: TimeAxis, size: CGSize) -> some View {
        let columns = wave.envelope?.columns(from: axis.start, to: axis.end, count: Int(size.width)) ?? []
        let sel = showsEdits ? selection?.wrappedValue : nil
        let marked = showsEdits ? (ranges?.wrappedValue ?? []).map(\.range) : []
        let gain = wave.displayGain
        let style = bleepStyle
        return Canvas { ctx, size in
            let mid = size.height / 2
            let amp = (mid - 6) * gain
            let limit = mid - 2
            ctx.fill(Path(CGRect(x: 0, y: mid, width: size.width, height: 1)), with: .color(Color.haloSecondaryText.opacity(0.35)))
            var inside = Path(), outside = Path(), bleeped = Path()
            let toneHalf = min(limit, CGFloat(BleepAudioRunner.toneAmplitude) * amp)
            for (i, c) in columns.enumerated() {
                let t = axis.time(CGFloat(i) + 0.5)
                let top = mid - min(limit, CGFloat(c.max) * amp), bottom = mid - max(-limit, CGFloat(c.min) * amp)
                let r = CGRect(x: CGFloat(i), y: top, width: 1, height: max(1, bottom - top))
                if marked.contains(where: { $0.contains(t) }) {
                    switch style {
                    case "tone": bleeped.addRect(CGRect(x: CGFloat(i), y: mid - toneHalf, width: 1, height: toneHalf * 2))
                    case "silence": bleeped.addRect(CGRect(x: CGFloat(i), y: mid - 0.5, width: 1, height: 1))
                    default: bleeped.addRect(r)
                    }
                }
                else if let sel, !sel.contains(t) { outside.addRect(r) }
                else { inside.addRect(r) }
            }
            ctx.fill(outside, with: .color(Color.haloSecondaryText.opacity(0.5)))
            ctx.fill(inside, with: .color(MediaStyle.accent))
            ctx.fill(bleeped, with: .color(MediaStyle.danger.opacity(0.85)))
        }
        .background(EditorPalette.chip)
        .accessibilityElement()
        .accessibilityLabel(Text("Waveform"))
        .accessibilityValue(Text(wave.isComplete ? "" : String(localized: "Loading")))
    }

    @ViewBuilder
    private func editsOverlay(axis: TimeAxis, height: CGFloat) -> some View {
        if let sel = selection?.wrappedValue {
            let x0 = axis.x(sel.lowerBound), x1 = axis.x(sel.upperBound)
            ZStack(alignment: .topLeading) {
                Rectangle().fill(EditorPalette.overlayHalo.opacity(0.18)).frame(width: max(0, x0), height: height)
                Rectangle().fill(EditorPalette.overlayHalo.opacity(0.18)).frame(width: max(0, axis.width - x1), height: height).offset(x: max(0, x1))
                Rectangle().fill(MediaStyle.accent.opacity(0.1)).frame(width: max(0, x1 - x0), height: height).offset(x: x0)
                edgeHandle(leading: true, height: height).offset(x: x0 - MediaStyle.handleWidth)
                    .accessibilityElement().accessibilityLabel(Text("In point"))
                    .accessibilityValue(Text(MediaTimes.timecode(sel.lowerBound)))
                    .accessibilityAdjustableAction { nudgeSelection(lower: true, $0) }
                edgeHandle(leading: false, height: height).offset(x: x1)
                    .accessibilityElement().accessibilityLabel(Text("Out point"))
                    .accessibilityValue(Text(MediaTimes.timecode(sel.upperBound)))
                    .accessibilityAdjustableAction { nudgeSelection(lower: false, $0) }
            }
        }
        if let ranges {
            ForEach(Array(ranges.wrappedValue.enumerated()), id: \.element.id) { n, r in
                let x0 = axis.x(r.range.lowerBound), x1 = axis.x(r.range.upperBound)
                let selected = selectedRange?.wrappedValue == r.id
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(MediaStyle.danger.opacity(selected ? 0.22 : 0.14))
                        .overlay(Rectangle().strokeBorder(MediaStyle.danger.opacity(selected ? 1 : 0.6),
                                                          lineWidth: selected ? (contrast == .increased ? 3 : 2) : 1))
                        .frame(width: max(2, x1 - x0), height: height)
                    // Flame with black text (6.3:1); the number names the bleep.
                    Text("\(n + 1)")
                        .font(.system(size: DesignTokens.TypeRamp.micro, weight: .bold).monospacedDigit())
                        .foregroundStyle(EditorPalette.onWarm)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill(EditorPalette.flame))
                        .offset(x: 4, y: 4)
                    if selected {
                        grip().offset(x: -4, y: height / 2 - 12)
                        grip().offset(x: max(2, x1 - x0) - 4, y: height / 2 - 12)
                    }
                }
                .offset(x: x0)
                .accessibilityElement()
                .accessibilityLabel(Text("Bleep \(n + 1)"))
                .accessibilityValue(Text("\(MediaTimes.timecode(r.range.lowerBound)) to \(MediaTimes.timecode(r.range.upperBound))"))
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
    }

    private func grip() -> some View {
        Capsule().fill(EditorPalette.flame).frame(width: 8, height: 24)
            .overlay(Capsule().strokeBorder(EditorPalette.overlayRim, lineWidth: DesignTokens.Shape.hairline))
            .overlay(VStack(spacing: 3) { ForEach(0..<3) { _ in Capsule().fill(EditorPalette.onWarm).frame(width: 4, height: 1.5) } })
    }

    private func edgeHandle(leading: Bool, height: CGFloat) -> some View {
        UnevenHandleShape(leading: leading)
            .fill(MediaStyle.accent)
            .frame(width: MediaStyle.handleWidth, height: height)
            .overlay(VStack(spacing: 3) { ForEach(0..<3) { _ in Capsule().fill(EditorPalette.overlayRim).frame(width: 2, height: 2) } })
    }

    private func playhead(axis: TimeAxis, height: CGFloat) -> some View {
        let x = axis.x(player.currentTime)
        let w = EditorTokens.Timeline.knob
        return OverlayStroke(path: Path { p in
                p.move(to: CGPoint(x: w / 2, y: 0))
                p.addLine(to: CGPoint(x: w / 2, y: height))
            }, width: MediaStyle.playheadWidth)
            .frame(width: w, height: height)
            .offset(x: x - w / 2)
            .opacity(x >= -2 && x <= axis.width + 2 ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(Text("Playhead"))
            .accessibilityValue(Text(MediaTimes.timecode(player.currentTime)))
            .accessibilityAdjustableAction { player.jump(by: $0 == .increment ? 0.1 : -0.1) }
    }

    /// Whole-file strip with the visible window, shown when zoomed in.
    @ViewBuilder
    private var overview: some View {
        if wave.zoom > 1.01 {
            GeometryReader { geo in
                let w = geo.size.width
                let x0 = CGFloat(wave.viewStart / max(duration, 0.001)) * w
                let x1 = CGFloat(wave.viewEnd / max(duration, 0.001)) * w
                ZStack(alignment: .leading) {
                    Capsule().fill(EditorPalette.chip)
                    Capsule().fill(MediaStyle.accent).frame(width: max(8, x1 - x0)).offset(x: x0)
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                    let center = Double(v.location.x / max(1, w)) * duration
                    wave.setStart(center - wave.viewSpan / 2)
                })
            }
            .frame(height: EditorTokens.Timeline.overviewHeight)
            .accessibilityElement()
            .accessibilityLabel(Text("Visible part"))
            .accessibilityValue(Text("\(MediaTimes.timecode(wave.viewStart)) to \(MediaTimes.timecode(wave.viewEnd))"))
            .accessibilityAdjustableAction { wave.pan(by: ($0 == .increment ? 0.5 : -0.5) * wave.viewSpan) }
        }
    }

    // MARK: Interaction

    private func handleScroll(_ event: NSEvent, x: CGFloat, axis: TimeAxis) -> Bool {
        if event.type == .magnify {
            wave.zoom(by: 1 + Double(event.magnification), around: axis.time(x))
            return true
        }
        let dx = event.scrollingDeltaX != 0 ? event.scrollingDeltaX : (event.modifierFlags.contains(.shift) ? event.scrollingDeltaY : 0)
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
            let factor = 1 + Double(event.scrollingDeltaY) * (event.hasPreciseScrollingDeltas ? 0.01 : 0.1)
            wave.zoom(by: factor, around: axis.time(x))
            return true
        }
        guard dx != 0, wave.zoom > 1.01 else { return false }
        let perPoint = wave.viewSpan / Double(max(1, axis.width))
        wave.pan(by: -Double(dx) * perPoint * (event.hasPreciseScrollingDeltas ? 1 : 8))
        return true
    }

    private func gesture(axis: TimeAxis) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let t = min(max(0, axis.time(v.location.x)), duration)
                if drag == nil { drag = begin(at: v.startLocation.x, axis: axis) }
                switch drag {
                case .selectionIn:
                    if let sel = selection {
                        sel.wrappedValue = max(0, min(t, sel.wrappedValue.upperBound - minRange))...sel.wrappedValue.upperBound
                        player.seek(to: sel.wrappedValue.lowerBound)
                    }
                case .selectionOut:
                    if let sel = selection {
                        sel.wrappedValue = sel.wrappedValue.lowerBound...min(duration, max(t, sel.wrappedValue.lowerBound + minRange))
                        player.seek(to: sel.wrappedValue.upperBound)
                    }
                case .rangeLower(let id):
                    updateRange(id) { r in max(0, min(t, r.upperBound - minRange))...r.upperBound }
                case .rangeUpper(let id):
                    updateRange(id) { r in r.lowerBound...min(duration, max(t, r.lowerBound + minRange)) }
                case .pending(let start):
                    if abs(v.translation.width) > 3, ranges != nil {
                        let r = MarkedRange(min(start, t)...max(start, t) + 0.0001)
                        ranges?.wrappedValue.append(r)
                        selectedRange?.wrappedValue = r.id
                        drag = .creating(r.id, anchor: start)
                    } else {
                        player.seek(to: t)
                    }
                case .creating(let id, let anchor):
                    updateRange(id) { _ in min(anchor, t)...max(anchor, t) }
                case .scrub, .none:
                    player.seek(to: t)
                }
            }
            .onEnded { _ in
                if case .creating(let id, _) = drag {
                    // Drop accidental slivers.
                    if let r = ranges?.wrappedValue.first(where: { $0.id == id }), r.range.upperBound - r.range.lowerBound < minRange {
                        ranges?.wrappedValue.removeAll { $0.id == id }
                    } else if let ranges {
                        ranges.wrappedValue.sort { $0.range.lowerBound < $1.range.lowerBound }
                    }
                }
                drag = nil
            }
    }

    private func begin(at x: CGFloat, axis: TimeAxis) -> Drag {
        player.pause()
        let grab: CGFloat = 8
        if let sel = selection?.wrappedValue {
            if abs(x - (axis.x(sel.lowerBound) - MediaStyle.handleWidth / 2)) < MediaStyle.handleWidth { return .selectionIn }
            if abs(x - (axis.x(sel.upperBound) + MediaStyle.handleWidth / 2)) < MediaStyle.handleWidth { return .selectionOut }
        }
        if let ranges = ranges?.wrappedValue {
            // Edges of the selected range first, then any range's edges.
            let ordered = ranges.sorted { a, _ in a.id == selectedRange?.wrappedValue }
            for r in ordered {
                if abs(x - axis.x(r.range.lowerBound)) < grab { selectedRange?.wrappedValue = r.id; return .rangeLower(r.id) }
                if abs(x - axis.x(r.range.upperBound)) < grab { selectedRange?.wrappedValue = r.id; return .rangeUpper(r.id) }
            }
            let t = axis.time(x)
            if let hit = ranges.first(where: { $0.range.contains(t) }) {
                selectedRange?.wrappedValue = hit.id
                return .scrub
            }
            selectedRange?.wrappedValue = nil
            return .pending(start: min(max(0, t), duration))
        }
        return .scrub
    }

    private func updateRange(_ id: UUID, _ change: (ClosedRange<Double>) -> ClosedRange<Double>) {
        guard let ranges, let i = ranges.wrappedValue.firstIndex(where: { $0.id == id }) else { return }
        ranges.wrappedValue[i].range = change(ranges.wrappedValue[i].range)
    }

    private func nudgeSelection(lower: Bool, _ dir: AccessibilityAdjustmentDirection) {
        guard let sel = selection else { return }
        let d = dir == .increment ? 0.01 : -0.01
        if lower {
            sel.wrappedValue = max(0, min(sel.wrappedValue.lowerBound + d, sel.wrappedValue.upperBound - minRange))...sel.wrappedValue.upperBound
        } else {
            sel.wrappedValue = sel.wrappedValue.lowerBound...min(duration, max(sel.wrappedValue.upperBound + d, sel.wrappedValue.lowerBound + minRange))
        }
    }
}

/// Scroll-wheel and pinch events over a view (macOS 13 SwiftUI has no scroll gestures).
struct ScrollMonitor: NSViewRepresentable {
    /// Event plus its x in the view; return true when handled.
    let handler: (NSEvent, CGFloat) -> Bool

    func makeNSView(context: Context) -> MonitorView {
        let v = MonitorView()
        v.handler = handler
        return v
    }

    func updateNSView(_ nsView: MonitorView, context: Context) { nsView.handler = handler }

    final class MonitorView: NSView {
        var handler: ((NSEvent, CGFloat) -> Bool)?
        private var monitor: Any?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] event in
                guard let self else { return event }
                let handled = MainActor.assumeIsolated { () -> Bool in
                    let p = self.convert(event.locationInWindow, from: nil)
                    guard event.window === self.window, self.bounds.contains(p), let handler = self.handler else { return false }
                    return handler(event, p.x)
                }
                return handled ? nil : event
            }
        }

        override func removeFromSuperview() {
            if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
            super.removeFromSuperview()
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
