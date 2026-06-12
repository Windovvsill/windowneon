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

        let launchAtLoginItem = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off

        let colorItem = NSMenuItem(title: "Customize border…", action: #selector(customizeBorderForCurrentApp), keyEquivalent: "")
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
        menu.item(withTag: 1002)?.title = "Customize border for \(appName)…"

        // Exclusion toggle label and state
        let excluded = isAppExcluded(bundleID)
        menu.item(withTag: 1004)?.title = excluded
            ? "Include \(appName) in border"
            : "Exclude \(appName) from border"

        // Global width submenu checkmarks
        if let submenu = menu.item(withTag: 1000)?.submenu {
            for item in submenu.items {
                item.state = CGFloat(item.tag) == HighlightWindow.globalBorderWidth ? .on : .off
            }
        }

        statusMenuIsOpen = true
        if HighlightWindow.globallyEnabled { locateMenuWindow(attempt: 0) }
    }

    func menuDidClose(_ menu: NSMenu) {
        statusMenuIsOpen = false
        menuBorderWindow?.orderOut(nil)
    }

    // MARK: - The menu deserves a border too

    /// NSMenu windows are system-drawn and don't exist yet in menuWillOpen,
    /// so poll briefly for the real menu window and wrap its exact frame.
    /// (Estimating from menu.size doesn't work — it counts hidden items.)
    private func locateMenuWindow(attempt: Int) {
        guard attempt < 10 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + (attempt == 0 ? 0.03 : 0.05)) { [weak self] in
            guard let self, self.statusMenuIsOpen else { return }
            if let menuRect = self.onScreenMenuWindowRect() {
                self.showMenuBorder(around: menuRect)
            } else {
                self.locateMenuWindow(attempt: attempt + 1)
            }
        }
    }

    /// Finds our process's menu window on screen and returns its frame in
    /// AppKit screen coordinates.
    private func onScreenMenuWindowRect() -> CGRect? {
        guard let infos = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let myPID = ProcessInfo.processInfo.processIdentifier
        let popUpLevel = Int(CGWindowLevelForKey(.popUpMenuWindow))
        let borderWindowNumber = menuBorderWindow?.windowNumber

        for info in infos {
            guard let pid = info[kCGWindowOwnerPID as String] as? Int32, pid == myPID,
                  let layer = info[kCGWindowLayer as String] as? Int, layer == popUpLevel,
                  let number = info[kCGWindowNumber as String] as? Int, number != borderWindowNumber,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let cgRect = CGRect(dictionaryRepresentation: boundsDict),
                  cgRect.width > 50, cgRect.height > 50
            else { continue }
            // CGWindow bounds are top-left based; AppKit is bottom-left based.
            let primaryHeight = NSScreen.screens.first?.frame.maxY ?? 0
            return CGRect(
                x: cgRect.minX,
                y: primaryHeight - cgRect.maxY,
                width: cgRect.width,
                height: cgRect.height
            )
        }
        return nil
    }

    private func showMenuBorder(around menuRect: CGRect) {
        let pad = HighlightWindow.borderWidth + 2
        let window = menuBorderWindow ?? makeMenuBorderWindow()
        window.setFrame(menuRect.insetBy(dx: -pad, dy: -pad), display: true)
        (window.contentView as? BorderView)?.refresh()
        window.orderFrontRegardless()
    }

    private func makeMenuBorderWindow() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isReleasedWhenClosed = false
        let view = BorderView()
        view.ticksAllowed = false
        view.radiusOverride = 16 // tracks the menu's own curvature plus the gap
        window.contentView = view
        menuBorderWindow = window
        return window
    }
}
