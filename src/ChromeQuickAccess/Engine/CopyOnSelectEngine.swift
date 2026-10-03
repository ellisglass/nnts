import Foundation
import CoreGraphics
import AppKit
import Cocoa
import Carbon
import os

@MainActor
public final class CopyOnSelectEngine: @unchecked Sendable {
    public static let shared = CopyOnSelectEngine()
    
    /// Blacklisted applications where automated copy-on-select must NEVER trigger (Security & UX protection)
    public static let sensitiveBundleIDs: Set<String> = [
        // Password Managers & Vaults
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.1password.1password",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "org.keepassxc.keepassxc",
        "com.dashlane.dashlanephone",
        "com.dashlane.Dashlane",
        "com.enpass.Enpass-Desktop",
        "com.nordpass.macos",
        "com.roboform.mac",
        "com.lastpass.LastPass",
        "org.whispersystems.signal-desktop",
        // Terminal Emulators (Sudo, SSH, Private Keys, Secret Environment Variables)
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "com.alacritty",
        "com.github.wez.wezterm",
        "co.zeit.hyper"
    ]
    
    public var isEnabled: Bool = true
    
    // 10.0pt threshold prevents false positive copies during micro-jitters or single clicks
    public var dragThreshold: CGFloat = 10.0
    // 150ms delay accommodates the macOS double-click timeframe (typically up to 500ms) 
    // and ensures UI highlighting is fully rendered before Cmd+C dispatch
    public var copyDelayMs: UInt64 = 150
    
    public var onCopyKeystrokePosted: (@MainActor () -> Void)?
    
    private var eventTapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMouseDownMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var mouseDownLocation: CGPoint?
    private var pendingCopyTask: Task<Void, Never>?
    public private(set) var isStarted: Bool = false
    
    public var hasPendingCopy: Bool {
        guard let task = pendingCopyTask else { return false }
        return !task.isCancelled
    }
    
    public func cancelPendingCopy() {
        pendingCopyTask?.cancel()
        pendingCopyTask = nil
    }
    
    public var isInteractingWithNNTSWindow: Bool {
        guard let app = (NSApp as NSApplication?) else { return false }
        if app.isActive { return true }
        if let frontID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           let myID = Bundle.main.bundleIdentifier,
           frontID == myID {
            return true
        }
        let mouseLoc = NSEvent.mouseLocation
        return app.windows.contains { window in
            window.isVisible && !(window is CopyToastWindow) && !(window is MinimalHUDWindow) && NSPointInRect(mouseLoc, window.frame)
        }
    }
    
    private let logger = Logger(subsystem: "com.almosteleven.nnts", category: "copy-on-select")
    
    public init() {}
    
