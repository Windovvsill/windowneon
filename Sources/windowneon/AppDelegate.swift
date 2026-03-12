import AppKit
import ApplicationServices
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var focusWatcher: FocusWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadSavedWidth()
        setupStatusItem()
        requestAccessibilityAndStart()
    }

    private static let widths: [CGFloat] = [1, 2, 3, 4, 6, 8, 10]

    private func loadSavedWidth() {
        let saved = UserDefaults.standard.double(forKey: "borderWidth")
        if saved > 0 { HighlightWindow.borderWidth = saved }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let config = NSImage.SymbolConfiguration(paletteColors: [.systemMint, .systemPurple])
        let icon = NSImage(systemSymbolName: "inset.filled.square", accessibilityDescription: "Windowneon")?
            .withSymbolConfiguration(config)
        statusItem.button?.image = icon
        statusItem.button?.imageScaling = .scaleProportionallyDown

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
        radiusItem.tag = 1001
        let colorItem = NSMenuItem(title: "Set Border Color…", action: #selector(setColorForCurrentApp), keyEquivalent: "")
        colorItem.tag = 1002

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(widthItem)
        menu.addItem(radiusItem)
        menu.addItem(colorItem)
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
        menu.item(withTag: 1001)?.title = "Set Corner Radius for \(appName)…"
        menu.item(withTag: 1002)?.title = "Set Border Color for \(appName)…"
    }

    private var radiusPanel: CornerRadiusPanel?
    private var colorPickerBundleID: String?
    private var colorPickerOriginal: NSColor?

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

    @objc private func setColorForCurrentApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else { return }

        colorPickerBundleID = bundleID
        colorPickerOriginal = resolvedColor(for: bundleID)

        let panel = NSColorPanel.shared
        panel.color = colorPickerOriginal!
        panel.setTarget(self)
        panel.setAction(#selector(appColorDidChange(_:)))
        panel.isContinuous = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func appColorDidChange(_ sender: NSColorPanel) {
        guard let bundleID = colorPickerBundleID else { return }
        HighlightWindow.borderColor = sender.color
        focusWatcher?.redrawBorder()
        setAppColor(sender.color, for: bundleID)
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
