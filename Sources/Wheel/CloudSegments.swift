import AppKit
import HaloCore
import RadialMenu

/// The ONLY file in Sources/Wheel that may reference `Entitlements` or
/// `CloudFeature` (scripts/check-entitlements.sh enforces it, BUILD.md §9b).
///
/// Pro segments (tools with a cloud feature, the share-link action) get a cloud
/// glyph and a "Pro" chip so it's always visible that they upload. Local
/// segments never consult entitlements: nothing on the Mac is ever gated.
@MainActor
public final class CloudSegments {
    /// Injected by the host (lane I's implementation). Nil = signed out.
    public var entitlements: (any Entitlements)?

    /// A Pro segment was chosen while signed out: show the calm one-screen explainer.
    public var onProTapWhileSignedOut: ((CloudFeature) -> Void)?

    /// A Pro segment was chosen while signed in without that feature on the plan.
    /// Defaults to the signed-out explainer when not set.
    public var onProTapWithoutPlan: ((CloudFeature) -> Void)?

    public init(entitlements: (any Entitlements)? = nil) {
        self.entitlements = entitlements
    }

    /// The server feature behind an entry, if any.
    nonisolated static func feature(of entry: WheelEntry) -> CloudFeature? {
        switch entry {
        case .convert: nil
        case .tool(let t): t.cloudFeature
        case .action(let a): a.cloudFeature
        }
    }

    nonisolated static func isCloud(_ entry: WheelEntry) -> Bool { feature(of: entry) != nil }

    /// Drops Pro entries when the user chose to hide them. Local entries pass untouched.
    nonisolated static func filter(_ entries: [WheelEntry], showCloudItems: Bool) -> [WheelEntry] {
        showCloudItems ? entries : entries.filter { !isCloud($0) }
    }

    /// Adds the cloud glyph + "Pro" chip to Pro segments. Local items are returned as-is.
    public func decorate(_ item: RadialItem, for entry: WheelEntry) -> RadialItem {
        guard CloudSegments.isCloud(entry) else { return item }
        var decorated = item
        decorated.badge = String(localized: "Pro", comment: "Chip on wheel segments that use the paid cloud service")
        decorated.accessory = RadialItem.symbol("icloud.fill") ?? RadialItem.symbol("cloud.fill")
        let note = String(localized: "Pro. Uploads the file to the cloud.",
                          comment: "VoiceOver hint for cloud segments")
        decorated.accessibilityHint = [item.accessibilityHint, note].compactMap { $0 }.joined(separator: " ")
        return decorated
    }

    /// Call before acting on a selection. Returns true when the entry is a Pro
    /// feature the user can't use right now; the explainer callback has been
    /// called and the host must not run the selection.
    @discardableResult
    public func intercept(_ entry: WheelEntry) -> Bool {
        guard let feature = CloudSegments.feature(of: entry) else { return false }
        guard let entitlements, entitlements.isSignedIn else {
            onProTapWhileSignedOut?(feature)
            return true
        }
        guard entitlements.can(feature) else {
            (onProTapWithoutPlan ?? onProTapWhileSignedOut)?(feature)
            return true
        }
        return false
    }

    /// The "convert in the cloud" option toggle (video options). Returns whether
    /// turning it on is allowed; if not, the explainer has been shown.
    public func allowsCloudJobs() -> Bool {
        guard let entitlements, entitlements.isSignedIn else {
            onProTapWhileSignedOut?(.cloudJobs)
            return false
        }
        guard entitlements.can(.cloudJobs) else {
            (onProTapWithoutPlan ?? onProTapWhileSignedOut)?(.cloudJobs)
            return false
        }
        return true
    }
}
