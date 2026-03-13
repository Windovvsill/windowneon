import AppKit

class CornerRadiusPanel: NSPanel, NSWindowDelegate {
    private let field = NSTextField()
    private let slider = NSSlider()
    private let originalRadius: CGFloat
    private let bundleID: String
    private let appName: String
    private var onUpdate: (CGFloat) -> Void
    private var onSave: (CGFloat) -> Void
    private var onCancel: () -> Void

    init(appName: String, bundleID: String, currentRadius: CGFloat, onUpdate: @escaping (CGFloat) -> Void, onSave: @escaping (CGFloat) -> Void, onCancel: @escaping () -> Void) {
        self.appName = appName
        self.bundleID = bundleID
        self.originalRadius = currentRadius
        self.onUpdate = onUpdate
        self.onSave = onSave
        self.onCancel = onCancel

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        title = "Corner radius – \(appName)"
        level = .floating
        isReleasedWhenClosed = false
        delegate = self
        isMovableByWindowBackground = true

        buildUI(currentRadius: currentRadius)
        center()
    }

    private func buildUI(currentRadius: CGFloat) {
        let content = contentView!

        slider.minValue = 0
        slider.maxValue = 40
        slider.doubleValue = Double(currentRadius)
        slider.frame = NSRect(x: 20, y: 55, width: 200, height: 20)
        slider.target = self
        slider.action = #selector(sliderChanged)
        slider.isContinuous = true
        content.addSubview(slider)

        field.frame = NSRect(x: 228, y: 52, width: 52, height: 24)
        field.stringValue = formatted(currentRadius)
        field.alignment = .right
        field.delegate = self
        content.addSubview(field)

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelTapped))
        cancel.frame = NSRect(x: 120, y: 16, width: 80, height: 28)
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        content.addSubview(cancel)

        let save = NSButton(title: "Save", target: self, action: #selector(saveTapped))
        save.frame = NSRect(x: 208, y: 16, width: 72, height: 28)
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        content.addSubview(save)
    }

    private func formatted(_ value: CGFloat) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(value))" : String(format: "%.1f", value)
    }

    @objc private func sliderChanged() {
        let r = CGFloat(slider.doubleValue)
        field.stringValue = formatted(r)
        HighlightWindow.cornerRadius = r
        onUpdate(r)
    }

    @objc private func saveTapped() {
        onSave(CGFloat(slider.doubleValue))
        close()
    }

    @objc private func cancelTapped() {
        onCancel()
        close()
    }

    func windowWillClose(_ notification: Notification) {
        // Closed via the red X — treat as cancel
        onCancel()
    }
}

extension CornerRadiusPanel: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let value = Double(field.stringValue) else { return }
        let r = CGFloat(max(0, min(40, value)))
        slider.doubleValue = Double(r)
        HighlightWindow.cornerRadius = r
        onUpdate(r)
    }
}
