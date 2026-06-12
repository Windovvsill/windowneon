import AppKit
import ApplicationServices


struct AXWindowKey: Hashable {
    let element: AXUIElement
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
    static func == (lhs: Self, rhs: Self) -> Bool { CFEqual(lhs.element, rhs.element) }
}

class FocusWatcher {
    let highlight = HighlightWindow()

    var appObserver: AXObserver?
    var windowObserver: AXObserver?
    var watchedPID: pid_t = 0
    var watchedWindow: AXUIElement?
    var eventTap: CFMachPort?
    var eventTapSource: CFRunLoopSource?
    var isDragging = false

    var onColorChange: (() -> Void)?

    var windowColorOverrides: [AXWindowKey: WindowStyleOverride] = [:]
    var pendingWindowUpdate: DispatchWorkItem?
    static let retryDelays: [Double] = [0.05, 0.1, 0.3, 0.5, 1.0]

    func start() {
        setupEventTap()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        if let frontmost = NSWorkspace.shared.frontmostApplication {
            switchToApp(pid: frontmost.processIdentifier)
        }
    }

    @objc private func appActivated(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        // Ignore our own activation (color picker, radius panel, etc.)
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
        switchToApp(pid: app.processIdentifier)
    }

    func redrawBorder() {
        highlight.redrawBorder()
    }

    /// Re-evaluate the highlight for the current window — call after toggling exclusion or dim.
    func updateCurrentHighlight() {
        guard let win = watchedWindow else { return }
        updateHighlight(for: win)
    }

    func handleMouseDrag() {
        guard !isDragging else { return }
        isDragging = true
        highlight.hide()
    }

    func handleMouseUp() {
        guard isDragging else { return }
        isDragging = false
        guard let win = watchedWindow else { return }
        updateHighlight(for: win)
    }

    func stop() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        teardownObserver(&appObserver)
        teardownObserver(&windowObserver)
        highlight.hide()
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = eventTapSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .defaultMode)
            }
        }
    }

    // MARK: - Helpers

    func teardownObserver(_ obs: inout AXObserver?) {
        guard let o = obs else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode)
        obs = nil
    }

}
