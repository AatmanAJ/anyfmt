import AppKit
import SwiftUI
import UniformTypeIdentifiers
import HaloCore

@MainActor
final class ImageBackgroundModel: ToolEditorModel {
    let tool: ToolSpec
    let inputs: [URL]
    let preview: CGImage?
    let pixelSize: CGSize

    @Published var style: BackdropStyle { didSet { if style != oldValue { styleChanged(oldValue) } } }
    @Published private(set) var rendered: CGImage?
    private var backgroundImage: CGImage?

    /// Hand-picked gradient pairs (our palette first).
    static let presets: [(String, String)] = [
        ("#6E56F8", "#22C3A6"), ("#FF7A59", "#FFC861"), ("#0A84FF", "#5E5CE6"), ("#1C1B22", "#4A4858"),
        ("#F5F3FF", "#DCD6FF"), ("#14B8A0", "#0E7C86"), ("#FF5F8F", "#8B78FF"), ("#F2F2F7", "#C7C7CC"),
    ]

    init(tool: ToolSpec, inputs: [URL]) {
        self.tool = tool
        self.inputs = inputs
        preview = inputs.first.flatMap { ImageEditorKit.preview($0, edge: 1000) }
        pixelSize = inputs.first.flatMap(ToolImageSupport.pixelSize(of:)) ?? .zero
        style = BackdropStyle(options: tool.defaultOptions)
        renderPreview()
    }

    var options: OptionValues { style.options }

    var canSave: Bool { preview != nil && (style.fill != .image || !style.imagePath.isEmpty) }

    var outputSize: CGSize { BackgroundComposer.canvasSize(for: pixelSize, style: style) }

    var statusLine: String? { "\(ImageEditorKit.pixelText(pixelSize)) → \(ImageEditorKit.pixelText(outputSize))" }

    private func styleChanged(_ old: BackdropStyle) {
        if style.imagePath != old.imagePath {
            backgroundImage = style.imagePath.isEmpty ? nil : ImageEditorKit.preview(URL(fileURLWithPath: style.imagePath), edge: 1400)
        }
        renderPreview()
    }

    func renderPreview() {
        guard let preview else { return }
        rendered = try? BackgroundComposer.compose(subject: preview, style: style, backgroundImage: backgroundImage)
    }

    func applyPreset(_ p: (String, String)) {
        style.fill = .gradient
        style.color1 = p.0
        style.color2 = p.1
    }

    func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose a background image")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        style.imagePath = url.path
        style.fill = .image
    }
}

struct ImageBackgroundEditor: View {
    @ObservedObject var model: ImageBackgroundModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void

    var body: some View {
        EditorShell(model: model, preview: { original in
            if original {
                ImageEditorKit.FittedImage(image: model.preview, size: model.pixelSize, checkerboard: true) { _ in EmptyView() }
                    .accessibilityLabel(String(localized: "Original image"))
            } else {
                ImageEditorKit.FittedImage(image: model.rendered, size: model.outputSize) { _ in EmptyView() }
                    .accessibilityLabel(String(localized: "Image on its new background"))
            }
        }, sidebar: {
            ImageBackgroundSidebar(model: model)
        }, onSave: onSave, onClose: onClose)
    }
}

struct ImageBackgroundSidebar: View {
    @ObservedObject var model: ImageBackgroundModel

    var body: some View {
        ImageEditorKit.Section(String(localized: "Fill")) {
            Picker(String(localized: "Fill"), selection: $model.style.fill) {
                Text("Solid").tag(BackdropStyle.Fill.solid)
                Text("Gradient").tag(BackdropStyle.Fill.gradient)
                Text("Image").tag(BackdropStyle.Fill.image)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            switch model.style.fill {
            case .solid:
                ImageEditorKit.SwatchPicker(hex: $model.style.color1,
                                            swatches: ["#FFFFFF", "#F2F2F7", "#1C1B22", "#6E56F8", "#22C3A6", "#FF7A59", "#FFC861", "#0A84FF"])
            case .gradient:
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                    ForEach(Array(ImageBackgroundModel.presets.enumerated()), id: \.offset) { _, p in
                        let selected = model.style.color1 == p.0 && model.style.color2 == p.1
                        Button { model.applyPreset(p) } label: {
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                .fill(LinearGradient(colors: [ImageEditorKit.color(hex: p.0), ImageEditorKit.color(hex: p.1)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                                    .strokeBorder(selected ? ImageEditorKit.accent : Color.primary.opacity(0.12), lineWidth: selected ? 2 : 0.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "Gradient preset"))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
                HStack(spacing: DesignTokens.Space.l) {
                    ImageEditorKit.ColorWell(label: String(localized: "From"), hex: $model.style.color1)
                    ImageEditorKit.ColorWell(label: String(localized: "To"), hex: $model.style.color2)
                    Spacer(minLength: 0)
                    Button {
                        let c = model.style.color1
                        model.style.color1 = model.style.color2
                        model.style.color2 = c
                    } label: { Image(systemName: "arrow.left.arrow.right") }
                    .buttonStyle(.borderless)
                    .help(String(localized: "Swap colours"))
                    .accessibilityLabel(String(localized: "Swap colours"))
                }
                .font(.system(size: DesignTokens.TypeRamp.body))
                ImageEditorKit.ValueSlider(label: String(localized: "Angle"), value: $model.style.angle, range: 0...360, step: 1, neutral: 135,
                                           format: { "\(Int($0))°" })
            case .image:
                HStack {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                    Text(model.style.imagePath.isEmpty ? String(localized: "No image chosen") : URL(fileURLWithPath: model.style.imagePath).lastPathComponent)
                        .lineLimit(1).truncationMode(.middle)
                        .font(.system(size: DesignTokens.TypeRamp.body))
                    Spacer()
                }
                Button(String(localized: "Choose image…")) { model.chooseImage() }
            }
        }
        ImageEditorKit.Section(String(localized: "Frame")) {
            ImageEditorKit.ValueSlider(label: String(localized: "Padding"), value: $model.style.padding, range: 0...40, step: 1, neutral: 10,
                                       format: { "\(Int($0)) %" })
            ImageEditorKit.ValueSlider(label: String(localized: "Corner radius"), value: $model.style.cornerRadius, range: 0...20, step: 1, neutral: 4,
                                       format: { "\(Int($0)) %" })
            Toggle(String(localized: "Soft shadow"), isOn: $model.style.shadow)
                .toggleStyle(.checkbox)
                .font(.system(size: DesignTokens.TypeRamp.body))
        }
    }
}
