import AppKit
import ApplicationServices


class FocusWatcher {
    private let highlight = HighlightWindow()

    private var appObserver: AXObserver?
    private var windowObserver: AXObserver?
    private var watchedPID: pid_t = 0
    private var watchedWindow: AXUIElement?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var isDragging = false

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

    // MARK: - App-level switching

    private func switchToApp(pid: pid_t) {
        teardownObserver(&appObserver)
        teardownObserver(&windowObserver)
        watchedWindow = nil
        watchedPID = pid

        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
        HighlightWindow.cornerRadius = cornerRadius(for: bundleID)
        HighlightWindow.borderColor = resolvedColor(for: bundleID)
        HighlightWindow.borderColor2 = resolvedColor2(for: bundleID)
        HighlightWindow.borderWidth = effectiveBorderWidth(for: bundleID)

        let appElement = AXUIElementCreateApplication(pid)
        var obs: AXObserver?
        guard AXObserverCreate(pid, axCallback, &obs) == .success, let obs else { return }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(obs, appElement, kAXFocusedWindowChangedNotification as CFString, selfPtr)
        AXObserverAddNotification(obs, appElement, kAXMainWindowChangedNotification as CFString, selfPtr)
        AXObserverAddNotification(obs, appElement, kAXWindowCreatedNotification as CFString, selfPtr)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        appObserver = obs

        // Show border for whatever window is already focused in this app
        updateFocusedWindow(appElement: appElement)
    }

    // MARK: - Window-level switching

    private func switchToWindow(_ windowElement: AXUIElement) {
        teardownObserver(&windowObserver)
        watchedWindow = windowElement

        var obs: AXObserver?
        guard AXObserverCreate(watchedPID, axCallback, &obs) == .success, let obs else { return }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(obs, windowElement, kAXWindowMovedNotification as CFString, selfPtr)
        AXObserverAddNotification(obs, windowElement, kAXWindowResizedNotification as CFString, selfPtr)
        AXObserverAddNotification(obs, windowElement, kAXUIElementDestroyedNotification as CFString, selfPtr)
        AXObserverAddNotification(obs, windowElement, kAXWindowMiniaturizedNotification as CFString, selfPtr)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        windowObserver = obs

        updateHighlight(for: windowElement)
    }

    // MARK: - Highlight updates

    private var pendingWindowUpdate: DispatchWorkItem?

    private func updateFocusedWindow(appElement: AXUIElement) {
        pendingWindowUpdate?.cancel()
        let pid = watchedPID  // capture PID, not the element — AX elements from callbacks go stale
        let work = DispatchWorkItem { [weak self] in
            self?.queryAndSwitchFocusedWindow(appElement: AXUIElementCreateApplication(pid))
        }
        pendingWindowUpdate = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    private func queryAndSwitchFocusedWindow(appElement: AXUIElement) {
        var value: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value)
        if focusResult != .success || value == nil {
            AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &value)
        }
        guard let windowElement = value else { return }
        // swiftlint:disable:next force_cast
        switchToWindow(windowElement as! AXUIElement)
    }

    private func isFullScreen(_ windowElement: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowElement, "AXFullScreen" as CFString, &value) == .success,
              let boolRef = value,
              CFGetTypeID(boolRef) == CFBooleanGetTypeID() else { return false }
        return CFBooleanGetValue((boolRef as! CFBoolean))
    }

    private func updateHighlight(for windowElement: AXUIElement) {
        guard !isDragging else { return }
        guard !isFullScreen(windowElement) else { highlight.hide(); return }

        // Hide the border for excluded apps.
        let bundleID = NSRunningApplication(processIdentifier: watchedPID)?.bundleIdentifier ?? ""
        if isAppExcluded(bundleID) { highlight.hide(); return }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowElement, "AXFrame" as CFString, &value) == .success,
              let axValue = value,
              CFGetTypeID(axValue) == AXValueGetTypeID() else {
            highlight.hide()
            return
        }

        var frame = CGRect.zero
        // swiftlint:disable:next force_cast
        AXValueGetValue(axValue as! AXValue, .cgRect, &frame)

        // AX coords: y=0 at top of primary screen. Cocoa: y=0 at bottom.
        let screenHeight = NSScreen.screens[0].frame.height
        let cocoaFrame = CGRect(
            x: frame.origin.x,
            y: screenHeight - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
        highlight.show(frame: cocoaFrame)
    }

    // MARK: - Callback dispatch

    func handleNotification(element: AXUIElement, notification: CFString) {
        switch notification as String {
        case kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification:
            updateFocusedWindow(appElement: element)
        case kAXWindowCreatedNotification:
            // element is the new window, not the app — rebuild the app element
            updateFocusedWindow(appElement: AXUIElementCreateApplication(watchedPID))
        case kAXWindowMovedNotification, kAXWindowResizedNotification:
            updateHighlight(for: element)
        case kAXUIElementDestroyedNotification, kAXWindowMiniaturizedNotification:
            highlight.hide()
        default:
            break
        }
    }

    // MARK: - Event tap (smooth drag tracking)

    private func setupEventTap() {
        let mask = CGEventMask(1 << CGEventType.leftMouseDragged.rawValue | 1 << CGEventType.leftMouseUp.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else { return }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        eventTapSource = source
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

    // MARK: - Helpers

    private func teardownObserver(_ obs: inout AXObserver?) {
        guard let o = obs else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(o), .defaultMode)
        obs = nil
    }
}

// Global C-compatible callback for CGEventTap (mouse drag)
private func eventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    _ event: CGEvent,
    _ refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if let refcon {
        let watcher = Unmanaged<FocusWatcher>.fromOpaque(refcon).takeUnretainedValue()
        switch type {
        case .leftMouseDragged: watcher.handleMouseDrag()
        case .leftMouseUp:      watcher.handleMouseUp()
        default: break
        }
    }
    return Unmanaged.passUnretained(event)
}

// Global C-compatible callback required by AXObserverCreate
private func axCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    Unmanaged<FocusWatcher>.fromOpaque(refcon).takeUnretainedValue()
        .handleNotification(element: element, notification: notification)
}