    public func start() {
        guard !isStarted else { return }
        
        guard AXIsProcessTrusted() else {
            logger.warning("Accessibility permission missing. CopyOnSelectEngine tap cannot be registered.")
            return
        }
        
        let eventMask: CGEventMask = (
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)
        )
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        if let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return nil }
                let engine = Unmanaged<CopyOnSelectEngine>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    engine.handleTapEvent(type: type, event: event)
                    return nil
                }
                engine.handleTapEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: selfPtr
        ) {
            eventTapPort = tap
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            isStarted = true
            logger.info("CopyOnSelectEngine started with CGEventTap (.listenOnly).")
            TelemetryBuffer.shared.append(category: "copy-on-select", level: "INFO", message: "CopyOnSelectEngine started with CGEventTap.")
        } else {
            logger.warning("CGEventTap creation failed. Falling back to NSEvent global monitors.")
            installNSEventMonitors()
        }
    }
    
    public func stop() {
        cancelPendingCopy()
        if let tap = eventTapPort {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTapPort = nil
            runLoopSource = nil
        }
        if let monitor = globalMouseDownMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseDownMonitor = nil
        }
        if let monitor = globalMouseUpMonitor {
            NSEvent.removeMonitor(monitor)
            globalMouseUpMonitor = nil
        }
        mouseDownLocation = nil
        isStarted = false
        logger.info("CopyOnSelectEngine stopped.")
        TelemetryBuffer.shared.append(category: "copy-on-select", level: "INFO", message: "CopyOnSelectEngine stopped.")
    }
    
    private func installNSEventMonitors() {
        guard globalMouseDownMonitor == nil else { return }
        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let engine = self, engine.isEnabled else { return }
                guard !engine.isInteractingWithNNTSWindow else {
                    engine.mouseDownLocation = nil
                    return
                }
                engine.cancelPendingCopy()
                let flags = NSEvent.modifierFlags
                if flags.contains(.command) || flags.contains(.control) {
                    engine.mouseDownLocation = nil
                    return
                }
                engine.mouseDownLocation = NSEvent.mouseLocation
            }
        }
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let engine = self, engine.isEnabled else { return }
                guard !engine.isInteractingWithNNTSWindow else {
                    engine.mouseDownLocation = nil
                    return
                }
                let flags = event.modifierFlags
                if flags.contains(.command) || flags.contains(.control) {
                    engine.mouseDownLocation = nil
                    return
                }
                let start = engine.mouseDownLocation ?? NSEvent.mouseLocation
                engine.mouseDownLocation = nil
                let end = NSEvent.mouseLocation
                let clicks = event.clickCount
                if engine.shouldTriggerCopy(start: start, end: end, clickCount: clicks) {
                    engine.scheduleCopy()
                }
            }
        }
        isStarted = true
        logger.info("CopyOnSelectEngine started with NSEvent global monitors.")
        TelemetryBuffer.shared.append(category: "copy-on-select", level: "INFO", message: "CopyOnSelectEngine started with NSEvent monitors.")
    }
    
    public func handleTapEvent(type: CGEventType, event: CGEvent) {
        // Auto-recover tap if disabled by system timeout or user input
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port = eventTapPort {
                CGEvent.tapEnable(tap: port, enable: true)
                logger.info("Auto-recovered disabled event tap in CopyOnSelectEngine.")
            }
            return
        }
        
        guard isEnabled else { return }
        
        if isInteractingWithNNTSWindow {
            cancelPendingCopy()
            mouseDownLocation = nil
            return
        }
        
        // Ignore drags with Command or Control held (e.g. Cmd-drag windows, Ctrl-drag Xcode outlets)
        if event.flags.contains(.maskCommand) || event.flags.contains(.maskControl) {
            cancelPendingCopy()
            mouseDownLocation = nil
            return
        }
        
        if type == .leftMouseDown {
            cancelPendingCopy()
            mouseDownLocation = event.location
        } else if type == .leftMouseUp {
            guard let start = mouseDownLocation else { return }
            mouseDownLocation = nil
            let end = event.location
            let clicks = Int(event.getIntegerValueField(.mouseEventClickState))
            if shouldTriggerCopy(start: start, end: end, clickCount: clicks) {
                scheduleCopy()
            }
        }
    }
    
    public func isFocusedElementSecure() -> Bool {
        if IsSecureEventInputEnabled() { return true }
        var focusedElement: CFTypeRef?
        let systemWide = AXUIElementCreateSystemWide()
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement,
              CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return false
        }
        
        // Safe cast verified via CFGetTypeID
        let axElement = element as! AXUIElement
        
        // 1. Check Subrole (e.g. AXSecureTextField)
        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXSubroleAttribute as CFString, &subrole) == .success,
           let subroleStr = subrole as? String {
            if subroleStr == "AXSecureTextField" || subroleStr == (kAXSecureTextFieldSubrole as String) {
                return true
            }
        }
        
        // 2. Check Role directly (some custom apps / WebKit controls set AXRole to AXSecureTextField)
        var role: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &role) == .success,
           let roleStr = role as? String {
            if roleStr == "AXSecureTextField" || roleStr == (kAXSecureTextFieldSubrole as String) {
                return true
            }
        }
        
        return false
    }
    
    public func shouldTriggerCopy(start: CGPoint, end: CGPoint, clickCount: Int) -> Bool {
        guard isEnabled else { return false }
        if isInteractingWithNNTSWindow { return false }
        
        // Level 1: System-wide Secure Event Input check (e.g. password field / sudo active)
        if IsSecureEventInputEnabled() {
            logger.debug("Copy skipped: IsSecureEventInputEnabled is true.")
            return false
        }
        
        // Level 2: Frontmost application sensitive blacklist (Password managers & terminal)
        if let frontmostID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           Self.sensitiveBundleIDs.contains(frontmostID) {
            logger.debug("Copy skipped: Frontmost app '\(frontmostID)' is sensitive.")
            return false
        }
        
        if clickCount > 1 {
            return true
        }
        let dx = abs(end.x - start.x)
        let dy = abs(end.y - start.y)
        return dx > dragThreshold || dy > dragThreshold
    }
    
    public func scheduleCopy() {
        cancelPendingCopy()
        let delay = copyDelayMs
        TelemetryBuffer.shared.append(
            category: "copy-on-select",
            level: "INFO",
            message: "Text selection detected; scheduling Cmd+C in \(delay)ms."
        )
        pendingCopyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
            guard !Task.isCancelled else { return }
            guard let engine = self, engine.isEnabled && engine.isStarted else { return }
            guard !engine.isInteractingWithNNTSWindow else { return }
            
            // Level 3: Accessibility field check right before posting synthetic keystroke
            guard !engine.isFocusedElementSecure() else {
                engine.logger.info("Copy skipped: Focused element is secure or password field.")
                return
            }
            
            // Level 4: Pre-flight accessibility check for empty string selection
            if let selectedText = engine.focusedElementSelectedText(),
               Self.isStringEmptyOrWhitespace(selectedText) {
                engine.logger.debug("Copy skipped: Accessibility selected text is empty string or whitespace.")
                TelemetryBuffer.shared.append(
                    category: "copy-on-select",
                    level: "INFO",
                    message: "Copy on select suppressed: AX selected text is empty string."
                )
                return
            }
            
            engine.postCopyKeystroke()
        }
    }
    
    public static var mockFocusedSelectedText: String? = nil
    
    public func focusedElementSelectedText() -> String? {
        if let mock = Self.mockFocusedSelectedText {
            return mock
        }
        var focusedElement: CFTypeRef?
        let systemWide = AXUIElementCreateSystemWide()
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement,
              CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return nil
        }
        
        let axElement = element as! AXUIElement
        var selectedTextRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selectedTextRef) == .success,
           let text = selectedTextRef as? String {
            return text
        }
        return nil
    }
    
    public static func isStringEmptyOrWhitespace(_ text: String?) -> Bool {
        guard let text = text else { return true }
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    public func postCopyKeystroke() {
        let initialChangeCount = NSPasteboard.general.changeCount
        
        // Snapshot current pasteboard items for clean restoration if Cmd+C produces an empty string
        let previousItems: [[NSPasteboard.PasteboardType: Data]] = NSPasteboard.general.pasteboardItems?.compactMap { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        } ?? []
        
        let src = CGEventSource(stateID: .hidSystemState)
        let cKeyCode: CGKeyCode = CGKeyCode(KeyCodes.kVK_ANSI_C)
        guard let down = CGEvent(keyboardEventSource: src, virtualKey: cKeyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: src, virtualKey: cKeyCode, keyDown: false) else {
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.setIntegerValueField(.eventSourceUserData, value: CapsLockEngine.syntheticMarker)
        up.setIntegerValueField(.eventSourceUserData, value: CapsLockEngine.syntheticMarker)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        logger.debug("Synthesized Cmd+C copy keystroke.")
        onCopyKeystrokePosted?()
        
        let mousePos = NSEvent.mouseLocation
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // Wait 50ms for target application to process Cmd+C keystroke
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard self.isEnabled && self.isStarted else { return }
            
            var newCount = NSPasteboard.general.changeCount
            if newCount == initialChangeCount {
                // Poll once more after another 70ms for heavier applications (e.g. Chromium, Electron)
                try? await Task.sleep(nanoseconds: 70_000_000)
                guard self.isEnabled && self.isStarted else { return }
                newCount = NSPasteboard.general.changeCount
            }
            
            _ = self.evaluateCopiedContent(
                initialChangeCount: initialChangeCount,
                previousItems: previousItems,
                mousePos: mousePos
            )
        }
    }
    
    @discardableResult
    public func evaluateCopiedContent(
        initialChangeCount: Int,
        previousItems: [[NSPasteboard.PasteboardType: Data]],
        mousePos: CGPoint
    ) -> Bool {
        let newCount = NSPasteboard.general.changeCount
        let didChange = newCount != initialChangeCount
        TelemetryBuffer.shared.append(
            category: "copy-on-select",
            level: "INFO",
            message: "Cmd+C evaluated: changeCount \(initialChangeCount) -> \(newCount) (copied: \(didChange))"
        )
        
        if didChange {
            // Level 5: Filter out empty strings and whitespace-only copied text
            if let newString = NSPasteboard.general.string(forType: .string),
               Self.isStringEmptyOrWhitespace(newString) {
                logger.debug("Cmd+C resulted in empty string; filtering out copy and restoring previous pasteboard.")
                TelemetryBuffer.shared.append(
                    category: "copy-on-select",
                    level: "INFO",
                    message: "Copy on select suppressed: copied string was empty or whitespace only."
                )
                
                // Restore previous pasteboard contents to prevent clobbering user's clipboard
                NSPasteboard.general.clearContents()
                if !previousItems.isEmpty {
                    for itemDict in previousItems {
                        let newItem = NSPasteboardItem()
                        for (type, data) in itemDict {
                            newItem.setData(data, forType: type)
                        }
                        NSPasteboard.general.writeObjects([newItem])
                    }
                }
                return false
            }
            
            CopyToastWindow.shared.show(at: mousePos)
            TelemetryBuffer.shared.append(
                category: "copy-on-select",
                level: "INFO",
                message: "Toast 'Copied!' displayed at (\(Int(mousePos.x)), \(Int(mousePos.y)))"
            )
            return true
        } else {
            logger.debug("Pasteboard unchanged after Cmd+C; suppressing false Copied toast.")
            return false
        }
    }
}
