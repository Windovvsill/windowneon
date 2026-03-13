import AppKit
import Foundation

enum SettingsPorter {

    // MARK: - Export

    static func export() throws -> Data {
        let ud = UserDefaults.standard
        let widthOverrides  = ud.dictionary(forKey: "borderWidthOverrides")  as? [String: Double] ?? [:]
        let radiusOverrides = ud.dictionary(forKey: "cornerRadiusOverrides") as? [String: Double] ?? [:]
        let excluded        = ud.stringArray(forKey: "excludedApps") ?? []

        // Collect every bundle ID that has any per-app data
        var bundleIDs = Set<String>()
        bundleIDs.formUnion(widthOverrides.keys)
        bundleIDs.formUnion(radiusOverrides.keys)
        bundleIDs.formUnion(excluded)
        for key in ud.dictionaryRepresentation().keys where key.hasPrefix("appColor_") {
            bundleIDs.insert(String(key.dropFirst("appColor_".count)))
        }

        var apps: [String: [String: Any]] = [:]
        for id in bundleIDs {
            var entry: [String: Any] = [:]
            if let w = widthOverrides[id]  { entry["borderWidth"]   = w }
            if let r = radiusOverrides[id] { entry["cornerRadius"]  = r }
            if excluded.contains(id)       { entry["excluded"]      = true }
            if let c = appColor(for: id)   { entry["color"]         = hex(from: c) }
            if let c = appColor2(for: id)  { entry["color2"]        = hex(from: c) }
            apps[id] = entry
        }

        let savedWidth = ud.double(forKey: "borderWidth")
        let payload: [String: Any] = [
            "version": 1,
            "global": [
                "borderWidth":  savedWidth > 0 ? savedWidth : Double(HighlightWindow.globalBorderWidth),
                "ticksEnabled": ud.object(forKey: "ticksEnabled") as? Bool ?? true,
            ],
            "apps": apps,
        ]

        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    // MARK: - Import

    static func `import`(from data: Data) throws {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Err.invalidFormat
        }

        let ud = UserDefaults.standard

        if let global = payload["global"] as? [String: Any] {
            if let w = global["borderWidth"] as? Double, w > 0 {
                ud.set(w, forKey: "borderWidth")
                HighlightWindow.globalBorderWidth = CGFloat(w)
                HighlightWindow.borderWidth = CGFloat(w)
            }
            if let t = global["ticksEnabled"] as? Bool {
                ud.set(t, forKey: "ticksEnabled")
                HighlightWindow.ticksEnabled = t
            }
        }

        if let apps = payload["apps"] as? [String: [String: Any]] {
            var widthOverrides  = ud.dictionary(forKey: "borderWidthOverrides")  as? [String: Double] ?? [:]
            var radiusOverrides = ud.dictionary(forKey: "cornerRadiusOverrides") as? [String: Double] ?? [:]
            var excludedSet     = Set(ud.stringArray(forKey: "excludedApps") ?? [])

            for (id, entry) in apps {
                if let w = entry["borderWidth"]  as? Double { widthOverrides[id]  = w }
                if let r = entry["cornerRadius"] as? Double { radiusOverrides[id] = r }
                if let ex = entry["excluded"] as? Bool {
                    if ex { excludedSet.insert(id) } else { excludedSet.remove(id) }
                }
                if let hexStr = entry["color"]  as? String, let c = color(from: hexStr) { setAppColor(c,  for: id) }
                if let hexStr = entry["color2"] as? String, let c = color(from: hexStr) { setAppColor2(c, for: id) }
            }

            ud.set(widthOverrides,       forKey: "borderWidthOverrides")
            ud.set(radiusOverrides,      forKey: "cornerRadiusOverrides")
            ud.set(Array(excludedSet),   forKey: "excludedApps")
        }
    }

    // MARK: - Color helpers

    private static func hex(from color: NSColor) -> String {
        guard let c = color.usingColorSpace(.sRGB) else { return "000000" }
        return String(format: "%02X%02X%02X",
                      Int((c.redComponent   * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()),
                      Int((c.blueComponent  * 255).rounded()))
    }

    private static func color(from hex: String) -> NSColor? {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >>  8) & 0xFF) / 255
        let b = CGFloat( value        & 0xFF) / 255
        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1)
    }

    enum Err: LocalizedError {
        case invalidFormat
        var errorDescription: String? { "Not a valid Windowneon settings file." }
    }
}
