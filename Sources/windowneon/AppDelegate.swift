import AppKit
import ApplicationServices
import ServiceManagement

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var focusWatcher: FocusWatcher?

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadSavedWidth()
        HighlightWindow.ticksEnabled = UserDefaults.standard.object(forKey: "ticksEnabled") as? Bool ?? true
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
        let widthItem = NSMenuItem(title: "Border width", action: nil, keyEquivalent: "")
        widthItem.tag = 1000
        widthItem.submenu = widthSubmenu

        // Per-app border width submenu
        let perAppWidthSubmenu = NSMenu()
        let resetWidthItem = NSMenuItem(title: "Use global default", action: #selector(resetWidthForCurrentApp), keyEquivalent: "")
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

        let launchAtLoginItem = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off

        let radiusItem = NSMenuItem(title: "Set corner radius…", action: #selector(setCornerRadiusForCurrentApp), keyEquivalent: "")
        radiusItem.tag = 1001
        let colorItem = NSMenuItem(title: "Set border color…", action: #selector(setColorForCurrentApp), keyEquivalent: "")
        colorItem.tag = 1002

        let excludeItem = NSMenuItem(title: "Exclude app from border", action: #selector(toggleExcludeCurrentApp), keyEquivalent: "")
        excludeItem.tag = 1004

        let ticksItem = NSMenuItem(title: "Show edge ticks", action: #selector(toggleTicks(_:)), keyEquivalent: "")
        ticksItem.tag = 1005
        ticksItem.state = HighlightWindow.ticksEnabled ? .on : .off

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(widthItem)
        menu.addItem(perAppWidthItem)
        menu.addItem(radiusItem)
        menu.addItem(colorItem)
        menu.addItem(excludeItem)
        menu.addItem(.separator())
        menu.addItem(ticksItem)
        menu.addItem(.separator())
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Export settings…", action: #selector(exportSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Import settings…", action: #selector(importSettings), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Windowneon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))  // proper noun
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

    @objc private func toggleTicks(_ sender: NSMenuItem) {
        HighlightWindow.ticksEnabled.toggle()
        sender.state = HighlightWindow.ticksEnabled ? .on : .off
        UserDefaults.standard.set(HighlightWindow.ticksEnabled, forKey: "ticksEnabled")
        focusWatcher?.redrawBorder()
    }

    @objc private func toggleExcludeCurrentApp() {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        toggleAppExclusion(bundleID)
        focusWatcher?.updateCurrentHighlight()
    }

    func menuWillOpen(_ menu: NSMenu) {
        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "This App"
        let bundleID = app?.bundleIdentifier ?? ""

        menu.item(withTag: 1001)?.title = "Set corner radius for \(appName)…"
        menu.item(withTag: 1002)?.title = "Set border color for \(appName)…"
        menu.item(withTag: 1003)?.title = "Set width for \(appName)…"

        // Exclusion toggle label and state
        let excluded = isAppExcluded(bundleID)
        menu.item(withTag: 1004)?.title = excluded
            ? "Include \(appName) in border"
            : "Exclude \(appName) from border"

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
    private var borderColorPanel: BorderColorPanel?
    private var colorPickerBundleID: String?
    private var colorPickerOriginal: (NSColor, NSColor?)?
    private var colorPickerSlot = 1

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
        colorPickerOriginal = (resolvedColor(for: bundleID), resolvedColor2(for: bundleID))

        borderColorPanel = BorderColorPanel(
            appName: app.localizedName ?? bundleID,
            color1: colorPickerOriginal!.0,
            color2: colorPickerOriginal!.1
        )
        borderColorPanel?.onRequestPicker = { [weak self] slot in
            self?.openColorPicker(slot: slot)
        }
        borderColorPanel?.onSave = { [weak self] color1, color2 in
            guard let bundleID = self?.colorPickerBundleID else { return }
            setAppColor(color1, for: bundleID)
            setAppColor2(color2, for: bundleID)
            HighlightWindow.borderColor = color1
            HighlightWindow.borderColor2 = color2
            self?.focusWatcher?.redrawBorder()
            NSColorPanel.shared.orderOut(nil)
        }
        borderColorPanel?.onCancel = { [weak self] in
            if let orig = self?.colorPickerOriginal {
                HighlightWindow.borderColor = orig.0
                HighlightWindow.borderColor2 = orig.1
                self?.focusWatcher?.redrawBorder()
            }
            NSColorPanel.shared.orderOut(nil)
        }
        borderColorPanel?.makeKeyAndOrderFront(nil)
    }

    private func openColorPicker(slot: Int) {
        colorPickerSlot = slot
        let current = slot == 1
            ? (borderColorPanel?.color1 ?? colorPickerOriginal?.0 ?? .systemBlue)
            : (borderColorPanel?.color2 ?? colorPickerOriginal?.1 ?? .systemBlue)
        let panel = NSColorPanel.shared
        panel.color = current
        panel.setTarget(self)
        panel.setAction(#selector(appColorDidChange(_:)))
        panel.isContinuous = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    @objc private func appColorDidChange(_ sender: NSColorPanel) {
        borderColorPanel?.updateColor(sender.color, slot: colorPickerSlot)
        if colorPickerSlot == 1 {
            HighlightWindow.borderColor = sender.color
        } else {
            HighlightWindow.borderColor2 = sender.color
        }
        focusWatcher?.redrawBorder()
    }

    @objc private func exportSettings() {
        guard let data = try? SettingsPorter.export() else { return }
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "windowneon-settings.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
    }

    @objc private func importSettings() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        do {
            try SettingsPorter.import(from: data)
            // Re-apply settings for the current window
            if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier {
                HighlightWindow.borderColor   = resolvedColor(for: bundleID)
                HighlightWindow.borderColor2  = resolvedColor2(for: bundleID)
                HighlightWindow.cornerRadius  = cornerRadius(for: bundleID)
                HighlightWindow.borderWidth   = effectiveBorderWidth(for: bundleID)
            }
            focusWatcher?.redrawBorder()
        } catch {
            NSAlert(error: error).runModal()
        }
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
