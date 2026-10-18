import XCTest
@testable import HaloCore

/// Tools 19–22 end to end with the bundled ffmpeg.
final class AudioToolsTests: XCTestCase {
    private func info(_ u: URL) async throws -> MediaInfo { try await MediaInfo.load(u, locator: TestEngines.locator) }

    // MARK: 19 Trim audio

    func testTrimMP3IsStreamCopy() async throws {
        let mp3 = try await MediaFixtures.url("tone.mp3")
        let (out, _) = try await runTool(TrimAudioRunner(), [mp3], ["range": .string("1-2.5")])
        let u = try XCTUnwrap(out.files.first)
        let i = try await info(u)
        XCTAssertEqual(u.pathExtension, "mp3")
        XCTAssertEqual(i.audio?.codec, "mp3")
        XCTAssertEqual(i.audio?.bitRate ?? 0, 192_000, accuracy: 8_000)
        XCTAssertEqual(i.duration, 1.5, accuracy: 0.06)
    }

    func testTrimWAVReencodesSampleExact() async throws {
        let wav = try await MediaFixtures.url("mono.wav")
        let (out, _) = try await runTool(TrimAudioRunner(), [wav], ["range": .string("0.5-1.75")])
        let u = try XCTUnwrap(out.files.first)
        let i = try await info(u)
        XCTAssertEqual(i.audio?.codec, "pcm_s16le")
        XCTAssertEqual(i.audio?.sampleRate, 44100)
        XCTAssertEqual(i.duration, 1.25, accuracy: 0.002)
    }

    func testTrimM4AKeepsAAC() async throws {
        let m4a = try await MediaFixtures.url("tone.m4a")
        let (out, _) = try await runTool(TrimAudioRunner(), [m4a], ["range": .string("1-3"), "lossless": .bool(false)])
        let i = try await info(try XCTUnwrap(out.files.first))
        XCTAssertEqual(i.audio?.codec, "aac")
        XCTAssertEqual(i.duration, 2, accuracy: 0.05)
    }

    // MARK: 20 Normalize

    func testNormalizeHitsTargets() async throws {
        let flac = try await MediaFixtures.url("quiet.flac")
        let ffmpeg = FFmpeg(locator: TestEngines.locator)
        for target in [-14.0, -23.0] {
            let (out, _) = try await runTool(NormalizeAudioRunner(), [flac], ["target": .string(String(Int(target)))])
            let u = try XCTUnwrap(out.files.first)
            let codec = try await info(u).audio?.codec
            XCTAssertEqual(codec, "flac")
            let m = try await LoudnessMeasurement.measure(u, stream: 0, target: target, truePeak: -1, ffmpeg: ffmpeg, duration: 6, progress: .ignore)
            XCTAssertEqual(m.integrated, target, accuracy: 1.0, "target \(target)")
        }
    }

    func testNormalizeVideoCopiesVideoStream() async throws {
        let clip = try await MediaFixtures.url("clip.mp4")
        let (out, _) = try await runTool(NormalizeAudioRunner(), [clip], ["target": .string("-16")])
        let u = try XCTUnwrap(out.files.first)
        let src = try await info(clip), dst = try await info(u)
        XCTAssertEqual(dst.video?.extradataHash, src.video?.extradataHash)
        XCTAssertEqual(dst.audio?.codec, "aac")
        let m = try await LoudnessMeasurement.measure(u, stream: dst.audio?.index ?? 1, target: -16, truePeak: -1,
                                                      ffmpeg: FFmpeg(locator: TestEngines.locator), duration: 4, progress: .ignore)
        XCTAssertEqual(m.integrated, -16, accuracy: 1.0)
    }

    func testNormalizeSilentVideoIsAHumanError() async throws {
        let clip = try await MediaFixtures.url("silent.mp4")
        do {
            _ = try await runTool(NormalizeAudioRunner(), [clip], [:])
            XCTFail("expected error")
        } catch let e as ConversionError {
            XCTAssertTrue(e.errorDescription?.contains("no audio") ?? false)
        }
    }

    // MARK: 21 Bleep

