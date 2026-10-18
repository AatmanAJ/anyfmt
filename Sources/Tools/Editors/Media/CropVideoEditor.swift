import AppKit
import Combine
import SwiftUI
import HaloCore

/// Pure crop-rectangle math in normalised coordinates (0…1, origin top-left).
enum VideoCropGeometry {
    enum Handle: CaseIterable { case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left }

    /// Minimum crop side, as a fraction of the frame.
    static let minimumSide = 0.04

    /// Normalised width/height ratio for a pixel aspect `ratio` in a `frame`-sized video.
    static func normalisedRatio(_ ratio: Double, frame: CGSize) -> Double { ratio * Double(frame.height / frame.width) }

    /// Aspect `ratio` (pixels) for a preset id, nil for free.
    static func ratio(_ id: String) -> Double? {
        let p = id.split(separator: ":").compactMap { Double($0) }
        return p.count == 2 && p[1] > 0 ? p[0] / p[1] : nil
    }

    /// The largest rect of normalised ratio `rn` centred on `r`'s centre that fits the frame, no larger than `r` allows.
    static func fit(_ rn: Double, around r: CGRectValue) -> CGRectValue {
        let cx = r.x + r.width / 2, cy = r.y + r.height / 2
        var w = r.width, h = w / rn
        if h > r.height { h = r.height; w = h * rn }
        // Grow to use the area when the old rect was thin in the other direction.
        let area = r.width * r.height
        let scale = min(sqrt(area / max(w * h, 1e-9)), 1 / w, 1 / h)
        w *= scale; h *= scale
        w = min(w, 1); h = min(h, 1)
        if w / h > rn { w = h * rn } else { h = w / rn }
        return clamp(CGRectValue(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
    }

    /// Full-frame rect at ratio `rn`, centred.
    static func maximal(_ rn: Double) -> CGRectValue {
        let w = rn >= 1 ? 1 : rn, h = rn >= 1 ? 1 / rn : 1
        let s = max(w, h) > 1 ? 1 / max(w, h) : 1
        return CGRectValue(x: (1 - w * s) / 2, y: (1 - h * s) / 2, width: w * s, height: h * s)
    }

    /// Keeps a rect inside the frame (moving, then shrinking if needed).
    static func clamp(_ r: CGRectValue) -> CGRectValue {
        let w = min(max(r.width, minimumSide / 2), 1), h = min(max(r.height, minimumSide / 2), 1)
        return CGRectValue(x: min(max(0, r.x), 1 - w), y: min(max(0, r.y), 1 - h), width: w, height: h)
    }

    static func move(_ r: CGRectValue, dx: Double, dy: Double) -> CGRectValue {
        clamp(CGRectValue(x: r.x + dx, y: r.y + dy, width: r.width, height: r.height))
    }

    /// Drags `handle` of `r` to normalised point `p`; `rn` locks the ratio.
    static func resize(_ r: CGRectValue, handle: Handle, to p: CGPoint, ratio rn: Double?) -> CGRectValue {
        let px = min(max(0, Double(p.x)), 1), py = min(max(0, Double(p.y)), 1)
        var x0 = r.x, y0 = r.y, x1 = r.x + r.width, y1 = r.y + r.height
        switch handle {
        case .topLeft: x0 = min(px, x1 - minimumSide); y0 = min(py, y1 - minimumSide)
        case .top: y0 = min(py, y1 - minimumSide)
        case .topRight: x1 = max(px, x0 + minimumSide); y0 = min(py, y1 - minimumSide)
        case .right: x1 = max(px, x0 + minimumSide)
        case .bottomRight: x1 = max(px, x0 + minimumSide); y1 = max(py, y0 + minimumSide)
        case .bottom: y1 = max(py, y0 + minimumSide)
        case .bottomLeft: x0 = min(px, x1 - minimumSide); y1 = max(py, y0 + minimumSide)
        case .left: x0 = min(px, x1 - minimumSide)
        }
        guard let rn else { return clamp(CGRectValue(x: x0, y: y0, width: x1 - x0, height: y1 - y0)) }
        // Locked ratio: size from the dragged extent, anchored opposite the handle
        // (edges stay centred on the other axis), capped so it stays in frame.
        let cx = r.x + r.width / 2, cy = r.y + r.height / 2
        var w = x1 - x0, h = y1 - y0
        switch handle {
        case .top, .bottom: w = h * rn
        case .left, .right: h = w / rn
        default: if w / h > rn { h = w / rn } else { w = h * rn }
        }
        let availW: Double, availH: Double
        switch handle {
        case .topLeft: availW = x1; availH = y1
        case .topRight: availW = 1 - x0; availH = y1
        case .bottomRight: availW = 1 - x0; availH = 1 - y0
        case .bottomLeft: availW = x1; availH = 1 - y0
        case .top: availW = 2 * min(cx, 1 - cx); availH = y1
        case .bottom: availW = 2 * min(cx, 1 - cx); availH = 1 - y0
        case .left: availW = x1; availH = 2 * min(cy, 1 - cy)
        case .right: availW = 1 - x0; availH = 2 * min(cy, 1 - cy)
        }
        // Respect the minimum side on both axes without breaking the ratio.
        let minW = max(minimumSide, minimumSide * rn)
        w = max(w, minW)
        w = min(w, max(availW, 0), max(availH, 0) * rn)
        h = w / rn
        let nx: Double, ny: Double
        switch handle {
        case .topLeft: nx = x1 - w; ny = y1 - h
        case .topRight: nx = x0; ny = y1 - h
        case .bottomRight: nx = x0; ny = y0
        case .bottomLeft: nx = x1 - w; ny = y0
        case .top: nx = cx - w / 2; ny = y1 - h
        case .bottom: nx = cx - w / 2; ny = y0
        case .left: nx = x1 - w; ny = cy - h / 2
        case .right: nx = x0; ny = cy - h / 2
        }
        return clamp(CGRectValue(x: nx, y: ny, width: w, height: h))
    }
}

@MainActor
final class CropVideoModel: MediaEditorModel {
    let tool: ToolSpec
    let inputs: [URL]
    let session: MediaSession
    @Published var rect: CGRectValue
    @Published var aspect: String { didSet { if aspect != oldValue { applyAspect() } } }
    private var bag: Set<AnyCancellable> = []

    static let aspects = ["free", "1:1", "4:3", "3:2", "16:9", "9:16"]

    init(tool: ToolSpec, inputs: [URL], options: OptionValues) {
        self.tool = tool
        self.inputs = inputs
        session = MediaSession(url: inputs[0], isVideo: true)
        rect = PixelCrop.parse(options.string("rect", default: "")) ?? .full
        aspect = options.string("aspect", default: "free")
        session.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }.store(in: &bag)
        session.$state.sink { [weak self] state in
            guard state == .ready else { return }
            Task { @MainActor in
                guard let self else { return }
                self.session.player.seek(to: self.session.duration / 3)
                if self.rect == .full, self.aspect != "free" { self.applyAspect() }
            }
        }.store(in: &bag)
    }

    func start() { session.load() }
    func teardown() { session.stop(); session.player.teardown() }
    func settle() async { await session.settle() }

    var frame: CGSize {
        guard let v = session.info?.video else { return CGSize(width: 16, height: 9) }
        return CGSize(width: v.displayWidth, height: v.displayHeight)
    }

    /// Normalised ratio for the current preset, nil when free.
    var lockedRatio: Double? { VideoCropGeometry.ratio(aspect).map { VideoCropGeometry.normalisedRatio($0, frame: frame) } }

    /// The crop that will be written. With a locked preset the size is an exact
    /// multiple of the ratio in even pixels (4:3 → 8m × 6m), so 4:3 really is 4:3.
    var pixels: PixelCrop {
        let fw = Int(frame.width), fh = Int(frame.height)
        let raw = PixelCrop.make(rect, frameWidth: fw, frameHeight: fh)
        let parts = aspect.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, parts[0] > 0, parts[1] > 0 else { return raw }
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        let g = gcd(parts[0], parts[1])
        let p = parts[0] / g * 2, q = parts[1] / g * 2
        let m = max(1, min((raw.width + p / 2) / p, (raw.height + q / 2) / q, fw / p, fh / q))
        let w = p * m, h = q * m
        let cx = raw.x + raw.width / 2, cy = raw.y + raw.height / 2
        let x = min(max(0, (cx - w / 2) / 2 * 2), (fw - w) / 2 * 2)
        let y = min(max(0, (cy - h / 2) / 2 * 2), (fh - h) / 2 * 2)
        return PixelCrop(x: x, y: y, width: w, height: h)
    }

    /// Normalised rect of `pixels` (what the runner turns back into the same pixels).
    var exactRect: CGRectValue {
        let p = pixels, fw = Double(frame.width), fh = Double(frame.height)
        return CGRectValue(x: Double(p.x) / fw, y: Double(p.y) / fh, width: Double(p.width) / fw, height: Double(p.height) / fh)
    }

    private func applyAspect() {
        guard let rn = lockedRatio else { return }
        rect = rect == .full ? VideoCropGeometry.maximal(rn) : VideoCropGeometry.fit(rn, around: rect)
    }

    func reset() {
        aspect = "free"
        rect = .full
    }

    /// Sets the crop's pixel width or height, keeping its centre (and the ratio, if locked).
    func setPixelSize(width: Int? = nil, height: Int? = nil) {
        let fw = Double(frame.width), fh = Double(frame.height)
        var w = width.map { Double($0) / fw } ?? rect.width
        var h = height.map { Double($0) / fh } ?? rect.height
        if let rn = lockedRatio {
            if width != nil { h = w / rn } else if height != nil { w = h * rn }
        }
        w = min(1, w); h = min(1, h)
        let cx = rect.x + rect.width / 2, cy = rect.y + rect.height / 2
        rect = VideoCropGeometry.clamp(CGRectValue(x: cx - w / 2, y: cy - h / 2, width: w, height: h))
    }

    var isFull: Bool { pixels.width >= Int(frame.width) - 1 && pixels.height >= Int(frame.height) - 1 }

    var options: OptionValues { OptionValues(["rect": .string(exactRect.optionText), "aspect": .string(aspect)]) }
    var canSave: Bool { session.state.isReady && !isFull && pixels.width >= 16 && pixels.height >= 16 }
    var statusLine: String? {
        guard session.state.isReady else { return nil }
        let p = pixels
        return String(localized: "\(Int(frame.width)) × \(Int(frame.height)) → \(p.width) × \(p.height) px")
    }

    func handle(_ key: EditorKey) -> Bool {
        let p = session.player
        switch key {
        case .space: p.togglePlay()
        case .left: p.step(-1)
        case .right: p.step(1)
        case .shiftLeft: p.jump(by: -1)
        case .shiftRight: p.jump(by: 1)
        default: return false
        }
        return true
    }
}

struct CropVideoEditor: View {
    @ObservedObject var model: CropVideoModel
    let onSave: (EditorResult) -> Void
    let onClose: () -> Void

