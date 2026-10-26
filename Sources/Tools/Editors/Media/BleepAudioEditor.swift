import AppKit
import Combine
import SwiftUI
import AnyfmtCore

/// Bleep: drag across the waveform to mark ranges; each becomes a 1 kHz tone
/// or silence. Playback previews the result live.
@MainActor
final class BleepAudioModel: MediaEditorModel {
    let tool: ToolSpec
    let inputs: [URL]
    let audio: AudioSession
    @Published var ranges: [MarkedRange]
    @Published var selected: UUID?
    @Published var style: String
    /// Live preview: mute (and tone) inside ranges while playing.
    var previewEnabled = true
    private let tone = TonePlayer()
    private var bag: Set<AnyCancellable> = []

    init(tool: ToolSpec, inputs: [URL], options: OptionValues) {
        self.tool = tool
        self.inputs = inputs
        audio = AudioSession(url: inputs[0])
        ranges = MediaTimes.ranges(options.string("ranges", default: "")).map { MarkedRange($0) }
        style = options.string("style", default: "tone") == "silence" ? "silence" : "tone"
        session.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &bag)
        session.$state.sink { [weak self] state in
            guard state == .ready else { return }
            Task { @MainActor in self?.audio.loadWaveform() }
        }.store(in: &bag)
        player.onTick = { [weak self] t in self?.preview(at: t) }
    }

    var session: MediaSession { audio.session }
    var player: PlayerController { session.player }
    var duration: Double { session.duration }

    func start() { session.load() }
    func teardown() {
        tone.stop()
        audio.teardown()
    }
    func settle() async { await audio.settle() }

    private func preview(at t: Double) {
        let inside = previewEnabled && player.isPlaying && ranges.contains { $0.range.contains(t) }
        player.player.volume = inside ? 0 : 1
        tone.setActive(inside && style == "tone")
    }

    var merged: [ClosedRange<Double>] { MediaTimes.merge(ranges.map(\.range)) }
    var total: Double { merged.reduce(0) { $0 + $1.upperBound - $1.lowerBound } }

    var options: OptionValues {
        OptionValues([
            "ranges": .string(merged.map(MediaTimes.format).joined(separator: ";")),
            "style": .string(style),
        ])
    }

    var canSave: Bool { session.state.isReady && !ranges.isEmpty }

    var statusLine: String? {
        guard session.state.isReady else { return nil }
        if ranges.isEmpty { return String(localized: "Drag across the waveform to mark what to bleep") }
        return String(localized: "\(merged.count) bleeps · \(MediaTimes.timecode(total)) muted")
    }

    /// Adds a half-second bleep at the playhead.
    func addAtPlayhead() {
        let t = player.currentTime
        let r = MarkedRange(max(0, t - 0.1)...min(duration, t + 0.4))
        ranges.append(r)
        ranges.sort { $0.range.lowerBound < $1.range.lowerBound }
        selected = r.id
    }

    func remove(_ id: UUID) {
        ranges.removeAll { $0.id == id }
        if selected == id { selected = nil }
    }

    /// Plays the selected range with half a second of lead-in.
    func previewSelected() {
        guard let r = ranges.first(where: { $0.id == selected }) ?? ranges.first else { return }
        player.loopRange = nil
        player.seek(to: max(0, r.range.lowerBound - 0.5))
        player.play()
    }

    func handle(_ key: EditorKey) -> Bool {
        switch key {
        case .space: player.togglePlay()
        case .left: player.jump(by: -0.1)
        case .right: player.jump(by: 0.1)
        case .shiftLeft: player.jump(by: -1)
        case .shiftRight: player.jump(by: 1)
        case .character("m"): addAtPlayhead()
        case .delete:
            guard let s = selected else { return false }
            remove(s)
        case .command("="), .command("+"): audio.wave.zoom(by: 1.6, around: player.currentTime)
        case .command("-"): audio.wave.zoom(by: 1 / 1.6, around: player.currentTime)
        default: return false
        }
        return true
    }
}

