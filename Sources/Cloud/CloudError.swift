import Foundation
import HaloCore

/// Everything that can go wrong in a cloud action, with the calm, human
/// sentence the UI shows (`errorDescription`) and the detail that goes
/// behind "Copy details" (`technicalDetails`). Never contains tokens.
enum CloudError: Error, LocalizedError, Sendable, Equatable {
    /// No account on this server. Signed-out code paths throw this before any request.
    case signedOut
    /// The network gate refused a request (wrong trigger, sync/inbox turned off).
    case notAllowed(String)
    /// The plan doesn't include this server-backed feature.
    case notEntitled(CloudFeature)
    case offline
    case serverUnreachable(String)
    case connectionLost
    /// Refresh failed: the account was signed out on the server.
    case sessionExpired
    case signInFailed(String)
    case quotaExceeded(message: String, resetsAt: Date?)
    case rateLimited(retryAfter: TimeInterval?)
    case payloadTooLarge(maxBytes: Int64?)
    case notFound
    case checksumMismatch
    case jobFailed(String)
    case fileUnreadable(String)
    case invalidResponse(String)
    case server(status: Int, code: String?, message: String?, requestID: String?)

    var errorDescription: String? {
        switch self {
        case .signedOut:
            return String(localized: "Sign in to use \(Brand.name) Cloud. Everything on your Mac keeps working without it.")
        case .notAllowed:
            return String(localized: "That cloud action isn’t turned on.")
        case .notEntitled(let feature):
            return String(localized: "\(CloudCopy.title(for: feature)) isn’t included in your plan.")
        case .offline:
            return String(localized: "You’re offline. Nothing was uploaded.")
        case .serverUnreachable(let host):
            return String(localized: "Couldn’t reach \(host). Check the address in Settings › Account.")
        case .connectionLost:
            return String(localized: "The connection dropped. Try again when you’re back online.")
        case .sessionExpired:
            return String(localized: "You were signed out. Sign in again to continue.")
        case .signInFailed(let reason):
            return reason.isEmpty ? String(localized: "Sign-in didn’t finish. Try again.") : reason
        case .quotaExceeded(let message, _):
            return message
        case .rateLimited:
            return String(localized: "The server is busy. Try again in a moment.")
        case .payloadTooLarge(let max):
            if let max {
                let size = ByteCountFormatter.string(fromByteCount: max, countStyle: .file)
                return String(localized: "That file is larger than your plan allows (\(size)).")
            }
            return String(localized: "That file is larger than your plan allows.")
        case .notFound:
            return String(localized: "That item is no longer on the server.")
        case .checksumMismatch:
            return String(localized: "The file was damaged in transit. Please try again.")
        case .jobFailed(let message):
            return message.isEmpty ? String(localized: "The cloud couldn’t process this file. The original is untouched.") : message
        case .fileUnreadable(let name):
            return String(localized: "“\(name)” couldn’t be read.")
        case .invalidResponse:
            return String(localized: "The server sent an unexpected reply.")
        case .server(_, _, let message, _):
            return message ?? String(localized: "The server couldn’t complete that. Try again later.")
        }
    }

    var technicalDetails: String {
        switch self {
        case .signedOut: "signed out"
        case .notAllowed(let why): "gate refused: \(why)"
        case .notEntitled(let f): "not entitled: \(f.rawValue)"
        case .offline: "offline"
        case .serverUnreachable(let host): "unreachable: \(host)"
        case .connectionLost: "connection lost"
        case .sessionExpired: "refresh rejected (invalid_grant)"
        case .signInFailed(let reason): "sign-in failed: \(reason)"
        case .quotaExceeded(_, let resets): "quota exceeded, resets \(resets.map { $0.formatted(.iso8601) } ?? "?")"
        case .rateLimited(let after): "rate limited, retry after \(after.map { String($0) } ?? "?")s"
        case .payloadTooLarge(let max): "payload too large (max \(max.map(String.init) ?? "?"))"
        case .notFound: "not found"
        case .checksumMismatch: "sha256 mismatch"
        case .jobFailed(let m): "job failed: \(m)"
        case .fileUnreadable(let n): "unreadable: \(n)"
        case .invalidResponse(let d): "invalid response: \(d)"
        case .server(let status, let code, let message, let rid):
            "HTTP \(status) \(code ?? "-") \(message ?? "") request=\(rid ?? "-")"
        }
    }

    /// Worth retrying the same request after a pause (uploads, polling).
    var isTransient: Bool {
        switch self {
        case .connectionLost, .rateLimited, .serverUnreachable: true
        case .server(let status, _, _, _): status >= 500
        default: false
        }
    }
}

/// Short, calm names and one-line descriptions for cloud features, shared
/// by the explainer, errors and the account screen.
enum CloudCopy {
    static func title(for feature: CloudFeature) -> String {
        switch feature {
        case .shareLink: String(localized: "Share links")
        case .shareLinkCustomDomain: String(localized: "Share links on your own domain")
        case .cloudJobs: String(localized: "Cloud conversion")
        case .sync: String(localized: "Sync")
        case .inbox: String(localized: "Inbox")
        case .transcription: String(localized: "Transcription")
        case .upscale: String(localized: "Upscale")
        case .backgroundRemovalHQ: String(localized: "High-quality background removal")
        }
    }

    static func summary(for feature: CloudFeature) -> String {
        switch feature {
        case .shareLink:
            String(localized: "Drop files on Share link to upload them and copy a link you can send to anyone. Links can expire, need a password or stop after a number of downloads.")
        case .shareLinkCustomDomain:
            String(localized: "Share links that use your own domain instead of ours.")
        case .cloudJobs:
            String(localized: "Send a heavy video conversion to the cloud when your Mac is busy or on battery. The result lands beside the original, as usual.")
        case .sync:
            String(localized: "Keep favourites, wheel order, presets and settings the same on every Mac you use.")
        case .inbox:
            String(localized: "Send files from your phone or browser and they appear in a folder on this Mac.")
        case .transcription:
            String(localized: "Turn speech in audio or video into SRT or VTT subtitles, using GPUs on our servers.")
        case .upscale:
            String(localized: "Enlarge images with a machine-learning model that runs on our servers.")
        case .backgroundRemovalHQ:
            String(localized: "Cut out subjects with a larger model than your Mac runs. The local Remove background tool stays free.")
        }
    }

    static func glyph(for feature: CloudFeature) -> String {
        switch feature {
        case .shareLink, .shareLinkCustomDomain: "link.icloud"
        case .cloudJobs: "icloud.and.arrow.up"
        case .sync: "arrow.triangle.2.circlepath.icloud"
        case .inbox: "tray.and.arrow.down"
        case .transcription: "text.bubble"
        case .upscale: "arrow.up.backward.and.arrow.down.forward"
        case .backgroundRemovalHQ: "wand.and.stars"
        }
    }
}