    var body: some View {
        EditorShell(model: model, preview: { original in preview(original) }, sidebar: { sidebar }, onSave: onSave, onClose: onClose)
            .background(KeyMonitor(handler: model.handle))
    }

    private func preview(_ original: Bool) -> some View {
        VStack(spacing: DesignTokens.Space.m) {
            GeometryReader { geo in
                let fitted = fittedRect(in: geo.size)
                ZStack(alignment: .topLeading) {
                    VideoSurface(player: model.session.player, aspect: model.session.displaySize)
                        .frame(width: fitted.width, height: fitted.height)
                        .offset(x: fitted.minX, y: fitted.minY)
                        .opacity(model.session.state.isReady ? 1 : 0)
                    if model.session.state.isReady && !original {
                        CropOverlay(model: model, area: fitted)
                    }
                    LoadingOverlay(state: model.session.state)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            TransportBar(player: model.session.player, duration: model.session.duration)
            FilmstripTimeline(filmstrip: model.session.filmstrip, player: model.session.player,
                              duration: model.session.duration, frameDuration: model.session.frameDuration)
                .disabled(!model.session.state.isReady)
        }
        .padding(DesignTokens.Space.l)
    }

    private func fittedRect(in size: CGSize) -> CGRect {
        let a = model.session.displaySize
        let inset: CGFloat = 12 // room for the handles
        let avail = CGSize(width: max(1, size.width - inset * 2), height: max(1, size.height - inset * 2))
        let s = min(avail.width / a.width, avail.height / a.height)
        let w = a.width * s, h = a.height * s
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    @ViewBuilder
    private var sidebar: some View {
        SidebarSection(String(localized: "Aspect ratio")) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignTokens.Space.s), count: 3), spacing: DesignTokens.Space.s) {
                ForEach(CropVideoModel.aspects, id: \.self) { id in AspectButton(id: id, selected: model.aspect == id) { model.aspect = id } }
            }
        }
        Divider()
        SidebarSection(String(localized: "Size")) {
            HStack(spacing: DesignTokens.Space.s) {
                PixelField(label: String(localized: "Width"), value: model.pixels.width) { model.setPixelSize(width: $0) }
                Text("×").foregroundStyle(.secondary)
                PixelField(label: String(localized: "Height"), value: model.pixels.height) { model.setPixelSize(height: $0) }
                Text("px").font(MediaStyle.caption()).foregroundStyle(.secondary)
            }
            InfoRow(label: String(localized: "Position"), value: "\(model.pixels.x), \(model.pixels.y)")
            InfoRow(label: String(localized: "Original"), value: "\(Int(model.frame.width)) × \(Int(model.frame.height))")
            Button(String(localized: "Reset")) { model.reset() }
                .controlSize(.small)
                .disabled(model.rect == .full && model.aspect == "free")
        }
        Divider()
        SidebarSection(String(localized: "Output")) {
            Note(systemImage: "speaker.wave.2", text: String(localized: "Sound is copied unchanged. The picture re-encodes in its own format, using the hardware encoder when available."))
            Note(systemImage: "ruler", text: String(localized: "Sizes are rounded to even pixels, which every video encoder needs."))
        }
        Divider()
        SidebarSection(String(localized: "Keyboard")) {
            KeyHints(hints: [("Space", String(localized: "Play / pause")), ("← →", String(localized: "Previous / next frame")),
                             ("B", String(localized: "Before / after"))])
        }
    }
}

