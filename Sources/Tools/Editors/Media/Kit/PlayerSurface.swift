import AppKit
import AVKit
import SwiftUI
import HaloCore

/// AVKit's player view without its own controls (the editors draw theirs).
struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let v = AVPlayerView()
        v.controlsStyle = .none
        v.videoGravity = .resizeAspect
        v.player = player
        v.allowsPictureInPicturePlayback = false
        v.setAccessibilityElement(false)
        return v
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player { nsView.player = player }
    }
}

/// The video preview: live player while playing or scrubbing, the exact still
/// when paused (frame-accurate, and the only thing offscreen renders capture).
struct VideoSurface: View {
    @ObservedObject var player: PlayerController
    let aspect: CGSize

    var body: some View {
        ZStack {
            PlayerView(player: player.player)
            if player.stillIsCurrent, let still = player.still {
                Image(nsImage: still).resizable().aspectRatio(contentMode: .fit)
            }
        }
        .aspectRatio(aspect, contentMode: .fit)
        .background(EditorPalette.overlayHalo)
        .overlay(Rectangle().strokeBorder(Color.haloHairline, lineWidth: DesignTokens.Shape.hairline))
        .accessibilityElement()
        .accessibilityLabel(Text("Video preview"))
        .accessibilityValue(Text(MediaTimes.timecode(player.currentTime)))
    }
}

/// Play/pause, frame steps and the timecode readout.
struct TransportBar: View {
    @ObservedObject var player: PlayerController
    let duration: Double
    var showsFrameSteps = true
    var leading: AnyView? = nil
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: DesignTokens.Space.s) {
            if let leading { leading }
            Spacer(minLength: 0)
            if showsFrameSteps {
                transportButton("backward.frame.fill", String(localized: "Previous frame (←)")) { player.step(-1) }
            }
            Button(action: player.togglePlay) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: DesignTokens.TypeRamp.title, weight: .bold))
                    .foregroundStyle(EditorPalette.onSelected)
                    .frame(width: EditorTokens.cellHeight - 10, height: EditorTokens.cellHeight - 10)
                    .background(Circle().fill(EditorPalette.selected))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help(player.isPlaying ? String(localized: "Pause (Space)") : String(localized: "Play (Space)"))
            .accessibilityLabel(player.isPlaying ? Text("Pause") : Text("Play"))
            if showsFrameSteps {
                transportButton("forward.frame.fill", String(localized: "Next frame (→)")) { player.step(1) }
            }
            Spacer(minLength: 0)
            Text("\(MediaTimes.timecode(player.currentTime)) / \(MediaTimes.timecode(duration))")
                .font(MediaStyle.timecode)
                .foregroundStyle(Color.haloSecondaryText)
                .accessibilityLabel(Text("Time \(MediaTimes.timecode(player.currentTime)) of \(MediaTimes.timecode(duration))"))
            if let trailing { trailing }
        }
    }

    private func transportButton(_ symbol: String, _ help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: DesignTokens.TypeRamp.body, weight: .semibold))
                .foregroundStyle(Color.haloInk)
                .frame(width: EditorTokens.chipHeight + 4, height: EditorTokens.chipHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(Text(help))
    }
}

/// Timecode text field bound to seconds ("0:01.25"); commits on Return/blur.
struct TimecodeField: View {
    let label: String
    @Binding var seconds: Double
    var range: ClosedRange<Double>
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(label, text: $text)
            .textFieldStyle(.roundedBorder)
            .font(MediaStyle.timecode)
            .multilineTextAlignment(.trailing)
            .frame(width: 96)
            .focused($focused)
            .onAppear { text = MediaTimes.timecode(seconds) }
            .onChange(of: seconds) { if !focused { text = MediaTimes.timecode($0) } }
            .onSubmit(commit)
            .onChange(of: focused) { if !$0 { commit() } }
            .accessibilityLabel(Text(label))
    }

    private func commit() {
        if let v = MediaTimes.seconds(text) { seconds = min(max(v, range.lowerBound), range.upperBound) }
        text = MediaTimes.timecode(seconds)
    }
}
