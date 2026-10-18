import AppKit
import SwiftUI
import HaloCore

/// Fallback wheel for the onboarding demo, used until lane B's
/// `RadialMenuView` is wired through `OnboardingHooks.demoWheel`. Same
/// geometry and motion tokens as the real wheel (DesignTokens.Wheel/Motion).
struct DemoWheelRing: View {
    let context: DemoWheelContext
    @State private var appeared = false
    @Environment(\.colorScheme) private var colorScheme

    private var inner: CGFloat { context.innerRadius }
    private var outer: CGFloat { context.outerRadius }
    private var side: CGFloat { (outer + DesignTokens.Wheel.hoverLift + 14) * 2 }

    var body: some View {
        let n = context.segments.count
        ZStack {
            // Soft disc behind the ring so it reads on any background.
            Circle()
                .fill(ringBase.opacity(colorScheme == .dark ? 0.5 : 0.65))
                .frame(width: outer * 2 + 10, height: outer * 2 + 10)
                .blur(radius: 6)
                .opacity(appeared ? 1 : 0)

            ForEach(Array(context.segments.enumerated()), id: \.element.id) { i, seg in
                wedge(i, n, seg)
            }

            hub
        }
        .frame(width: side, height: side)
        .compositingGroup()
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.45 : 0.18), radius: 14, y: 6)
        .onAppear {
            if context.reduceMotion {
                withAnimation(.easeOut(duration: DesignTokens.Motion.crossfade)) { appeared = true }
            } else {
                withAnimation(.spring(response: DesignTokens.Motion.hoverResponse, dampingFraction: DesignTokens.Motion.hoverDamping)) {
                    appeared = true
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(context.kind.role.title) wheel"))
    }

    private var ringBase: Color {
        colorScheme == .dark ? Color(nsColor: NSColor(hex: 0x2A2832)) : Color(nsColor: NSColor(hex: 0xFFFFFF))
    }

    @ViewBuilder
    private func wedge(_ i: Int, _ n: Int, _ seg: DemoSegment) -> some View {
        let hot = context.highlighted == seg.id
        let mid = DemoHitTest.midAngle(i, count: n)
        let lift = hot && !context.reduceMotion ? DesignTokens.Wheel.hoverLift : 0
        let delay = context.reduceMotion ? 0 : DesignTokens.Motion.openStaggerPerSegment * Double(i)
        let shape = WedgeShape(index: i, count: n, inner: inner, outer: outer,
                               gap: 3, cornerRadius: DesignTokens.Wheel.segmentCornerRadius * 0.75)
        ZStack {
            shape
                .fill(hot ? AnyShapeStyle(LinearGradient(colors: [Color.iris, Color.iris.opacity(0.82)],
                                                         startPoint: .top, endPoint: .bottom))
                          : AnyShapeStyle(ringBase))
            shape
                .stroke(hot ? Color.white.opacity(0.18) : Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.07), lineWidth: 0.75)
            label(seg, hot: hot)
                .position(x: side / 2 + cos(mid) * (inner + outer) / 2, y: side / 2 + sin(mid) * (inner + outer) / 2)
        }
        .frame(width: side, height: side)
        .scaleEffect(hot && !context.reduceMotion ? DesignTokens.Wheel.hoverScale : 1)
        .offset(x: cos(mid) * lift, y: sin(mid) * lift)
        .scaleEffect(appeared || context.reduceMotion ? 1 : 0.55)
        .opacity(appeared ? 1 : 0)
        .animation(.spring(response: DesignTokens.Motion.hoverResponse, dampingFraction: DesignTokens.Motion.hoverDamping), value: hot)
        .animation(context.reduceMotion ? .easeOut(duration: DesignTokens.Motion.crossfade)
                   : .spring(response: 0.22, dampingFraction: 0.82).delay(delay), value: appeared)
        .contentShape(shape)
        .onTapGesture { context.select(seg.id) }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: seg.title))
        .accessibilityAddTraits(hot ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { context.select(seg.id) }
    }

    private func label(_ seg: DemoSegment, hot: Bool) -> some View {
        let isFormat = context.kind == .convert
        return VStack(spacing: 3) {
            Image(systemName: seg.glyph)
                .font(.system(size: DesignTokens.Wheel.glyphSize * (isFormat ? 0.82 : 0.9), weight: .medium))
            Text(verbatim: seg.title)
                .font(.system(size: isFormat ? DesignTokens.Wheel.labelSize : DesignTokens.Wheel.toolLabelSize,
                              weight: isFormat ? .bold : .semibold, design: isFormat ? .rounded : .default))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(width: 58)
        }
        .foregroundStyle(hot ? Color.white : Color.primary.opacity(0.85))
    }

    private var hub: some View {
        let r = DesignTokens.Wheel.hubRadius * DemoModel.scale
        return Image(nsImage: context.thumbnail)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: r * 2 - 10, height: r * 2 - 10)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 2))
            .frame(width: r * 2, height: r * 2)
            .background(Circle().fill(ringBase))
            .scaleEffect(appeared || context.reduceMotion ? 1 : 0.7)
            .opacity(appeared ? 1 : 0)
            .accessibilityHidden(true)
    }
}

