import AppKit
import SwiftUI
import HaloCore

/// Screen 2: drag Sample.heic around a small stage and press the real trigger keys.
/// Editorial split: the headline, instructions and key legend on the left; the
/// live stage (a charcoal tile) on the right. The hovered wedge's heat band is
/// this page's one spotlight.
struct OnboardingDemoPage: View {
    @ObservedObject var demo: DemoModel
    @ObservedObject var settings: AppSettings
    let wheelHook: ((DemoWheelContext) -> AnyView)?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private typealias T = DesignTokens.Component.Onboarding

    var body: some View {
        let triggers = demo.triggers
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: DesignTokens.Space.l + DesignTokens.Space.xxs) {
                OnboardingHeadline(text: settings.opensOnPress
                                       ? String(localized: "Drag.\nPress.\nDrop.", comment: "Onboarding demo headline, one word per line")
                                       : String(localized: "Drag.\nTap.\nDrop.", comment: "Onboarding demo headline, one word per line"),
                                   size: T.headlineCompact)
                OnboardingSubtitle(text: settings.opensOnPress
                    ? String(localized: "Drag \(DemoModel.fileName) and, while you hold the mouse button, press \(triggers[.convert].displayName). Tap it or hold it.")
                    : String(localized: "Drag \(DemoModel.fileName) and, while you hold the mouse button, tap \(triggers[.convert].displayName)."))
                KeyLegend(triggers: triggers, active: demo.openKind?.role, pressing: demo.pressing)
                    .padding(.top, DesignTokens.Space.xs)
            }
            .frame(width: T.demoColumn, alignment: .leading)

            Spacer(minLength: DesignTokens.Space.l)

            VStack(alignment: .leading, spacing: DesignTokens.Space.m) {
                DemoStage(demo: demo, wheelHook: wheelHook, reduceMotion: reduceMotion)
                HintLine(hint: demo.hint, triggers: triggers, threshold: settings.tapThreshold, press: settings.opensOnPress)
                    .frame(width: T.stageWidth, alignment: .leading)
            }
        }
        .onAppear { demo.start() }
        .onDisappear { demo.stop() }
    }
}

private struct DemoStage: View {
    @ObservedObject var demo: DemoModel
    let wheelHook: ((DemoWheelContext) -> AnyView)?
    let reduceMotion: Bool

    private var settle: Animation {
        reduceMotion ? .easeOut(duration: DesignTokens.Curve.reducedCrossfade)
            : .spring(response: DesignTokens.Motion.hoverResponse, dampingFraction: DesignTokens.Motion.hoverDamping)
    }

    var body: some View {
        let size = DemoModel.stageSize
        ZStack(alignment: .topLeading) {
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

            // The dragged file: smaller and translucent while a wheel is open, like a drag image.
            FileTile(image: demo.thumbnail, name: DemoModel.fileName, badge: nil,
                     selected: demo.phase != .idle && demo.result == nil, isNew: false)
                .scaleEffect(demo.openKind != nil ? 0.72 : (demo.phase == .dragging && !reduceMotion ? 1.04 : 1))
                .opacity(demo.openKind != nil ? 0.82 : 1)
                .position(demo.tileCenter)
                .animation(demo.phase == .dragging || demo.openKind != nil ? .interactiveSpring(response: 0.12) : settle, value: demo.tileCenter)
                .accessibilityElement()
                .accessibilityLabel(Text("\(DemoModel.fileName), a sample photo"))
                .accessibilityHint(Text("Drag it, then press a trigger key. Or use the actions to open a wheel."))
                .accessibilityAction(named: Text("Open the Convert wheel")) { demo.openForAccessibility(.convert) }
                .accessibilityAction(named: Text("Open the Tools wheel")) { demo.openForAccessibility(.tools) }
                .accessibilityAction(named: Text("Open the Actions wheel")) { demo.openForAccessibility(.actions) }

            if let r = demo.result {
                ResultCard(result: r) { withAnimation(settle) { demo.reset() } }
                    .padding(DesignTokens.Space.m)
                    .frame(width: size.width, height: size.height, alignment: .bottom)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(width: size.width, height: size.height)
        .background(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous).fill(Color.haloTile))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous))
        .coordinateSpace(name: "stage")
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named("stage"))
                .onChanged { v in demo.dragChanged(start: v.startLocation, location: v.location) }
                .onEnded { v in withAnimation(settle) { demo.dragEnded(location: v.location) } }
        )
        .animation(settle, value: demo.openKind)
        .animation(settle, value: demo.result)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("onboarding.demoStage")
    }

    @ViewBuilder private func wheel(_ kind: DemoWheelKind) -> some View {
        let ctx = DemoWheelContext(
            kind: kind, segments: DemoModel.segments(kind), highlighted: demo.highlighted,
            pointer: CGPoint(x: demo.pointer.x - demo.wheelCenter.x, y: demo.pointer.y - demo.wheelCenter.y),
            thumbnail: demo.thumbnail, reduceMotion: reduceMotion,
            innerRadius: DemoModel.innerRadius, outerRadius: DemoModel.outerRadius,
            select: { id in withAnimation(settle) { demo.select(id) } })
        if let wheelHook {
            wheelHook(ctx)
        } else {
            DemoWheelRing(context: ctx)
        }
    }
}

/// A Finder-style image icon: the photo in a thin white mount, the name under it.
private struct FileTile: View {
    let image: NSImage
    let name: String
    let badge: String?
    let selected: Bool
    let isNew: Bool

    private typealias T = DesignTokens.Component.Onboarding

