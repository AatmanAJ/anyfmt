import AppKit
import SwiftUI
import HaloCore

/// Screen 1: drag Sample.heic around a small stage and press the real trigger keys.
struct OnboardingDemoPage: View {
    @ObservedObject var demo: DemoModel
    @ObservedObject var settings: AppSettings
    let wheelHook: ((DemoWheelContext) -> AnyView)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let triggers = demo.triggers
        VStack(spacing: DesignTokens.Space.m) {
            PageHeader(title: settings.opensOnPress ? String(localized: "Drag. Press. Drop.") : String(localized: "Drag. Tap. Drop."),
                       subtitle: settings.opensOnPress
                           ? String(localized: "Drag \(DemoModel.fileName) and, while you hold the mouse button, press \(triggers[.convert].displayName). Tap it or hold it.")
                           : String(localized: "Drag \(DemoModel.fileName) and, while you hold the mouse button, tap \(triggers[.convert].displayName)."))
                .padding(.bottom, DesignTokens.Space.xs)
            DemoStage(demo: demo, wheelHook: wheelHook, reduceMotion: reduceMotion)
            KeyLegend(triggers: triggers, active: demo.openKind?.role, pressing: demo.pressing)
                .padding(.top, DesignTokens.Space.xxs)
            HintLine(hint: demo.hint, triggers: triggers, threshold: settings.tapThreshold, press: settings.opensOnPress)
                .frame(height: 16)
        }
        .onAppear { demo.start() }
        .onDisappear { demo.stop() }
    }
}

private struct DemoStage: View {
    @ObservedObject var demo: DemoModel
    let wheelHook: ((DemoWheelContext) -> AnyView)?
    let reduceMotion: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var spring: Animation {
        reduceMotion ? .easeOut(duration: DesignTokens.Motion.crossfade)
            : .spring(response: DesignTokens.Motion.hoverResponse, dampingFraction: DesignTokens.Motion.hoverDamping)
    }

    var body: some View {
        let size = DemoModel.stageSize
        ZStack(alignment: .topLeading) {
            DotGrid()
                .foregroundStyle(Color.primary.opacity(colorScheme == .dark ? 0.09 : 0.08))

            // Result file appears beside the original.
            if let r = demo.result, let name = r.outputName {
                FileTile(image: demo.thumbnail, name: name, badge: r.outputBadge, selected: false, isNew: true)
                    .position(DemoModel.resultCenter)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
            }

            if let kind = demo.openKind {
                wheel(kind)
                    .position(demo.wheelCenter)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.85).combined(with: .opacity))
                    .id(kind)
            }

            // The dragged file: a translucent drag image while a wheel is open.
            FileTile(image: demo.thumbnail, name: DemoModel.fileName, badge: nil,
                     selected: demo.phase != .idle && demo.result == nil, isNew: false)
                .scaleEffect(demo.openKind != nil ? 0.72 : (demo.phase == .dragging ? 1.04 : 1))
                .opacity(demo.openKind != nil ? 0.82 : 1)
                .shadow(color: .black.opacity(demo.phase == .dragging ? 0.25 : 0), radius: 10, y: 6)
                .position(demo.tileCenter)
                .animation(demo.phase == .dragging || demo.openKind != nil ? .interactiveSpring(response: 0.12) : spring, value: demo.tileCenter)
                .accessibilityElement()
                .accessibilityLabel(Text("\(DemoModel.fileName), a sample photo"))
                .accessibilityHint(Text("Drag it, then press a trigger key. Or use the actions to open a wheel."))
                .accessibilityAction(named: Text("Open the Convert wheel")) { demo.openForAccessibility(.convert) }
                .accessibilityAction(named: Text("Open the Tools wheel")) { demo.openForAccessibility(.tools) }
                .accessibilityAction(named: Text("Open the Actions wheel")) { demo.openForAccessibility(.actions) }

            if let r = demo.result {
                ResultCard(result: r) { withAnimation(spring) { demo.reset() } }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DesignTokens.Space.l)
                    .frame(height: size.height, alignment: .bottom)
                    .padding(.bottom, DesignTokens.Space.m)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(width: size.width, height: size.height)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.05 : 0.035))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous))
        .coordinateSpace(name: "stage")
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named("stage"))
                .onChanged { v in demo.dragChanged(start: v.startLocation, location: v.location) }
                .onEnded { v in withAnimation(spring) { demo.dragEnded(location: v.location) } }
        )
        .animation(spring, value: demo.openKind)
        .animation(spring, value: demo.result)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.demoStage")
    }

    @ViewBuilder private func wheel(_ kind: DemoWheelKind) -> some View {
        let ctx = DemoWheelContext(
            kind: kind, segments: DemoModel.segments(kind), highlighted: demo.highlighted,
            pointer: CGPoint(x: demo.pointer.x - demo.wheelCenter.x, y: demo.pointer.y - demo.wheelCenter.y),
            thumbnail: demo.thumbnail, reduceMotion: reduceMotion,
            innerRadius: DemoModel.innerRadius, outerRadius: DemoModel.outerRadius,
            select: { id in withAnimation(spring) { demo.select(id) } })
        if let wheelHook {
            wheelHook(ctx)
        } else {
            DemoWheelRing(context: ctx)
        }
    }
}