struct BleepAudioEditor: View {
    @ObservedObject var model: BleepAudioModel
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
                                 ranges: original ? nil : $model.ranges, selectedRange: $model.selected, showsEdits: !original,
                                 bleepStyle: model.style)
                    .opacity(model.session.state.isReady ? 1 : 0.3)
                LoadingOverlay(state: model.session.state)
            }
            HStack {
                ZoomControls(wave: model.audio.wave)
                Spacer()
                Text("Drag across the waveform to mark a bleep").font(MediaStyle.caption()).foregroundStyle(Color.anyfmtSecondaryText)
            }
            Spacer(minLength: 0)
            TransportBar(player: model.player, duration: model.duration, showsFrameSteps: false, leading: AnyView(
                Button { model.addAtPlayhead() } label: { Label("Bleep Here", systemImage: "plus") }
                    .help(String(localized: "Mark half a second at the playhead (M)"))))
        }
        .padding(DesignTokens.Space.l)
        .onChange(of: original) { model.previewEnabled = !$0 }
    }

    @ViewBuilder
    private var sidebar: some View {
        SidebarSection(String(localized: "Replace with")) {
            EditorChoiceChips(String(localized: "Replace with"), selection: $model.style, options: [
                .init("tone", String(localized: "Tone"), systemImage: "speaker.wave.3"),
                .init("silence", String(localized: "Silence"), systemImage: "speaker.slash"),
            ])
            Text(model.style == "tone" ? String(localized: "A 1 kHz tone replaces the sound, like broadcast censoring.")
                                       : String(localized: "The marked parts go silent."))
                .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Button { model.previewSelected() } label: { Label("Preview", systemImage: "play.circle") }
                .disabled(model.ranges.isEmpty)
                .help(String(localized: "Play the selected bleep with a short lead-in"))
        }
        SidebarSection(String(localized: "Bleeps")) {
            if model.ranges.isEmpty {
                Text("None yet. Drag across the waveform, or press M at the playhead.")
                    .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(model.ranges.enumerated()), id: \.element.id) { i, r in
                    let isSelected = model.selected == r.id
                    HStack(spacing: DesignTokens.Space.s) {
                        Text("\(i + 1)")
                            .font(MediaStyle.caption(.bold).monospacedDigit()).foregroundStyle(EditorPalette.onWarm)
                            .frame(width: 20, height: 16).background(Capsule().fill(EditorPalette.flame))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(MediaTimes.timecode(r.range.lowerBound)) – \(MediaTimes.timecode(r.range.upperBound))")
                                .font(MediaStyle.timecode)
                            Text(String(format: "%.2f s", r.range.upperBound - r.range.lowerBound))
                                .font(MediaStyle.caption().monospacedDigit()).foregroundStyle(Color.anyfmtSecondaryText)
                        }
                        Spacer()
                        Button { model.remove(r.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.anyfmtSecondaryText) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Remove bleep \(i + 1)"))
                    }
                    .padding(.vertical, 4).padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous)
                        .fill(isSelected ? MediaStyle.danger.opacity(0.16) : .clear))
                    .overlay(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous)
                        .strokeBorder(isSelected ? MediaStyle.danger : .clear, lineWidth: DesignTokens.Shape.hairline + 0.5))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.selected = r.id
                        model.player.seek(to: r.range.lowerBound)
                        model.audio.wave.reveal(r.range.lowerBound)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                Button(String(localized: "Remove All")) { model.ranges = []; model.selected = nil }
            }
        }
        SidebarSection(String(localized: "Keyboard")) {
            KeyHints(hints: [("Space", String(localized: "Play with preview")), ("M", String(localized: "Bleep at playhead")),
                             ("⌫", String(localized: "Remove selected bleep")), ("⌘= ⌘−", String(localized: "Zoom in / out"))])
        }
    }
}
