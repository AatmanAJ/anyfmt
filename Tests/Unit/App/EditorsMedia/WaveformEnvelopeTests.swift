import XCTest
@testable import AnyfmtApp
import AnyfmtCore

final class WaveformEnvelopeTests: XCTestCase {
    func testBuilderFoldsChannelsAndHandlesChunkBoundaries() {
        // Stereo frames; the right channel carries the extremes in bin 2.
        let frames: [(Float, Float)] = [(0.1, -0.2), (0.3, 0.0), (-0.5, 0.2), (0.0, 0.9), (0.2, -0.7), (0.1, 0.1), (0.4, -0.1)]
        let interleaved = frames.flatMap { [$0.0, $0.1] }
        var whole = WaveformEnvelope.Builder(sampleRate: 10, samplesPerBin: 3)
        whole.append(interleaved, channels: 2)
        var chunked = WaveformEnvelope.Builder(sampleRate: 10, samplesPerBin: 3)
        chunked.append(Array(interleaved[0..<4]), channels: 2)   // 2 frames
        chunked.append(Array(interleaved[4..<10]), channels: 2)  // 3 frames
        chunked.append(Array(interleaved[10...]), channels: 2)   // 2 frames
        let a = whole.snapshot(), b = chunked.snapshot()
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.binCount, 3, "two full bins + the partial one")
        XCTAssertEqual(a.mins, [-0.5, -0.7, -0.1])
        XCTAssertEqual(a.maxs, [0.3, 0.9, 0.4])
        XCTAssertEqual(a.binDuration, 0.3, accuracy: 1e-12)
    }

    func testColumnsReduceAndPadPastTheEnd() {
        let env = WaveformEnvelope(sampleRate: 100, samplesPerBin: 10, mins: [-0.1, -0.5, -0.2, -0.3], maxs: [0.2, 0.1, 0.8, 0.3])
        XCTAssertEqual(env.duration, 0.4, accuracy: 1e-12)
        let two = env.columns(from: 0, to: 0.4, count: 2)
        XCTAssertEqual(two.map(\.min), [-0.5, -0.3])
        XCTAssertEqual(two.map(\.max), [0.2, 0.8])
        let zoomed = env.columns(from: 0.2, to: 0.3, count: 4)
        XCTAssertTrue(zoomed.allSatisfy { $0.max == 0.8 && $0.min == -0.2 }, "zooming in repeats the covering bin")
        let past = env.columns(from: 0.3, to: 0.6, count: 3)
        XCTAssertEqual(past.last?.max, 0, "nothing decoded there yet")
        XCTAssertTrue(env.columns(from: 1, to: 0.5, count: 3).isEmpty)
    }

    func testLoaderMeasuresARealFile() async throws {
        let wav = try await MediaEditorSamples.url("Short.wav") // 1 s, 440 Hz, amplitude 1/8, 8 kHz
        let box = EnvelopeBox()
        try await WaveformLoader.load(wav) { env, done in if done { box.set(env) } }
        let env = try XCTUnwrap(box.value)
        XCTAssertEqual(env.sampleRate, 8000)
        XCTAssertEqual(env.duration, 1, accuracy: 0.01)
        let peak = max(env.maxs.max() ?? 0, -(env.mins.min() ?? 0))
        XCTAssertEqual(peak, 0.125, accuracy: 0.01)
        // Second load is served from the cache.
        let again = EnvelopeBox()
        try await WaveformLoader.load(wav) { env, done in if done { again.set(env) } }
        XCTAssertEqual(again.value, env)
    }
}

private final class EnvelopeBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: WaveformEnvelope?
    var value: WaveformEnvelope? { lock.withLock { stored } }
    func set(_ e: WaveformEnvelope) { lock.withLock { stored = e } }
}
