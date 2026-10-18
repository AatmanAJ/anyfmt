import QuartzCore

/// Small Core Animation helpers. Model values are always set with implicit
/// actions disabled, then an explicit animation runs from the current
/// on-screen (presentation) value, so interrupted animations never jump.
@MainActor
enum LayerAnimation {
    /// Expo-out: fast start, gentle settle. Used for open and morphs.
    static let easeOut = CAMediaTimingFunction(controlPoints: 0.16, 1, 0.3, 1)
    static let easeInOut = CAMediaTimingFunction(controlPoints: 0.45, 0, 0.25, 1)
    static let easeIn = CAMediaTimingFunction(controlPoints: 0.5, 0, 0.9, 0.6)

    static func withoutActions(_ body: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        body()
        CATransaction.commit()
    }

    static func spring(_ config: RadialMenuConfiguration) -> CASpringAnimation {
        let a = CASpringAnimation()
        a.mass = 1
        a.stiffness = config.springStiffness
        a.damping = config.springDampingCoefficient
        a.initialVelocity = 0
        a.duration = a.settlingDuration
        return a
    }

    static func basic(_ duration: CFTimeInterval, _ timing: CAMediaTimingFunction = easeOut) -> CABasicAnimation {
        let a = CABasicAnimation()
        a.duration = duration
        a.timingFunction = timing
        return a
    }
}

@MainActor
extension CALayer {
    /// Sets `keyPath` to `value` and animates there from what's on screen now.
    /// `animation == nil` sets the value instantly and cancels any running animation.
    func set(_ keyPath: String, to value: Any?, animation: CABasicAnimation?, delay: CFTimeInterval = 0) {
        let from = (presentation() ?? self).value(forKeyPath: keyPath)
        LayerAnimation.withoutActions { setValue(value, forKeyPath: keyPath) }
        guard let animation else {
            removeAnimation(forKey: keyPath)
            return
        }
        let a = animation.copy() as? CABasicAnimation ?? animation
        a.keyPath = keyPath
        a.fromValue = from
        a.toValue = value
        if delay > 0 {
            a.beginTime = convertTime(CACurrentMediaTime(), from: nil) + delay
            a.fillMode = .backwards
        }
        add(a, forKey: keyPath)
    }

    /// Animates `keyPath` from `from` to the current model value (used for entrances).
    func animate(_ keyPath: String, from: Any?, animation: CABasicAnimation, delay: CFTimeInterval = 0) {
        let a = animation.copy() as? CABasicAnimation ?? animation
        a.keyPath = keyPath
        a.fromValue = from
        a.toValue = value(forKeyPath: keyPath)
        if delay > 0 {
            a.beginTime = convertTime(CACurrentMediaTime(), from: nil) + delay
            a.fillMode = .backwards
        }
        add(a, forKey: keyPath)
    }
}

extension CATransform3D {
    static func scale(_ s: CGFloat, about point: CGPoint, in bounds: CGRect) -> CATransform3D {
        // Layers here are sized to the canvas with a centred anchor, so translate
        // relative to the bounds centre.
        let dx = point.x - bounds.midX, dy = point.y - bounds.midY
        var t = CATransform3DMakeTranslation(dx, dy, 0)
        t = CATransform3DScale(t, s, s, 1)
        return CATransform3DTranslate(t, -dx, -dy, 0)
    }
}
