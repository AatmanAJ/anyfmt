import Foundation

/// Errors engines and jobs throw. `errorDescription` is the human message the
/// progress window shows; `technicalDetails` goes behind "Copy details".
public enum ConversionError: Error, LocalizedError, Sendable {
    case unsupported(from: FormatID, to: FormatID)
    case noRoute(from: FormatID, to: FormatID)
    case unreadable(URL, detail: String)
    case engineMissing(String, detail: String)
    case engineFailed(String, status: Int32, detail: String)
    case outputMissing(String)
    case invalidOption(String)
    case cancelled
    case other(String, detail: String)

    public var errorDescription: String? {
        switch self {
        case .unsupported(let f, let t), .noRoute(let f, let t):
            return L("\(Formats.label(f)) files can’t be converted to \(Formats.label(t)).")
        case .unreadable(let url, _):
            return L("“\(url.lastPathComponent)” couldn’t be read. It may be damaged or in an unexpected format.")
        case .engineMissing(let name, _):
            return L("A component this conversion needs (\(name)) is missing. Reinstalling \(Brand.name) should fix it.")
        case .engineFailed:
            return L("The conversion stopped unexpectedly. The original file is untouched.")
        case .outputMissing:
            return L("The conversion finished but produced no file.")
        case .invalidOption(let o):
            return L("The option “\(o)” isn’t valid for this conversion.")
        case .cancelled:
            return L("Cancelled.")
        case .other(let message, _):
            return message
        }
    }

    /// `technicalDetails` without the engine's command line (the `$ …` line), for
    /// one-line messages. "Copy details" keeps the full version.
    public var briefDetails: String {
        technicalDetails.split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasPrefix("$ ") }
            .joined(separator: "\n")
    }

    public var technicalDetails: String {
        switch self {
        case .unsupported(let f, let t): "unsupported \(f)→\(t)"
        case .noRoute(let f, let t): "no route \(f)→\(t)"
        case .unreadable(let url, let d): "unreadable \(url.path): \(d)"
        case .engineMissing(let n, let d): "engine missing \(n): \(d)"
        case .engineFailed(let n, let s, let d): "\(n) exited \(s)\n\(d)"
        case .outputMissing(let d): "output missing: \(d)"
        case .invalidOption(let o): "invalid option \(o)"
        case .cancelled: "cancelled"
        case .other(let m, let d): "\(m)\n\(d)"
        }
    }
}
