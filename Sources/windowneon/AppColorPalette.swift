import AppKit

private let palette: [NSColor] = stride(from: 0, to: 360, by: 30).map { hue in
    NSColor(hue: CGFloat(hue) / 360, saturation: 0.45, brightness: 0.92, alpha: 1)
}

func appColor(for bundleID: String) -> NSColor? {
    guard let data = UserDefaults.standard.data(forKey: "appColor_\(bundleID)"),
          let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)
    else { return nil }
    return color
}

func setAppColor(_ color: NSColor, for bundleID: String) {
    if let data = try? NSKeyedArchiver.archivedData(withRootObject: color, requiringSecureCoding: false) {
        UserDefaults.standard.set(data, forKey: "appColor_\(bundleID)")
    }
}

func resolvedColor(for bundleID: String) -> NSColor {
    appColor(for: bundleID) ?? paletteColor(for: bundleID)
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
