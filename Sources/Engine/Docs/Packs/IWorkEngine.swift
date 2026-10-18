import AppKit
import Foundation

/// Pages / Keynote / Numbers import and export by scripting the user's own
/// iWork apps. Strictly opt-in: a row is available only when the app is
/// installed **and** the user enabled "optIn.iWorkAppleEvents" in Settings
/// (macOS then asks once for Automation permission). Scripts run through
/// `/usr/bin/osascript`, off the main thread and cancellable.
///
/// Never exercised by tests: running a script would trigger a permission prompt.
public struct PagesAppleEventsEngine: ConversionEngine {
    public let id = EngineIDs.pagesAppleEvents
    public static let optInKey = "optIn.iWorkAppleEvents"

    public enum App: String, Sendable, CaseIterable {
        case pages = "com.apple.iWork.Pages"
        case keynote = "com.apple.iWork.Keynote"
        case numbers = "com.apple.iWork.Numbers"
    }

    /// Injectable environment so availability logic is testable without iWork.
    public struct Environment: Sendable {
        public var isInstalled: @Sendable (App) -> Bool
        public var optedIn: @Sendable () -> Bool
        public init(isInstalled: @escaping @Sendable (App) -> Bool, optedIn: @escaping @Sendable () -> Bool) {
            self.isInstalled = isInstalled
            self.optedIn = optedIn
        }

        public static let live = Environment(
            isInstalled: { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.rawValue) != nil },
            optedIn: { UserDefaults.standard.bool(forKey: PagesAppleEventsEngine.optInKey) }
        )
    }

    let env: Environment
    public init(environment: Environment = .live) { env = environment }

    public static func app(for c: Capability) -> App? {
        for f in [c.from, c.to] {
            switch f {
            case Formats.pages: return .pages
            case Formats.key: return .keynote
            case Formats.numbers: return .numbers
            default: continue
            }
        }
        return nil
    }

    public func isAvailable(_ capability: Capability) -> Bool {
        guard let app = Self.app(for: capability) else { return false }
        return env.optedIn() && env.isInstalled(app)
    }

    /// Export format names from each app's scripting dictionary.
    public static func exportFormat(app: App, to: FormatID) -> String? {
        switch (app, to) {
        case (.pages, Formats.pdf), (.keynote, Formats.pdf), (.numbers, Formats.pdf): "PDF"
        case (.pages, Formats.docx): "Microsoft Word"
        case (.pages, Formats.epub): "EPUB"
        case (.pages, Formats.txt): "unformatted text"
        case (.pages, Formats.rtf): "formatted text"
        case (.keynote, Formats.pptx): "Microsoft PowerPoint"
        case (.numbers, Formats.xlsx): "Microsoft Excel"
        case (.numbers, Formats.csv): "CSV"
        default: nil
        }
    }

    /// AppleScript source for one conversion (exposed for tests; never run there).
    public static func script(app: App, input: URL, output: URL, to: FormatID) -> String? {
        let inPath = quote(input.path), outPath = quote(output.path)
        let open = "set theDoc to open (POSIX file \(inPath))"
        let body: String
        if [Formats.pages, Formats.key, Formats.numbers].contains(to) {
            body = "\(open)\n    save theDoc in (POSIX file \(outPath))"
        } else if let fmt = exportFormat(app: app, to: to) {
            body = "\(open)\n    export theDoc to (POSIX file \(outPath)) as \(fmt)"
        } else {
            return nil
        }
        return """
        with timeout of 900 seconds
          tell application id "\(app.rawValue)"
            \(body)
            close theDoc saving no
          end tell
        end timeout
        """
    }

    static func quote(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    public func convert(_ request: ConversionRequest, context: EngineContext) async throws -> ConversionOutput {
        let cap = Capability(request.from, request.to, id)
        guard let app = Self.app(for: cap), isAvailable(cap) else {
            throw ConversionError.other(L("Turn on iWork conversions in Settings to use this format."), detail: "pages-ae not opted in or app missing")
        }
        let out = request.defaultOutputURL
        guard let src = Self.script(app: app, input: request.input, output: out, to: request.to) else {
            throw ConversionError.unsupported(from: request.from, to: request.to)
        }
        context.progress(0.1)
        _ = try await ProcessRunner.run(URL(fileURLWithPath: "/usr/bin/osascript"), ["-e", src])
        guard FileManager.default.fileExists(atPath: out.path) else { throw ConversionError.outputMissing(out.lastPathComponent) }
        context.progress(1)
        return ConversionOutput(out)
    }
}
