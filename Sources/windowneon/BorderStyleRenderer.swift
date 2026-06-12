import AppKit

/// Core Animation renderer shared by the real border (BorderView) and the
/// preview strip in the customization panel.
///
/// Layer tree:
///   host (glow shadow, pulse opacity)
///    └─ masked (mask = shape: the stroked ring + ticks, dash pattern, march)
///        └─ gradient (axial when static, conic + rotation when spinning)
///
/// The glow shadow lives on `host` rather than `masked` because a layer's own
/// mask clips its shadow; a superlayer's shadow is built from the already
/// masked composite, so the halo follows the ring shape.
final class BorderStyleRenderer {
    private let host = CALayer()
    private let masked = CALayer()
    private let gradient = CAGradientLayer()
    private let shape = CAShapeLayer()
    private var appliedStyle: BorderStyle?

    init() {
        host.masksToBounds = false
        masked.masksToBounds = false
        masked.mask = shape
        shape.fillColor = nil
        shape.strokeColor = NSColor.white.cgColor
        shape.lineCap = .round
        masked.addSublayer(gradient)
        host.addSublayer(masked)
    }

    func attach(to parent: CALayer) {
        parent.addSublayer(host)
    }

    func render(style: BorderStyle, path: CGPath, lineWidth: CGFloat, bounds: CGRect, scale: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for layer in [host, masked, gradient, shape] as [CALayer] { layer.contentsScale = scale }
        host.frame = bounds
        masked.frame = host.bounds
        shape.frame = masked.bounds

        shape.path = path
        shape.lineWidth = lineWidth
        switch style.stroke {
        case .solid:
            shape.lineDashPattern = nil
        case .dashed:
            shape.lineDashPattern = [NSNumber(value: lineWidth * 3), NSNumber(value: lineWidth * 1.5)]
        case .dotted:
            shape.lineDashPattern = [NSNumber(value: 0.001), NSNumber(value: lineWidth * 2)]
        }

        let cgColors = style.colors.map { $0.cgColor }
        if style.motion == .spin {
            gradient.type = .conic
            gradient.startPoint = CGPoint(x: 0.5, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
            // A single spinning color becomes a comet: transparent tail sweeping
            // into the full color. Multiple colors wrap around seamlessly.
            gradient.colors = cgColors.count == 1
                ? [style.primaryColor.withAlphaComponent(0).cgColor, cgColors[0]]
                : cgColors + [cgColors[0]]
            // Square covering the bounds diagonal so rotation never exposes corners.
            // bounds/position rather than frame: frame is undefined under the
            // rotation animation's transform.
            let diagonal = (bounds.width * bounds.width + bounds.height * bounds.height).squareRoot()
            gradient.bounds = CGRect(x: 0, y: 0, width: diagonal, height: diagonal)
        } else {
            gradient.type = .axial
            gradient.startPoint = CGPoint(x: 0, y: 1)  // top-left
            gradient.endPoint = CGPoint(x: 1, y: 0)    // bottom-right
            gradient.colors = cgColors.count == 1 ? [cgColors[0], cgColors[0]] : cgColors
            gradient.bounds = CGRect(origin: .zero, size: bounds.size)
        }
        gradient.position = CGPoint(x: host.bounds.midX, y: host.bounds.midY)

        if style.glow {
            host.shadowColor = style.primaryColor.cgColor
            host.shadowOpacity = 0.9
            host.shadowRadius = max(8, lineWidth * 2.5)
            host.shadowOffset = .zero
        } else {
            host.shadowOpacity = 0
        }

        if appliedStyle != style || animationsMissing(for: style) {
            applyAnimations(for: style)
            appliedStyle = style
        }
        CATransaction.commit()
    }

    private func animationsMissing(for style: BorderStyle) -> Bool {
        switch style.motion {
        case .none: return false
        case .pulse: return host.animation(forKey: "pulse") == nil
        case .spin: return gradient.animation(forKey: "spin") == nil
        case .march: return shape.lineDashPattern != nil && shape.animation(forKey: "march") == nil
        }
    }

    private func applyAnimations(for style: BorderStyle) {
        host.removeAnimation(forKey: "pulse")
        gradient.removeAnimation(forKey: "spin")
        shape.removeAnimation(forKey: "march")

        switch style.motion {
        case .none:
            break
        case .pulse:
            let anim = CABasicAnimation(keyPath: "opacity")
            anim.fromValue = 1.0
            anim.toValue = 0.35
            anim.duration = 0.62 / style.speed
            anim.autoreverses = true
            anim.repeatCount = .infinity
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            host.add(anim, forKey: "pulse")
        case .spin:
            let anim = CABasicAnimation(keyPath: "transform.rotation.z")
            anim.fromValue = 0.0
            anim.toValue = -2 * Double.pi
            anim.duration = 4.0 / style.speed
            anim.repeatCount = .infinity
            gradient.add(anim, forKey: "spin")
        case .march:
            guard let pattern = shape.lineDashPattern else { break }
            let period = pattern.reduce(0.0) { $0 + $1.doubleValue }
            let anim = CABasicAnimation(keyPath: "lineDashPhase")
            anim.fromValue = 0.0
            anim.toValue = -period
            anim.duration = 0.55 / style.speed
            anim.repeatCount = .infinity
            shape.add(anim, forKey: "march")
        }
    }
}
