import CoreGraphics
import Foundation

func effectiveBorderWidth(for bundleID: String) -> CGFloat {
    let overrides = UserDefaults.standard.dictionary(forKey: "borderWidthOverrides") as? [String: Double] ?? [:]
    if let w = overrides[bundleID] { return CGFloat(w) }
    return HighlightWindow.globalBorderWidth
}

func setBorderWidthOverride(_ width: CGFloat, for bundleID: String) {
    var overrides = UserDefaults.standard.dictionary(forKey: "borderWidthOverrides") as? [String: Double] ?? [:]
    overrides[bundleID] = Double(width)
    UserDefaults.standard.set(overrides, forKey: "borderWidthOverrides")
}

func removeBorderWidthOverride(for bundleID: String) {
    var overrides = UserDefaults.standard.dictionary(forKey: "borderWidthOverrides") as? [String: Double] ?? [:]
    overrides.removeValue(forKey: bundleID)
    UserDefaults.standard.set(overrides, forKey: "borderWidthOverrides")
}
