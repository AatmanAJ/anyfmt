import Foundation
import CoreText
import ImageIO
import XCTest
@testable import AnyfmtCore

/// Live estimates vs real conversions. Each check runs `Estimator` cold (caches
/// cleared), then the real route through `Router.live()` + `RouteExecutor`, and
/// compares. Tolerances are the measured error plus headroom; the measured
/// numbers are printed as `ESTIMATE …` lines and recorded in the commit message.
///
/// Inputs: the generated fixtures (2 s clips, 640×480 images: converted whole,
/// so exact) plus longer/larger media made here, where sampling and scaling
/// actually happen: a 12 s 640×360 noisy clip, a 12 s tone+noise WAV and a
/// 3000×2000 gradient+noise PNG.
final class EstimatorTests: XCTestCase {
    // MARK: Inputs

    private static let generatedDir: URL = LaneE.repoRoot.appendingPathComponent("Tests/Fixtures/generated")

    private func fixture(_ name: String) throws -> URL {
        _ = try LaneE.requireEngines()
        _ = ImageTestSupport.locator // points EngineLocator.shared at the bundled engines
        let url = Self.generatedDir.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { throw XCTSkip("run `make fixtures` (missing \(name))") }
        return url
    }

    private nonisolated(unsafe) static var madeMedia: [String: URL] = [:]
    private static let mediaLock = NSLock()

    /// Long/large inputs, generated once per run with the bundled ffmpeg.
    private func made(_ name: String) async throws -> URL {
        _ = try LaneE.requireEngines()
        _ = ImageTestSupport.locator
        if let u = Self.mediaLock.withLock({ Self.madeMedia[name] }) { return u }
        let out = try LaneE.tempDirectory().appendingPathComponent(name)
        switch name {
        case "long.mp4":
            try await LaneE.ffmpeg(["-filter_complex",
                                    "testsrc2=size=640x360:rate=30:duration=12,noise=alls=4:allf=t[v];aevalsrc=0.3*sin(2*PI*440*t)|0.3*sin(2*PI*660*t):s=44100:d=12[a]",
                                    "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p",
                                    "-c:a", "aac_at", "-b:a", "128k", out.path])
        case "long.wav":
            try await LaneE.ffmpeg(["-filter_complex",
                                    "aevalsrc=0.3*sin(2*PI*440*t)|0.3*sin(2*PI*660*t):s=44100:d=12[t];anoisesrc=d=12:c=pink:a=0.15:r=44100:seed=3[n];[n]pan=stereo|c0=c0|c1=c0[n2];[t][n2]amix=inputs=2[a]",
                                    "-map", "[a]", "-c:a", "pcm_s16le", out.path])
        case "photo.png", "smooth.png", "screen.png":
            let image = Self.drawLarge(name)
            try ImageWriter.write(image, to: out, uti: ImageUTI.png, options: [:])
        default:
            XCTFail("unknown input \(name)")
        }
        Self.mediaLock.withLock { Self.madeMedia[name] = out }
        return out
    }

