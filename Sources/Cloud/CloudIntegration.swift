import AppKit
import HaloCore

/// The app's single doorway into cloud features. Every entitlement check lives
/// here or elsewhere in Sources/Cloud (scripts/check-entitlements.sh), so the
/// coordinator can route selections without ever consulting a plan itself.
@MainActor
enum CloudIntegration {
    private static var observer: UUID?

    /// Start background cloud services only when they were opted into (inbox/sync).
    /// Touching `.shared` makes no request while signed out (CloudNetworkGate).
    static func start(wheel: WheelController) {
        let services = CloudServices.shared
        wheel.cloud.entitlements = services.entitlements
        wheel.cloud.onProTapWhileSignedOut = { CloudPanels.showProExplainer(for: $0) }
        wheel.cloud.onProTapWithoutPlan = { CloudPanels.showProExplainer(for: $0) }
        if observer == nil {
            observer = services.state.observe { [weak wheel] snapshot in
                Task { @MainActor in wheel?.cloud.entitlements = snapshot.entitlements }
            }
        }
    }

    @discardableResult
    static func handleCallback(_ url: URL) -> Bool { CloudServices.shared.handleCallback(url) }

    /// A conversion whose options ask for the cloud. Returns false to run locally.
    static func convertIfRequested(_ files: [URL], target: FormatID, options: OptionValues,
                                   jobs: JobsController, near point: CGPoint) -> Bool {
        guard CloudJobOperation.wantsCloud(options) else { return false }
        let services = CloudServices.shared
        guard services.entitlements.can(.cloudJobs) else {
            CloudPanels.showProExplainer(for: .cloudJobs)
            return true
        }
        var local = options
        local[OptionKey.cloud] = .bool(false)
        for file in files {
            let job = services.makeCloudJob(input: file, operation: .convert(target: target, options: local))
            jobs.submit(job, near: point)
        }
        return true
    }

    /// A Pro tool (transcribe, upscale, HQ background removal).
    static func runTool(_ tool: ToolSpec, on files: [URL], jobs: JobsController, near point: CGPoint) {
        let services = CloudServices.shared
        guard let feature = tool.cloudFeature else { return }
        guard services.entitlements.can(feature) else {
            CloudPanels.showProExplainer(for: feature)
            return
        }
        guard let operation = CloudJobOperation.forTool(tool.id, options: tool.defaultOptions) else { return }
        for file in files {
            jobs.submit(services.makeCloudJob(input: file, operation: operation), near: point)
        }
    }

    /// The Pro share-link action. Returns a one-line confirmation for the HUD.
    static func shareLink(_ files: [URL]) async -> String? {
        do {
            switch try await CloudPanels.runShareLink(files: files) {
            case .created(_, let remaining)?:
                if let remaining { return String(localized: "Link copied. \(remaining) free links left this month.") }
                return String(localized: "Link copied to the clipboard.")
            case .declined?, nil:
                return nil
            }
        } catch {
            Log.cloud.error("share link failed: \(error.localizedDescription, privacy: .public)")
            return String(localized: "Couldn’t create the link: \(error.localizedDescription)")
        }
    }
}
