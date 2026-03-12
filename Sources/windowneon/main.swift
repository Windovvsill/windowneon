import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
