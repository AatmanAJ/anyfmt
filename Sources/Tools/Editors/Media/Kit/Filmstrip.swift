import AppKit
import AVFoundation
import SwiftUI
import AnyfmtCore

/// Thumbnails for the filmstrip, sized to the strip: as many frames as fit
/// at the video's aspect ratio, evenly spaced, loaded progressively.
@MainActor
final class FilmstripLoader: ObservableObject {
    @Published private(set) var thumbnails: [NSImage?] = []
    private var assetURL: URL?
    private var duration: Double = 0
    private var aspect: CGFloat = 16.0 / 9
    private var requestedCount = 0
    private var task: Task<Void, Never>?

    func attach(asset: AVURLAsset, duration: Double, aspect size: CGSize) {
        assetURL = asset.url
        self.duration = duration
        aspect = max(0.3, min(4, size.width / max(1, size.height)))
        if requestedCount > 0 { load(count: requestedCount) }
    }

    /// Thumbnails to fill a strip of `width` × `height` points.
    func layout(width: CGFloat, height: CGFloat) {
        let count = max(4, min(60, Int((width / (height * aspect)).rounded(.up))))
        guard count != requestedCount else { return }
        let first = requestedCount == 0
        requestedCount = count
        guard assetURL != nil else { return }
        if first { load(count: count); return }
        // Live window resizes: wait for the size to settle before regenerating.
        relayout?.cancel()
        relayout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled, let self, self.requestedCount == count else { return }
            self.load(count: count)
        }
    }

    private var relayout: Task<Void, Never>?

    /// True once every requested thumbnail is in (or nothing has been requested yet).
    var isComplete: Bool { requestedCount == 0 || (!thumbnails.isEmpty && thumbnails.allSatisfy { $0 != nil }) }

    private func load(count: Int) {
        task?.cancel()
        guard let url = assetURL, duration > 0 else { return }
        thumbnails = Array(repeating: nil, count: count)
        let duration = duration
        let times = (0..<count).map { CMTime(seconds: duration * (Double($0) + 0.5) / Double(count), preferredTimescale: 600) }
        let height = MediaStyle.stripHeight * 2
        task = Task.detached(priority: .utility) { [weak self] in
            let g = AVAssetImageGenerator(asset: AVURLAsset(url: url))
            g.appliesPreferredTrackTransform = true
            g.maximumSize = CGSize(width: 0, height: height)
            let tolerance = CMTime(seconds: duration / Double(count) / 2, preferredTimescale: 600)
            g.requestedTimeToleranceBefore = tolerance
            g.requestedTimeToleranceAfter = tolerance
            for (i, t) in times.enumerated() {
                guard !Task.isCancelled else { return }
                guard let cg = try? await g.image(at: t).image else { continue }
                await self?.set(i, cg, generation: count)
            }
        }
    }

    private func set(_ i: Int, _ cg: CGImage, generation: Int) {
        guard generation == thumbnails.count, i < thumbnails.count else { return }
        thumbnails[i] = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    func cancel() { task?.cancel() }

    func waitUntilComplete(timeout: Double = 8) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !isComplete && Date() < deadline { try? await Task.sleep(nanoseconds: 30_000_000) }
    }
}

/// Maps time ↔ x across a visible window of the timeline.
struct TimeAxis {
    let start: Double
    let end: Double
    let width: CGFloat

    var span: Double { max(0.000_1, end - start) }
    func x(_ t: Double) -> CGFloat { CGFloat((t - start) / span) * width }
    func time(_ x: CGFloat) -> Double { start + Double(x / max(1, width)) * span }

    /// Tick spacing that gives labels roughly every 80 pt.
    var tickStep: Double {
        let target = span * 80 / Double(max(1, width))
        let steps: [Double] = [0.01, 0.02, 0.05, 0.1, 0.2, 0.5, 1, 2, 5, 10, 15, 30, 60, 120, 300, 600, 900, 1800, 3600]
        return steps.first { $0 >= target } ?? 3600
    }
}

/// Time labels under a timeline.
struct TimeRuler: View {
    let axis: TimeAxis