/// Crop rectangle with dimmed surround, thirds grid, eight handles and a size badge.
private struct CropOverlay: View {
    @ObservedObject var model: CropVideoModel
    let area: CGRect
    @State private var dragStart: CGRectValue?
    @State private var active = false
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let r = model.rect
        let crop = CGRect(x: area.minX + CGFloat(r.x) * area.width, y: area.minY + CGFloat(r.y) * area.height,
                          width: CGFloat(r.width) * area.width, height: CGFloat(r.height) * area.height)
        ZStack(alignment: .topLeading) {
            Path { p in p.addRect(area); p.addRect(crop) }
                .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)
            Path { p in
                for i in 1...2 {
                    let x = crop.minX + crop.width * CGFloat(i) / 3, y = crop.minY + crop.height * CGFloat(i) / 3
                    p.move(to: CGPoint(x: x, y: crop.minY)); p.addLine(to: CGPoint(x: x, y: crop.maxY))
                    p.move(to: CGPoint(x: crop.minX, y: y)); p.addLine(to: CGPoint(x: crop.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(active ? 0.55 : 0.28), lineWidth: 1)
            .allowsHitTesting(false)
            Rectangle()
                .strokeBorder(Color.white, lineWidth: contrast == .increased ? 2.5 : 1.5)
                .frame(width: crop.width, height: crop.height)
                .offset(x: crop.minX, y: crop.minY)
                .contentShape(Rectangle())
                .gesture(moveGesture)
                .accessibilityElement()
                .accessibilityLabel(Text("Crop area"))
                .accessibilityValue(Text("\(model.pixels.width) by \(model.pixels.height) pixels"))
            ForEach(VideoCropGeometry.Handle.allCases, id: \.self) { h in handleView(h, crop: crop) }
            Text("\(model.pixels.width) × \(model.pixels.height)")
                .font(MediaStyle.caption(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(Capsule().fill(Color.black.opacity(0.6)))
                .offset(x: crop.minX + 8, y: max(area.minY + 6, crop.minY + 8))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func position(_ h: VideoCropGeometry.Handle, _ c: CGRect) -> CGPoint {
        switch h {
        case .topLeft: CGPoint(x: c.minX, y: c.minY)
        case .top: CGPoint(x: c.midX, y: c.minY)
        case .topRight: CGPoint(x: c.maxX, y: c.minY)
        case .right: CGPoint(x: c.maxX, y: c.midY)
        case .bottomRight: CGPoint(x: c.maxX, y: c.maxY)
        case .bottom: CGPoint(x: c.midX, y: c.maxY)
        case .bottomLeft: CGPoint(x: c.minX, y: c.maxY)
        case .left: CGPoint(x: c.minX, y: c.midY)
        }
    }

    private func handleView(_ h: VideoCropGeometry.Handle, crop: CGRect) -> some View {
        let p = position(h, crop)
        let corner = [.topLeft, .topRight, .bottomRight, .bottomLeft].contains(h)
        let horizontal = h == .top || h == .bottom
        let size = corner ? CGSize(width: 14, height: 14) : (horizontal ? CGSize(width: 26, height: 6) : CGSize(width: 6, height: 26))
        return RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.45), radius: 1.5)
            .frame(width: size.width, height: size.height)
            .frame(width: 30, height: 30)
            .contentShape(Rectangle())
            .offset(x: p.x - 15, y: p.y - 15)
            .gesture(DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { v in
                    active = true
                    if dragStart == nil { dragStart = model.rect }
                    let base = dragStart ?? model.rect
                    let basePoint = position(h, rectInView(base))
                    let point = CGPoint(x: basePoint.x + v.translation.width, y: basePoint.y + v.translation.height)
                    model.rect = VideoCropGeometry.resize(base, handle: h, to: normalised(point), ratio: model.lockedRatio)
                }
                .onEnded { _ in dragStart = nil; active = false })
            .accessibilityHidden(true)
    }

    private var moveGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { v in
                active = true
                if dragStart == nil { dragStart = model.rect }
                guard let base = dragStart else { return }
                model.rect = VideoCropGeometry.move(base, dx: Double(v.translation.width / area.width), dy: Double(v.translation.height / area.height))
            }
            .onEnded { _ in dragStart = nil; active = false }
    }

    private func rectInView(_ r: CGRectValue) -> CGRect {
        CGRect(x: area.minX + CGFloat(r.x) * area.width, y: area.minY + CGFloat(r.y) * area.height,
               width: CGFloat(r.width) * area.width, height: CGFloat(r.height) * area.height)
    }

    private func normalised(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - area.minX) / area.width, y: (p.y - area.minY) / area.height)
    }
}

