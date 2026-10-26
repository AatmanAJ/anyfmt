import XCTest
import ImageIO
@testable import AnyfmtCore

/// BUILD.md §10 budget: 12 MP HEIC → JPG under 400 ms.
final class ImagePerfTests: XCTestCase {
    typealias S = ImageTestSupport

    /// A detailed 4032×3024 Display P3 photo stand-in (gradient + shapes + noise).
    private func twelveMegapixelHEIC(_ dir: URL, orientation: Int) -> URL {
        let w = 4032, h = 3024
        let img = S.image(w, h, space: S.p3, alpha: false) { ctx in
            let g = CGGradient(colorsSpace: S.p3, colors: [S.color(1, 0.3, 0, space: S.p3), S.color(0, 0.4, 1, space: S.p3)] as CFArray, locations: nil)!
            ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: w, y: h), options: [])
            var state: UInt64 = 7
            for _ in 0..<3000 {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                let x = Int(state >> 40) % w, y = Int(state >> 20) % h
                ctx.setFillColor(S.color(CGFloat(state & 0xFF) / 255, CGFloat((state >> 8) & 0xFF) / 255, CGFloat((state >> 16) & 0xFF) / 255, space: S.p3))
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: 40 + Int(state % 90), height: 30 + Int(state % 70)))
            }
        }
        return S.write(img, to: dir.appendingPathComponent("photo-\(orientation).heic"), uti: "public.heic",
                       properties: [kCGImageDestinationLossyCompressionQuality: 0.8, kCGImagePropertyOrientation: orientation])
    }

    private func medianMilliseconds(_ src: URL, runs: Int = 5) async throws -> Double {
        var times: [Double] = []
        for i in 0..<runs {
            let out = try S.tempDir("perf\(i)")
            let started = DispatchTime.now().uptimeNanoseconds
            let files = try await S.convert(ImageIOEngine(), src, from: Formats.heic, to: Formats.jpg, in: out)
            times.append(Double(DispatchTime.now().uptimeNanoseconds - started) / 1_000_000)
            XCTAssertNotNil(S.decode(files[0]))
        }
        return times.sorted()[times.count / 2]
    }

    func testTwelveMegapixelHEICToJPGUnderBudget() async throws {
        let dir = try S.tempDir()
        let upright = try await medianMilliseconds(twelveMegapixelHEIC(dir, orientation: 1))
        let rotated = try await medianMilliseconds(twelveMegapixelHEIC(dir, orientation: 6))
        print(String(format: "lane D perf: 12 MP HEIC → JPG median %.0f ms (upright), %.0f ms (orientation 6, rotated)", upright, rotated))
        XCTAssertLessThan(upright, 400)
        XCTAssertLessThan(rotated, 400)
    }
}