    var body: some View {
        Canvas { ctx, size in
            let step = axis.tickStep
            var t = (axis.start / step).rounded(.up) * step
            let minor = step / 5
            var m = (axis.start / minor).rounded(.up) * minor
            while m <= axis.end {
                let x = axis.x(m)
                ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: 3)), with: .color(Color.anyfmtSecondaryText.opacity(0.6)))
                m += minor
            }
            while t <= axis.end + 1e-9 {
                let x = axis.x(t)
                ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: 6)), with: .color(Color.anyfmtSecondaryText))
                let text = Text(MediaTimes.timecode(t, fraction: step < 1 ? 2 : 0)).font(MediaStyle.caption().monospacedDigit())
                    .foregroundColor(Color.anyfmtSecondaryText)
                let resolved = ctx.resolve(text)
                let w = resolved.measure(in: size).width
                let lx = min(max(0, x - w / 2), size.width - w)
                ctx.draw(resolved, at: CGPoint(x: lx, y: 7), anchor: .topLeading)
                t += step
            }
        }
        .frame(height: MediaStyle.rulerHeight)
        .accessibilityHidden(true)
    }
}

/// A marker on the timeline (split point, captured frame).
struct TimelineMarker: Identifiable, Equatable {
    let id: Int
    let time: Double
    let label: String
}

