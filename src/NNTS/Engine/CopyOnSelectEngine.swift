import Foundation
import CoreGraphics
import AppKit
import Cocoa
import Carbon
import os

@MainActor
public final class CopyOnSelectEngine: @unchecked Sendable {
    public static let shared = CopyOnSelectEngine()
    
    public static let keyIsEnabled = "CopyOnSelect_IsEnabled"
    public static let keyIsToastEnabled = "CopyOnSelect_IsToastEnabled"
    public static let keyAllowEverywhere = "CopyOnSelect_AllowEverywhere"
    
    public static var mockFrontmostBundleID: String? = nil
    public static var mockNonTextControlDetected: Bool? = nil
    public static var mockSpreadsheetEnvironment: Bool? = nil
    public static var mockEditingTextInSpreadsheet: Bool? = nil
    public static var mockHasActiveTextSelection: Bool? = nil
    
    public var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.keyIsEnabled) == nil {
                return true // Default: Turn on
            }
            return UserDefaults.standard.bool(forKey: Self.keyIsEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.keyIsEnabled)
        }
    }
    
    public var isToastEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.keyIsToastEnabled) == nil {
                return false // Default: Toast off
            }
            return UserDefaults.standard.bool(forKey: Self.keyIsToastEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.keyIsToastEnabled)
        }
    }
    
    public var allowEverywhere: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.keyAllowEverywhere) == nil {
                return true // Default: Allow everywhere
            }
            return UserDefaults.standard.bool(forKey: Self.keyAllowEverywhere)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.keyAllowEverywhere)
        }
    }
    public var isTemporarilySuppressed: Bool = false
    
    // 7.0pt horizontal threshold catches short words/tokens while filtering single-click micro-jitters
    public var dragThreshold: CGFloat = 7.0
    // 15.0pt vertical threshold ensures multi-line drag selections are captured while filtering single-line vertical jitter
    public var multiLineVerticalThreshold: CGFloat = 15.0
    // 0.09s (90ms) minimum drag duration to reject rapid click-slips
    public var minDragDurationSeconds: TimeInterval = 0.09
    
    // 50ms delay for drag selection (selection is already complete upon mouseUp)
    public var dragCopyDelayMs: UInt64 = 50
    // 140ms delay for multi-click accommodates double- vs triple-click discrimination
    public var multiClickCopyDelayMs: UInt64 = 140
    // Backwards-compatible alias for multiClickCopyDelayMs
    public var copyDelayMs: UInt64 {
        get { multiClickCopyDelayMs }
        set { multiClickCopyDelayMs = newValue }
    }
    
    public var onCopyKeystrokePosted: (@MainActor () -> Void)?
    
    private var eventTapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMouseDownMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var mouseDownLocation: CGPoint?
    private var mouseDownTimestamp: TimeInterval?
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
                guard let engine = self, engine.isEnabled, !engine.isTemporarilySuppressed else { return }
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
                engine.mouseDownTimestamp = ProcessInfo.processInfo.systemUptime
            }
        }
        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            Task { @MainActor [weak self] in
                guard let engine = self, engine.isEnabled, !engine.isTemporarilySuppressed else { return }
                guard !engine.isInteractingWithNNTSWindow else {
                    engine.mouseDownLocation = nil
                    engine.mouseDownTimestamp = nil
                    return
                }
                let flags = event.modifierFlags
                if flags.contains(.command) || flags.contains(.control) {
                    engine.mouseDownLocation = nil
                    engine.mouseDownTimestamp = nil
                    return
                }
                let start = engine.mouseDownLocation ?? NSEvent.mouseLocation
                let startTimestamp = engine.mouseDownTimestamp ?? 0
                engine.mouseDownLocation = nil
                engine.mouseDownTimestamp = nil
                let end = NSEvent.mouseLocation
                let clicks = event.clickCount
                let duration = startTimestamp > 0 ? (ProcessInfo.processInfo.systemUptime - startTimestamp) : 1.0
                if engine.shouldTriggerCopy(start: start, end: end, clickCount: clicks, duration: duration) {
                    let screenHeight = NSScreen.screens.first?.frame.height ?? 1080
                    let cgStart = CGPoint(x: start.x, y: screenHeight - start.y)
                    let cgEnd = CGPoint(x: end.x, y: screenHeight - end.y)
                    engine.scheduleCopy(start: cgStart, end: cgEnd, clickCount: clicks, anchor: end)
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
        
        guard isEnabled, !isTemporarilySuppressed else { return }
        
        if isInteractingWithNNTSWindow {
            cancelPendingCopy()
            mouseDownLocation = nil
            mouseDownTimestamp = nil
            return
        }
        
        // Ignore drags with Command or Control held (e.g. Cmd-drag windows, Ctrl-drag Xcode outlets)
        if event.flags.contains(.maskCommand) || event.flags.contains(.maskControl) {
            cancelPendingCopy()
            mouseDownLocation = nil
            mouseDownTimestamp = nil
            return
        }
        
        if type == .leftMouseDown {
            cancelPendingCopy()
            mouseDownLocation = event.location
            mouseDownTimestamp = ProcessInfo.processInfo.systemUptime
        } else if type == .leftMouseUp {
            guard let start = mouseDownLocation else { return }
            let startTimestamp = mouseDownTimestamp ?? 0
            mouseDownLocation = nil
            mouseDownTimestamp = nil
            let end = event.location
            let clicks = Int(event.getIntegerValueField(.mouseEventClickState))
            let duration = startTimestamp > 0 ? (ProcessInfo.processInfo.systemUptime - startTimestamp) : 1.0
            if shouldTriggerCopy(start: start, end: end, clickCount: clicks, duration: duration) {
                // Use Cocoa global mouseLocation directly to avoid multi-monitor coordinate inversion errors
                let anchor = NSEvent.mouseLocation
                scheduleCopy(start: start, end: end, clickCount: clicks, anchor: anchor)
            }
        }
    }
    
    public func shouldTriggerCopy(
        start: CGPoint,
        end: CGPoint,
        clickCount: Int,
        duration: TimeInterval = 1.0
    ) -> Bool {
        guard isEnabled else { return false }
        if isInteractingWithNNTSWindow { return false }
        
        // Level 1: System-wide Secure Event Input check (e.g. password field / sudo active)
        if IsSecureEventInputEnabled() {
            logger.debug("Copy skipped: IsSecureEventInputEnabled is true.")
            return false
        }
        
        // Level 2A: Inviolable Password Managers & Vaults (NEVER bypassed, even under allowEverywhere)
        let frontmostID = Self.mockFrontmostBundleID ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let frontID = frontmostID {
            if Self.immutableVaultBundleIDs.contains(frontID) {
                logger.debug("Copy skipped: Frontmost app '\(frontID)' is an immutable security vault.")
                return false
            }
        }
        
        // Level 2B: Frontmost application developer terminal and canvas tools (governed by allowEverywhere)
        if !allowEverywhere {
            if let frontID = frontmostID {
                if Self.developerTerminalBundleIDs.contains(frontID) || Self.sensitiveBundleIDs.contains(frontID) {
                    logger.debug("Copy skipped: Frontmost app '\(frontID)' is sensitive terminal/app.")
                    return false
                }
                if Self.canvasAndDrawingBundleIDs.contains(frontID) {
                    logger.debug("Copy skipped: Frontmost app '\(frontID)' is a canvas/creative tool.")
                    return false
                }
            }
        }
        
        // Level 2.2: Spreadsheet environment protection (Excel, Google Sheets, Microsoft 365, Numbers)
        // Suppress grid/header/tab double-clicks and drag operations unless actively editing text in a cell or formula bar.
        if Self.isSpreadsheetEnvironmentActive() && !isEditingTextInSpreadsheet() {
            logger.debug("Copy skipped: Active spreadsheet environment and not editing text in cell/formula bar.")
            TelemetryBuffer.shared.append(
                category: "copy-on-select",
                level: "INFO",
                message: "Copy on select suppressed: Active spreadsheet grid/header interaction."
            )
            return false
        }
        
        if clickCount > 1 {
            return true
        }
        
        return isIntentionalTextDrag(start: start, end: end, duration: duration)
    }
    
    /// Evaluates whether a drag gesture represents an intentional text selection
    /// rather than a click-slip, micro-jitter, or accidental vertical drift.
    public func isIntentionalTextDrag(start: CGPoint, end: CGPoint, duration: TimeInterval) -> Bool {
        let dx = abs(end.x - start.x)
        let dy = abs(end.y - start.y)
        let distance = hypot(dx, dy)
        
        // Filter 1: Minimum Euclidean displacement (reject sub-threshold micro-jitters)
        guard distance >= dragThreshold else {
            return false
        }
        
        // Filter 2: Click-slip temporal rejection (rapid finger slips < 90ms under 18pt)
        if duration < minDragDurationSeconds && distance < 18.0 {
            logger.debug("Copy skipped: Rapid click-slip detected (duration: \(duration)s, distance: \(distance)pt).")
            return false
        }
        
        // Filter 3: Directional geometry rejection (pure vertical drift on single line)
        // In text lines, 2-3pt horizontal with small vertical drift does not select characters.
        if dx < 4.0 && dy < multiLineVerticalThreshold {
            logger.debug("Copy skipped: Pure vertical jitter on single line (dx: \(dx)pt, dy: \(dy)pt).")
            return false
        }
        
        // Filter 4: Must meet either horizontal text selection threshold or multi-line vertical threshold
        return dx >= dragThreshold || dy >= multiLineVerticalThreshold
    }
    
    /// Verifies via Accessibility whether the focused element has an active, non-zero text selection.
    /// Returns false if the focused element explicitly reports a caret with zero length (range.length == 0).
    public func hasActiveTextSelection() -> Bool {
        if let mock = Self.mockHasActiveTextSelection {
            return mock
        }
        
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement,
              CFGetTypeID(element) == AXUIElementGetTypeID() else {
            // If focused element cannot be inspected, fall back to letting Cmd+C proceed
            return true
        }
        
        let axElement = element as! AXUIElement
        
        // 1. Check selected text range (supported by standard Cocoa/WebKit/Xcode/VSCode text controls)
        var rangeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
           let val = rangeValue {
            var range = CFRange()
            if AXValueGetValue(val as! AXValue, .cfRange, &range) {
                // If range.length == 0, caret is blinking but zero characters are selected
                if range.length == 0 {
                    return false
                }
                return true
            }
        }
        
        // 2. Check selected text string directly if available
        var selectedTextRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXSelectedTextAttribute as CFString, &selectedTextRef) == .success,
           let text = selectedTextRef as? String {
            if text.isEmpty {
                return false
            }
            return true
        }
        
        return true
    }
    
    public func scheduleCopy(
        start: CGPoint? = nil,
        end: CGPoint? = nil,
        clickCount: Int = 1,
        anchor: CGPoint? = nil
    ) {
        cancelPendingCopy()
        let delay = clickCount > 1 ? multiClickCopyDelayMs : dragCopyDelayMs
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
            
            // Level 2.5: Non-text UI control check (sliders, scrollbars, splitters, headers, buttons)
            if let startPoint = start, engine.isPointOnNonTextControl(cgPoint: startPoint) {
                engine.logger.debug("Copy skipped: Drag started on non-text control.")
                TelemetryBuffer.shared.append(
                    category: "copy-on-select",
                    level: "INFO",
                    message: "Copy on select suppressed: Drag started on non-text control."
                )
                return
            }
            if let endPoint = end, engine.isPointOnNonTextControl(cgPoint: endPoint) {
                engine.logger.debug("Copy skipped: Drag ended on non-text control.")
                TelemetryBuffer.shared.append(
                    category: "copy-on-select",
                    level: "INFO",
                    message: "Copy on select suppressed: Drag ended on non-text control."
                )
                return
            }
            
            // Level 3: Accessibility field check right before posting synthetic keystroke
            guard !engine.isFocusedElementSecure() else {
                engine.logger.info("Copy skipped: Focused element is secure or password field.")
                return
            }
            
            // Level 3.5: Caret check (ensures cursor is not just blinking at length 0, avoiding copying full line on click-jitter)
            if clickCount == 1 && !engine.hasActiveTextSelection() {
                engine.logger.debug("Copy skipped: Focused element has caret only (zero selected characters).")
                TelemetryBuffer.shared.append(
                    category: "copy-on-select",
                    level: "INFO",
                    message: "Copy on select suppressed: Caret with zero selected characters."
                )
                return
            }
            
            engine.postCopyKeystroke(anchor: anchor)
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
    
    /// Detects whether copied text is internal structured data from a canvas, whiteboard,
    /// diagram editor, or vector tool rather than human-selected text.
    public static func isCanvasOrInternalEditorPayload(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        
        // 1. Direct canvas/whiteboard schema signatures
        let knownCanvasSignatures = [
            "\"type\":\"excalidraw/clipboard\"",
            "\"type\": \"excalidraw/clipboard\"",
            "\"type\":\"excalidraw/lib\"",
            "\"type\": \"excalidraw/lib\"",
            "\"type\":\"excalidraw\"",
            "\"type\": \"excalidraw\"",
            "\"type\":\"tldraw/clipboard\"",
            "\"type\": \"tldraw/clipboard\"",
            "\"type\":\"tldraw\"",
            "\"type\": \"tldraw\"",
            "\"schema\":\"miro\"",
            "\"schema\": \"miro\"",
            "\"application/vnd.miro\"",
            "\"type\":\"drawio\"",
            "\"type\": \"drawio\"",
            "\"figma.com\"",
            "<mxGraphModel",
            "<mxfile"
        ]
        for sig in knownCanvasSignatures {
            if trimmed.contains(sig) {
                return true
            }
        }
        
        // 2. Structured canvas/editor JSON payloads
        if (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) || (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")) {
            // Empty element collections produced when clicking/dragging on empty canvas or deselecting
            let emptyCanvasPatterns = [
                "\"elements\":[]",
                "\"elements\": []",
                "\"objects\":[]",
                "\"objects\": []",
                "\"shapes\":[]",
                "\"shapes\": []",
                "\"nodes\":[]",
                "\"nodes\": []"
            ]
            for pattern in emptyCanvasPatterns {
                if trimmed.contains(pattern) {
                    return true
                }
            }
            
            // Canvas element geometry dictionary heuristics (roughness, strokeWidth, fillStyle, etc.)
            let canvasPropertyMarkers = [
                "\"strokeColor\":",
                "\"strokeWidth\":",
                "\"roughness\":",
                "\"boundElements\":",
                "\"fillStyle\":"
            ]
            var markerCount = 0
            for marker in canvasPropertyMarkers {
                if trimmed.contains(marker) {
                    markerCount += 1
                }
            }
            if markerCount >= 2 {
                return true
            }
        }
        
        // 3. Standalone raw SVG canvas dumps
        if trimmed.hasPrefix("<svg") && trimmed.hasSuffix("</svg>") && !trimmed.contains("<p>") {
            return true
        }
        
        return false
    }
    
    /// Detects whether copied payload is an entire spreadsheet cell, range, or table structure
    /// copied from Google Sheets, Microsoft 365 / Excel, or Apple Numbers.
    public static func isSpreadsheetCellOrGridPayload(pasteboard: NSPasteboard = .general) -> Bool {
        // 1. HTML origin signatures
        if let html = pasteboard.string(forType: .html) {
            let knownSignatures = [
                "google-sheets-html-origin",
                "data-sheets-value",
                "data-sheets-userformat",
                "ProgId=\"Excel.Sheet\"",
                "ProgId='Excel.Sheet'",
                "ProgId=Excel.Sheet",
                "xmlns:x=\"urn:schemas-microsoft-com:office:excel\"",
                "xmlns:x='urn:schemas-microsoft-com:office:excel'"
            ]
            for sig in knownSignatures {
                if html.contains(sig) {
                    return true
                }
            }
        }
        
        // 2. Proprietary pasteboard types for desktop Excel and Numbers
        if let types = pasteboard.types {
            for type in types {
                let raw = type.rawValue.lowercased()
                if raw.contains("com.microsoft.excel") ||
                   raw.contains("iwork.tsucustomformat") ||
                   raw.contains("iwork.table") ||
                   raw == "xlss" {
                    return true
                }
            }
        }
        
        return false
    }
    
    public static func restorePreviousPasteboard(_ previousItems: [[NSPasteboard.PasteboardType: Data]]) {
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
    }
    
    public func postCopyKeystroke(anchor: CGPoint? = nil) {
        let initialChangeCount = NSPasteboard.general.changeCount
        
        // Snapshot current pasteboard items for clean restoration if Cmd+C produces an empty string or spreadsheet cell
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
        
        let mousePos = anchor ?? NSEvent.mouseLocation
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            // Hold keystroke down for 15ms so target application run loops register Cmd+C
            try? await Task.sleep(nanoseconds: 15_000_000)
            up.post(tap: .cghidEventTap)
            self.logger.debug("Synthesized Cmd+C copy keystroke.")
            self.onCopyKeystrokePosted?()
            
            // Poll every 20ms up to 450ms for target application to process Cmd+C
            var elapsed: UInt64 = 0
            let timeout: UInt64 = 450_000_000
            let interval: UInt64 = 20_000_000
            var newCount = NSPasteboard.general.changeCount
            while elapsed < timeout && newCount == initialChangeCount {
                try? await Task.sleep(nanoseconds: interval)
                elapsed += interval
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
            // Level 5A: Require valid plain-text content (filter out images, files, binary data)
            guard let newString = NSPasteboard.general.string(forType: .string) else {
                logger.debug("Cmd+C resulted in non-text payload (image/binary); restoring previous pasteboard.")
                TelemetryBuffer.shared.append(
                    category: "copy-on-select",
                    level: "INFO",
                    message: "Copy on select suppressed: clipboard content was not plain text."
                )
                Self.restorePreviousPasteboard(previousItems)
                return false
            }
            
            // Level 5B: Filter out empty strings, whitespace, and canvas/editor payloads
            if Self.isStringEmptyOrWhitespace(newString) || Self.isCanvasOrInternalEditorPayload(newString) {
                logger.debug("Cmd+C resulted in empty or canvas/editor payload; restoring previous pasteboard.")
                TelemetryBuffer.shared.append(
                    category: "copy-on-select",
                    level: "INFO",
                    message: "Copy on select suppressed: empty or canvas/editor payload filtered."
                )
                Self.restorePreviousPasteboard(previousItems)
                return false
            }
            
            // Level 5C: Filter out spreadsheet cell/grid payloads when not in active text edit mode
            if Self.isSpreadsheetCellOrGridPayload() && !isEditingTextInSpreadsheet() {
                logger.debug("Cmd+C resulted in spreadsheet cell/grid payload; restoring previous pasteboard.")
                TelemetryBuffer.shared.append(
                    category: "copy-on-select",
                    level: "INFO",
                    message: "Copy on select suppressed: spreadsheet cell/grid payload filtered."
                )
                Self.restorePreviousPasteboard(previousItems)
                return false
            }
            
            if isToastEnabled {
                CopyToastWindow.shared.show(at: mousePos)
                TelemetryBuffer.shared.append(
                    category: "copy-on-select",
                    level: "INFO",
                    message: "Toast 'Copied!' displayed at (\(Int(mousePos.x)), \(Int(mousePos.y)))"
                )
            } else {
                TelemetryBuffer.shared.append(
                    category: "copy-on-select",
                    level: "INFO",
                    message: "Text copied to clipboard; toast suppressed per user preference (toast off)."
                )
            }
            return true
        } else {
            logger.debug("Pasteboard unchanged after Cmd+C; suppressing false Copied toast.")
            return false
        }
    }
}
