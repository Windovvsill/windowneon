import AppKit

extension AppDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { handleURL(url) }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "windowneon" else { return }
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        switch url.host {
        case "set":
            guard let hexStr = components?.queryItems?.first(where: { $0.name == "color" })?.value,
                  let color = NSColor(hex: hexStr) else { return }
            HighlightWindow.colorOverride = color
        case "reset":
            HighlightWindow.colorOverride = nil
        default:
            return
        }

        // Apply immediately to the current window
        if let pid = focusWatcher?.watchedPID,
           let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier {
            HighlightWindow.borderColor = HighlightWindow.colorOverride ?? resolvedColor(for: bundleID)
            HighlightWindow.borderColor2 = HighlightWindow.colorOverride != nil ? nil : resolvedColor2(for: bundleID)
        }
        focusWatcher?.redrawBorder()
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
