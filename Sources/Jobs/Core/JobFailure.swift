import Foundation

/// Words the progress window uses for a job. Conversions and tools conform;
/// any other `Job` falls back to its `title`.
public protocol JobDescribing {
    /// While running: "Converting to MP4", "Compressing".
    var activityTitle: String { get }
    /// After success: "Converted to MP4", "Compressed".
    var completedTitle: String { get }
    /// After failure: "Couldn’t convert to MP4".
    var failedTitle: String { get }
    /// Route, engines and options, for "Copy details". No full paths.
    var diagnostics: String { get }
}

/// A finished job's error, split into what the user reads and what a bug report needs.
public struct JobFailure: Sendable, Equatable {
    public let message: String
    public let details: String
    public let isCancellation: Bool

    public init(message: String, details: String, isCancellation: Bool = false) {
        self.message = message
        self.details = details
        self.isCancellation = isCancellation
    }

    /// Maps any error a job can throw to a calm, human message plus technical details.
    public static func from(_ error: Error) -> JobFailure {
        if error is CancellationError {
            return JobFailure(message: L("Cancelled."), details: "cancelled", isCancellation: true)
        }
        if let c = error as? ConversionError {
            if case .cancelled = c { return JobFailure(message: L("Cancelled."), details: "cancelled", isCancellation: true) }
            return JobFailure(message: c.errorDescription ?? L("The conversion stopped unexpectedly. The original file is untouched."),
                              details: c.technicalDetails)
        }
        let ns = error as NSError
        let technical = "\(ns.domain) \(ns.code): \(String(describing: error))"
        if ns.domain == NSCocoaErrorDomain {
            let name = (ns.userInfo[NSFilePathErrorKey] as? String).map { ($0 as NSString).lastPathComponent }
            switch CocoaError.Code(rawValue: ns.code) {
            case .fileReadNoSuchFile, .fileNoSuchFile:
                let who = name ?? L("The file")
                return JobFailure(message: L("“\(who)” couldn’t be found. It may have been moved or deleted."), details: technical)
            case .fileReadNoPermission, .fileWriteNoPermission:
                return JobFailure(message: L("\(Brand.name) doesn’t have permission to use this location. Try saving to another folder in Settings."), details: technical)
            case .fileWriteOutOfSpace:
                return JobFailure(message: L("There isn’t enough free disk space to save the result."), details: technical)
            case .fileWriteVolumeReadOnly:
                return JobFailure(message: L("This disk is read-only, so the result can’t be saved beside the original. Choose an output folder in Settings."), details: technical)
            default:
                break
            }
        }
        if ns.domain == NSPOSIXErrorDomain, ns.code == Int(ENOSPC) {
            return JobFailure(message: L("There isn’t enough free disk space to save the result."), details: technical)
        }
        return JobFailure(message: L("Something went wrong. The original file is untouched."), details: technical)
    }
}

/// The header every "Copy details" report starts with.
public enum JobDiagnostics {
    public static var environment: String {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info["CFBundleVersion"] as? String ?? "0"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        return "\(Brand.name) \(version) (\(build)) · macOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion) · arm64"
    }

    /// Full report: environment, job, diagnostics, then the error.
    public static func report(title: String, diagnostics: String, failure: JobFailure, attempt: Int) -> String {
        var lines = [environment, "Job: \(title)"]
        if !diagnostics.isEmpty { lines.append(diagnostics) }
        if attempt > 1 { lines.append("Attempt: \(attempt)") }
        lines.append("Error: \(failure.details)")
        return lines.joined(separator: "\n")
    }
}
