import AppKit
import ServiceManagement
import Sparkle

extension AppDelegate {
    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.imageScaling = .scaleProportionallyDown
        updateStatusIcon()

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

        let activatedItem = NSMenuItem(title: "Activate borders", action: #selector(toggleBordersActivated(_:)), keyEquivalent: "")
        activatedItem.tag = 1006
        activatedItem.state = HighlightWindow.globallyEnabled ? .on : .off

        let hotkeyItem = NSMenuItem(title: "Set hotkey…", action: #selector(openHotkeyPanel), keyEquivalent: "")
        hotkeyItem.tag = 1009

        let ticksItem = NSMenuItem(title: "Show edge ticks", action: #selector(toggleTicks(_:)), keyEquivalent: "")
        ticksItem.tag = 1005
        ticksItem.state = HighlightWindow.ticksEnabled ? .on : .off

        let placementItem = NSMenuItem(title: "Draw border outside window", action: #selector(toggleBorderPlacement(_:)), keyEquivalent: "")
        placementItem.tag = 1007
        placementItem.state = HighlightWindow.borderPlacement == .outside ? .on : .off

        let fadeItem = NSMenuItem(title: "Fade in on focus", action: #selector(toggleFade(_:)), keyEquivalent: "")
        fadeItem.tag = 1008
        fadeItem.state = HighlightWindow.fadeEnabled ? .on : .off

        let accessibilityWarningItem = NSMenuItem(
            title: "⚠ Accessibility permission required",
            action: #selector(openAccessibilitySettings),
            keyEquivalent: ""
        )
        accessibilityWarningItem.tag = 9999
        accessibilityWarningItem.isHidden = true

        let menu = NSMenu()
        menu.delegate = self
        let accessibilityWarningSeparator = NSMenuItem.separator()
        accessibilityWarningSeparator.tag = 9998
        accessibilityWarningSeparator.isHidden = true

        menu.addItem(accessibilityWarningItem)
        menu.addItem(accessibilityWarningSeparator)
        menu.addItem(widthItem)
        menu.addItem(perAppWidthItem)
        menu.addItem(radiusItem)
        menu.addItem(colorItem)
        menu.addItem(excludeItem)
        menu.addItem(.separator())
        menu.addItem(activatedItem)
        menu.addItem(hotkeyItem)
        menu.addItem(ticksItem)
        menu.addItem(placementItem)
        menu.addItem(fadeItem)
        menu.addItem(.separator())
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Export settings…", action: #selector(exportSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Import settings…", action: #selector(importSettings), keyEquivalent: ""))
        menu.addItem(.separator())
        let updateItem = NSMenuItem(title: "Check for updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Windowneon", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))  // proper noun
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "This App"
        let bundleID = app?.bundleIdentifier ?? ""

        let shortcut = hotkeyKeyCode == UInt16.max ? "disabled" : hotkeyDisplay
        menu.item(withTag: 1006)?.title = "Activate borders  \(shortcut)"
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
}
