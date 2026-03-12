import Foundation

private let excludedAppsKey = "excludedApps"

func isAppExcluded(_ bundleID: String) -> Bool {
    (UserDefaults.standard.stringArray(forKey: excludedAppsKey) ?? []).contains(bundleID)
}

func toggleAppExclusion(_ bundleID: String) {
    var set = Set(UserDefaults.standard.stringArray(forKey: excludedAppsKey) ?? [])
    if set.contains(bundleID) { set.remove(bundleID) } else { set.insert(bundleID) }
    UserDefaults.standard.set(Array(set), forKey: excludedAppsKey)
}
