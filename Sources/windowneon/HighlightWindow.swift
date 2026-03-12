import AppKit

class HighlightWindow: NSWindow {
    /// Persistent global default (set by the user via the "Border Width" menu).
    static var globalBorderWidth: CGFloat = 3.0
    /// Active width for the currently focused window (may be a per-app override).
    static var borderWidth: CGFloat = 3.0
    static var borderColor: NSColor = .systemBlue
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
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: radius, yRadius: radius)
        path.lineWidth = width
        color.setStroke()
        path.stroke()
    }
}
