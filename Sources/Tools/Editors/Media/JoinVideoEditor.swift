import AppKit
import AVFoundation
import SwiftUI
import AnyfmtCore

/// Join clips: reorderable list with thumbnails and details, and an upfront
/// verdict on whether the join is lossless or needs a re-encode (and why).
@MainActor
final class JoinVideoModel: MediaEditorModel {
    struct Clip: Identifiable, Equatable {
        let url: URL
        var info: MediaInfo?
        var thumbnail: NSImage?
        var failed = false
        var id: URL { url }
    }

    let tool: ToolSpec
    let originalInputs: [URL]
    @Published var clips: [Clip]
    @Published var selection: URL?
    private var tasks: [Task<Void, Never>] = []

    init(tool: ToolSpec, inputs: [URL], options: OptionValues) {
        self.tool = tool
        originalInputs = inputs
        let order = JoinPlanner.order(options.string("order", default: ""), count: inputs.count) ?? Array(inputs.indices)
        clips = order.map { Clip(url: inputs[$0]) }
    }

    /// The clips in the order they'll be joined (EditorResult carries this order).
    var inputs: [URL] { clips.map(\.url) }

    func start() {
        guard tasks.isEmpty else { return }
        for clip in clips {
            let url = clip.url
            tasks.append(Task { [weak self] in
                let info = try? await MediaInfo.load(url)
                let mid = (info?.duration ?? 0) / 2
                let thumb = await PlayerController.exactFrame(url, at: mid, maximumSize: CGSize(width: 240, height: 240))
                guard let self, let i = self.clips.firstIndex(where: { $0.url == url }) else { return }
                self.clips[i].info = info
                self.clips[i].failed = info == nil
                if let thumb { self.clips[i].thumbnail = NSImage(cgImage: thumb, size: NSSize(width: thumb.width, height: thumb.height)) }
            })
        }
    }

    func teardown() { tasks.forEach { $0.cancel() } }

    func settle() async {
        let deadline = Date().addingTimeInterval(10)
        while !isLoaded, Date() < deadline { try? await Task.sleep(nanoseconds: 30_000_000) }
    }

    var subject: String { String(localized: "\(clips.count) clips") }
    var isLoaded: Bool { clips.allSatisfy { $0.info != nil || $0.failed } }
    var verdict: JoinPlanner.Verdict? {
        let infos = clips.compactMap(\.info)
        guard isLoaded, infos.count == clips.count else { return nil }
        return JoinPlanner.verdict(infos)
    }

    var totalDuration: Double { clips.compactMap { $0.info?.duration }.reduce(0, +) }

    func move(from source: IndexSet, to destination: Int) { clips.move(fromOffsets: source, toOffset: destination) }

    func move(_ clip: Clip, by delta: Int) {
        guard let i = clips.firstIndex(of: clip) else { return }
        let j = min(max(0, i + delta), clips.count - 1)
        guard i != j else { return }
        clips.swapAt(i, j)
    }

    func remove(_ clip: Clip) {
        guard clips.count > 2 else { return }
        clips.removeAll { $0.url == clip.url }
    }

    /// The drag order lives in `inputs`, so no "order" option is needed.
    var options: OptionValues { OptionValues(["order": .string("")]) }

    var canSave: Bool { clips.count >= 2 && verdict != nil }

    var statusLine: String? {
        guard isLoaded else { return String(localized: "Reading clips…") }
        return String(localized: "\(clips.count) clips · \(MediaTimes.timecode(totalDuration)) total")
    }

    /// Short "why it differs" tag for a clip versus the first.
    func mismatch(for clip: Clip) -> String? {
        guard let first = clips.first?.info?.video, let v = clip.info?.video, clip.url != clips.first?.url else { return nil }
        if v.displayWidth != first.displayWidth || v.displayHeight != first.displayHeight { return String(localized: "Different size") }
        if v.codec != first.codec { return String(localized: "Different codec") }
        if abs(v.frameRate - first.frameRate) > 0.01 { return String(localized: "Different frame rate") }
        if (clip.info?.hasAudio ?? false) != (clips.first?.info?.hasAudio ?? false) { return String(localized: "Sound differs") }
        return nil
    }
}

