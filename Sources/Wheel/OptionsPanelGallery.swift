import AppKit
import HaloCore
import SwiftUI

/// Renders the pinned options panel for `make gallery` (light and dark, with a
/// sample estimate), so it's checked alongside the wheel states.
@MainActor
enum OptionsPanelGallery {
    static func render(into dir: URL) throws -> [URL] {
        let router = Router(table: CapabilityTable([Capability("mov", "gif", "gallery", schema: StandardSchemas.gif)]))
        guard let target = router.commonTargets(for: ["mov"]).first(where: { $0.format == "gif" }) else { return [] }
        let store = PresetStore(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("halo-gallery-presets-\(UUID().uuidString).json"))
        var out: [URL] = []
        for (name, appearance) in [("options-panel-dark", NSAppearance.Name.darkAqua), ("options-panel-light", .aqua)] {
            let model = OptionsPanelModel(target: target, values: OptionValues([OptionKey.gifWidth: .int(480), OptionKey.fps: .int(15)]),
                                          input: URL(fileURLWithPath: "/tmp/clip.mov"), presetStore: store)
            model.setEstimateForGallery(.init(bytes: 2_400_000, duration: 4.8, frames: 72, inputBytes: 6_300_000))
            let host = NSHostingView(rootView: OptionsPanelView(model: model).snapshotActiveAppearance())
            host.appearance = NSAppearance(named: appearance)
            host.frame = NSRect(origin: .zero, size: host.fittingSize)
            let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: appearance)
            window.contentView = host
            host.layoutSubtreeIfNeeded()
            guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { continue }
            host.cacheDisplay(in: host.bounds, to: rep)
            let url = dir.appendingPathComponent("\(name).png")
            try rep.representation(using: .png, properties: [:])?.write(to: url)
            out.append(url)
        }
        return out
    }
}

extension OptionsPanelModel {
    /// Gallery only: show a fixed estimate without running the estimator.
    func setEstimateForGallery(_ e: OptionsPanelController.Estimate) {
        estimator = nil
        overrideEstimate(e)
    }
}
