import AppKit
import SwiftUI
import AnyfmtCore

@MainActor
final class ImageAdjustModel: ToolEditorModel {
    let tool: ToolSpec
    let inputs: [URL]
    let preview: CGImage?
    let pixelSize: CGSize

    @Published var adjustments: ImageAdjustments { didSet { if adjustments != oldValue { renderPreview() } } }
    @Published private(set) var rendered: CGImage?
    /// Last preview render time, for the ≤ 50 ms budget.
    private(set) var lastRenderSeconds: Double = 0

    init(tool: ToolSpec, inputs: [URL]) {
        self.tool = tool
        self.inputs = inputs
        preview = inputs.first.flatMap { ImageEditorKit.preview($0) }
        pixelSize = inputs.first.flatMap(ToolImageSupport.pixelSize(of:)) ?? .zero
        adjustments = ImageAdjustments(options: tool.defaultOptions)
        rendered = preview
    }

    var options: OptionValues { adjustments.options }
    var canSave: Bool { preview != nil && !adjustments.isNeutral }

    var statusLine: String? {
        adjustments.isNeutral ? ImageEditorKit.pixelText(pixelSize) : String(localized: "Edited · \(ImageEditorKit.pixelText(pixelSize))")
    }

    func renderPreview() {
        guard let preview else { return }
        let start = CFAbsoluteTimeGetCurrent()
        rendered = (try? adjustments.render(preview)) ?? preview
        lastRenderSeconds = CFAbsoluteTimeGetCurrent() - start
    }

    func resetAll() { adjustments = .neutral }
}

struct ImageAdjustEditor: View {
    @ObservedObject var model: ImageAdjustModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void

    var body: some View {
        EditorShell(model: model, preview: { original in
            ImageEditorKit.FittedImage(image: original ? model.preview : model.rendered, size: model.pixelSize, checkerboard: true,
                                       source: model.inputs.first) { _ in EmptyView() }
                .accessibilityLabel(original ? String(localized: "Original image") : String(localized: "Adjusted image"))
        }, sidebar: {
            ImageAdjustSidebar(model: model)
        }, onSave: onSave, onClose: onClose)
    }
}

struct ImageAdjustSidebar: View {
    @ObservedObject var model: ImageAdjustModel

    var body: some View {
        ImageEditorKit.Section(String(localized: "Light")) {
            ImageEditorKit.ValueSlider(label: String(localized: "Exposure"), value: $model.adjustments.exposure, range: -2...2, step: 0.05,
                                       neutral: 0, format: { String(format: "%+.2f EV", $0) })
            ImageEditorKit.ValueSlider(label: String(localized: "Contrast"), value: $model.adjustments.contrast, range: 0.5...1.5, step: 0.01,
                                       neutral: 1, format: Self.percentFromOne)
        }
        ImageEditorKit.Section(String(localized: "Colour")) {
            ImageEditorKit.ValueSlider(label: String(localized: "Saturation"), value: $model.adjustments.saturation, range: 0...2, step: 0.01,
                                       neutral: 1, format: Self.percentFromOne)
            ImageEditorKit.ValueSlider(label: String(localized: "Warmth"), value: $model.adjustments.warmth, range: -1...1, step: 0.01,
                                       neutral: 0, format: { $0 == 0 ? "0" : String(format: "%+.0f", $0 * 100) })
        }
        HStack {
            ImageEditorKit.Hint(String(localized: "Double-click a slider to reset it."))
            Spacer()
            Button(String(localized: "Reset all")) { model.resetAll() }
                .disabled(model.adjustments.isNeutral)
        }
        .padding(.horizontal, EditorTokens.sectionPadding)
    }

    static func percentFromOne(_ v: Double) -> String {
        let p = Int(((v - 1) * 100).rounded())
        return p == 0 ? "0" : String(format: "%+d", p)
    }
}
