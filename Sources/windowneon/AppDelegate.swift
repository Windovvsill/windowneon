import AppKit
import ApplicationServices
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var focusWatcher: FocusWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadSavedWidth()
        loadSavedDimEnabled()
        setupStatusItem()
        requestAccessibilityAndStart()
    }

    private static let widths: [CGFloat] = [1, 2, 3, 4, 6, 8, 10]

    private func loadSavedWidth() {
        let saved = UserDefaults.standard.double(forKey: "borderWidth")
        if saved > 0 {
            HighlightWindow.globalBorderWidth = saved
            HighlightWindow.borderWidth = saved
        }
    }

    private func loadSavedDimEnabled() {
        HighlightWindow.dimEnabled = UserDefaults.standard.bool(forKey: "dimUnfocused")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let config = NSImage.SymbolConfiguration(paletteColors: [.systemMint, .systemPurple])
        let icon = NSImage(systemSymbolName: "inset.filled.square", accessibilityDescription: "Windowneon")?
            .withSymbolConfiguration(config)
        statusItem.button?.image = icon
        statusItem.button?.imageScaling = .scaleProportionallyDown

        // Global border width submenu
        let widthSubmenu = NSMenu()
        for w in Self.widths {
            let item = NSMenuItem(title: "\(Int(w)) pt", action: #selector(setWidth(_:)), keyEquivalent: "")
            item.tag = Int(w)
            item.state = w == HighlightWindow.globalBorderWidth ? .on : .off
            widthSubmenu.addItem(item)
        }
        let widthItem = NSMenuItem(title: "Border Width", action: nil, keyEquivalent: "")
        widthItem.tag = 1000
        widthItem.submenu = widthSubmenu

        // Per-app border width submenu
        let perAppWidthSubmenu = NSMenu()
        let resetWidthItem = NSMenuItem(title: "Use Global Default", action: #selector(resetWidthForCurrentApp), keyEquivalent: "")
        resetWidthItem.tag = 0
        perAppWidthSubmenu.addItem(resetWidthItem)
        perAppWidthSubmenu.addItem(.separator())
        for w in Self.widths {
            let item = NSMenuItem(title: "\(Int(w)) pt", action: #selector(setWidthForCurrentApp(_:)), keyEquivalent: "")
            item.tag = Int(w)
            perAppWidthSubmenu.addItem(item)
        }
        let perAppWidthItem = NSMenuItem(title: "Set Width for App…", action: nil, keyEquivalent: "")
        perAppWidthItem.tag = 1003
        perAppWidthItem.submenu = perAppWidthSubmenu

        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off

        let radiusItem = NSMenuItem(title: "Set Corner Radius…", action: #selector(setCornerRadiusForCurrentApp), keyEquivalent: "")
        radiusItem.tag = 1001
        let colorItem = NSMenuItem(title: "Set Border Color…", action: #selector(setColorForCurrentApp), keyEquivalent: "")
        colorItem.tag = 1002

        let excludeItem = NSMenuItem(title: "Exclude App from Border", action: #selector(toggleExcludeCurrentApp), keyEquivalent: "")
        excludeItem.tag = 1004

        let dimItem = NSMenuItem(title: "Dim Unfocused Windows", action: #selector(toggleDimUnfocused(_:)), keyEquivalent: "")
        dimItem.tag = 1005
        dimItem.state = HighlightWindow.dimEnabled ? .on : .off

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(widthItem)
        menu.addItem(perAppWidthItem)
        menu.addItem(radiusItem)
        menu.addItem(colorItem)
        menu.addItem(excludeItem)
        menu.addItem(.separator())
        menu.addItem(dimItem)
        menu.addItem(.separator())
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Windowneon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    @objc private func setWidth(_ sender: NSMenuItem) {
        let width = CGFloat(sender.tag)
        HighlightWindow.globalBorderWidth = width
        // Only update the active width if the current app has no per-app override.
        let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
        let overrides = UserDefaults.standard.dictionary(forKey: "borderWidthOverrides") as? [String: Double] ?? [:]
        if overrides[bundleID] == nil {
            HighlightWindow.borderWidth = width
            focusWatcher?.redrawBorder()
        }
        UserDefaults.standard.set(Double(width), forKey: "borderWidth")
        sender.menu?.items.forEach { $0.state = $0 == sender ? .on : .off }
    }

    @objc private func setWidthForCurrentApp(_ sender: NSMenuItem) {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        let width = CGFloat(sender.tag)
        setBorderWidthOverride(width, for: bundleID)
        HighlightWindow.borderWidth = width
        focusWatcher?.redrawBorder()
    }

    @objc private func resetWidthForCurrentApp() {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        removeBorderWidthOverride(for: bundleID)
        HighlightWindow.borderWidth = HighlightWindow.globalBorderWidth
        focusWatcher?.redrawBorder()
    }

    @objc private func toggleExcludeCurrentApp() {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        toggleAppExclusion(bundleID)
        focusWatcher?.updateCurrentHighlight()
    }

    @objc private func toggleDimUnfocused(_ sender: NSMenuItem) {
        HighlightWindow.dimEnabled.toggle()
        sender.state = HighlightWindow.dimEnabled ? .on : .off
        UserDefaults.standard.set(HighlightWindow.dimEnabled, forKey: "dimUnfocused")
        if !HighlightWindow.dimEnabled {
            focusWatcher?.hideDimHighlight()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "This App"
        let bundleID = app?.bundleIdentifier ?? ""

        menu.item(withTag: 1001)?.title = "Set Corner Radius for \(appName)…"
        menu.item(withTag: 1002)?.title = "Set Border Color for \(appName)…"
        menu.item(withTag: 1003)?.title = "Set Width for \(appName)…"

        // Exclusion toggle label and state
        let excluded = isAppExcluded(bundleID)
        menu.item(withTag: 1004)?.title = excluded
            ? "Include \(appName) in Border"
            : "Exclude \(appName) from Border"

        // Per-app width submenu checkmarks
        if let submenu = menu.item(withTag: 1003)?.submenu {
            let overrides = UserDefaults.standard.dictionary(forKey: "borderWidthOverrides") as? [String: Double] ?? [:]
            let currentOverride = overrides[bundleID]
            for item in submenu.items {
                guard item.tag != 0 else {
                    item.state = currentOverride == nil ? .on : .off
                    continue
                }
                item.state = currentOverride.map { CGFloat($0) } == CGFloat(item.tag) ? .on : .off
            }
        }

        // Global width submenu checkmarks
        if let submenu = menu.item(withTag: 1000)?.submenu {
            for item in submenu.items {
                item.state = CGFloat(item.tag) == HighlightWindow.globalBorderWidth ? .on : .off
            }
        }
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