/// Filmstrip with draggable in/out handles, a playhead and markers. Click or
/// drag anywhere to scrub; drag the handles to set the selection.
struct FilmstripTimeline: View {
    @ObservedObject var filmstrip: FilmstripLoader
    @ObservedObject var player: PlayerController
    let duration: Double
    let frameDuration: Double
    /// nil hides the selection (split, snapshot, crop).
    var selection: Binding<ClosedRange<Double>>?
    var dimOutside = true
    /// Where a lossless cut will really land (dashed), when it differs from the selection.
    var ghost: ClosedRange<Double>?
    var markers: [TimelineMarker] = []
    var onMarkerTap: ((TimelineMarker) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var dragging: DragTarget?

    private enum DragTarget { case scrub, inHandle, outHandle }

    var body: some View {
        VStack(spacing: DesignTokens.Space.xs) {
            if let sel = selection?.wrappedValue {
                GeometryReader { geo in
                    HandleLabels(selection: sel, axis: TimeAxis(start: 0, end: max(duration, 0.001), width: geo.size.width),
                                 handleWidth: MediaStyle.handleWidth)
                }
                .frame(height: EditorTokens.Timeline.labelHeight)
            }
            GeometryReader { geo in
                let axis = TimeAxis(start: 0, end: max(duration, 0.001), width: geo.size.width)
                ZStack(alignment: .topLeading) {
                    strip(geo.size)
                    if let sel = selection?.wrappedValue {
                        selectionOverlay(sel, axis: axis, height: geo.size.height)
                    }
                    if let ghost, selection != nil {
                        // Where a lossless cut really lands: dashed white with a dark anyfmt.
                        OverlayStroke(path: Path(CGRect(x: axis.x(ghost.lowerBound), y: 6,
                                                        width: max(2, axis.x(ghost.upperBound) - axis.x(ghost.lowerBound)),
                                                        height: geo.size.height - 12)),
                                      dash: [5, 3], quiet: true)
                    }
                    ForEach(markers) { m in markerView(m, axis: axis, height: geo.size.height) }
                    playhead(axis: axis, height: geo.size.height)
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(axis: axis))
                .onAppear { filmstrip.layout(width: geo.size.width, height: geo.size.height) }
                .onChange(of: geo.size) { filmstrip.layout(width: $0.width, height: $0.height) }
            }
            .frame(height: MediaStyle.stripHeight)
            GeometryReader { geo in
                TimeRuler(axis: TimeAxis(start: 0, end: max(duration, 0.001), width: geo.size.width))
            }
            .frame(height: MediaStyle.rulerHeight)
        }
    }

    private func strip(_ size: CGSize) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(filmstrip.thumbnails.enumerated()), id: \.offset) { _, image in
                Group {
                    if let image {
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle().fill(EditorPalette.chip)
                    }
                }
                .frame(width: size.width / CGFloat(max(1, filmstrip.thumbnails.count)), height: size.height)
                .clipped()
            }
        }
        .frame(width: size.width, height: size.height)
        .background(EditorPalette.chip)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous))
        .accessibilityHidden(true)
    }

    private func selectionOverlay(_ sel: ClosedRange<Double>, axis: TimeAxis, height: CGFloat) -> some View {
        let x0 = axis.x(sel.lowerBound), x1 = axis.x(sel.upperBound)
        let border: CGFloat = contrast == .increased ? 4 : 3
        let dim = EditorPalette.overlayHalo.opacity(contrast == .increased ? EditorTokens.Overlay.dimIncreased : EditorTokens.Overlay.dim)
        let frame = RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous)
        return ZStack(alignment: .topLeading) {
            if dimOutside {
                Rectangle().fill(dim).frame(width: max(0, x0), height: height)
                Rectangle().fill(dim).frame(width: max(0, axis.width - x1), height: height).offset(x: x1)
            }
            frame
                .strokeBorder(MediaStyle.accent, lineWidth: border)
                // A white inner rim keeps the frame visible over blue footage.
                .overlay(frame.inset(by: border).strokeBorder(EditorPalette.overlayRim, lineWidth: DesignTokens.Shape.hairline))
                .frame(width: max(MediaStyle.handleWidth * 2, x1 - x0 + MediaStyle.handleWidth * 2), height: height)
                .offset(x: x0 - MediaStyle.handleWidth)
            handle(edge: .leading).offset(x: x0 - MediaStyle.handleWidth)
                .accessibilityElement()
                .accessibilityLabel(Text("In point"))
                .accessibilityValue(Text(MediaTimes.timecode(sel.lowerBound)))
                .accessibilityAdjustableAction { dir in nudge(inPoint: true, dir) }
            handle(edge: .trailing).offset(x: x1)
                .accessibilityElement()
                .accessibilityLabel(Text("Out point"))
                .accessibilityValue(Text(MediaTimes.timecode(sel.upperBound)))
                .accessibilityAdjustableAction { dir in nudge(inPoint: false, dir) }
        }
        .frame(height: height)
    }

    private func handle(edge: HorizontalEdge) -> some View {
        UnevenHandleShape(leading: edge == .leading)
            .fill(MediaStyle.accent)
            .frame(width: MediaStyle.handleWidth, height: MediaStyle.stripHeight)
            .overlay(
                VStack(spacing: 3) { ForEach(0..<3) { _ in Capsule().fill(EditorPalette.overlayRim).frame(width: 2, height: 2) } }
                    .frame(width: 2)
            )
            .contentShape(Rectangle().inset(by: -6))
    }

    private func markerView(_ m: TimelineMarker, axis: TimeAxis, height: CGFloat) -> some View {
        let x = axis.x(m.time)
        return VStack(spacing: 0) {
            // Orange with black text (9.6:1); the number names the part.
            Text(m.label)
                .font(.system(size: DesignTokens.TypeRamp.micro, weight: .bold).monospacedDigit())
                .foregroundStyle(EditorPalette.onWarm)
                .padding(.horizontal, 4).padding(.vertical, 1)
                .background(Capsule().fill(EditorPalette.orange))
                .overlay(Capsule().strokeBorder(EditorPalette.overlayHalo.opacity(0.5), lineWidth: DesignTokens.Shape.hairline))
            Rectangle().fill(EditorPalette.orange).frame(width: 2, height: height - 12)
                .overlay(Rectangle().stroke(EditorPalette.overlayHalo.opacity(0.4), lineWidth: 0.5))
        }
        .frame(width: 28)
        .offset(x: x - 14, y: -2)
        .onTapGesture { onMarkerTap?(m) }
        .accessibilityElement()
        .accessibilityLabel(Text("Marker \(m.label) at \(MediaTimes.timecode(m.time))"))
        .accessibilityAddTraits(.isButton)
    }

    private func playhead(axis: TimeAxis, height: CGFloat) -> some View {
        let x = axis.x(player.currentTime)
        let knob = EditorTokens.Timeline.knob
        return ZStack(alignment: .top) {
            OverlayStroke(path: Path { p in
                p.move(to: CGPoint(x: knob / 2, y: 0))
                p.addLine(to: CGPoint(x: knob / 2, y: height + 8))
            }, width: MediaStyle.playheadWidth)
            .frame(width: knob, height: height + 8)
            OverlayHandle(round: true, size: knob).offset(y: -knob / 2)
        }
        .frame(width: knob, height: height + 8, alignment: .top)
        .offset(x: x - knob / 2, y: -4)
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(Text("Playhead"))
        .accessibilityValue(Text(MediaTimes.timecode(player.currentTime)))
        .accessibilityAdjustableAction { dir in player.step(dir == .increment ? 1 : -1) }
    }

    private func dragGesture(axis: TimeAxis) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { v in
                let t = TrimPlanner.snapToFrame(min(max(0, axis.time(v.location.x)), duration), frameDuration)
                if dragging == nil {
                    dragging = .scrub
                    if let sel = selection?.wrappedValue {
                        let startX = v.startLocation.x
                        if abs(startX - (axis.x(sel.lowerBound) - MediaStyle.handleWidth / 2)) < MediaStyle.handleWidth { dragging = .inHandle }
                        else if abs(startX - (axis.x(sel.upperBound) + MediaStyle.handleWidth / 2)) < MediaStyle.handleWidth { dragging = .outHandle }
                    }
                    player.pause()
                }
                switch dragging {
                case .inHandle:
                    guard let sel = selection else { break }
                    let lo = min(t, sel.wrappedValue.upperBound - frameDuration)
                    sel.wrappedValue = max(0, lo)...sel.wrappedValue.upperBound
                    player.seek(to: sel.wrappedValue.lowerBound)
                case .outHandle:
                    guard let sel = selection else { break }
                    let hi = max(t, sel.wrappedValue.lowerBound + frameDuration)
                    sel.wrappedValue = sel.wrappedValue.lowerBound...min(duration, hi)
                    player.seek(to: max(0, sel.wrappedValue.upperBound - frameDuration))
                default:
                    player.seek(to: t)
                }
            }
            .onEnded { _ in dragging = nil }
    }

    private func nudge(inPoint: Bool, _ dir: AccessibilityAdjustmentDirection) {
        guard let sel = selection else { return }
        let d = dir == .increment ? frameDuration : -frameDuration
        if inPoint {
            sel.wrappedValue = max(0, min(sel.wrappedValue.lowerBound + d, sel.wrappedValue.upperBound - frameDuration))...sel.wrappedValue.upperBound
        } else {
            sel.wrappedValue = sel.wrappedValue.lowerBound...min(duration, max(sel.wrappedValue.upperBound + d, sel.wrappedValue.lowerBound + frameDuration))
        }
    }
}

