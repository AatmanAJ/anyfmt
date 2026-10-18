import AppKit
import Combine
import SwiftUI
import HaloCore

/// Trim video: filmstrip with in/out handles, synced player, frame stepping,
/// lossless-when-possible with a live keyframe verdict.
@MainActor
final class TrimVideoModel: MediaEditorModel {
    let tool: ToolSpec
    let inputs: [URL]
    let session: MediaSession
    @Published var range: ClosedRange<Double> = 0...0 { didSet { syncLoop() } }
    @Published var lossless: Bool
    private var requested: ClosedRange<Double>?
    private var bag: Set<AnyCancellable> = []

    init(tool: ToolSpec, inputs: [URL], options: OptionValues) {
        self.tool = tool
        self.inputs = inputs
        session = MediaSession(url: inputs[0], isVideo: true)
        lossless = options.bool(OptionKey.lossless, default: true)
        requested = MediaTimes.range(options.string("range", default: ""))
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
        let d = session.duration
        range = requested.map { max(0, $0.lowerBound)...min(d, $0.upperBound) } ?? 0...d
        session.player.seek(to: range.lowerBound)
    }

    private func syncLoop() { session.player.loopRange = range.upperBound > range.lowerBound ? range : nil }

    var duration: Double { session.duration }
    var fd: Double { session.frameDuration }

    var plan: TrimPlan {
        TrimPlanner.plan(requested: range, duration: duration, frameDuration: fd, keyframes: session.keyframes, lossless: lossless)
    }

    var isWholeFile: Bool { range.lowerBound < fd / 2 && range.upperBound > duration - fd / 2 }

    var options: OptionValues {
        OptionValues(["range": .string(MediaTimes.format(range)), OptionKey.lossless: .bool(lossless)])
    }

    var canSave: Bool { session.state.isReady && duration > 0 && !isWholeFile }

    var statusLine: String? {
        guard session.state.isReady else { return nil }
        let len = range.upperBound - range.lowerBound
        return String(localized: "\(MediaTimes.timecode(range.lowerBound)) – \(MediaTimes.timecode(range.upperBound)) · \(MediaTimes.timecode(len)) of \(MediaTimes.timecode(duration))")
    }

    func setIn() {
        let t = TrimPlanner.snapToFrame(session.player.currentTime, fd)
        range = min(t, range.upperBound - fd)...range.upperBound
    }

    func setOut() {
        let t = TrimPlanner.snapToFrame(session.player.currentTime + fd, fd)
        range = range.lowerBound...min(duration, max(t, range.lowerBound + fd))
    }

    func handle(_ key: EditorKey) -> Bool {
        let p = session.player
        switch key {
        case .space: p.togglePlay()
        case .left: p.step(-1)
        case .right: p.step(1)
        case .shiftLeft: p.jump(by: -1)
        case .shiftRight: p.jump(by: 1)
        case .character("i"): setIn()
        case .character("o"): setOut()
        default: return false
        }
        return true
    }
}

struct TrimVideoEditor: View {
    @ObservedObject var model: TrimVideoModel
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
            TransportBar(player: model.session.player, duration: model.duration,
                         leading: AnyView(inOutButtons))
            FilmstripTimeline(filmstrip: model.session.filmstrip, player: model.session.player,
                              duration: model.duration, frameDuration: model.fd,
                              selection: original ? nil : $model.range, dimOutside: true)
                .disabled(!model.session.state.isReady)
        }
        .padding(DesignTokens.Space.l)
        .onChange(of: original) { model.session.player.loopRange = $0 ? nil : model.range }
    }

    private var inOutButtons: some View {
        HStack(spacing: DesignTokens.Space.xs) {
            Button { model.setIn() } label: { Label("Set In", systemImage: "arrow.right.to.line") }
                .help(String(localized: "Set the in point at the playhead (I)"))
            Button { model.setOut() } label: { Label("Set Out", systemImage: "arrow.left.to.line") }
                .help(String(localized: "Set the out point at the playhead (O)"))
        }
        .labelStyle(.titleAndIcon)
        .controlSize(.small)
    }

    @ViewBuilder
    private var sidebar: some View {
        SidebarSection(String(localized: "Selection")) {
            timeRow(String(localized: "In"), value: Binding(
                get: { model.range.lowerBound },
                set: { model.range = min($0, model.range.upperBound - model.fd)...model.range.upperBound }))
            timeRow(String(localized: "Out"), value: Binding(
                get: { model.range.upperBound },
                set: { model.range = model.range.lowerBound...max($0, model.range.lowerBound + model.fd) }))
            InfoRow(label: String(localized: "Duration"), value: MediaTimes.timecode(model.range.upperBound - model.range.lowerBound))
            if let v = model.session.info?.video {
                InfoRow(label: String(localized: "Video"), value: "\(v.displayWidth) × \(v.displayHeight) · \(String(format: "%.2f", v.frameRate)) fps")
            }
        }
        Divider()
        SidebarSection(String(localized: "Quality")) {
            Toggle(String(localized: "Lossless when possible"), isOn: $model.lossless)
                .toggleStyle(.switch)
                .controlSize(.small)
            Text("Lossless cuts copy the video as-is: instant, with no quality loss, but they can only start on a keyframe. Turn it off for cuts exact to the frame (re-encodes).")
                .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            planNote
        }
        Divider()
        SidebarSection(String(localized: "Keyboard")) {
            KeyHints(hints: [("Space", String(localized: "Play / pause selection")), ("← →", String(localized: "Previous / next frame")),
                             ("⇧← ⇧→", String(localized: "Back / forward 1 second")), ("I  O", String(localized: "Set in / out at playhead")),
                             ("B", String(localized: "Before / after"))])
        }
    }

    private func timeRow(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label).font(MediaStyle.label()).foregroundStyle(.secondary).frame(width: 34, alignment: .leading)
            Spacer()
            TimecodeField(label: label, seconds: value, range: 0...max(0, model.duration))
        }
    }

    @ViewBuilder
    private var planNote: some View {
        if model.session.state.isReady {
            switch model.plan {
            case .copy(let s, let e, _):
                let snapped = abs(s - model.range.lowerBound) > model.fd / 2 || abs(e - model.range.upperBound) > model.fd / 2
                Note(systemImage: "checkmark.seal.fill",
                     text: snapped ? String(localized: "Lossless. Cuts snap to the nearest keyframes: \(MediaTimes.timecode(s)) – \(MediaTimes.timecode(e)).")
                                   : String(localized: "Lossless. Your cuts are already on keyframes."),
                     tint: MediaStyle.success)
            case .reencode(_, _, let reason):
                switch reason {
                case .losslessOff:
                    Note(systemImage: "film.stack", text: String(localized: "Re-encodes for frame-exact cuts, using the hardware encoder when available."))
                case .noVideoIndex:
                    Note(systemImage: "hourglass", text: String(localized: "Checking keyframes…"))
                case .noKeyframeNearStart, .noKeyframeNearEnd:
                    Note(systemImage: "exclamationmark.circle.fill",
                         text: String(localized: "No keyframe within 1 second of a cut, so this trim re-encodes to stay frame-exact."),
                         tint: .orange)
                }
            }
        }
    }
}
