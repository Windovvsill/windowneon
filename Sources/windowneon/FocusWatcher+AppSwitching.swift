import AppKit
import ApplicationServices

extension FocusWatcher {
    // MARK: - App-level switching

    func switchToApp(pid: pid_t) {
        teardownObserver(&appObserver)
        teardownObserver(&windowObserver)
        watchedWindow = nil
        watchedPID = pid

        let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? ""
        HighlightWindow.cornerRadius = cornerRadius(for: bundleID)
        HighlightWindow.style = resolvedStyle(for: bundleID)
        HighlightWindow.borderWidth = effectiveBorderWidth(for: bundleID)
        onColorChange?()

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
        updateFocusedWindow()
    }

    // MARK: - Window-level switching

    func switchToWindow(_ windowElement: AXUIElement) {
        teardownObserver(&windowObserver)
        watchedWindow = windowElement

        let bundleID = NSRunningApplication(processIdentifier: watchedPID)?.bundleIdentifier ?? ""
        HighlightWindow.style = windowColorOverrides[AXWindowKey(element: windowElement)]
            ?? resolvedStyle(for: bundleID)
        onColorChange?()

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

    func updateFocusedWindow() {
        pendingWindowUpdate?.cancel()
        scheduleWindowQuery(pid: watchedPID, attempt: 0)
    }

    func scheduleWindowQuery(pid: pid_t, attempt: Int) {
        guard attempt < Self.retryDelays.count else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.watchedPID == pid else { return }
            if !self.queryAndSwitchFocusedWindow(pid: pid) {
                self.scheduleWindowQuery(pid: pid, attempt: attempt + 1)
            }
        }
        pendingWindowUpdate = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryDelays[attempt], execute: work)
    }

    // Returns true if a window was found, false if we should retry.
    @discardableResult
    func queryAndSwitchFocusedWindow(pid: pid_t) -> Bool {
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let focusResult = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value)
        if focusResult != .success || value == nil {
            AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &value)
        }
        guard let windowElement = value else { return false }
        // swiftlint:disable:next force_cast
        switchToWindow(windowElement as! AXUIElement)
        return true
    }
}
