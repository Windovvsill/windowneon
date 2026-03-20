import AppKit

extension AppDelegate {
    @objc func setWidth(_ sender: NSMenuItem) {
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

    @objc func setWidthForCurrentApp(_ sender: NSMenuItem) {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        let width = CGFloat(sender.tag)
        setBorderWidthOverride(width, for: bundleID)
        HighlightWindow.borderWidth = width
        focusWatcher?.redrawBorder()
    }

    @objc func resetWidthForCurrentApp() {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        removeBorderWidthOverride(for: bundleID)
        HighlightWindow.borderWidth = HighlightWindow.globalBorderWidth
        focusWatcher?.redrawBorder()
    }

    @objc func toggleTicks(_ sender: NSMenuItem) {
        HighlightWindow.ticksEnabled.toggle()
        sender.state = HighlightWindow.ticksEnabled ? .on : .off
        UserDefaults.standard.set(HighlightWindow.ticksEnabled, forKey: "ticksEnabled")
        focusWatcher?.redrawBorder()
    }

    @objc func toggleBorderPlacement(_ sender: NSMenuItem) {
        let isNowOutside = HighlightWindow.borderPlacement == .inside
        HighlightWindow.borderPlacement = isNowOutside ? .outside : .inside
        sender.state = isNowOutside ? .on : .off
        UserDefaults.standard.set(isNowOutside, forKey: "borderPlacementOutside")
        focusWatcher?.updateCurrentHighlight()
    }

    @objc func toggleFade(_ sender: NSMenuItem) {
        HighlightWindow.fadeEnabled.toggle()
        sender.state = HighlightWindow.fadeEnabled ? .on : .off
        UserDefaults.standard.set(HighlightWindow.fadeEnabled, forKey: "fadeEnabled")
    }

    @objc func toggleBordersActivated(_ sender: NSMenuItem) {
        toggleBordersActivation()
    }

    func toggleBordersActivation() {
        HighlightWindow.globallyEnabled.toggle()
        UserDefaults.standard.set(HighlightWindow.globallyEnabled, forKey: "globallyEnabled")
        statusItem.menu?.item(withTag: 1006)?.state = HighlightWindow.globallyEnabled ? .on : .off
        if HighlightWindow.globallyEnabled {
            let happy = NSImage(systemSymbolName: "face.smiling.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(paletteColors: [.black, .systemYellow]))
            statusItem.button?.image = happy
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.updateStatusIcon() }
        } else {
            updateStatusIcon()
        }
        focusWatcher?.updateCurrentHighlight()
    }

    @objc func toggleExcludeCurrentApp() {
        guard let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        toggleAppExclusion(bundleID)
        focusWatcher?.updateCurrentHighlight()
    }
}
