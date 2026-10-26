import Foundation
import AnyfmtCore

/// Sendable snapshot implementing the `Entitlements` contract.
///
/// Only Sources/Cloud (and the wheel's CloudSegments.swift) may read this;
/// `scripts/check-entitlements.sh` enforces that no local feature does.
/// Signed out → `isSignedIn == false`, `.free`, and `can(_:)` is false for
/// every feature.
struct CloudEntitlements: Entitlements, Equatable, Codable {
    let isSignedIn: Bool
    let plan: Plan
    let features: Set<CloudFeature>
    let quotas: CloudQuotas
    let customDomains: [String]
    /// The active offline licence folded in by `merging(_:now:)` (Licence/LicenceEntitlements.swift).
    /// Only ever raises `plan` and reports seats; never grants a feature.
    var licence: LicenceEntitlements? = nil

    func can(_ feature: CloudFeature) -> Bool {
        isSignedIn && features.contains(feature)
    }

    static let signedOut = CloudEntitlements(isSignedIn: false, plan: .free, features: [], quotas: .none, customDomains: [])

    init(isSignedIn: Bool, plan: Plan, features: Set<CloudFeature>, quotas: CloudQuotas, customDomains: [String]) {
        self.isSignedIn = isSignedIn
        self.plan = plan
        self.features = features
        self.quotas = quotas
        self.customDomains = customDomains
    }

    /// From the server's account payload. Unknown plans read as free and
    /// unknown features are ignored, so a newer server never breaks the app.
    init(_ dto: CloudEntitlementsDTO) {
        isSignedIn = true
        plan = Plan(rawValue: dto.plan) ?? .free
        features = Set(dto.features.compactMap(CloudFeature.init(rawValue:)))
        quotas = dto.quotas
        customDomains = features.contains(.shareLinkCustomDomain) ? (dto.customDomains ?? []) : []
    }

    /// Share links left this period, or nil when unlimited.
    var remainingShareLinks: Int? {
        guard let limit = quotas.shareLinksPerMonth else { return nil }
        return max(0, limit - (quotas.shareLinksUsed ?? 0))
    }

    /// Records a link created locally so the UI stays right without another request.
    func recordingShareLink() -> CloudEntitlements {
        var q = quotas
        q.shareLinksUsed = (q.shareLinksUsed ?? 0) + 1
        return CloudEntitlements(isSignedIn: isSignedIn, plan: plan, features: features, quotas: q, customDomains: customDomains)
    }

    /// The neutral usage line under the plan badge. Never an upsell.
    var usageLine: String? {
        guard isSignedIn else { return nil }
        guard can(.shareLink) else { return nil }
        guard let limit = quotas.shareLinksPerMonth else {
            return String(localized: "Unlimited share links")
        }
        let left = remainingShareLinks ?? 0
        if let resets = quotas.periodResetsAt {
            let date = resets.formatted(.dateTime.month(.abbreviated).day())
            return String(localized: "\(left) of \(limit) share links left this month · renews \(date)")
        }
        return String(localized: "\(left) of \(limit) share links left this month")
    }
}

/// The signed-in account as the UI shows it, cached per server so the plan
/// badge is right at launch without a request.
struct CloudAccount: Codable, Sendable, Equatable {
    let userID: String
    let email: String
    let name: String?
    var entitlements: CloudEntitlements

    init(_ dto: CloudAccountDTO) {
        userID = dto.user.id
        email = dto.user.email
        name = dto.user.name
        entitlements = CloudEntitlements(dto.entitlements)
    }

    init(userID: String, email: String, name: String?, entitlements: CloudEntitlements) {
        self.userID = userID
        self.email = email
        self.name = name
        self.entitlements = entitlements
    }
}
