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
    var hotkeyPanel: HotkeyPanel?
    var colorPickerBundleID: String?
    var colorPickerOriginal: (NSColor, NSColor?)?
    var colorPickerSlot = 1
    var accessibilityRecoveryTimer: Timer?

    var hotkeyKeyCode: UInt16 = 11
    var hotkeyModifiers: NSEvent.ModifierFlags = [.command, .option]
    var hotkeyDisplay: String = "⌘⌥B"
    var globalHotkeyMonitor: Any?

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
        if let kc = UserDefaults.standard.object(forKey: "hotkeyKeyCode") as? Int {
            hotkeyKeyCode = UInt16(kc)
            hotkeyModifiers = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: "hotkeyModifiers")))
            hotkeyDisplay = UserDefaults.standard.string(forKey: "hotkeyDisplay") ?? "⌘⌥B"
        }
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

    func setupGlobalHotkey() {
        if let m = globalHotkeyMonitor { NSEvent.removeMonitor(m); globalHotkeyMonitor = nil }
        guard hotkeyKeyCode != UInt16.max else { return }
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            let mods = event.modifierFlags.intersection([.option, .command, .shift, .control])
            guard mods == self.hotkeyModifiers, event.keyCode == self.hotkeyKeyCode else { return }
            self.toggleBordersActivation()
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
