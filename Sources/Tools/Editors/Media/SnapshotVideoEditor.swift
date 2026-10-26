import AppKit
import Combine
import SwiftUI
import AnyfmtCore

/// Snapshot frames: scrub to a frame, press F (or Add Frame) to capture it,
/// pick PNG or JPG. With no captures the middle frame is saved.
@MainActor
final class SnapshotVideoModel: MediaEditorModel {
    struct Capture: Identifiable, Equatable {
        let time: Double
        var image: NSImage?
        var id: Double { time }
    }

    let tool: ToolSpec
    let inputs: [URL]
    let session: MediaSession
    @Published private(set) var captures: [Capture] = []
    @Published var format: String
    private var bag: Set<AnyCancellable> = []

    init(tool: ToolSpec, inputs: [URL], options: OptionValues) {
        self.tool = tool
        self.inputs = inputs
        session = MediaSession(url: inputs[0], isVideo: true)
        format = options.string("format", default: "png") == "jpg" ? "jpg" : "png"
        let initial = MediaTimes.list(options.string("times", default: ""))
        session.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &bag)
        session.$state.sink { [weak self] state in
            guard state == .ready else { return }
            Task { @MainActor in
                guard let self else { return }
                self.session.player.seek(to: self.session.duration / 2)
                for t in initial { self.add(at: t) }
            }
        }.store(in: &bag)
    }

    func start() { session.load() }
    func teardown() { session.stop(); session.player.teardown() }
    func settle() async {
        await session.settle()
        let deadline = Date().addingTimeInterval(5)
        while captures.contains(where: { $0.image == nil }), Date() < deadline { try? await Task.sleep(nanoseconds: 30_000_000) }
    }

    var fd: Double { session.frameDuration }

    func addCurrent() { add(at: session.player.currentTime) }

    func add(at t: Double) {
        let frame = SnapshotVideoRunner.frameStart(at: t, frameDuration: fd)
        guard !captures.contains(where: { abs($0.time - frame) < fd / 2 }) else { return }
        captures.append(Capture(time: frame, image: nil))
        captures.sort { $0.time < $1.time }
        guard let url = session.asset?.url else { return }
        let size = CGSize(width: 160, height: 160)
        Task { [weak self] in
            let cg = await PlayerController.exactFrame(url, at: frame + 1e-4, maximumSize: size)
            guard let self, let cg, let i = self.captures.firstIndex(where: { $0.time == frame }) else { return }
            self.captures[i].image = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
    }

    func remove(_ c: Capture) { captures.removeAll { $0.time == c.time } }

    var options: OptionValues {
        OptionValues(["times": .string(captures.map { MediaTimes.format($0.time) }.joined(separator: ",")), "format": .string(format)])
    }

    var canSave: Bool { session.state.isReady }

    var statusLine: String? {
        guard session.state.isReady else { return nil }
        let f = format.uppercased()
        return captures.isEmpty ? String(localized: "Middle frame (\(MediaTimes.timecode(session.duration / 2))) · \(f)")
                                : String(localized: "\(captures.count) frames · \(f)")
    }

    func handle(_ key: EditorKey) -> Bool {
        let p = session.player
        switch key {
        case .space: p.togglePlay()
        case .left: p.step(-1)
        case .right: p.step(1)
        case .shiftLeft: p.jump(by: -1)
        case .shiftRight: p.jump(by: 1)
        case .character("f"): addCurrent()
        default: return false
        }
        return true
    }
}

struct SnapshotVideoEditor: View {
    @ObservedObject var model: SnapshotVideoModel
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
            TransportBar(player: model.session.player, duration: model.session.duration, leading: AnyView(
                Button { model.addCurrent() } label: { Label("Add Frame", systemImage: "camera") }
                    .help(String(localized: "Capture the frame on screen (F)"))))
            FilmstripTimeline(filmstrip: model.session.filmstrip, player: model.session.player,
                              duration: model.session.duration, frameDuration: model.fd,
                              markers: original ? [] : model.captures.enumerated().map { TimelineMarker(id: $0.offset, time: $0.element.time, label: "\($0.offset + 1)") },
                              onMarkerTap: { model.session.player.seek(to: $0.time) })
                .disabled(!model.session.state.isReady)
        }
        .padding(DesignTokens.Space.l)
    }

    @ViewBuilder
    private var sidebar: some View {
        SidebarSection(String(localized: "Format")) {
            EditorChoiceChips(String(localized: "Format"), selection: $model.format, options: [
                .init("png", String(localized: "PNG")),
                .init("jpg", String(localized: "JPG")),
            ])
            Text(model.format == "png" ? String(localized: "Lossless, exact pixels. Larger files.") : String(localized: "Smaller files, very high quality."))
                .font(MediaStyle.caption()).foregroundStyle(.secondary)
            if let v = model.session.info?.video {
                InfoRow(label: String(localized: "Size"), value: "\(v.displayWidth) × \(v.displayHeight) px")
            }
        }
        SidebarSection(String(localized: "Frames")) {
            if model.captures.isEmpty {
                Text("No frames yet, so the middle frame will be saved. Scrub to a frame and press F to add it.")
                    .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(Array(model.captures.enumerated()), id: \.element.id) { i, c in
                    HStack(spacing: DesignTokens.Space.s) {
                        Group {
                            if let image = c.image {
                                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
                            } else {
                                Rectangle().fill(EditorPalette.chip)
                            }
                        }
                        .frame(width: EditorTokens.thumbnail.width, height: EditorTokens.thumbnail.height)
                        .clipped()
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Frame \(i + 1)").font(MediaStyle.label(.medium))
                            Text(MediaTimes.timecode(c.time)).font(MediaStyle.caption().monospacedDigit()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { model.remove(c) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.anyfmtSecondaryText) }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("Remove frame \(i + 1)"))
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { model.session.player.seek(to: c.time) }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        SidebarSection(String(localized: "Keyboard")) {
            KeyHints(hints: [("F", String(localized: "Add the frame on screen")), ("← →", String(localized: "Previous / next frame")),
                             ("Space", String(localized: "Play / pause"))])
        }
    }
}