/// "In 0:02.40" / "Out 0:08.60" tags over the trim handles, so the handles say
/// what they are and where they sit (not just a colour).
struct HandleLabels: View {
    let selection: ClosedRange<Double>
    let axis: TimeAxis
    let handleWidth: CGFloat
    var inTitle = String(localized: "In")
    var outTitle = String(localized: "Out")

    var body: some View {
        let x0 = axis.x(selection.lowerBound) - handleWidth, x1 = axis.x(selection.upperBound) + handleWidth
        ZStack(alignment: .topLeading) {
            // Pins the stack's leading edge to x = 0 so the guides below are absolute.
            Color.clear.frame(width: axis.width, height: 1)
            tag(inTitle, selection.lowerBound)
                .fixedSize()
                .alignmentGuide(.leading) { d in min(max(0, x0 - d.width), axis.width - d.width) * -1 }
            tag(outTitle, selection.upperBound)
                .fixedSize()
                .alignmentGuide(.leading) { d in min(max(0, x1), axis.width - d.width) * -1 }
        }
        .frame(width: axis.width, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func tag(_ title: String, _ t: Double) -> some View {
        HStack(spacing: DesignTokens.Space.xs) {
            Text(title).fontWeight(.bold)
            Text(MediaTimes.timecode(t)).monospacedDigit()
        }
        .font(.system(size: DesignTokens.TypeRamp.micro, weight: .semibold))
        .foregroundStyle(EditorPalette.onSelected)
        .padding(.horizontal, DesignTokens.Space.s - 2)
        .frame(height: EditorTokens.Timeline.labelHeight - 2)
        .background(Capsule().fill(EditorPalette.overlayCore))
    }
}

/// Handle shape: rounded on the outer side only.
struct UnevenHandleShape: Shape {
    let leading: Bool

    func path(in rect: CGRect) -> Path {
        let r = min(DesignTokens.Shape.tile, rect.width)
        var p = Path()
        if leading {
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX + r, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.minY + r), control: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - r))
            p.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        } else {
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
            p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        }
        p.closeSubpath()
        return p
    }
}
