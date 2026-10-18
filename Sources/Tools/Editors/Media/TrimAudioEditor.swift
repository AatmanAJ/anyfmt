import AppKit
import Combine
import SwiftUI
import HaloCore

/// Trim audio: zoomable waveform with in/out handles and playback.
@MainActor
final class TrimAudioModel: MediaEditorModel {
    let tool: ToolSpec
    let inputs: [URL]
    let audio: AudioSession
    @Published var range: ClosedRange<Double> = 0...0 { didSet { syncLoop() } }
    @Published var lossless: Bool
    private var requested: ClosedRange<Double>?
    private var bag: Set<AnyCancellable> = []

    init(tool: ToolSpec, inputs: [URL], options: OptionValues) {
        self.tool = tool
        self.inputs = inputs
        audio = AudioSession(url: inputs[0])
        lossless = options.bool(OptionKey.lossless, default: true)
        requested = MediaTimes.range(options.string("range", default: ""))
        session.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &bag)
        session.$state.sink { [weak self] state in
            guard state == .ready else { return }
            Task { @MainActor in self?.didLoad() }
        }.store(in: &bag)
    }

    var session: MediaSession { audio.session }
    var player: PlayerController { session.player }

    func start() { session.load() }
    func teardown() { audio.teardown() }
    func settle() async { await audio.settle() }

    private func didLoad() {
        let d = session.duration
        range = requested.map { max(0, $0.lowerBound)...min(d, $0.upperBound) } ?? 0...d
        audio.loadWaveform()
        player.seek(to: range.lowerBound)
    }

    private func syncLoop() { player.loopRange = range.upperBound > range.lowerBound ? range : nil }

    var duration: Double { session.duration }
    private let minimum = 0.05

    var copyPossible: Bool {
        guard let a = session.info?.audio, let c = MediaContainer(extension: inputs[0].pathExtension) else { return false }
        return TrimAudioRunner.canCopy(codec: a.codec, container: c)
    }

    var isLosslessCodec: Bool {
        guard let c = session.info?.audio?.codec else { return false }
        return c.hasPrefix("pcm_") || c == "flac" || c == "alac"
    }

    var isWholeFile: Bool { range.lowerBound < 0.005 && range.upperBound > duration - 0.005 }

    var options: OptionValues {
        OptionValues(["range": .string(MediaTimes.format(range)), OptionKey.lossless: .bool(lossless)])
    }

    var canSave: Bool { session.state.isReady && !isWholeFile && range.upperBound - range.lowerBound >= minimum }

    var statusLine: String? {
        guard session.state.isReady else { return nil }
        return String(localized: "\(MediaTimes.timecode(range.lowerBound)) – \(MediaTimes.timecode(range.upperBound)) · \(MediaTimes.timecode(range.upperBound - range.lowerBound)) of \(MediaTimes.timecode(duration))")
    }

    func setIn() { range = min(player.currentTime, range.upperBound - minimum)...range.upperBound }
    func setOut() { range = range.lowerBound...min(duration, max(player.currentTime, range.lowerBound + minimum)) }

    func handle(_ key: EditorKey) -> Bool {
        switch key {
        case .space: player.togglePlay()
        case .left: player.jump(by: -0.1)
        case .right: player.jump(by: 0.1)
        case .shiftLeft: player.jump(by: -1)
        case .shiftRight: player.jump(by: 1)
        case .character("i"): setIn()
        case .character("o"): setOut()
        case .command("="), .command("+"): audio.wave.zoom(by: 1.6, around: player.currentTime)
        case .command("-"): audio.wave.zoom(by: 1 / 1.6, around: player.currentTime)
        default: return false
        }
        return true
    }
}

struct TrimAudioEditor: View {
    @ObservedObject var model: TrimAudioModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void

    var body: some View {
        EditorShell(model: model, preview: { original in preview(original) }, sidebar: { sidebar }, onSave: onSave, onClose: onClose)
            .background(KeyMonitor(handler: model.handle))
    }

