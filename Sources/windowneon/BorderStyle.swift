import AppKit

/// Full description of how a border looks: colors, stroke pattern, motion and glow.
struct BorderStyle: Equatable {
    enum Stroke: String, CaseIterable {
        case solid, dashed, dotted
    }

    enum Motion: String, CaseIterable {
        case none, pulse, spin, march
    }

    static let maxColors = 8

    var colors: [NSColor]
    var stroke: Stroke = .solid
    var motion: Motion = .none
    var glow: Bool = false
    /// Multiplier applied to animated effects. 1.0 = default pace.
    var speed: Double = 1.0

    var primaryColor: NSColor { colors.first ?? .systemBlue }

    init(colors: [NSColor], stroke: Stroke = .solid, motion: Motion = .none, glow: Bool = false, speed: Double = 1.0) {
        self.colors = colors.isEmpty ? [.systemBlue] : Array(colors.prefix(Self.maxColors))
        self.stroke = stroke
        self.motion = motion
        self.glow = glow
        self.speed = min(max(speed, 0.25), 4)
    }
}

// MARK: - Serialization (UserDefaults dictionaries, settings files, URL params)

extension BorderStyle {
    var dictionary: [String: Any] {
        var d: [String: Any] = [
            "colors": colors.map { $0.hexString },
            "stroke": stroke.rawValue,
            "motion": motion.rawValue,
        ]
        if glow { d["glow"] = true }
        if speed != 1.0 { d["speed"] = speed }
        return d
    }

    init?(dictionary: [String: Any]) {
        guard let hexes = dictionary["colors"] as? [String] else { return nil }
        let parsed = hexes.compactMap { NSColor(hexString: $0) }
        guard !parsed.isEmpty else { return nil }
        self.init(
            colors: parsed,
            stroke: (dictionary["stroke"] as? String).flatMap(Stroke.init(rawValue:)) ?? .solid,
            motion: (dictionary["motion"] as? String).flatMap(Motion.init(rawValue:)) ?? .none,
            glow: dictionary["glow"] as? Bool ?? false,
            speed: dictionary["speed"] as? Double ?? 1.0
        )
    }
}

// MARK: - Hex colors (RRGGBB or RRGGBBAA)

extension NSColor {
    convenience init?(hexString: String) {
        let h = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6 || h.count == 8, let value = UInt64(h, radix: 16) else { return nil }
        let hasAlpha = h.count == 8
        let rgb = hasAlpha ? value >> 8 : value
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >>  8) & 0xFF) / 255
        let b = CGFloat( rgb        & 0xFF) / 255
        let a = hasAlpha ? CGFloat(value & 0xFF) / 255 : 1
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }

    var hexString: String {
        guard let c = usingColorSpace(.sRGB) else { return "0000FF" }
        let r = Int((c.redComponent   * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent  * 255).rounded())
        let a = Int((c.alphaComponent * 255).rounded())
        return a == 255
            ? String(format: "%02X%02X%02X", r, g, b)
            : String(format: "%02X%02X%02X%02X", r, g, b, a)
    }
}
