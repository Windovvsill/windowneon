import AppKit

extension AppDelegate {
    @objc func customizeBorderForCurrentApp() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let bundleID = app.bundleIdentifier else { return }

        colorPickerBundleID = bundleID
        let original = (
            style: resolvedStyle(for: bundleID),
            width: effectiveBorderWidth(for: bundleID),
            radius: cornerRadius(for: bundleID)
        )
        colorPickerOriginal = original

        let model = BorderStyleEditorModel(
            appName: app.localizedName ?? bundleID,
            appIcon: app.icon,
            style: original.style,
            width: original.width,
            radius: original.radius
        )

        model.onLiveChange = { [weak self, weak model] in
            guard let model else { return }
            HighlightWindow.style = model.style
            HighlightWindow.borderWidth = model.width
            HighlightWindow.cornerRadius = model.radius
            self?.focusWatcher?.redrawBorder()
            self?.updateStatusIcon()
        }
        model.onPickColor = { [weak self] index in
            self?.openColorPicker(index: index)
        }
        model.onSave = { [weak self, weak model] in
            guard let self, let model, let bundleID = self.colorPickerBundleID else { return }
            setAppStyle(model.style, for: bundleID)
            setCornerRadius(model.radius, for: bundleID)
            if model.width == HighlightWindow.globalBorderWidth {
                // Matches the global default — keep following it.
                removeBorderWidthOverride(for: bundleID)
            } else {
                setBorderWidthOverride(model.width, for: bundleID)
            }
            HighlightWindow.style = model.style
            HighlightWindow.borderWidth = model.width
            HighlightWindow.cornerRadius = model.radius
            self.focusWatcher?.redrawBorder()
            self.updateStatusIcon()
            NSColorPanel.shared.orderOut(nil)
            self.borderStylePanel?.commit()
            self.borderStylePanel?.close()
        }
        model.onCancel = { [weak self] in
            if let orig = self?.colorPickerOriginal {
                HighlightWindow.style = orig.style
                HighlightWindow.borderWidth = orig.width
                HighlightWindow.cornerRadius = orig.radius
                self?.focusWatcher?.redrawBorder()
                self?.updateStatusIcon()
            }
            NSColorPanel.shared.orderOut(nil)
            self?.borderStylePanel?.commit() // cancel handled; don't re-fire from windowWillClose
            self?.borderStylePanel?.close()
        }

        let panel = BorderStylePanel(model: model)
        borderStylePanel = panel
        positionUnderStatusItem(panel)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Drop the panel just below the menu bar icon, clamped to the screen.
    private func positionUnderStatusItem(_ panel: NSWindow) {
        guard let buttonWindow = statusItem.button?.window,
              let screen = buttonWindow.screen ?? NSScreen.main else {
            panel.center()
            return
        }
        let visible = screen.visibleFrame
        var x = buttonWindow.frame.midX - panel.frame.width / 2
        x = min(x, visible.maxX - panel.frame.width - 12)
        x = max(x, visible.minX + 12)
        let y = buttonWindow.frame.minY - 10 - panel.frame.height
        panel.setFrameOrigin(NSPoint(x: x, y: max(y, visible.minY + 12)))
    }

    func openColorPicker(index: Int) {
        colorPickerSlot = index
        let colors = borderStylePanel?.model.style.colors ?? []
        let current = colors.indices.contains(index) ? colors[index] : .systemBlue
        let panel = NSColorPanel.shared
        let wasVisible = panel.isVisible
        panel.showsAlpha = true
        panel.color = current
        panel.setTarget(self)
        panel.setAction(#selector(appColorDidChange(_:)))
        panel.isContinuous = true
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        // Snap the picker next to the style panel instead of wherever it last
        // was — but don't yank it around once the user can see it.
        if !wasVisible, let styleFrame = borderStylePanel?.frame, let screen = borderStylePanel?.screen {
            var x = styleFrame.minX - panel.frame.width - 12
            if x < screen.visibleFrame.minX + 12 {
                x = styleFrame.maxX + 12
            }
            panel.setFrameTopLeftPoint(NSPoint(x: x, y: styleFrame.maxY))
        }
    }

    @objc func appColorDidChange(_ sender: NSColorPanel) {
        // The model fires onLiveChange, which applies the style to the real
        // border and the preview strip.
        borderStylePanel?.model.updateColor(sender.color, at: colorPickerSlot)
    }
}
