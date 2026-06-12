import AppKit

private let palette: [NSColor] = stride(from: 0, to: 360, by: 30).map { hue in
    NSColor(hue: CGFloat(hue) / 360, saturation: 0.45, brightness: 0.92, alpha: 1)
}

/// User-saved style for an app, if any. Falls back to the legacy
/// appColor_/appColor2_ keys written by older versions.
func appStyle(for bundleID: String) -> BorderStyle? {
    if let dict = UserDefaults.standard.dictionary(forKey: "borderStyle_\(bundleID)"),
       let style = BorderStyle(dictionary: dict) {
        return style
    }
    guard let c1 = legacyColor(key: "appColor_\(bundleID)") else { return nil }
    var colors = [c1]
    if let c2 = legacyColor(key: "appColor2_\(bundleID)") { colors.append(c2) }
    return BorderStyle(colors: colors)
}

func setAppStyle(_ style: BorderStyle?, for bundleID: String) {
    let ud = UserDefaults.standard
    if let style {
        ud.set(style.dictionary, forKey: "borderStyle_\(bundleID)")
    } else {
        ud.removeObject(forKey: "borderStyle_\(bundleID)")
    }
    // The new key supersedes the legacy pair; drop them so they can't resurface.
    ud.removeObject(forKey: "appColor_\(bundleID)")
    ud.removeObject(forKey: "appColor2_\(bundleID)")
}

func resolvedStyle(for bundleID: String) -> BorderStyle {
    appStyle(for: bundleID) ?? BorderStyle(colors: [paletteColor(for: bundleID)])
}

private func legacyColor(key: String) -> NSColor? {
    guard let data = UserDefaults.standard.data(forKey: key),
          let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    else { return nil }
    return color
}

func paletteColor(for bundleID: String) -> NSColor {
    // FNV-1a 32-bit — stable across runs, no Swift hashValue randomisation
    var hash: UInt32 = 2166136261
    for byte in bundleID.utf8 {
        hash ^= UInt32(byte)
        hash = hash &* 16777619
    }
    return palette[Int(hash % UInt32(palette.count))]
}
