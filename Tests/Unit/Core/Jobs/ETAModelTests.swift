import XCTest
@testable import HaloCore

final class ETAModelTests: XCTestCase {
    /// Deterministic jitter in ±amplitude.
    private func noise(_ i: Int, _ amplitude: Double) -> Double {
        let x = sin(Double(i) * 12.9898) * 43758.5453
        return (x - x.rounded(.down) - 0.5) * 2 * amplitude
    }

    func testSteadyProgressCountsDownMonotonically() {
        var model = ETAModel()
        let total = 20.0
        let start = 1000.0
        var shown: [(t: Double, eta: Double)] = []
        for i in 0..<(30 * 19) {
            let t = Double(i) / 30
            let f = min(0.999, max(0, t / total + noise(i, 0.004)))
            if let eta = model.update(fraction: f, at: start + t) { shown.append((t, eta)) }
        }
        XCTAssertFalse(shown.isEmpty)
        XCTAssertGreaterThanOrEqual(shown.first?.t ?? 0, 0.8, "nothing shown during warm-up")
        for (a, b) in zip(shown, shown.dropFirst()) {
            XCTAssertLessThanOrEqual(b.eta, a.eta + 1e-9, "ETA never goes up at a steady rate (t=\(b.t))")
        }
        for s in shown where s.t > 3 {
            XCTAssertEqual(s.eta, total - s.t, accuracy: max(1.5, 0.15 * (total - s.t)), "close to the truth at t=\(s.t)")
        }
    }

    func testRealSlowdownRaisesETA() {
        var model = ETAModel()
        var t = 1.0, f = 0.0
        var last: Double?
        // 10 s at 5 %/s, then the rate drops to 1 %/s.
        for _ in 0..<300 { t += 1.0 / 30; f += 0.05 / 30; last = model.update(fraction: f, at: t) ?? last }
        let before = last ?? 0
        for _ in 0..<300 { t += 1.0 / 30; f += 0.01 / 30; last = model.update(fraction: f, at: t) ?? last }
        let after = last ?? 0
        XCTAssertGreaterThan(after, before, "a genuine slowdown is reflected")
        XCTAssertEqual(after, (1 - f) / 0.01, accuracy: 15)
    }

    func testNoETAWhenStalledOrDone() {
        var model = ETAModel()
        for i in 0..<60 { XCTAssertNil(model.update(fraction: 0, at: 1 + Double(i) / 30)) }
        XCTAssertNil(model.update(fraction: 1, at: 10))
        XCTAssertNil(model.update(fraction: .nan, at: 11))
    }
}
