import AppKit
import SwiftUI
import AnyfmtCore

/// Fallback wheel for the onboarding demo, used until the real `RadialMenuView`
/// is wired through `OnboardingHooks.demoWheel`. Drawn in the phase 2 wheel look:
/// a black disc, charcoal wedges, heavy uppercase labels, and the heat band on the
/// wedge under the pointer, like a stage light swinging onto it. Nothing glows,
/// nothing is blurred. Same geometry and motion tokens as the real wheel.
struct DemoWheelRing: View {
    let context: DemoWheelContext
    @State private var appeared = false
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private typealias T = DesignTokens.Component.Onboarding

    private var inner: CGFloat { context.innerRadius }
    private var outer: CGFloat { context.outerRadius }
    private var side: CGFloat { (outer + T.wheelRim + DesignTokens.Wheel.hoverLift + DesignTokens.Space.s) * 2 }

    var body: some View {
        let n = context.segments.count
        ZStack {
            Circle()
                .fill(Color(hex: T.wheelDisc))
                .frame(width: (outer + T.wheelRim) * 2, height: (outer + T.wheelRim) * 2)
                .opacity(appeared ? 1 : 0)

            ForEach(Array(context.segments.enumerated()), id: \.element.id) { i, seg in
                wedge(i, n, seg)
            }

            hub
        }
        .frame(width: side, height: side)
        .onAppear {
            withAnimation(context.reduceMotion ? .easeOut(duration: DesignTokens.Curve.reducedCrossfade)
                          : .spring(response: DesignTokens.Motion.hoverResponse, dampingFraction: DesignTokens.Motion.hoverDamping)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(context.kind.role.title) wheel"))
    }

    /// Bands are flat when transparency is reduced or contrast is increased; an
    /// outline then marks the hot wedge as well as the fill.
    private var flatBands: Bool { reduceTransparency || contrast == .increased }

    @ViewBuilder
    private func wedge(_ i: Int, _ n: Int, _ seg: DemoSegment) -> some View {
        let hot = context.highlighted == seg.id
        let mid = DemoHitTest.midAngle(i, count: n)
        let lift = hot && !context.reduceMotion ? DesignTokens.Wheel.hoverLift : 0
        let delay = context.reduceMotion ? 0 : DesignTokens.Motion.openStaggerPerSegment * Double(i)
        let shape = WedgeShape(index: i, count: n, inner: inner, outer: outer,
                               gap: T.wheelGap, cornerRadius: DesignTokens.Shape.segment * 0.5)
        let box = shape.path(in: CGRect(x: 0, y: 0, width: side, height: side)).boundingRect
        ZStack {
            if hot {
                // The heat band laid across this wedge's own bounds, so all six bands show.
                BandGradient(bands: DesignTokens.Band.heat, flat: DesignTokens.Band.heatFlat)
                    .frame(width: box.width, height: box.height)
                    .position(x: box.midX, y: box.midY)
                    .frame(width: side, height: side)
                    .mask(shape)
                if flatBands {
                    shape.stroke(Color(hex: T.wheelLabelOnBand), lineWidth: DesignTokens.Component.Focus.ringWidth)
                }
            } else {
                shape.fill(Color(hex: T.wheelWedge))
            }
            label(seg, hot: hot)
                .position(x: side / 2 + cos(mid) * (inner + outer) / 2, y: side / 2 + sin(mid) * (inner + outer) / 2)
        }
        .frame(width: side, height: side)
        .scaleEffect(hot && !context.reduceMotion ? DesignTokens.Wheel.hoverScale : 1)
        .offset(x: cos(mid) * lift, y: sin(mid) * lift)
        .scaleEffect(appeared || context.reduceMotion ? 1 : 0.55)
        .opacity(appeared ? 1 : 0)
        .animation(context.reduceMotion ? .easeOut(duration: DesignTokens.Curve.reducedCrossfade)
                   : .spring(response: DesignTokens.Motion.hoverResponse, dampingFraction: DesignTokens.Motion.hoverDamping), value: hot)
        .animation(context.reduceMotion ? .easeOut(duration: DesignTokens.Curve.reducedCrossfade)
                   : .spring(response: 0.22, dampingFraction: 0.82).delay(delay), value: appeared)
        .contentShape(shape)
        .onTapGesture { context.select(seg.id) }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: seg.title))
        .accessibilityAddTraits(hot ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { context.select(seg.id) }
    }

    /// Format names set big, like a record label; tool and action names smaller,
    /// on up to two lines. Black on the band (5:1 or better on every band).
    private func label(_ seg: DemoSegment, hot: Bool) -> some View {
        let isFormat = context.kind == .convert
        let size = isFormat ? T.formatLabel : T.toolLabel
        return Text(verbatim: seg.title.localizedUppercase)
            .font(.anyfmtDisplay(size, black: isFormat))
            .displayTracking(size)
            .multilineTextAlignment(.center)
            .lineLimit(isFormat ? 1 : 2)
            .minimumScaleFactor(0.7)
            .frame(width: T.toolLabelWidth)
            .foregroundStyle(Color(hex: hot ? T.wheelLabelOnBand : T.wheelLabel))
    }

    private var hub: some View {
        let r = DesignTokens.Wheel.hubRadius * DemoModel.scale
        return Image(nsImage: context.thumbnail)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: r * 2 - DesignTokens.Space.s * 2, height: r * 2 - DesignTokens.Space.s * 2)
            .clipShape(Circle())
            .frame(width: r * 2, height: r * 2)
            .background(Circle().fill(Color(hex: DesignTokens.Primitive.ink900)))
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