struct JoinVideoEditor: View {
    @ObservedObject var model: JoinVideoModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void

    var body: some View {
        EditorShell(model: model, preview: { original in preview(original) }, sidebar: { sidebar }, onSave: onSave, onClose: onClose)
    }

    private func preview(_ original: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            HStack {
                EditorCaption(original ? String(localized: "Drag order") : String(localized: "Join order"))
                Spacer()
                Text("Drag clips to reorder").font(MediaStyle.caption()).foregroundStyle(Color.anyfmtSecondaryText)
            }
            .padding(.horizontal, DesignTokens.Space.xs)
            List {
                ForEach(Array(displayed(original).enumerated()), id: \.element.id) { i, clip in
                    ClipRow(index: i, clip: clip, mismatch: model.mismatch(for: clip),
                            canMoveUp: i > 0 && !original, canMoveDown: i < model.clips.count - 1 && !original,
                            canRemove: model.clips.count > 2 && !original,
                            move: { model.move(clip, by: $0) }, remove: { model.remove(clip) })
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
                }
                .onMove(perform: original ? nil : { model.move(from: $0, to: $1) })
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            if !original, model.isLoaded {
                EditorCaption(String(localized: "Result · \(MediaTimes.timecode(model.totalDuration))"))
                    .padding(.horizontal, DesignTokens.Space.xs)
                resultBar
            }
        }
        .padding(DesignTokens.Space.l)
    }

    private func displayed(_ original: Bool) -> [JoinVideoModel.Clip] {
        guard original else { return model.clips }
        return model.originalInputs.compactMap { u in model.clips.first { $0.url == u } }
    }

    /// The joined timeline as proportional blocks.
    private var resultBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(model.clips.enumerated()), id: \.element.id) { i, c in
                    let d = c.info?.duration ?? 0
                    ZStack {
                        if let t = c.thumbnail {
                            Image(nsImage: t).resizable().aspectRatio(contentMode: .fill)
                        }
                        Rectangle().fill(EditorPalette.overlayHalo.opacity(0.45))
                        Text("\(i + 1)").font(MediaStyle.label(.bold)).foregroundStyle(EditorPalette.overlayRim)
                    }
                    .frame(width: max(8, geo.size.width * CGFloat(d / max(model.totalDuration, 0.001)) - 2), height: 30)
                    .clipped()
                }
            }
        }
        .frame(height: 30)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var sidebar: some View {
        SidebarSection(String(localized: "Result")) {
            InfoRow(label: String(localized: "Clips"), value: "\(model.clips.count)")
            InfoRow(label: String(localized: "Length"), value: MediaTimes.timecode(model.totalDuration))
            if let v = model.verdict {
                if v.lossless {
                    InfoRow(label: String(localized: "Format"), value: model.clips.first?.url.pathExtension.uppercased() ?? "")
                    Note(systemImage: "checkmark.seal.fill",
                         text: String(localized: "All clips match, so they’re joined losslessly: no re-encode, same quality, done in seconds."),
                         tint: MediaStyle.success)
                } else {
                    InfoRow(label: String(localized: "Format"), value: "MP4 · H.264 · AAC")
                    InfoRow(label: String(localized: "Size"), value: "\(v.width) × \(v.height)")
                    Note(systemImage: "exclamationmark.circle.fill",
                         text: String(localized: "These clips don’t match, so they’ll be re-encoded to one MP4. Smaller clips are letterboxed, never stretched."),
                         tint: MediaStyle.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(v.reasons, id: \.self) { r in
                            Label(r, systemImage: "circle.fill").labelStyle(BulletLabelStyle())
                        }
                    }
                }
            } else {
                HStack(spacing: DesignTokens.Space.s) {
                    ProgressView().controlSize(.small)
                    Text("Reading clips…").font(MediaStyle.caption()).foregroundStyle(.secondary)
                }
            }
        }
        SidebarSection(String(localized: "Order")) {
            Text("Clips play in list order. Drag a row, or use the arrows, to move it.")
                .font(MediaStyle.caption()).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct BulletLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            configuration.icon.font(.system(size: DesignTokens.Space.xs)).foregroundStyle(Color.anyfmtSecondaryText)
            configuration.title.font(MediaStyle.caption()).foregroundStyle(Color.anyfmtSecondaryText)
        }
    }
}

