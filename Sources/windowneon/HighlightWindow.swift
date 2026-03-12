import AppKit

class HighlightWindow: NSWindow {
    static var borderWidth: CGFloat = 3.0
    static var borderColor: NSColor = .systemBlue
    static var cornerRadius: CGFloat = defaultCornerRadius

    convenience init() {
        self.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        level = .floating             // above normal windows, below system UI
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
        let inset = HighlightWindow.borderWidth / 2
        let radius = HighlightWindow.cornerRadius
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: radius, yRadius: radius)
        path.lineWidth = HighlightWindow.borderWidth
        HighlightWindow.borderColor.setStroke()
        path.stroke()
    }
}
