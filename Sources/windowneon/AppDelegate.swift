import AppKit
import ApplicationServices
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
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

        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off

        let radiusItem = NSMenuItem(title: "Set Corner Radius…", action: #selector(setCornerRadiusForCurrentApp), keyEquivalent: "")

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(NSMenuItem(title: "Border Color…", action: #selector(showColorPicker), keyEquivalent: ""))
        menu.addItem(widthItem)
        menu.addItem(radiusItem)
        menu.addItem(.separator())
        menu.addItem(launchAtLoginItem)
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

    func menuWillOpen(_ menu: NSMenu) {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "This App"
        menu.item(withTitle: "Set Corner Radius…")?.title = "Set Corner Radius for \(appName)…"
    }

    private var radiusPanel: CornerRadiusPanel?

    @objc private func setCornerRadiusForCurrentApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else { return }

        let current = cornerRadius(for: bundleID)

        radiusPanel = CornerRadiusPanel(
            appName: app.localizedName ?? bundleID,
            bundleID: bundleID,
            currentRadius: current,
            onUpdate: { [weak self] _ in
                self?.focusWatcher?.redrawBorder()
            },
            onSave: { [weak self] radius in
                setCornerRadius(radius, for: bundleID)
                HighlightWindow.cornerRadius = radius
                self?.focusWatcher?.redrawBorder()
            },
            onCancel: { [weak self] in
                HighlightWindow.cornerRadius = current
                self?.focusWatcher?.redrawBorder()
            }
        )
        radiusPanel?.makeKeyAndOrderFront(nil)
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
                sender.state = .off
            } else {
                try SMAppService.mainApp.register()
                sender.state = .on
            }
        } catch {
            NSAlert(error: error).runModal()
        }
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