private struct ClipRow: View {
    let index: Int
    let clip: JoinVideoModel.Clip
    let mismatch: String?
    let canMoveUp: Bool
    let canMoveDown: Bool
    let canRemove: Bool
    let move: (Int) -> Void
    let remove: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Space.m) {
            Image(systemName: "line.3.horizontal").foregroundStyle(Color.anyfmtSecondaryText).accessibilityHidden(true)
            Text("\(index + 1)")
                .font(MediaStyle.label(.bold).monospacedDigit())
                .foregroundStyle(EditorPalette.onSelected)
                .frame(width: 22, height: 22)
                .background(Circle().fill(MediaStyle.accent))
            ZStack {
                Rectangle().fill(EditorPalette.overlayHalo)
                if let t = clip.thumbnail {
                    Image(nsImage: t).resizable().aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: clip.failed ? "exclamationmark.triangle.fill" : "film")
                        .foregroundStyle(clip.failed ? Color.anyfmtDanger : Color.anyfmtSecondaryText)
                }
            }
            .frame(width: 112, height: 63)
            .clipped()
            VStack(alignment: .leading, spacing: 3) {
                Text(clip.url.lastPathComponent).font(MediaStyle.body(.medium)).lineLimit(1).truncationMode(.middle)
                Text(details).font(MediaStyle.caption().monospacedDigit())
                    .foregroundStyle(clip.failed ? Color.anyfmtDanger : Color.anyfmtSecondaryText).lineLimit(1)
                if let mismatch {
                    Label(mismatch, systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: DesignTokens.TypeRamp.micro, weight: .bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .foregroundStyle(EditorPalette.onWarm)
                        .background(Capsule().fill(EditorPalette.orange))
                }
            }
            Spacer()
            HStack(spacing: 2) {
                Button { move(-1) } label: { Image(systemName: "chevron.up") }.disabled(!canMoveUp)
                    .accessibilityLabel(Text("Move up"))
                Button { move(1) } label: { Image(systemName: "chevron.down") }.disabled(!canMoveDown)
                    .accessibilityLabel(Text("Move down"))
                Button(action: remove) { Image(systemName: "minus.circle") }.disabled(!canRemove)
                    .accessibilityLabel(Text("Remove from join"))
                    .help(String(localized: "Leave this clip out"))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Color.anyfmtInk)
        }
        .padding(DesignTokens.Space.s)
        .background(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous).fill(Color.anyfmtTile))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Clip \(index + 1), \(clip.url.lastPathComponent), \(details)"))
        .accessibilityAction(named: Text("Move up")) { if canMoveUp { move(-1) } }
        .accessibilityAction(named: Text("Move down")) { if canMoveDown { move(1) } }
    }

    private var details: String {
        guard let info = clip.info else { return clip.failed ? String(localized: "Couldn’t read this clip") : String(localized: "Reading…") }
        var parts = [MediaTimes.timecode(info.duration)]
        if let v = info.video {
            parts.append("\(v.displayWidth)×\(v.displayHeight)")
            parts.append(MediaStyle.codecName(v.codec))
            parts.append(String(format: "%.0f fps", v.frameRate))
        }
        parts.append(info.hasAudio ? String(localized: "sound") : String(localized: "no sound"))
        return parts.joined(separator: " · ")
    }
}
