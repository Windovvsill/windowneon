import AppKit
import ApplicationServices

extension FocusWatcher {
    // MARK: - Highlight updates

    func isFullScreen(_ windowElement: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(windowElement, "AXFullScreen" as CFString, &value) == .success,
              let boolRef = value,
              CFGetTypeID(boolRef) == CFBooleanGetTypeID() else { return false }
        return CFBooleanGetValue((boolRef as! CFBoolean))
    }

    func updateHighlight(for windowElement: AXUIElement) {
        guard !isDragging else { return }
        guard HighlightWindow.globallyEnabled else { highlight.hide(); return }
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
        var cocoaFrame = CGRect(
            x: frame.origin.x,
            y: screenHeight - frame.origin.y - frame.height,
            width: frame.width,
            height: frame.height
        )
        if HighlightWindow.borderPlacement == .outside {
            let expansion = HighlightWindow.borderWidth
            cocoaFrame = cocoaFrame.insetBy(dx: -expansion, dy: -expansion)
        }
        highlight.show(frame: cocoaFrame)
    }

    // MARK: - Callback dispatch

    func handleNotification(element: AXUIElement, notification: CFString) {
        switch notification as String {
        case kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification:
            updateFocusedWindow()
        case kAXWindowCreatedNotification:
            updateFocusedWindow()
        case kAXWindowMovedNotification, kAXWindowResizedNotification:
            updateHighlight(for: element)
        case kAXUIElementDestroyedNotification, kAXWindowMiniaturizedNotification:
            highlight.hide()
        default:
            break
        }
    }

    // MARK: - Event tap (smooth drag tracking)

    func setupEventTap() {
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
}

// Global C-compatible callback for CGEventTap (mouse drag)
func eventTapCallback(
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
func axCallback(
    _ observer: AXObserver,
    _ element: AXUIElement,
    _ notification: CFString,
    _ refcon: UnsafeMutableRawPointer?
) {
    guard let refcon else { return }
    Unmanaged<FocusWatcher>.fromOpaque(refcon).takeUnretainedValue()
        .handleNotification(element: element, notification: notification)
}