    private func preview(_ original: Bool) -> some View {
        VStack(spacing: DesignTokens.Space.m) {
            AudioHeader(url: model.inputs[0], info: model.session.info)
            Spacer(minLength: 0)
            ZStack {
                WaveformTimeline(wave: model.audio.wave, player: model.player, duration: model.duration,
                                 selection: original ? nil : $model.range)
                    .opacity(model.session.state.isReady ? 1 : 0.3)
                LoadingOverlay(state: model.session.state)
            }
            HStack {
                ZoomControls(wave: model.audio.wave, fitTo: original ? nil : model.range)
                Spacer()
            }
            Spacer(minLength: 0)
            TransportBar(player: model.player, duration: model.duration, showsFrameSteps: false, leading: AnyView(
                HStack(spacing: DesignTokens.Space.xs) {
                    Button { model.setIn() } label: { Label("Set In", systemImage: "arrow.right.to.line") }
                        .help(String(localized: "Set the start at the playhead (I)"))
                    Button { model.setOut() } label: { Label("Set Out", systemImage: "arrow.left.to.line") }
                        .help(String(localized: "Set the end at the playhead (O)"))
                }
                .controlSize(.small)))
        }
        .padding(DesignTokens.Space.l)
        .onChange(of: original) { model.player.loopRange = $0 ? nil : model.range }
    }

    @ViewBuilder
    private var sidebar: some View {
        SidebarSection(String(localized: "Selection")) {
            row(String(localized: "Start"), Binding(get: { model.range.lowerBound },
                                                    set: { model.range = min($0, model.range.upperBound - 0.05)...model.range.upperBound }))
            row(String(localized: "End"), Binding(get: { model.range.upperBound },
                                                  set: { model.range = model.range.lowerBound...max($0, model.range.lowerBound + 0.05) }))
            InfoRow(label: String(localized: "Length"), value: MediaTimes.timecode(model.range.upperBound - model.range.lowerBound))
        }
        Divider()
        SidebarSection(String(localized: "Quality")) {
            if model.copyPossible {
                Toggle(String(localized: "Lossless when possible"), isOn: $model.lossless).toggleStyle(.switch).controlSize(.small)
                Text(model.lossless ? String(localized: "Copies the audio without re-encoding. Cuts land within a few milliseconds of your marks.")
                                    : String(localized: "Re-encodes at the original bitrate for sample-exact cuts."))
                    .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else if model.isLosslessCodec {
                Note(systemImage: "checkmark.seal.fill", text: String(localized: "This format is lossless, so the trim is sample-exact with no quality loss."), tint: MediaStyle.success)
            } else {
                Note(systemImage: "waveform", text: String(localized: "Re-encodes in the same format and bitrate, cut exactly at your marks."))
            }
        }
        Divider()
        SidebarSection(String(localized: "Keyboard")) {
            KeyHints(hints: [("Space", String(localized: "Play / pause selection")), ("← →", String(localized: "Back / forward 0.1 s")),
                             ("I  O", String(localized: "Set start / end")), ("⌘= ⌘−", String(localized: "Zoom in / out")),
                             ("⌥ scroll", String(localized: "Zoom at the pointer"))])
        }
    }

    private func row(_ label: String, _ value: Binding<Double>) -> some View {
        HStack {
            Text(label).font(MediaStyle.label()).foregroundStyle(.secondary)
            Spacer()
            TimecodeField(label: label, seconds: value, range: 0...max(0, model.duration))
        }
    }
}

/// File name and format facts above a waveform.
struct AudioHeader: View {
    let url: URL
    let info: MediaInfo?

    var body: some View {
        HStack(spacing: DesignTokens.Space.m) {
            Image(systemName: "waveform")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.small).fill(MediaStyle.accent))
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent).font(MediaStyle.body(.semibold)).lineLimit(1).truncationMode(.middle)
                if let info, let a = info.audio {
                    Text(Self.describe(a, duration: info.duration)).font(MediaStyle.caption().monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    static func describe(_ a: MediaInfo.Audio, duration: Double) -> String {
        var parts = [MediaTimes.timecode(duration), MediaStyle.codecName(a.codec),
                     String(format: "%.1f kHz", Double(a.sampleRate) / 1000)]
        parts.append(a.channels == 1 ? String(localized: "mono") : (a.channels == 2 ? String(localized: "stereo") : String(localized: "\(a.channels) channels")))
        if let b = a.bitRate, b > 0 { parts.append("\(b / 1000) kbps") }
        return parts.joined(separator: " · ")
    }
}
