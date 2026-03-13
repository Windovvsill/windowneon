import AppKit

class HighlightWindow: NSWindow {
    /// Persistent global default (set by the user via the "Border Width" menu).
    static var globalBorderWidth: CGFloat = 3.0
    /// Active width for the currently focused window (may be a per-app override).
    static var borderWidth: CGFloat = 3.0
    static var borderColor: NSColor = .systemBlue
    static var borderColor2: NSColor? = nil
    static var cornerRadius: CGFloat = defaultCornerRadius

    convenience init() {
        self.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        contentView = BorderView()
    }

    func show(frame: CGRect) {
        setFrame(frame, display: true)
        contentView?.needsDisplay = true
        if !isVisible { orderFrontRegardless() }
    }

    func hide() {
        orderOut(nil)
    }

    func redrawBorder() {
        contentView?.needsDisplay = true
    }
}

private class BorderView: NSView {
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
    }
}