    var body: some View {
        VStack(spacing: DesignTokens.Space.s - DesignTokens.Space.xxs) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: T.fileIcon, height: T.fileIcon)
                .padding(T.fileBorder)
                .background(Color(hex: DesignTokens.Primitive.paper0))
                .overlay(Rectangle().strokeBorder(Color.haloHairline, lineWidth: DesignTokens.Shape.hairline))
                .overlay(alignment: .bottomTrailing) {
                    if let badge {
                        Text(verbatim: badge.localizedUppercase)
                            .font(.haloDisplay(DesignTokens.Typeface.Size.label))
                            .foregroundStyle(Color(hex: DesignTokens.Semantic.onAccentPrimary))
                            .padding(.horizontal, DesignTokens.Space.s)
                            .padding(.vertical, DesignTokens.Space.xxs)
                            .background(Capsule().fill(Color.iris))
                            .offset(x: DesignTokens.Space.s + DesignTokens.Space.xxs, y: DesignTokens.Space.s - DesignTokens.Space.xxs)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if isNew {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: DesignTokens.Typeface.Size.title, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Color(hex: DesignTokens.Semantic.onAccentPrimary), Color.iris)
                            .offset(x: DesignTokens.Space.s, y: -DesignTokens.Space.s)
                            .accessibilityLabel(Text("New file"))
                    }
                }
            Text(verbatim: name)
                .font(.system(size: DesignTokens.TypeRamp.label, weight: .semibold))
                .foregroundStyle(selected ? Color(hex: DesignTokens.Semantic.onAccentPrimary) : Color.haloInk)
                .padding(.horizontal, DesignTokens.Space.s - DesignTokens.Space.xxs)
                .padding(.vertical, DesignTokens.Space.xxs)
                .background(Capsule().fill(selected ? Color.iris : Color.clear))
                .fixedSize()
        }
    }
}

private struct ResultCard: View {
    let result: DemoModel.Result
    let again: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: DesignTokens.Space.m) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DesignTokens.Typeface.Size.title, weight: .semibold))
                .foregroundStyle(Color.accentText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Space.xxs) {
                Text(verbatim: result.title)
                    .font(.system(size: DesignTokens.TypeRamp.body, weight: .semibold))
                    .foregroundStyle(Color.haloInk)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: result.detail)
                    .font(.system(size: DesignTokens.TypeRamp.label))
                    .foregroundStyle(Color.haloSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DesignTokens.Space.xs)
            Button(String(localized: "Try Another"), action: again)
                .buttonStyle(.haloQuiet)
                .accessibilityIdentifier("onboarding.tryAgain")
        }
        .padding(.leading, DesignTokens.Space.l)
        .padding(.trailing, DesignTokens.Space.s)
        .padding(.vertical, DesignTokens.Space.m)
        .background(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous).fill(Color.haloRaised))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.Shape.tile, style: .continuous)
            .strokeBorder(Color.haloHairline, lineWidth: DesignTokens.Shape.hairline))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.result")
    }
}

/// Which key opens which wheel, read from Settings. One row per wheel.
private struct KeyLegend: View {
    let triggers: TriggerAssignment
    let active: TriggerRole?
    let pressing: TriggerKey?

    private typealias T = DesignTokens.Component.Onboarding

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Space.s) {
            ForEach(TriggerRole.allCases) { role in
                let key = triggers[role]
                let on = active == role || pressing == key
                HStack(spacing: DesignTokens.Space.m) {
                    DemoKeyCap(text: key.displayName, prominent: on)
                    Text(verbatim: role.title.localizedUppercase)
                        .font(.haloDisplay(T.tagSize, black: false))
                        .displayTracking(T.tagSize)
                        .foregroundStyle(active == role ? Color.haloInk : Color.haloSecondaryText)
                }
                .animation(.easeOut(duration: DesignTokens.Curve.reducedCrossfade), value: on)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("\(key.name) opens \(role.title)"))
                .accessibilityAddTraits(active == role ? .isSelected : [])
            }
        }
    }
}

/// A key as a pill: charcoal at rest, cobalt while it's down or its wheel is open
/// (and the role name beside it turns primary, so colour isn't the only signal).
private struct DemoKeyCap: View {
    let text: String
    let prominent: Bool

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: DesignTokens.TypeRamp.label, weight: .semibold))
            .foregroundStyle(prominent ? Color(hex: DesignTokens.Semantic.onAccentPrimary) : Color.haloInk)
            .lineLimit(1)
            .padding(.horizontal, DesignTokens.Space.m)
            .frame(minWidth: DesignTokens.Component.Onboarding.keyCapWidth, alignment: .leading)
            .frame(height: DesignTokens.Component.Onboarding.keyCapHeight)
            .background(PillBorder(fill: prominent ? Color.iris : Color.haloTile,
                                   border: prominent ? Color.iris : Color.haloHairline))
    }
}

private struct HintLine: View {
    let hint: DemoModel.Hint
    let triggers: TriggerAssignment
    let threshold: Double
    var press = true

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: DesignTokens.TypeRamp.body))
            .foregroundStyle(Color.haloSecondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .id(text)
            .transition(.opacity)
            .animation(.easeOut(duration: DesignTokens.Curve.reducedCrossfade), value: text)
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

/// A filled pill with a hairline edge, drawn as two fills (a stroked capsule
/// renders uneven ends at this size).
struct PillBorder: View {
    let fill: Color
    let border: Color
    var width: CGFloat = DesignTokens.Shape.hairline

    var body: some View {
        Capsule().fill(border)
            .overlay(Capsule().fill(fill).padding(width))
    }
}
