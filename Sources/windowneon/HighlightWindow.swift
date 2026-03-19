import AppKit

class HighlightWindow: NSWindow {
    /// Persistent global default (set by the user via the "Border Width" menu).
    static var globalBorderWidth: CGFloat = 3.0
    /// Active width for the currently focused window (may be a per-app override).
    static var borderWidth: CGFloat = 3.0
    static var borderColor: NSColor = .systemBlue
    static var borderColor2: NSColor? = nil
    static var cornerRadius: CGFloat = defaultCornerRadius
    static var ticksEnabled: Bool = true
    static var globallyEnabled: Bool = true
    static var borderPlacement: BorderPlacement = .inside
    static var fadeEnabled: Bool = false

    enum BorderPlacement { case inside, outside }

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

    private var fadeTimer: Timer?

    func show(frame: CGRect) {
        setFrame(frame, display: true)
        contentView?.needsDisplay = true
        if HighlightWindow.fadeEnabled {
            fadeTimer?.invalidate()
            alphaValue = 0
            if !isVisible { orderFrontRegardless() }
            let start = Date()
            let duration: TimeInterval = 0.4
            fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                let t = min(Date().timeIntervalSince(start) / duration, 1)
                self.alphaValue = CGFloat(t)
                if t >= 1 { timer.invalidate() }
            }
        } else {
            alphaValue = 1
            if !isVisible { orderFrontRegardless() }
        }
    }

    func hide() {
        orderOut(nil)
    }

    func redrawBorder() {
        contentView?.needsDisplay = true
    }
}
