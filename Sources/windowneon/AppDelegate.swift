import AppKit
import ApplicationServices
import ServiceManagement
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var statusItem: NSStatusItem!
    var focusWatcher: FocusWatcher?
    var updaterController: SPUStandardUpdaterController!

    var radiusPanel: CornerRadiusPanel?
    var borderColorPanel: BorderColorPanel?
    var colorPickerBundleID: String?
    var colorPickerOriginal: (NSColor, NSColor?)?
    var colorPickerSlot = 1
    var accessibilityRecoveryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if !DEBUG
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        #endif
        loadSavedWidth()
        HighlightWindow.ticksEnabled = UserDefaults.standard.object(forKey: "ticksEnabled") as? Bool ?? true
        HighlightWindow.globallyEnabled = UserDefaults.standard.object(forKey: "globallyEnabled") as? Bool ?? true
        let savedOutside = UserDefaults.standard.object(forKey: "borderPlacementOutside") as? Bool ?? false
        HighlightWindow.borderPlacement = savedOutside ? .outside : .inside
        HighlightWindow.fadeEnabled = UserDefaults.standard.object(forKey: "fadeEnabled") as? Bool ?? false
        setupStatusItem()
        setupGlobalHotkey()
        requestAccessibilityAndStart()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(accessibilityChanged),
            name: NSNotification.Name("com.apple.accessibility.api"),
            object: nil
        )
    }

    static let widths: [CGFloat] = [1, 2, 3, 4, 6, 8, 10]

    private func loadSavedWidth() {
        let saved = UserDefaults.standard.double(forKey: "borderWidth")
        if saved > 0 {
            HighlightWindow.globalBorderWidth = saved
            HighlightWindow.borderWidth = saved
        }
    }

    func updateStatusIcon() {
        let (color1, color2): (NSColor, NSColor) = HighlightWindow.globallyEnabled
            ? (HighlightWindow.borderColor, HighlightWindow.borderColor2 ?? HighlightWindow.borderColor)
            : (.tertiaryLabelColor, .tertiaryLabelColor)
        let config = NSImage.SymbolConfiguration(paletteColors: [color1, color2])
        let icon = NSImage(systemSymbolName: "inset.filled.square", accessibilityDescription: "Windowneon")?
            .withSymbolConfiguration(config)
        statusItem.button?.image = icon
    }

    private func setupGlobalHotkey() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.modifierFlags.intersection([.option, .command, .shift, .control]) == [.option, .command],
                  event.keyCode == 11 else { return } // 11 = B
            self?.toggleBordersActivation()
        }
    }

    private func requestAccessibilityAndStart() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            startWatcher()
        } else {
            // Poll until granted — only needed at first launch
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.startWatcher()
                }
            }
        }
    }

    func startWatcher() {
        focusWatcher = FocusWatcher()
        focusWatcher?.onColorChange = { [weak self] in self?.updateStatusIcon() }
        focusWatcher?.start()
    }
}
