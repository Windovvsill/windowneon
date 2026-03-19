import AppKit
import ServiceManagement

extension AppDelegate {
    @objc func exportSettings() {
        guard let data = try? SettingsPorter.export() else { return }
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "windowneon-settings.json"
        panel.allowedContentTypes = [.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
    }

    @objc func importSettings() {
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
            updateStatusIcon()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc func toggleLaunchAtLogin(_ sender: NSMenuItem) {
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

    @objc func accessibilityChanged() {
        // The notification fires before AXIsProcessTrusted() reflects the new
        // state, so wait briefly then evaluate the actual state.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.applyAccessibilityState()
        }
    }

    func applyAccessibilityState() {
        if AXIsProcessTrusted() {
            accessibilityRecoveryTimer?.invalidate()
            accessibilityRecoveryTimer = nil
            setAccessibilityWarning(visible: false)
            if focusWatcher == nil { startWatcher() }
        } else {
            if focusWatcher != nil {
                focusWatcher?.stop()
                focusWatcher = nil
            }
            setAccessibilityWarning(visible: true)
            guard accessibilityRecoveryTimer == nil else { return }
            accessibilityRecoveryTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.accessibilityRecoveryTimer = nil
                    self?.setAccessibilityWarning(visible: false)
                    self?.startWatcher()
                }
            }
        }
    }

    func setAccessibilityWarning(visible: Bool) {
        statusItem.menu?.item(withTag: 9999)?.isHidden = !visible
        statusItem.menu?.item(withTag: 9998)?.isHidden = !visible
    }

    @objc func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:root=Privacy_Accessibility")!)
    }
}
