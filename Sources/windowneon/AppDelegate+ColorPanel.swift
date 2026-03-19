import AppKit

extension AppDelegate {
    @objc func setCornerRadiusForCurrentApp() {
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

    @objc func setColorForCurrentApp() {
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
            self?.updateStatusIcon()
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

    func openColorPicker(slot: Int) {
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

    @objc func appColorDidChange(_ sender: NSColorPanel) {
        borderColorPanel?.updateColor(sender.color, slot: colorPickerSlot)
        if colorPickerSlot == 1 {
            HighlightWindow.borderColor = sender.color
        } else {
            HighlightWindow.borderColor2 = sender.color
        }
        focusWatcher?.redrawBorder()
        updateStatusIcon()
    }
}
