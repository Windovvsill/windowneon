import AppKit

class HotkeyPanel: NSPanel {
    var onSave: ((UInt16, NSEvent.ModifierFlags, String) -> Void)?
    var onDisable: (() -> Void)?

    private let shortcutLabel: NSTextField
    private var recordMonitor: Any?

    init(currentDisplay: String) {
        shortcutLabel = NSTextField(labelWithString: currentDisplay.isEmpty ? "None" : currentDisplay)
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 115),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        title = "Toggle borders hotkey"
        isFloatingPanel = true
        hidesOnDeactivate = false
        buildUI()
    }

    private func buildUI() {
        let instruction = NSTextField(labelWithString: "Click Record, then press your shortcut")
        instruction.font = .systemFont(ofSize: 12)
        instruction.textColor = .secondaryLabelColor
        instruction.alignment = .center

        shortcutLabel.font = .monospacedSystemFont(ofSize: 15, weight: .medium)
        shortcutLabel.alignment = .center

        let recordButton = NSButton(title: "Record", target: self, action: #selector(startRecording))
        let disableButton = NSButton(title: "Disable", target: self, action: #selector(disableHotkey))

        let buttonRow = NSStackView(views: [disableButton, recordButton])
        buttonRow.spacing = 8
        buttonRow.distribution = .fillEqually

        let stack = NSStackView(views: [instruction, shortcutLabel, buttonRow])
        stack.orientation = .vertical
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView?.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView!.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView!.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView!.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView!.bottomAnchor),
        ])
    }

    @objc private func startRecording() {
        shortcutLabel.stringValue = "Press shortcut…"
        NSApp.activate(ignoringOtherApps: true)
        makeKeyAndOrderFront(nil)
        recordMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
            return nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.keyCode == 53 { // Escape
            shortcutLabel.stringValue = "Cancelled"
            stopRecording()
            return
        }
        guard !mods.isEmpty else { return }
        let char = event.charactersIgnoringModifiers?.uppercased() ?? "?"
        let display = modifierSymbols(mods) + char
        shortcutLabel.stringValue = display
        stopRecording()
        onSave?(event.keyCode, mods, display)
        close()
    }

    private func stopRecording() {
        if let m = recordMonitor { NSEvent.removeMonitor(m); recordMonitor = nil }
    }

    @objc private func disableHotkey() {
        stopRecording()
        onDisable?()
        close()
    }

    private func modifierSymbols(_ mods: NSEvent.ModifierFlags) -> String {
        var s = ""
        if mods.contains(.control) { s += "⌃" }
        if mods.contains(.option)  { s += "⌥" }
        if mods.contains(.shift)   { s += "⇧" }
        if mods.contains(.command) { s += "⌘" }
        return s
    }

    override func close() {
        stopRecording()
        super.close()
    }
}
