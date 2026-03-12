import AppKit
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var focusWatcher: FocusWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadSavedColor()
        loadSavedWidth()
        setupStatusItem()
        requestAccessibilityAndStart()
    }

    private static let widths: [CGFloat] = [1, 2, 3, 4, 6, 8, 10]

    private func loadSavedColor() {
        guard let data = UserDefaults.standard.data(forKey: "borderColor"),
              let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
        else { return }
        HighlightWindow.borderColor = color
    }

    private func loadSavedWidth() {
        let saved = UserDefaults.standard.double(forKey: "borderWidth")
        if saved > 0 { HighlightWindow.borderWidth = saved }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.title = "◻"

        let widthSubmenu = NSMenu()
        for w in Self.widths {
            let item = NSMenuItem(title: "\(Int(w)) pt", action: #selector(setWidth(_:)), keyEquivalent: "")
            item.tag = Int(w)
            item.state = w == HighlightWindow.borderWidth ? .on : .off
            widthSubmenu.addItem(item)
        }
        let widthItem = NSMenuItem(title: "Border Width", action: nil, keyEquivalent: "")
        widthItem.submenu = widthSubmenu

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Border Color…", action: #selector(showColorPicker), keyEquivalent: ""))
        menu.addItem(widthItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Windowneon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func setWidth(_ sender: NSMenuItem) {
        let width = CGFloat(sender.tag)
        HighlightWindow.borderWidth = width
        focusWatcher?.redrawBorder()
        UserDefaults.standard.set(Double(width), forKey: "borderWidth")
        // Update checkmarks
        sender.menu?.items.forEach { $0.state = $0 == sender ? .on : .off }
    }

    @objc private func showColorPicker() {
        let panel = NSColorPanel.shared
        panel.color = HighlightWindow.borderColor
        panel.setTarget(self)
        panel.setAction(#selector(colorDidChange(_:)))
        panel.isContinuous = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func colorDidChange(_ sender: NSColorPanel) {
        HighlightWindow.borderColor = sender.color
        focusWatcher?.redrawBorder()
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: sender.color, requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: "borderColor")
        }
    }

    private func requestAccessibilityAndStart() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            startWatcher()
        } else {
            // Poll until granted — only needed at first launch
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.startWatcher()
                }
            }
        }
    }

    private func startWatcher() {
        focusWatcher = FocusWatcher()
        focusWatcher?.start()
    }
}
