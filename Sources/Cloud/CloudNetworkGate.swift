import Foundation
import AnyfmtCore

/// Why a request is being made. Every request names one, and the gate
/// decides from it. "Local is sacred" (BUILD.md §2): signed out, nothing
/// but the two user-initiated pre-auth calls can pass.
enum CloudTrigger: String, Sendable, CustomStringConvertible {
    /// The user clicked, dropped or pressed something that is a cloud action.
    case user
    /// Finishing a browser sign-in the user started (code exchange, first account fetch).
    case signIn
    /// The sync engine. Only while signed in **and** the user turned sync on.
    case sync
    /// The inbox poller. Only while signed in **and** the user turned the inbox on.
    case inbox

    var description: String { rawValue }
}

/// What an endpoint needs before the gate lets a request out.
enum CloudAccess: Sendable, Equatable {
    /// `GET /v1/health`: the "Validate" button. Allowed signed out, only for `.user`.
    case probe
    /// `POST /v1/auth/token` with a code: only for `.signIn` with a pending browser sign-in.
    case codeExchange
    /// `POST /v1/auth/revoke`: only as part of the user signing out.
    case revocation
    /// Everything else. Needs a signed-in account.
    case authenticated
    /// A result/inbox download from a signed URL (maybe another host). Needs a
    /// signed-in account; gets the bearer token only on the server's own origin.
    case signedDownload
}

enum CloudNetworkGate {
    /// Throws unless `trigger` may perform a request needing `access` in state `s`.
    static func check(_ trigger: CloudTrigger, _ access: CloudAccess, _ s: CloudSnapshot) throws {
        switch access {
        case .probe:
            guard trigger == .user else { throw CloudError.notAllowed("server check needs a user action") }
        case .codeExchange:
            guard trigger == .signIn, let pending = s.pendingSignIn, !pending.isExpired() else {
                throw CloudError.notAllowed("no sign-in in progress")
            }
        case .revocation:
            guard trigger == .user else { throw CloudError.notAllowed("sign-out needs a user action") }
        case .authenticated, .signedDownload:
            guard s.isSignedIn else { throw CloudError.signedOut }
            switch trigger {
            case .user, .signIn: break
            case .sync: guard s.syncEnabled else { throw CloudError.notAllowed("sync is off") }
            case .inbox: guard s.inboxEnabled else { throw CloudError.notAllowed("inbox is off") }
            }
        }
    }
}
