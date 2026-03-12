import CoreGraphics

// Corner radius overrides by bundle ID.
// Default (no entry) = 9pt, which matches standard macOS windows.
// Set to 0 for apps with square windows.

let cornerRadiusOverrides: [String: CGFloat] = [
    // Apple
    "com.apple.finder":             9,
    "com.apple.Safari":             9,
    "com.apple.mail":               9,
    "com.apple.Notes":              9,
    "com.apple.Terminal":           9,
    "com.mitchellh.ghostty":        13,
    "com.apple.dt.Xcode":           9,
    "com.apple.systempreferences":  9,
    "com.apple.iCal":               9,
    "com.apple.MobileSMS":          9,
    "com.apple.Music":              9,
    "com.apple.Photos":             9,

    // Browsers
    "com.google.Chrome":            20,
    "org.mozilla.firefox":          9,
    "com.brave.Browser":            9,
    "com.microsoft.edgemac":        9,
    "com.operasoftware.Opera":      9,
    "com.arc.app":                  12,  // Arc has a slightly larger radius

    // Dev tools
    "com.microsoft.VSCode":         9,
    "com.jetbrains.intellij":       9,
    "com.sublimetext.4":            9,
    "com.github.atom":              9,
    "com.panic.Nova":               9,
    "com.todesktop.230313mzl4w4u92": 13,

    // Productivity
    "com.tinyspeck.slackmacgap":    9,
    "com.hnc.Discord":              9,
    "com.notion.id":                9,
    "com.linear.Linear":            9,
    "com.figma.Desktop":            9,
    "com.spotify.client":           9,
]

let defaultCornerRadius: CGFloat = 9