/// Aspect preset button with a little proportional glyph.
private struct AspectButton: View {
    let id: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                glyph.frame(height: 18)
                Text(id == "free" ? String(localized: "Free") : (id == "1:1" ? String(localized: "Square") : id))
                    .font(MediaStyle.caption(selected ? .semibold : .regular))
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .fill(selected ? MediaStyle.accent.opacity(0.16) : Color.primary.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: DesignTokens.Radius.small)
                .strokeBorder(selected ? MediaStyle.accent : Color.primary.opacity(0.1), lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(selected ? MediaStyle.accent : Color.primary)
        .accessibilityLabel(Text(id == "free" ? String(localized: "Free aspect ratio") : id))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var glyph: some View {
        if let r = VideoCropGeometry.ratio(id) {
            let w: CGFloat = r >= 1 ? 22 : 22 * CGFloat(r), h: CGFloat = r >= 1 ? 22 / CGFloat(r) : 22
            RoundedRectangle(cornerRadius: 2).strokeBorder(lineWidth: 1.5).frame(width: max(8, w * 0.8), height: max(8, h * 0.8))
        } else {
            Image(systemName: "crop").font(.system(size: 14))
        }
    }
}

/// Integer pixel field committing on Return or blur.
private struct PixelField: View {
    let label: String
    let value: Int
    let commit: (Int) -> Void
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(label, text: $text)
            .textFieldStyle(.roundedBorder)
            .font(MediaStyle.timecode)
            .multilineTextAlignment(.trailing)
            .frame(width: 72)
            .focused($focused)
            .onAppear { text = String(value) }
            .onChange(of: value) { if !focused { text = String($0) } }
            .onSubmit { apply() }
            .onChange(of: focused) { if !$0 { apply() } }
            .accessibilityLabel(Text(label))
    }

    private func apply() {
        if let v = Int(text.trimmingCharacters(in: .whitespaces)), v > 0 { commit(v) }
        text = String(value)
    }
}
