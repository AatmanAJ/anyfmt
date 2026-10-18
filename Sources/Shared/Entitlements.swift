import Foundation

// Cloud entitlements contract (BUILD.md §9b).
//
// RULE: local features never consult this. Every conversion, tool and action
// that runs on the Mac is free, forever, including commercial use. Only
// server-backed actions (`CloudFeature`) check entitlements.
// `scripts/check-entitlements.sh` (run by `make test`) greps the tree and
// fails if anything outside Sources/Cloud or the cloud segment builder
// (Sources/Wheel/CloudSegments.swift) references `Entitlements` or `CloudFeature`.

public enum Plan: String, Sendable, Codable, CaseIterable {
    case free, pro, team

    public var displayName: String {
        switch self {
        case .free: L("Free")
        case .pro: L("Pro")
        case .team: L("Team")
        }
    }
}

/// Features that need our (or a self-hosted) server.
public enum CloudFeature: String, Sendable, Codable, CaseIterable {
    case shareLink
    case shareLinkCustomDomain
    case cloudJobs
    case sync
    case inbox
    case transcription
    case upscale
    case backgroundRemovalHQ
}

public protocol Entitlements: Sendable {
    var isSignedIn: Bool { get }
    var plan: Plan { get }
    func can(_ feature: CloudFeature) -> Bool
}
