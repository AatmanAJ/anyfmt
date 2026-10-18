import AppKit
import Combine
import SwiftUI
import HaloCore

/// Split video: split markers on the filmstrip, or every N seconds, with a
/// live preview of the parts and whether the cut can be lossless.
@MainActor
final class SplitVideoModel: MediaEditorModel {
    let tool: ToolSpec
    let inputs: [URL]
    let session: MediaSession
    @Published var mode: String
    @Published var markers: [Double]
    @Published var every: Int
    @Published var lossless: Bool
    private var bag: Set<AnyCancellable> = []

    static let everyPresets = [5, 10, 30, 60, 300, 600]

    init(tool: ToolSpec, inputs: [URL], options: OptionValues) {
        self.tool = tool
        self.inputs = inputs
        session = MediaSession(url: inputs[0], isVideo: true)
        mode = options.string("mode", default: "every") == "at" ? "at" : "every"
        markers = MediaTimes.list(options.string("at", default: ""))
        every = max(1, options.int("every", default: 60))
        lossless = options.bool(OptionKey.lossless, default: true)
        session.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &bag)
        session.$state.sink { [weak self] state in
            guard state == .ready else { return }
            Task { @MainActor in self?.didLoad() }
        }.store(in: &bag)
    }

    func start() { session.load(wantsKeyframes: true) }
    func teardown() { session.stop(); session.player.teardown() }
    func settle() async {
        await session.settle()
        let deadline = Date().addingTimeInterval(5)
        while session.keyframes == nil, Date() < deadline { try? await Task.sleep(nanoseconds: 30_000_000) }
    }

    private func didLoad() {
        // A sensible default "every" for short clips: about four parts.
        let d = session.duration
        if Double(every) >= d { every = max(1, Int((d / 4).rounded(.up))) }
    }

    var duration: Double { session.duration }
    var fd: Double { session.frameDuration }

    var cuts: [Double] {
        SplitPlan.requestedCuts(mode: mode, every: Double(every), at: markers, duration: duration, minimumSegment: max(fd, 0.1))
    }

    var cutPlan: SplitPlan {
        SplitPlan.make(cuts: cuts, duration: duration, frameDuration: fd, keyframes: session.keyframes, preferLossless: lossless)
    }

    /// Part boundaries for the preview bar (where the parts will actually start).
    var parts: [ClosedRange<Double>] {
        let b = [0] + cutPlan.cuts + [duration]
        return zip(b, b.dropFirst()).map { $0...$1 }
    }

    var options: OptionValues {
        OptionValues([
            "mode": .string(mode),
            "at": .string(markers.map(MediaTimes.format).joined(separator: ",")),
            "every": .int(every),
            OptionKey.lossless: .bool(lossless),
        ])
    }

    var canSave: Bool { session.state.isReady && !cuts.isEmpty }

    var statusLine: String? {
        guard session.state.isReady else { return nil }
        let n = cuts.isEmpty ? 1 : cutPlan.segmentCount
        return cutPlan.lossless ? String(localized: "\(n) parts · lossless") : String(localized: "\(n) parts · re-encoded at exact times")
    }

    func addMarker() {
        let t = TrimPlanner.snapToFrame(session.player.currentTime, fd)
        guard t > fd, t < duration - fd, !markers.contains(where: { abs($0 - t) < fd / 2 }) else { return }
        mode = "at"
        markers = (markers + [t]).sorted()
    }

    func removeMarker(_ t: Double) { markers.removeAll { abs($0 - t) < 1e-6 } }

    /// Removes the marker nearest the playhead (within a second).
    func removeNearestMarker() {
        let t = session.player.currentTime
        guard let m = markers.min(by: { abs($0 - t) < abs($1 - t) }), abs(m - t) <= 1 else { return }
        removeMarker(m)
    }

    func handle(_ key: EditorKey) -> Bool {
        let p = session.player
        switch key {
        case .space: p.togglePlay()
        case .left: p.step(-1)
        case .right: p.step(1)
        case .shiftLeft: p.jump(by: -1)
        case .shiftRight: p.jump(by: 1)
        case .character("m"): addMarker()
        case .delete: removeNearestMarker()
        default: return false
        }
        return true
    }
}

struct SplitVideoEditor: View {
    @ObservedObject var model: SplitVideoModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void

    var body: some View {
        EditorShell(model: model, preview: { original in preview(original) }, sidebar: { sidebar }, onSave: onSave, onClose: onClose)
            .background(KeyMonitor(handler: model.handle))
    }

