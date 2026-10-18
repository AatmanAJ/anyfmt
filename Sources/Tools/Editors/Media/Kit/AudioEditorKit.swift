import AppKit
import AVFoundation
import os
import SwiftUI
import HaloCore

/// Shared state for the waveform editors: the session plus its envelope.
@MainActor
final class AudioSession {
    let session: MediaSession
    let wave = WaveformModel()

    init(url: URL) {
        session = MediaSession(url: url, isVideo: false)
    }

    /// Call once the session is ready: decodes the waveform from the playable file.
    func loadWaveform() {
        guard let url = session.asset?.url else { return }
        wave.load(url: url, duration: session.duration)
    }

    func settle() async {
        await session.settle()
        await wave.waitUntilComplete()
    }

    func teardown() {
        session.stop()
        session.player.teardown()
        wave.cancel()
    }
}

/// Zoom controls under a waveform.
struct ZoomControls: View {
    @ObservedObject var wave: WaveformModel
    var fitTo: ClosedRange<Double>?

    var body: some View {
        HStack(spacing: DesignTokens.Space.xs) {
            Button { wave.zoom(by: 1 / 1.6, around: wave.viewStart + wave.viewSpan / 2) } label: { Image(systemName: "minus.magnifyingglass") }
                .help(String(localized: "Zoom out (⌘−)"))
                .accessibilityLabel(Text("Zoom out"))
            Slider(value: Binding(get: { log2(max(1, wave.zoom)) }, set: { wave.setZoom(pow(2, $0)) }),
                   in: 0...max(1, log2(max(2, wave.duration / WaveformModel.minimumSpan))))
                .frame(width: 110)
                .controlSize(.small)
                .accessibilityLabel(Text("Zoom"))
            Button { wave.zoom(by: 1.6, around: wave.viewStart + wave.viewSpan / 2) } label: { Image(systemName: "plus.magnifyingglass") }
                .help(String(localized: "Zoom in (⌘=)"))
                .accessibilityLabel(Text("Zoom in"))
            if let fitTo {
                Button(String(localized: "Fit Selection")) {
                    let span = max(WaveformModel.minimumSpan, (fitTo.upperBound - fitTo.lowerBound) * 1.2)
                    wave.setZoom(wave.duration / span)
                    wave.setStart((fitTo.lowerBound + fitTo.upperBound) / 2 - wave.viewSpan / 2)
                }
                .controlSize(.small)
            }
            Button(String(localized: "Show All")) { wave.setZoom(1) }
                .controlSize(.small)
                .disabled(wave.zoom <= 1.01)
        }
        .buttonStyle(.borderless)
    }
}

/// 1 kHz preview tone for the bleep editor (AVAudioEngine source node).
@MainActor
final class TonePlayer {
    private final class State: @unchecked Sendable {
        let lock = OSAllocatedUnfairLock(initialState: false)
        var phase: Double = 0 // render thread only
    }

    private let engine = AVAudioEngine()
    private let state = State()
    private var node: AVAudioSourceNode?
    private var started = false

    func setActive(_ on: Bool) {
        if on && !started { start() }
        state.lock.withLock { $0 = on }
    }

    private func start() {
        if node == nil { attachNode() }
        do {
            try engine.start()
            started = true
        } catch {
            Log.tools.error("tone preview unavailable: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func attachNode() {
        let format = engine.outputNode.inputFormat(forBus: 0)
        let rate = format.sampleRate > 0 ? format.sampleRate : 48000
        let state = state
        let amplitude = Float(BleepAudioRunner.toneAmplitude)
        let node = AVAudioSourceNode { _, _, frameCount, buffers -> OSStatus in
            let on = state.lock.withLock { $0 }
            let list = UnsafeMutableAudioBufferListPointer(buffers)
            let step = 2 * Double.pi * 1000 / rate
            for frame in 0..<Int(frameCount) {
                let v: Float = on ? amplitude * Float(sin(state.phase)) : 0
                state.phase += step
                if state.phase > 2 * .pi { state.phase -= 2 * .pi }
                for b in list { b.mData?.assumingMemoryBound(to: Float.self)[frame] = v }
            }
            return noErr
        }
        let mono = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1)
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: mono)
        self.node = node
    }

    func stop() {
        state.lock.withLock { $0 = false }
        if started { engine.stop() }
        started = false
    }
}