/// A Finder-style file icon: photo with a white border, name underneath.
private struct FileTile: View {
    let image: NSImage
    let name: String
    let badge: String?
    let selected: Bool
    let isNew: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .padding(3)
                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.white))
                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                .overlay(alignment: .bottomTrailing) {
                    if let badge {
                        FormatChip(label: badge, kind: .image, size: 10)
                            .offset(x: 8, y: 6)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isNew {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color.white, Color.haloSuccess)
                            .offset(x: 9, y: -9)
                    }
                }
            Text(verbatim: name)
                .font(.system(size: DesignTokens.TypeRamp.label, weight: .medium))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1.5)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(selected ? Color.iris : Color.clear))
                .fixedSize()
        }
    }
}

private struct ResultCard: View {
    let result: DemoModel.Result
    let again: () -> Void

    var body: some View {
        HStack(spacing: DesignTokens.Space.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.haloSuccess)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: result.title)
                    .font(.system(size: DesignTokens.TypeRamp.body, weight: .semibold))
                Text(verbatim: result.detail)
                    .font(.system(size: DesignTokens.TypeRamp.label))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: DesignTokens.Space.s)
            Button("Try Another", action: again)
                .controlSize(.small)
                .accessibilityIdentifier("onboarding.tryAgain")
        }
        .padding(.horizontal, DesignTokens.Space.l)
        .padding(.vertical, DesignTokens.Space.m)
        .background {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.14), radius: 10, y: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.result")
    }
}

/// Which key opens which wheel, read from Settings.
private struct KeyLegend: View {
    let triggers: TriggerAssignment
    let active: TriggerRole?
    let pressing: TriggerKey?

    var body: some View {
        HStack(spacing: DesignTokens.Space.xl) {
            ForEach(TriggerRole.allCases) { role in
                let key = triggers[role]
                HStack(spacing: DesignTokens.Space.s) {
                    KeyCap(text: key.displayName, prominent: active == role || pressing == key)
                    Text(verbatim: role.title)
                        .font(.system(size: DesignTokens.TypeRamp.body, weight: active == role ? .semibold : .regular))
                        .foregroundStyle(active == role ? Color.primary : Color.secondary)
                }
                .animation(.easeOut(duration: DesignTokens.Motion.crossfade), value: active)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("\(key.name) opens \(role.title)"))
            }
        }
    }
}

private struct HintLine: View {
    let hint: DemoModel.Hint
    let triggers: TriggerAssignment
    let threshold: Double
    var press = true

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: DesignTokens.TypeRamp.label))
            .foregroundStyle(.secondary)
            .id(text)
            .transition(.opacity)
            .animation(.easeOut(duration: DesignTokens.Motion.crossfade), value: text)
            .accessibilityIdentifier("onboarding.hint")
    }

    private var text: String {
        let s = OptionsFormLogic.display(threshold, decimals: 2, unit: "s")
        switch hint {
        case .start: return String(localized: "Press and hold on the photo, then move it.")
        case .tapNow:
            return press ? String(localized: "Keep holding the mouse, and press \(triggers[.convert].displayName).")
                : String(localized: "Keep holding the mouse, and tap \(triggers[.convert].displayName): press and let go.")
        case .chooseSegment: return String(localized: "Move onto a segment and let go. Drop in the middle to cancel.")
        case .held: return String(localized: "That was a hold. A tap is a quick press, under \(s).")
        case .chord: return String(localized: "Use one key on its own.")
        case .unassigned(let k): return String(localized: "\(k.name) isn’t assigned to a wheel. Change keys in Settings › Keys.")
        case .dragFirst:
            return press ? String(localized: "Start dragging the photo first, then press the key.")
                : String(localized: "Start dragging the photo first, then tap.")
        case .cancelled: return String(localized: "Cancelled. Nothing happened to the file.")
        case .done:
            return press ? String(localized: "Press \(triggers[.tools].displayName) or \(triggers[.actions].displayName) mid-drag for the other wheels.")
                : String(localized: "Tap \(triggers[.tools].displayName) or \(triggers[.actions].displayName) mid-drag for the other wheels.")
        }
    }
}

/// Faint dot grid, like a desktop.
private struct DotGrid: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 16
            var y = step / 2
            while y < size.height {
                var x = step / 2
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8)), with: .foreground)
                    x += step
                }
                y += step
            }
        }
        .accessibilityHidden(true)
    }
}

/// Title + subtitle used at the top of every onboarding screen.
struct PageHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: DesignTokens.Space.xs + 2) {
            Text(verbatim: title)
                .font(.system(size: DesignTokens.TypeRamp.display, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: subtitle)
                .font(.system(size: DesignTokens.TypeRamp.title))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 560)
        }
    }
}