    func testBleepToneAndSilence() async throws {
        let wav = try await MediaFixtures.url("mono.wav")
        let rate = 48000
        let original = TestEngines.rms(try await TestEngines.pcm(wav, rate: rate)[rate * 3..<rate * 4])

        let (tone, _) = try await runTool(BleepAudioRunner(), [wav], ["ranges": .string("1-1.5; 2-2.5"), "style": .string("tone")])
        let t = try await TestEngines.pcm(try XCTUnwrap(tone.files.first), rate: rate)
        let toneRMS = BleepAudioRunner.toneAmplitude / 2.0.squareRoot()
        XCTAssertEqual(TestEngines.rms(t[Int(1.05 * Double(rate))..<Int(1.45 * Double(rate))]), toneRMS, accuracy: 0.01)
        XCTAssertEqual(TestEngines.rms(t[Int(2.05 * Double(rate))..<Int(2.45 * Double(rate))]), toneRMS, accuracy: 0.01)
        XCTAssertEqual(TestEngines.rms(t[rate * 3..<rate * 4]), original, accuracy: 0.005, "outside ranges untouched")

        let (quiet, _) = try await runTool(BleepAudioRunner(), [wav], ["ranges": .string("1-1.5"), "style": .string("silence")])
        let q = try await TestEngines.pcm(try XCTUnwrap(quiet.files.first), rate: rate)
        XCTAssertLessThan(TestEngines.rms(q[Int(1.05 * Double(rate))..<Int(1.45 * Double(rate))]), 0.001)
        XCTAssertEqual(TestEngines.rms(q[rate * 3..<rate * 4]), original, accuracy: 0.005)
    }

    // MARK: 22 Channels

    func testChannelModes() async throws {
        let lr = try await MediaFixtures.url("lr.wav")
        let (mono, _) = try await runTool(ChannelsAudioRunner(), [lr], ["mode": .string("mono")])
        let m = try await info(try XCTUnwrap(mono.files.first))
        XCTAssertEqual(m.audio?.channels, 1)
        // Plain PCM WAV stores no layout; AAC does.
        let m4a = try await MediaFixtures.url("tone.m4a")
        let (aacMono, _) = try await runTool(ChannelsAudioRunner(), [m4a], ["mode": .string("mono")])
        let am = try await info(try XCTUnwrap(aacMono.files.first))
        XCTAssertEqual(am.audio?.channels, 1)
        XCTAssertEqual(am.audio?.channelLayout, "mono")
        XCTAssertEqual(am.audio?.codec, "aac")

        let (swapped, _) = try await runTool(ChannelsAudioRunner(), [lr], ["mode": .string("swap")])
        let s = try XCTUnwrap(swapped.files.first)
        let swappedChannels = try await info(s).audio?.channels
        XCTAssertEqual(swappedChannels, 2)
        let left = TestEngines.rms(try await TestEngines.pcm(s, channel: 0)[...])
        let right = TestEngines.rms(try await TestEngines.pcm(s, channel: 1)[...])
        XCTAssertLessThan(left, 0.001, "the silent channel is now on the left")
        XCTAssertGreaterThan(right, 0.05)

        let wav = try await MediaFixtures.url("mono.wav")
        let (stereo, _) = try await runTool(ChannelsAudioRunner(), [wav], ["mode": .string("stereo")])
        let st = try await info(try XCTUnwrap(stereo.files.first))
        XCTAssertEqual(st.audio?.channels, 2)
        let up = try await TestEngines.pcm(try XCTUnwrap(stereo.files.first), channel: 1)
        XCTAssertGreaterThan(TestEngines.rms(up[...]), 0.05, "mono duplicated into the right channel")
        do {
            _ = try await runTool(ChannelsAudioRunner(), [wav], ["mode": .string("mono")])
            XCTFail("mono → mono should explain itself")
        } catch let e as ConversionError {
            XCTAssertTrue(e.errorDescription?.contains("already mono") ?? false)
        }
    }

    func testChannelsKeepsMP3Codec() async throws {
        let mp3 = try await MediaFixtures.url("tone.mp3")
        let (out, _) = try await runTool(ChannelsAudioRunner(), [mp3], ["mode": .string("mono")])
        let i = try await info(try XCTUnwrap(out.files.first))
        XCTAssertEqual(i.audio?.codec, "mp3")
        XCTAssertEqual(i.audio?.channels, 1)
    }
}
