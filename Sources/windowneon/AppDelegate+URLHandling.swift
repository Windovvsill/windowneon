import AppKit

extension AppDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { handleURL(url) }
    }

    // windowneon://set?colors=FF0000,00FF00&stroke=dashed&motion=spin&glow=true&speed=1.5&width=4&radius=12
    // Legacy params still work: color=, color2=, pulse=true.
    private func handleURL(_ url: URL) {
        guard url.scheme == "windowneon",
              let watcher = focusWatcher,
              let windowElement = watcher.watchedWindow else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let param: (String) -> String? = { name in
            components?.queryItems?.first(where: { $0.name == name })?.value
        }
        let key = AXWindowKey(element: windowElement)

        switch url.host {
        case "set":
            var colors = param("colors")?
                .split(separator: ",")
                .compactMap { NSColor(hexString: String($0)) } ?? []
            if colors.isEmpty, let c = param("color").flatMap(NSColor.init(hexString:)) {
                colors = [c]
                if let c2 = param("color2").flatMap(NSColor.init(hexString:)) { colors.append(c2) }
            }
            guard !colors.isEmpty else { return }

            let style = BorderStyle(
                colors: colors,
                stroke: param("stroke").flatMap(BorderStyle.Stroke.init(rawValue:)) ?? .solid,
                motion: param("pulse") == "true"
                    ? .pulse
                    : param("motion").flatMap(BorderStyle.Motion.init(rawValue:)) ?? .none,
                glow: param("glow") == "true",
                speed: param("speed").flatMap(Double.init) ?? 1.0
            )
            let override = WindowStyleOverride(
                style: style,
                width: param("width").flatMap(Double.init).map { CGFloat(min(max($0, 0.5), 20)) },
                radius: param("radius").flatMap(Double.init).map { CGFloat(min(max($0, 0), 40)) }
            )
            watcher.windowColorOverrides[key] = override
            HighlightWindow.style = style
            if let w = override.width { HighlightWindow.borderWidth = w }
            if let r = override.radius { HighlightWindow.cornerRadius = r }
        case "reset":
            watcher.windowColorOverrides.removeValue(forKey: key)
            let bundleID = NSRunningApplication(processIdentifier: watcher.watchedPID)?.bundleIdentifier ?? ""
            HighlightWindow.style = resolvedStyle(for: bundleID)
            HighlightWindow.borderWidth = effectiveBorderWidth(for: bundleID)
            HighlightWindow.cornerRadius = cornerRadius(for: bundleID)
        default:
            return
        }

        watcher.redrawBorder()
        updateStatusIcon()
    }
}