/// One rounded annular wedge. Each corner is a circle tangent to the ring arc
/// and to the wedge's edge; edges are parallel to the radius, so the gaps
/// between neighbours stay an even width.
struct WedgeShape: Shape {
    let index: Int
    let count: Int
    let inner: CGFloat
    let outer: CGFloat
    /// Linear gap between neighbouring wedges, points.
    let gap: CGFloat
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let slice = 2 * CGFloat.pi / CGFloat(max(count, 1))
        let mid = DemoHitTest.midAngle(index, count: count)
        let a0 = mid - slice / 2, a1 = mid + slice / 2
        let d = gap / 2 + cornerRadius
        let r0 = inner + cornerRadius, r1 = outer - cornerRadius
        guard r1 > r0, count > 1 else {
            return Path { p in
                p.addArc(center: c, radius: outer, startAngle: .zero, endAngle: .degrees(360), clockwise: false)
                p.addArc(center: c, radius: inner, startAngle: .degrees(360), endAngle: .zero, clockwise: true)
            }
        }
        // Corner-circle centres sit on the radial lines offset by `d`;
        // at radius r that line is at angle a ± asin(d / r).
        func off(_ r: CGFloat) -> CGFloat { asin(min(0.99, d / r)) }
        func pt(_ r: CGFloat, _ a: CGFloat) -> CGPoint { CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r) }
        let cr = cornerRadius
        let os = pt(r1, a0 + off(r1)), oe = pt(r1, a1 - off(r1))
        let ie = pt(r0, a1 - off(r0)), ist = pt(r0, a0 + off(r0))
        // In SwiftUI's y-down space, clockwise: false sweeps toward larger angles.
        var p = Path()
        p.move(to: pt(outer, a0 + off(r1)))
        p.addArc(center: c, radius: outer, startAngle: .radians(a0 + off(r1)), endAngle: .radians(a1 - off(r1)), clockwise: false)
        p.addArc(center: oe, radius: cr, startAngle: .radians(a1 - off(r1)), endAngle: .radians(a1 + .pi / 2), clockwise: false)
        p.addArc(center: ie, radius: cr, startAngle: .radians(a1 + .pi / 2), endAngle: .radians(a1 - off(r0) + .pi), clockwise: false)
        p.addArc(center: c, radius: inner, startAngle: .radians(a1 - off(r0)), endAngle: .radians(a0 + off(r0)), clockwise: true)
        p.addArc(center: ist, radius: cr, startAngle: .radians(a0 + off(r0) + .pi), endAngle: .radians(a0 + 1.5 * .pi), clockwise: false)
        p.addArc(center: os, radius: cr, startAngle: .radians(a0 - .pi / 2), endAngle: .radians(a0 + off(r1)), clockwise: false)
        p.closeSubpath()
        return p
    }
}
