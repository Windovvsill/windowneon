import AppKit

extension AppDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { handleURL(url) }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "windowneon",
              let watcher = focusWatcher,
              let windowElement = watcher.watchedWindow else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let key = AXWindowKey(element: windowElement)

        switch url.host {
        case "set":
            guard let hexStr = components?.queryItems?.first(where: { $0.name == "color" })?.value,
                  let color = NSColor(hex: hexStr) else { return }
            let color2 = components?.queryItems?.first(where: { $0.name == "color2" })?.value.flatMap { NSColor(hex: $0) }
            watcher.windowColorOverrides[key] = (color, color2)
            HighlightWindow.borderColor = color
            HighlightWindow.borderColor2 = color2
        case "reset":
            watcher.windowColorOverrides.removeValue(forKey: key)
            let bundleID = NSRunningApplication(processIdentifier: watcher.watchedPID)?.bundleIdentifier ?? ""
            HighlightWindow.borderColor = resolvedColor(for: bundleID)
            HighlightWindow.borderColor2 = resolvedColor2(for: bundleID)
        default:
            return
        }

        watcher.redrawBorder()
        updateStatusIcon()
    }
}

private extension NSColor {
    convenience init?(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >>  8) & 0xFF) / 255
        let b = CGFloat( value        & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}
