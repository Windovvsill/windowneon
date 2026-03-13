import AppKit

class BorderColorPanel: NSPanel {
    private(set) var color1: NSColor
    private(set) var color2: NSColor?

    private let swatch1: ColorSwatchButton
    private let swatch2: ColorSwatchButton
    private let clearButton: NSButton
    private let preview: GradientPreviewStrip

    var onRequestPicker: ((Int) -> Void)?
    var onSave: ((NSColor, NSColor?) -> Void)?
    var onCancel: (() -> Void)?

    init(appName: String, color1: NSColor, color2: NSColor?) {
        self.color1 = color1
        self.color2 = color2
        swatch1 = ColorSwatchButton(color: color1)
        swatch2 = ColorSwatchButton(color: color2)
        clearButton = NSButton(title: "✕", target: nil, action: nil)
        preview = GradientPreviewStrip(frame: .zero)

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 170),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        level = .floating
        title = "Border color — \(appName)"
        isReleasedWhenClosed = false

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 170))
        contentView = container

        let lbl1 = NSTextField(labelWithString: "Color 1")
        lbl1.font = .systemFont(ofSize: 11)
        lbl1.frame = NSRect(x: 24, y: 126, width: 56, height: 16)

        swatch1.frame = NSRect(x: 24, y: 94, width: 52, height: 28)
        swatch1.target = self
        swatch1.action = #selector(tappedSwatch1)

        let lbl2 = NSTextField(labelWithString: "Color 2")
        lbl2.font = .systemFont(ofSize: 11)
        lbl2.frame = NSRect(x: 116, y: 126, width: 56, height: 16)

        swatch2.frame = NSRect(x: 116, y: 94, width: 52, height: 28)
        swatch2.target = self
        swatch2.action = #selector(tappedSwatch2)

        clearButton.frame = NSRect(x: 172, y: 94, width: 26, height: 28)
        clearButton.bezelStyle = .inline
        clearButton.font = .systemFont(ofSize: 10)
        clearButton.isHidden = color2 == nil
        clearButton.target = self
        clearButton.action = #selector(clearSecondColor)

        preview.frame = NSRect(x: 20, y: 58, width: 260, height: 24)
        preview.color1 = color1
        preview.color2 = color2

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(didCancel))
        cancelBtn.bezelStyle = .rounded
        cancelBtn.keyEquivalent = "\u{1B}"
        cancelBtn.frame = NSRect(x: 168, y: 14, width: 56, height: 24)

        let okBtn = NSButton(title: "OK", target: self, action: #selector(didSave))
        okBtn.bezelStyle = .rounded
        okBtn.keyEquivalent = "\r"
        okBtn.frame = NSRect(x: 232, y: 14, width: 48, height: 24)

        [lbl1, swatch1, lbl2, swatch2, clearButton, preview, cancelBtn, okBtn].forEach {
            container.addSubview($0)
        }
    }

    func updateColor(_ color: NSColor, slot: Int) {
        if slot == 1 {
            color1 = color
            swatch1.color = color1
        } else {
            color2 = color
            swatch2.color = color
            clearButton.isHidden = false
        }
        preview.color1 = color1
        preview.color2 = color2
        preview.needsDisplay = true
    }

    @objc private func tappedSwatch1() { onRequestPicker?(1) }
    @objc private func tappedSwatch2() { onRequestPicker?(2) }

    @objc private func clearSecondColor() {
        color2 = nil
        swatch2.color = nil
        clearButton.isHidden = true
        preview.color2 = nil
        preview.needsDisplay = true
    }

    @objc private func didSave() {
        onSave?(color1, color2)
        close()
    }

    @objc private func didCancel() {
        onCancel?()
        close()
    }
}

// MARK: - Color Swatch Button

private class ColorSwatchButton: NSButton {
    var color: NSColor? { didSet { updateImage() } }

    init(color: NSColor?) {
        super.init(frame: .zero)
        self.color = color
        bezelStyle = .regularSquare
        title = ""
        updateImage()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateImage() {
        let size = NSSize(width: 44, height: 22)
        image = NSImage(size: size, flipped: false) { rect in
            if let color = self.color {
                color.setFill()
                NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 3, yRadius: 3).fill()
            } else {
                NSColor.quaternaryLabelColor.setFill()
                NSBezierPath(roundedRect: rect.insetBy(dx: 2, dy: 2), xRadius: 3, yRadius: 3).fill()
                NSColor.secondaryLabelColor.setFill()
                let cx = rect.midX, cy = rect.midY, len: CGFloat = 8, t: CGFloat = 1.5
                NSBezierPath(rect: CGRect(x: cx - len / 2, y: cy - t / 2, width: len, height: t)).fill()
                NSBezierPath(rect: CGRect(x: cx - t / 2, y: cy - len / 2, width: t, height: len)).fill()
            }
            return true
        }
        imageScaling = .scaleAxesIndependently
    }
}

// MARK: - Gradient Preview Strip

private class GradientPreviewStrip: NSView {
    var color1: NSColor = .systemBlue
    var color2: NSColor?

    override func draw(_ dirtyRect: NSRect) {
        let radius: CGFloat = bounds.height / 2
        let width: CGFloat = 5
        let inset = width / 2

        if let c2 = color2 {
            NSGraphicsContext.saveGraphicsState()
            let outer = NSBezierPath(roundedRect: bounds, xRadius: radius + inset, yRadius: radius + inset)
            let inner = NSBezierPath(
                roundedRect: bounds.insetBy(dx: width, dy: width),
                xRadius: max(0, radius - inset), yRadius: max(0, radius - inset)
            )
            outer.append(inner)
            outer.windingRule = .evenOdd
            outer.addClip()
            NSGradient(starting: color1, ending: c2)?.draw(in: bounds, angle: -45)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset), xRadius: radius, yRadius: radius)
            path.lineWidth = width
            color1.setStroke()
            path.stroke()
        }
    }
}
