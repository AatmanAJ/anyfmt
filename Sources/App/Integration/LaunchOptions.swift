import Foundation
import Darwin

/// Command-line switches the app understands (used by make targets and tests).
///   --perf-report <file>     write launch→ready timing JSON (scripts/perf.sh)
///   --quit-after-ready       exit once ready (with --perf-report)
///   --no-onboarding          skip the welcome window
///   --show-onboarding        force the welcome window
///   --render-gallery <dir>   render Wheel Gallery PNGs offscreen and exit (make gallery)
///   --render-demo-gif <file> render the README wheel GIF and exit
///   --render-direction <dir> render the phase 2 art-direction board and exit
struct LaunchOptions {
    var perfReport: URL?
    var renderDirection: URL?
    var quitAfterReady = false
    var noOnboarding = false
    var showOnboarding = false
    var renderGallery: URL?
    var renderDemoGIF: URL?

    init(_ args: [String] = CommandLine.arguments) {
        func value(after flag: String) -> String? {
            args.firstIndex(of: flag).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
        }
        perfReport = value(after: "--perf-report").map { URL(fileURLWithPath: $0) }
        quitAfterReady = args.contains("--quit-after-ready")
        noOnboarding = args.contains("--no-onboarding")
        showOnboarding = args.contains("--show-onboarding")
        renderGallery = value(after: "--render-gallery").map { URL(fileURLWithPath: $0, isDirectory: true) }
        renderDemoGIF = value(after: "--render-demo-gif").map { URL(fileURLWithPath: $0) }
        renderDirection = value(after: "--render-direction").map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Wall time since the kernel started this process, in milliseconds.
    static func millisecondsSinceProcessStart() -> Double? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return nil }
        let start = info.kp_proc.p_un.__p_starttime
        let startSeconds = Double(start.tv_sec) + Double(start.tv_usec) / 1_000_000
        return (Date().timeIntervalSince1970 - startSeconds) * 1000
    }

    func writePerfReport(extra: [String: Any] = [:]) {
        guard let perfReport else { return }
        var obj: [String: Any] = extra
        if let ms = Self.millisecondsSinceProcessStart() { obj["launchToReadyMs"] = Int(ms.rounded()) }
        if let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) {
            try? d.write(to: perfReport)
        }
    }
}
