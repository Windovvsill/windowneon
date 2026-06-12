import AppKit

class BorderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let color = HighlightWindow.borderColor
        let radius = HighlightWindow.cornerRadius
        let width = HighlightWindow.borderWidth
        let inset = width / 2

        if let color2 = HighlightWindow.borderColor2 {
            NSGraphicsContext.saveGraphicsState()
            let outer = NSBezierPath(roundedRect: bounds, xRadius: radius + inset, yRadius: radius + inset)
            let inner = NSBezierPath(
                roundedRect: bounds.insetBy(dx: width, dy: width),
                xRadius: max(0, radius - inset), yRadius: max(0, radius - inset)
            )
            outer.append(inner)
            outer.windingRule = .evenOdd
            outer.addClip()
            NSGradient(starting: color, ending: color2)?.draw(in: bounds, angle: -45)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: radius, yRadius: radius)
            path.lineWidth = width
            color.setStroke()
            path.stroke()
        }

        if HighlightWindow.ticksEnabled { drawTicks(color: color, color2: HighlightWindow.borderColor2, width: width, inset: inset) }
    }

    // Returns the interpolated gradient color at a point for a -45° gradient (top-left=color1, bottom-right=color2).
    // t = (x - y + height) / (width + height) projects the point onto the gradient axis.
    private func gradientColor(at point: CGPoint, from color1: NSColor, to color2: NSColor) -> NSColor? {
        let range = bounds.width + bounds.height
        guard range > 0 else { return color1 }
        let t = max(0, min(1, (point.x - point.y + bounds.height) / range))
        return color1.blended(withFraction: t, of: color2)
    }

    private func drawTicks(color: NSColor, color2: NSColor?, width: CGFloat, inset: CGFloat) {
        guard let windowFrame = self.window?.frame else { return }

        let threshold: CGFloat = 2
        var showTop    = bounds.height >= 120
        var showBottom = bounds.height >= 120
        var showLeft   = bounds.width  >= 120
        var showRight  = bounds.width  >= 120
        for screen in NSScreen.screens {
            let sf = screen.frame
            if abs(windowFrame.maxY - sf.maxY) < threshold { showTop = false }
            if abs(windowFrame.maxY - screen.visibleFrame.maxY) < threshold { showTop = false }
            if abs(windowFrame.minY - sf.minY) < threshold { showBottom = false }
            if abs(windowFrame.minX - sf.minX) < threshold { showLeft = false }
            if abs(windowFrame.maxX - sf.maxX) < threshold { showRight = false }
        }

        let tickLength = width + 8
        let cx = bounds.midX, cy = bounds.midY

        let candidates: [(Bool, CGPoint, CGPoint)] = [
            (showTop,    CGPoint(x: cx, y: bounds.maxY - inset), CGPoint(x: cx, y: bounds.maxY - inset - tickLength)),
            (showBottom, CGPoint(x: cx, y: bounds.minY + inset), CGPoint(x: cx, y: bounds.minY + inset + tickLength)),
            (showLeft,   CGPoint(x: bounds.minX + inset, y: cy), CGPoint(x: bounds.minX + inset + tickLength, y: cy)),
            (showRight,  CGPoint(x: bounds.maxX - inset, y: cy), CGPoint(x: bounds.maxX - inset - tickLength, y: cy)),
        ]

        for (show, start, end) in candidates where show {
            let tickColor = color2.flatMap { gradientColor(at: start, from: color, to: $0) } ?? color
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = width
            path.lineCapStyle = .round
            tickColor.setStroke()
            path.stroke()
        }
    }
}
