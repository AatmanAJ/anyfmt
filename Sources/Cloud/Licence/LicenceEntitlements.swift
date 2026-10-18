import Foundation
import HaloCore

/// What a licence can prove offline: a plan and a seat count, for a time window.
///
/// Merged into `CloudSnapshot.entitlements`, it raises the reported `plan`
/// (never lowers it) and exposes `seats`. It does **not** add features,
/// quotas or custom domains, and it does not change `isSignedIn`, so
/// `can(_:)` still answers false for every cloud feature until the server
/// says otherwise. Cloud calls still need sign-in and are enforced server-side.
struct LicenceEntitlements: Sendable, Equatable, Codable {
    let licenceID: String
    let plan: Plan
    let seats: Int
    /// `issuedAt` minus the verifier's clock skew.
    let notBefore: Date
    let expiresAt: Date?

    init(_ licence: Licence, clockSkew: TimeInterval = LicenceVerifier.shipped.clockSkew) {
        licenceID = licence.licenceID
        plan = licence.plan
        seats = licence.seats
        notBefore = licence.issuedAt.addingTimeInterval(-clockSkew)
        expiresAt = licence.expiresAt
    }

    func isActive(at now: Date) -> Bool {
        guard now >= notBefore else { return false }
        if let expiresAt, now >= expiresAt { return false }
        return true
    }
}

extension Plan {
    /// free < pro < team, for "the better of the server's plan and the licence's".
    var licenceRank: Int {
        switch self {
        case .free: 0
        case .pro: 1
        case .team: 2
        }
    }
}

extension CloudEntitlements {
    /// Seats proven by an active licence, if any.
    var licenceSeats: Int? { licence?.seats }

    /// These entitlements with an active licence's plan folded in. An inactive
    /// (expired, not yet valid) or missing licence returns `self` unchanged.
    func merging(_ licence: LicenceEntitlements?, now: Date = Date()) -> CloudEntitlements {
        guard let licence, licence.isActive(at: now) else { return self }
        var merged = CloudEntitlements(
            isSignedIn: isSignedIn,
            plan: licence.plan.licenceRank > plan.licenceRank ? licence.plan : plan,
            features: features,
            quotas: quotas,
            customDomains: customDomains)
        merged.licence = licence
        return merged
    }
}