    private func preview(_ original: Bool) -> some View {
        VStack(spacing: DesignTokens.Space.m) {
            ZStack {
                VideoSurface(player: model.session.player, aspect: model.session.displaySize)
                    .opacity(model.session.state.isReady ? 1 : 0)
                LoadingOverlay(state: model.session.state)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            TransportBar(player: model.session.player, duration: model.duration, leading: AnyView(
                Button { model.addMarker() } label: { Label("Split Here", systemImage: "scissors") }
                    .controlSize(.small)
                    .help(String(localized: "Add a split at the playhead (M)"))))
            FilmstripTimeline(filmstrip: model.session.filmstrip, player: model.session.player,
                              duration: model.duration, frameDuration: model.fd,
                              markers: original ? [] : markers, onMarkerTap: { model.session.player.seek(to: $0.time) })
                .disabled(!model.session.state.isReady)
            if !original && model.session.state.isReady { PartsBar(parts: model.parts, duration: model.duration) }
        }
        .padding(DesignTokens.Space.l)
    }

    /// Your marks in "at" mode; the computed cuts in "every" mode.
    private var markers: [TimelineMarker] {
        let times = model.mode == "at" ? model.markers : model.cuts
        return times.enumerated().map { TimelineMarker(id: $0.offset, time: $0.element, label: "\($0.offset + 2)") }
    }

    @ViewBuilder
    private var sidebar: some View {
        SidebarSection(String(localized: "Split")) {
            Picker(String(localized: "Split"), selection: $model.mode) {
                Text("At markers").tag("at")
                Text("Every…").tag("every")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            if model.mode == "every" { everyControls } else { markerList }
        }
        Divider()
        SidebarSection(String(localized: "Quality")) {
            Toggle(String(localized: "Lossless when possible"), isOn: $model.lossless).toggleStyle(.switch).controlSize(.small)
            if model.session.state.isReady && !model.cuts.isEmpty {
                if model.cutPlan.lossless {
                    let moved = zip(model.cutPlan.cuts, model.cuts).contains { abs($0 - $1) > model.fd / 2 }
                    Note(systemImage: "checkmark.seal.fill",
                         text: moved ? String(localized: "Lossless. Parts start on the nearest keyframes: \(model.cutPlan.cuts.map { MediaTimes.timecode($0) }.joined(separator: ", ")).")
                                     : String(localized: "Lossless. Every cut is already on a keyframe."),
                         tint: MediaStyle.success)
                } else if model.lossless {
                    Note(systemImage: "exclamationmark.circle.fill", text: String(localized: "Some cuts are far from a keyframe, so the video re-encodes once and every part starts exactly on time."), tint: .orange)
                } else {
                    Note(systemImage: "film.stack", text: String(localized: "Re-encodes once; every part starts exactly on time."))
                }
            }
        }
        Divider()
        SidebarSection(String(localized: "Keyboard")) {
            KeyHints(hints: [("Space", String(localized: "Play / pause")), ("← →", String(localized: "Previous / next frame")),
                             ("M", String(localized: "Split at playhead")), ("⌫", String(localized: "Remove nearest split"))])
        }
    }

    private var everyControls: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            HStack {
                Text("Part length").font(MediaStyle.label()).foregroundStyle(.secondary)
                Spacer()
                TextField(String(localized: "Seconds"), value: $model.every, format: .number)
                    .textFieldStyle(.roundedBorder).frame(width: 64).multilineTextAlignment(.trailing)
                Stepper(String(localized: "Part length"), value: $model.every, in: 1...36000).labelsHidden()
                Text("s").font(MediaStyle.caption()).foregroundStyle(.secondary)
            }
            HStack(spacing: DesignTokens.Space.xs) {
                ForEach(SplitVideoModel.everyPresets, id: \.self) { s in
                    Button(s < 60 ? "\(s)s" : "\(s / 60)m") { model.every = s }
                        .controlSize(.small)
                        .buttonStyle(.bordered)
                        .tint(model.every == s ? MediaStyle.accent : nil)
                }
            }
            if model.session.state.isReady {
                let parts = model.parts
                let last = parts.last.map { $0.upperBound - $0.lowerBound } ?? 0
                Text(parts.count > 1
                     ? String(localized: "\(parts.count) parts of \(MediaTimes.timecode(Double(model.every), fraction: 0)), last one \(MediaTimes.timecode(last))")
                     : String(localized: "The video is shorter than one part."))
                    .font(MediaStyle.caption()).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var markerList: some View {
        if model.markers.isEmpty {
            Text("Move the playhead and press M (or Split Here) to add a split.")
                .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(spacing: 2) {
                ForEach(Array(model.markers.enumerated()), id: \.element) { i, t in
                    HStack {
                        Text("\(i + 2)").font(MediaStyle.caption(.bold).monospacedDigit()).foregroundStyle(.white)
                            .frame(width: 18, height: 16).background(Capsule().fill(MediaStyle.mint))
                        Button(MediaTimes.timecode(t)) { model.session.player.seek(to: t) }
                            .buttonStyle(.plain).font(MediaStyle.timecode)
                        Spacer()
                        Button { model.removeMarker(t) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Remove split at \(MediaTimes.timecode(t))"))
                    }
                    .padding(.vertical, 3)
                }
            }
            Button(String(localized: "Remove All")) { model.markers = [] }.controlSize(.small)
        }
    }
}

/// Coloured preview of the resulting parts with numbers and lengths.
private struct PartsBar: View {
    let parts: [ClosedRange<Double>]
    let duration: Double

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(parts.enumerated()), id: \.offset) { i, p in
                    let w = max(4, geo.size.width * CGFloat((p.upperBound - p.lowerBound) / max(duration, 0.001)) - 2)
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).fill((i % 2 == 0 ? MediaStyle.accent : MediaStyle.mint).opacity(0.22))
                        RoundedRectangle(cornerRadius: 4).strokeBorder((i % 2 == 0 ? MediaStyle.accent : MediaStyle.mint).opacity(0.6))
                        if w > 54 {
                            Text("\(i + 1) · \(MediaTimes.timecode(p.upperBound - p.lowerBound, fraction: 1))")
                                .font(MediaStyle.caption(.medium).monospacedDigit()).lineLimit(1)
                        } else if w > 16 {
                            Text("\(i + 1)").font(MediaStyle.caption(.medium))
                        }
                    }
                    .frame(width: w)
                    .accessibilityElement()
                    .accessibilityLabel(Text("Part \(i + 1), \(MediaTimes.timecode(p.upperBound - p.lowerBound))"))
                }
            }
        }
        .frame(height: 22)
    }
}
