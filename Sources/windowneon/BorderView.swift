import AppKit

class BorderView: NSView {
    /// Set false for auxiliary borders (e.g. around the status menu) that
    /// shouldn't inherit the focused window's tick marks.
    var ticksAllowed = true
    /// Overrides the per-app corner radius for auxiliary borders.
    var radiusOverride: CGFloat?

    private let renderer = BorderStyleRenderer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        layer = CALayer()
        wantsLayer = true
        renderer.attach(to: layer!)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        refresh()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        refresh()
    }

    func refresh() {
        guard let layer else { return }
        let style = HighlightWindow.style
        let radius = radiusOverride ?? HighlightWindow.cornerRadius
        let width = HighlightWindow.borderWidth
        let inset = width / 2

        let path = CGMutablePath()
        let ringRect = bounds.insetBy(dx: inset, dy: inset)
        guard ringRect.width > 0, ringRect.height > 0 else { return }
        let r = min(radius, ringRect.width / 2, ringRect.height / 2)
        path.addRoundedRect(in: ringRect, cornerWidth: r, cornerHeight: r)
        if HighlightWindow.ticksEnabled && ticksAllowed { addTicks(to: path, width: width, inset: inset) }

        renderer.render(
            style: style,
            path: path,
            lineWidth: width,
            bounds: bounds,
            scale: window?.backingScaleFactor ?? 2
        )
        layer.isHidden = false
    }

    // Ticks are part of the mask path, so they pick up the gradient (and any
    // dash/motion effect) exactly like the ring does.
    private func addTicks(to path: CGMutablePath, width: CGFloat, inset: CGFloat) {
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
            path.move(to: start)
            path.addLine(to: end)
        }
    }
}