    /// Deterministic 3000×2000 test pictures:
    /// - smooth: soft gradients and blurred blobs only (worst case for tiling: seams are the only edges);
    /// - photo: the same plus shapes and ±6 levels of per-pixel noise, like sensor grain;
    /// - screen: a UI-like layout, flat panels and many lines of text.
    static func drawLarge(_ name: String) -> CGImage {
        let w = 3000, h = 2000
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        var seed: UInt64 = 0x9E3779B97F4A7C15
        func rnd() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 11) / Double(1 << 53) }
        func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor { CGColor(colorSpace: space, components: [r, g, b, a])! }
        if name == "screen.png" {
            ctx.setFillColor(color(0.97, 0.97, 0.98)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
            ctx.setFillColor(color(0.18, 0.2, 0.25)); ctx.fill(CGRect(x: 0, y: 0, width: 520, height: h))
            ctx.setFillColor(color(0.9, 0.92, 0.95)); ctx.fill(CGRect(x: 520, y: h - 120, width: w - 520, height: 120))
            let font = CTFontCreateWithName("Helvetica" as CFString, 26, nil)
            for line in 0..<60 {
                let letters = Array("abcdefghijklmnopqrstuvwxyz")
                let words = (0..<Int(6 + rnd() * 14)).map { _ in
                    String((0..<(2 + Int(rnd() * 8))).map { _ in letters[Int(rnd() * 26)] })
                }
                let text = words.joined(separator: " ")
                let attrs = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color(0.1, 0.1, 0.12)] as CFDictionary
                let ctLine = CTLineCreateWithAttributedString(CFAttributedStringCreate(nil, text as CFString, attrs)!)
                ctx.textPosition = CGPoint(x: 580, y: Double(h - 180 - line * 30))
                CTLineDraw(ctLine, ctx)
            }
            for i in 0..<12 {
                ctx.setFillColor(color(0.3 + rnd() * 0.5, 0.4, 0.8, 1))
                ctx.fill(CGRect(x: 40, y: 200 + i * 120, width: 440, height: 80))
            }
            return ctx.makeImage()!
        }
        let gradient = CGGradient(colorsSpace: space, colors: [color(0.2, 0.35, 0.6), color(0.85, 0.6, 0.4), color(0.95, 0.9, 0.7)] as CFArray,
                                  locations: [0, 0.6, 1])!
        ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: w, y: h), options: [])
        for _ in 0..<14 {
            let c = CGPoint(x: rnd() * Double(w), y: rnd() * Double(h)), r = 150 + rnd() * 500
            let blob = CGGradient(colorsSpace: space, colors: [color(rnd(), rnd(), rnd(), 0.6), color(rnd(), rnd(), rnd(), 0)] as CFArray, locations: [0, 1])!
            ctx.drawRadialGradient(blob, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
        }
        guard name == "photo.png" else { return ctx.makeImage()! }
        for _ in 0..<300 {
            ctx.setFillColor(color(rnd(), rnd(), rnd(), 0.5 + rnd() * 0.5))
            let r = CGRect(x: rnd() * Double(w), y: rnd() * Double(h), width: 10 + rnd() * 120, height: 10 + rnd() * 120)
            if rnd() < 0.5 { ctx.fillEllipse(in: r) } else { ctx.fill(r) }
        }
        let p = ctx.data!.assumingMemoryBound(to: UInt8.self)
        for i in 0..<(w * h * 4) where i % 4 != 3 {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let n = Int((seed >> 59) % 13) - 6
            p[i] = UInt8(clamping: Int(p[i]) + n)
        }
        return ctx.makeImage()!
    }

    // MARK: Measuring

    struct Actual {
        var bytes: Int64
        var files: [URL]
    }

    /// The real conversion, the way a job runs it.
    private func actual(_ input: URL, _ target: FormatID, _ options: OptionValues) async throws -> Actual {
        let from = try XCTUnwrap(Formats.detect(input))
        let route = try XCTUnwrap(Router.live().route(from: from, to: target), "no route \(from) → \(target)")
        let dir = try LaneE.tempDirectory()
        let files = try await RouteExecutor().execute(route, inputs: [input], options: options, baseName: "out",
                                                      metadata: .keep, workDirectory: dir, context: LaneE.context)
        return Actual(bytes: files.reduce(0) { $0 + Estimator.fileSize($1) }, files: files)
    }

    @discardableResult
    private func check(_ name: String, _ input: URL, _ target: FormatID, _ options: [String: OptionValue] = [:],
                       tolerance: Double, expectExact: Bool? = nil,
                       file: StaticString = #filePath, line: UInt = #line) async throws -> (ConversionEstimate, Actual) {
        let opts = OptionValues(options)
        Estimator.resetCaches()
        let t0 = Date()
        let est = try await Estimator.estimate(input: input, target: target, options: opts, locator: LaneE.locator)
        let ms = Date().timeIntervalSince(t0) * 1000
        let real = try await actual(input, target, opts)
        let bytes = try XCTUnwrap(est.bytes, "\(name): no size estimate", file: file, line: line)
        let err = (Double(bytes) - Double(real.bytes)) / Double(real.bytes)
        print(String(format: "ESTIMATE %-34@ est=%9lld actual=%9lld err=%+6.1f%% exact=%@ t=%5.0f ms",
                     name as NSString, bytes, real.bytes, err * 100, est.isExact ? "yes" : "no ", ms))
        XCTAssertLessThanOrEqual(abs(err), tolerance, "\(name): estimate \(bytes) vs actual \(real.bytes)", file: file, line: line)
        XCTAssertEqual(est.inputBytes, Estimator.fileSize(input), file: file, line: line)
        if let expectExact { XCTAssertEqual(est.isExact, expectExact, "\(name): isExact", file: file, line: line) }
        XCTAssertLessThan(ms, 4000, "\(name): estimate took \(Int(ms)) ms", file: file, line: line)
        return (est, real)
    }

    private func streamInfo(_ url: URL) async throws -> (width: Int, height: Int, frames: Int) {
        guard let exe = LaneE.locator.ffprobe else { throw XCTSkip("no ffprobe") }
        let r = try await ProcessRunner.run(exe, ["-v", "error", "-select_streams", "v:0", "-count_packets",
                                                  "-show_entries", "stream=width,height,nb_read_packets", "-of", "csv=p=0", url.path])
        let parts = r.stdoutString.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ",").compactMap { Int($0) }
        guard parts.count == 3 else { throw XCTSkip("unexpected ffprobe output") }
        return (parts[0], parts[1], parts[2])
    }

    // MARK: GIF

    func testGIFFromLongClipIsWithinTolerance() async throws {
        let input = try await made("long.mp4")
        let (est, real) = try await check("long.mp4 → gif 480w 15fps", input, Formats.gif,
                                          [OptionKey.gifWidth: .string("480"), OptionKey.fps: .string("15")],
                                          tolerance: 0.35, expectExact: false)
        let info = try await streamInfo(real.files[0])
        XCTAssertEqual(est.pixelSize, CGSize(width: info.width, height: info.height))
        XCTAssertEqual(Double(try XCTUnwrap(est.frames)), Double(info.frames), accuracy: 2)
        XCTAssertEqual(try XCTUnwrap(est.duration), 12, accuracy: 0.1)
    }

    func testGIFOtherSettingsTrackTheRealOutput() async throws {
        let input = try await made("long.mp4")
        try await check("long.mp4 → gif 320w 10fps", input, Formats.gif,
                        [OptionKey.gifWidth: .string("320"), OptionKey.fps: .string("10")], tolerance: 0.35)
        try await check("long.mp4 → gif keep 24fps", input, Formats.gif,
                        [OptionKey.gifWidth: .string("0"), OptionKey.fps: .string("24")], tolerance: 0.35)
    }

    func testShortClipGIFIsConvertedWholeAndExact() async throws {
        let input = try fixture("sample.mp4")
        let (est, real) = try await check("sample.mp4 → gif (whole)", input, Formats.gif, tolerance: 0.02, expectExact: true)
        let info = try await streamInfo(real.files[0])
        XCTAssertEqual(est.frames, info.frames)
        XCTAssertEqual(est.pixelSize, CGSize(width: info.width, height: info.height))
    }

    // MARK: Video

    func testVideoReencodeIsWithinTolerance() async throws {
        let input = try await made("long.mp4")
        try await check("long.mp4 → mov small (VT h264)", input, Formats.mov, [OptionKey.videoQuality: .string("small")],
                        tolerance: 0.35, expectExact: false)
        let (est, _) = try await check("long.mp4 → webm (vp9)", input, Formats.webm, tolerance: 0.35, expectExact: false)
        XCTAssertEqual(est.pixelSize, CGSize(width: 640, height: 360))
        XCTAssertEqual(try XCTUnwrap(est.duration), 12, accuracy: 0.1)
        let (scaled, _) = try await check("long.mp4 → mov 240p sw x264", input, Formats.mov,
                                          [OptionKey.resolution: .string("240"), OptionKey.hardware: .bool(false)], tolerance: 0.35)
        XCTAssertEqual(scaled.pixelSize, CGSize(width: 426, height: 240))
    }

    /// Slow software encoders on a big clip still answer in about a second: the slice shrinks.
    func testHeavyEncodesStayWithinTheTimeBudget() async throws {
        _ = try LaneE.requireEngines()
        let clip = try await LaneE.makeClip(seconds: 20, size: "1920x1080", ext: "mp4")
        for (name, target, options) in [
            ("1080p → webm (vp9)", Formats.webm, [String: OptionValue]()),
            ("1080p → mkv hevc sw", Formats.mkv, [OptionKey.videoCodec: .string("hevc"), OptionKey.hardware: .bool(false)]),
            ("1080p → gif keep 30fps", Formats.gif, [OptionKey.gifWidth: .string("0"), OptionKey.fps: .string("30")]),
        ] {
            Estimator.resetCaches()
            let t0 = Date()
            let est = try await Estimator.estimate(input: clip, target: target, options: OptionValues(options), locator: LaneE.locator)
            let ms = Date().timeIntervalSince(t0) * 1000
            print(String(format: "ESTIMATE %-34@ est=%9lld (no reference) t=%5.0f ms", name as NSString, est.bytes ?? -1, ms))
            XCTAssertNotNil(est.bytes, name)
            XCTAssertLessThan(ms, 3000, "\(name) took \(Int(ms)) ms")
        }
    }

    func testRemuxUsesStreamBitrates() async throws {
        let input = try await made("long.mp4")
        try await check("long.mp4 → mkv (remux)", input, Formats.mkv, tolerance: 0.05)
    }

    func testShortClipVideoIsExact() async throws {
        try await check("sample.mp4 → webm (whole)", try fixture("sample.mp4"), Formats.webm, tolerance: 0.02, expectExact: true)
    }

    // MARK: Audio

    func testCBRAndPCMAudioAreComputedExactly() async throws {
        let wav = try await made("long.wav")
        try await check("long.wav → mp3 192k", wav, Formats.mp3, [OptionKey.bitrate: .string("192")], tolerance: 0.03, expectExact: true)
        try await check("long.wav → mp3 96k mono", wav, Formats.mp3,
                        [OptionKey.bitrate: .string("96"), OptionKey.channels: .string("mono")], tolerance: 0.03, expectExact: true)
        try await check("long.wav → aiff 24-bit", wav, Formats.aiff, [OptionKey.bitDepth: .string("24")], tolerance: 0.01, expectExact: true)
        try await check("long.mp4 → mp3 (extract)", try await made("long.mp4"), Formats.mp3, tolerance: 0.03, expectExact: true)
        try await check("sample.flac → wav", try fixture("sample.flac"), Formats.wav, tolerance: 0.01, expectExact: true)
    }

    func testSampledAudioIsWithinTolerance() async throws {
        let wav = try await made("long.wav")
        // 12 s fits the 10 s sample window × 1.25, so long.wav is encoded whole; a 30 s file isn't.
        let longer = try LaneE.tempDirectory().appendingPathComponent("longer.wav")
        try await LaneE.ffmpeg(["-stream_loop", "2", "-i", wav.path, "-af", "volume=0.9", "-c:a", "pcm_s16le", longer.path])
        try await check("longer.wav → m4a 128k", longer, Formats.m4a, [OptionKey.bitrate: .string("128")], tolerance: 0.10, expectExact: false)
        try await check("longer.wav → opus 96k", longer, Formats.opus, [OptionKey.bitrate: .string("96")], tolerance: 0.15)
        try await check("longer.wav → ogg 192k", longer, Formats.ogg, [OptionKey.bitrate: .string("192")], tolerance: 0.15)
        try await check("longer.wav → flac", longer, Formats.flac, tolerance: 0.10)
        try await check("long.wav → flac (whole)", wav, Formats.flac, tolerance: 0.01, expectExact: true)

        // Album art is carried once, not scaled with the duration.
        let covered = try LaneE.tempDirectory().appendingPathComponent("covered.mp3")
        try await LaneE.ffmpeg(["-i", longer.path, "-i", try fixture("sample.jpg").path, "-map", "0:a", "-map", "1:v",
                                "-c:a", "libmp3lame", "-b:a", "160k", "-c:v", "copy", "-disposition:v:0", "attached_pic",
                                "-id3v2_version", "3", covered.path])
        try await check("covered.mp3 → m4a 128k (art)", covered, Formats.m4a, [OptionKey.bitrate: .string("128")], tolerance: 0.10)
        try await check("covered.mp3 → flac (art)", covered, Formats.flac, tolerance: 0.10)
        try await check("covered.mp3 → caf/alac (art)", covered, Formats.caf, tolerance: 0.10)
        try await check("covered.mp3 → wav (art dropped)", covered, Formats.wav, tolerance: 0.01, expectExact: true)
    }

    // MARK: Images

    func testSmallImagesAreConvertedWholeAndExact() async throws {
        let jpg = try fixture("sample.jpg")
        for target in [Formats.webp, Formats.heic, Formats.avif, Formats.png] {
            let (est, real) = try await check("sample.jpg → \(target) q85", jpg, target, tolerance: 0.01, expectExact: true)
            XCTAssertEqual(est.pixelSize, try imageSize(real.files[0]))
        }
        let (small, real) = try await check("sample.png → jpg q60 max 320", try fixture("sample.png"), Formats.jpg,
                                            [OptionKey.quality: .int(60), OptionKey.maxDimension: .int(320)], tolerance: 0.01, expectExact: true)
        XCTAssertEqual(small.pixelSize, try imageSize(real.files[0]))
    }

    func testLargeImagesAreScaledFromATileMosaic() async throws {
        for (name, tolerance) in [("photo.png", 0.25), ("screen.png", 0.30), ("smooth.png", 0.25)] {
            let png = try await made(name)
            for target in [Formats.jpg, Formats.webp, Formats.heic, Formats.avif, Formats.tiff] {
                let (est, real) = try await check("\(name) 6 MP → \(target)", png, target, tolerance: tolerance, expectExact: false)
                XCTAssertEqual(est.pixelSize, CGSize(width: 3000, height: 2000))
                XCTAssertEqual(est.pixelSize, try imageSize(real.files[0]))
            }
            try await check("\(name) → jpg q50", png, Formats.jpg, [OptionKey.quality: .int(50)], tolerance: tolerance)
            try await check("\(name) → webp lossless", png, Formats.webp, [OptionKey.lossless: .bool(true)], tolerance: tolerance)
            try await check("\(name) → heic max 2800", png, Formats.heic, [OptionKey.maxDimension: .int(2800)], tolerance: tolerance)
        }
        let png = try await made("photo.png")
        let (fit, real) = try await check("photo.png → jpg max 2000 (exact)", png, Formats.jpg, [OptionKey.maxDimension: .int(2000)],
                                          tolerance: 0.01, expectExact: true)
        XCTAssertEqual(fit.pixelSize, try imageSize(real.files[0]))
    }

    private func imageSize(_ url: URL) throws -> CGSize {
        let src = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
        let p = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any])
        let w = try XCTUnwrap(p[kCGImagePropertyPixelWidth] as? Int), h = try XCTUnwrap(p[kCGImagePropertyPixelHeight] as? Int)
        let o = (p[kCGImagePropertyOrientation] as? Int) ?? 1
        return o >= 5 ? CGSize(width: h, height: w) : CGSize(width: w, height: h)
    }

    // MARK: PDF

    func testPDFPagesAreEstimatedFromPageOne() async throws {
        let pdf = try fixture("sample.pdf")
        try await check("sample.pdf → png 150 dpi", pdf, Formats.png, [OptionKey.dpi: .string("150")], tolerance: 0.35)
        try await check("sample.pdf → jpg 300 dpi", pdf, Formats.jpg, tolerance: 0.35)
        try await check("sample.pdf → png 300 dpi", pdf, Formats.png, tolerance: 0.35)
        try await check("sample.pdf → heic 600 dpi", pdf, Formats.heic, [OptionKey.dpi: .string("600")], tolerance: 0.35)
        try await check("sample.pdf → webp 72 dpi p1", pdf, Formats.webp, [OptionKey.dpi: .string("72"), OptionKey.pages: .string("1")],
                        tolerance: 0.01, expectExact: true)
    }

    // MARK: Cache, cancellation, odd inputs

    func testSecondCallWithSameOptionsHitsTheCache() async throws {
        let input = try await made("long.mp4")
        let opts = OptionValues([OptionKey.gifWidth: .string("320")])
        Estimator.resetCaches()
        let first = try await Estimator.estimate(input: input, target: Formats.gif, options: opts, locator: LaneE.locator)
        let samples = Estimator.stats.sampleCount
        let t0 = Date()
        let second = try await Estimator.estimate(input: input, target: Formats.gif, options: opts, locator: LaneE.locator)
        let ms = Date().timeIntervalSince(t0) * 1000
        print(String(format: "ESTIMATE cache hit t=%.3f ms", ms))
        XCTAssertEqual(first, second)
        XCTAssertEqual(Estimator.stats.sampleCount, samples, "a cache hit must not encode")
        XCTAssertLessThan(ms, 20)

        // New options re-sample but reuse the probe; touching the file invalidates both.
        _ = try await Estimator.estimate(input: input, target: Formats.gif, options: OptionValues([OptionKey.gifWidth: .string("480")]),
                                         locator: LaneE.locator)
        XCTAssertEqual(Estimator.stats.sampleCount, samples + 1)
        try FileManager.default.setAttributes([.modificationDate: Date().addingTimeInterval(5)], ofItemAtPath: input.path)
        _ = try await Estimator.estimate(input: input, target: Formats.gif, options: opts, locator: LaneE.locator)
        XCTAssertEqual(Estimator.stats.sampleCount, samples + 2, "a changed file must be re-estimated")
    }

    func testCancellationStopsTheSampleEncode() async throws {
        let input = try await made("long.mp4")
        Estimator.resetCaches()
        let task = Task {
            try await Estimator.estimate(input: input, target: Formats.webm, options: OptionValues([OptionKey.videoQuality: .string("high")]),
                                         locator: LaneE.locator)
        }
        try await Task.sleep(nanoseconds: 150_000_000)
        let t0 = Date()
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("expected cancellation")
        } catch is CancellationError {
        } catch {
            XCTFail("expected CancellationError, got \(error)")
        }
        let ms = Date().timeIntervalSince(t0) * 1000
        print(String(format: "ESTIMATE cancel latency t=%.0f ms", ms))
        XCTAssertLessThan(ms, 2500)
        XCTAssertEqual(Estimator.results.count, 0, "a cancelled estimate must not be cached")
    }

    func testUnsupportedPairsReturnInputSizeOnly() async throws {
        let docx = try fixture("sample.docx")
        let est = try await Estimator.estimate(input: docx, target: Formats.pdf, options: OptionValues(), locator: LaneE.locator)
        XCTAssertEqual(est, ConversionEstimate(inputBytes: Estimator.fileSize(docx)))
        let zip = try fixture("sample.zip")
        let z = try await Estimator.estimate(input: zip, target: Formats.tar, options: OptionValues(), locator: LaneE.locator)
        XCTAssertNil(z.bytes)
        XCTAssertNotNil(z.inputBytes)
    }

    func testUnreadableInputThrows() async throws {
        let missing = FileManager.default.temporaryDirectory.appendingPathComponent("anyfmt-missing-\(UUID().uuidString).mp4")
        do {
            _ = try await Estimator.estimate(input: missing, target: Formats.gif, options: OptionValues())
            XCTFail("expected an error")
        } catch let e as ConversionError {
            guard case .unreadable = e else { return XCTFail("expected .unreadable, got \(e)") }
        }
        let garbage = try LaneE.tempDirectory().appendingPathComponent("garbage.mp4")
        try Data(repeating: 7, count: 4096).write(to: garbage)
        do {
            _ = try await Estimator.estimate(input: garbage, target: Formats.gif, options: OptionValues(), locator: LaneE.locator)
            XCTFail("expected an error")
        } catch is ConversionError {}
    }

    // MARK: Pure helpers

    func testTrimInsertsSeekBeforeTheInputOnly() {
        let args = ["-stats_period", "0.25", "-i", "/in.mp4", "-i", "/pal.png", "-filter_complex", "x", "/out.gif"]
        XCTAssertEqual(Estimator.trim(args, input: "/in.mp4", start: 5, length: 2),
                       ["-stats_period", "0.25", "-ss", "5.000", "-t", "2.000", "-i", "/in.mp4", "-i", "/pal.png", "-filter_complex", "x", "/out.gif"])
        // From the start: no seek at all (the same decode path as the real conversion).
        XCTAssertEqual(Estimator.trim(["-i", "/a.mp3", "/o.flac"], input: "/a.mp3", start: 0, length: 10),
                       ["-t", "10.000", "-i", "/a.mp3", "/o.flac"])
    }

    func testSampleLengthIsBoundedBySpeed() {
        XCTAssertEqual(Estimator.sampleSeconds(duration: 60, pixelWork: 1, encoder: "gif", maxSample: 2), 2)
        XCTAssertEqual(Estimator.sampleSeconds(duration: 1, pixelWork: 1, encoder: "gif", maxSample: 2), 1)
        // 4K60 software HEVC gets the shortest slice.
        XCTAssertEqual(Estimator.sampleSeconds(duration: 60, pixelWork: 3840 * 2160 * 60, encoder: "libx265", maxSample: 2), 0.5)
    }

    func testLRUEvictsTheOldest() {
        let c = LRUCache<Int, Int>(capacity: 2)
        c.set(1, 1); c.set(2, 2)
        _ = c.get(1)
        c.set(3, 3)
        XCTAssertEqual(c.get(1), 1)
        XCTAssertNil(c.get(2))
        XCTAssertEqual(c.get(3), 3)
    }
}
