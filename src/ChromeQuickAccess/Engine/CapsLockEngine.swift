import Foundation
import CoreGraphics
import AppKit
import Cocoa
import os

// MARK: - HID Mapping Service
public enum HIDMappingService {
    public static let hidCapsLock: UInt64 = 0x700000039
    public static let hidF18: UInt64 = 0x70000006D
    
    @discardableResult
    public static func applyCapsLockToF18() -> Bool {
        let json = "{\"UserKeyMapping\":[{\"HIDKeyboardModifierMappingSrc\":\(hidCapsLock),\"HIDKeyboardModifierMappingDst\":\(hidF18)}]}"
        let task = Process()
        task.launchPath = "/usr/bin/hidutil"
        task.arguments = ["property", "--set", json]
        do {
            try task.run()
            task.waitUntilExit()
            Logger(subsystem: "com.almosteleven.xomsky", category: "hid").info("Applied Caps Lock -> F18 mapping via hidutil.")
            return task.terminationStatus == 0
        } catch {
            Logger(subsystem: "com.almosteleven.xomsky", category: "hid").error("Failed to set hidutil mapping: \(error.localizedDescription)")
            return false
        }
    }
    
    @discardableResult
    public static func restoreDefaultMapping() -> Bool {
        let task = Process()
        task.launchPath = "/usr/bin/hidutil"
        task.arguments = ["property", "--set", "{\"UserKeyMapping\":[]}"]
        do {
            try task.run()
            task.waitUntilExit()
            Logger(subsystem: "com.almosteleven.xomsky", category: "hid").info("Restored default HID key mapping.")
            return task.terminationStatus == 0
        } catch {
            Logger(subsystem: "com.almosteleven.xomsky", category: "hid").error("Failed to restore hidutil mapping: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - CapsLock Engine (Modifier & Shortcuts)
@MainActor
public final class CapsLockEngine: @unchecked Sendable {
    public static let shared = CapsLockEngine()
    
    public static let f18KeyCode: Int64 = Int64(KeyCodes.kVK_F18) // 79 (0x4F)
    public static let capsLockKeyCode: Int64 = Int64(KeyCodes.kVK_CapsLock) // 57 (0x39)
    public static let syntheticMarker: Int64 = 0x43514150 // "CQAP"
    
    private var eventTapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    public private(set) var isStarted: Bool = false
    
    public var isCapsHeld: Bool = false
    public var isExternalHyperHeld: Bool = false
    public var capsUsedAsModifier: Bool = false
    
    /// Callbacks for actions
    public var onChromeTrigger: (@MainActor () -> Void)?
    public var onProfileTrigger: (@MainActor (Int) -> Void)?
    public var onModifierReleased: (@MainActor () -> Void)?
    public var onCancelTrigger: (@MainActor () -> Void)?
    public var onNavigateLeft: (@MainActor () -> Void)?
    public var onNavigateRight: (@MainActor () -> Void)?
    
    /// Dynamic hotkey triggers keyed by virtual keycode (app-name letter shortcuts)
    public var dynamicKeyTriggers: [UInt32: @MainActor () -> Void] = [:]
    
    private let logger = Logger(subsystem: "com.almosteleven.xomsky", category: "engine")
    
    public init() {
        setupWakeNotification()
    }
    
    public func start() {
        guard !isStarted else { return }
        
        // 1. Accessibility check
        guard AXIsProcessTrusted() else {
            logger.warning("Accessibility permission missing. Global event tap cannot be registered.")
            return
        }
        
        // 2. Remap Caps Lock -> F18 at driver level
        HIDMappingService.applyCapsLockToF18()
        
        // 3. Register CoreGraphics Head-Insert Event Tap
        let eventMask: CGEventMask = (
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue)
        )
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let engine = Unmanaged<CapsLockEngine>.fromOpaque(refcon).takeUnretainedValue()
                return engine.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: selfPtr
        ) else {
            logger.error("Failed to create CGEventTap for CapsLockEngine.")
            TelemetryBuffer.shared.append(category: "engine", level: "ERROR", message: "Failed to create CGEventTap.")
            Task { @MainActor in
                let alert = NSAlert()
                alert.messageText = "Accessibility Bug Detected"
                alert.informativeText = "macOS granted Accessibility permissions, but denied the event tap. This happens when an app is recompiled and macOS caches the previous cdhash.\n\nPlease remove Xomsky from System Settings > Privacy & Security > Accessibility and add it back."
                alert.alertStyle = .critical
                alert.runModal()
            }
            return
        }
        
        eventTapPort = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isStarted = true
        
        logger.info("CapsLockEngine event tap started successfully.")
        TelemetryBuffer.shared.append(category: "engine", level: "INFO", message: "CapsLockEngine event tap started.")
    }
    
    public func stop() {
        if let tap = eventTapPort {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTapPort = nil
            runLoopSource = nil
        }
        HIDMappingService.restoreDefaultMapping()
        isStarted = false
        isCapsHeld = false
        isExternalHyperHeld = false
        capsUsedAsModifier = false
    }
    
    private func setupWakeNotification() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.logger.info("System woke from sleep: Re-applying HID Caps Lock mapping.")
                HIDMappingService.applyCapsLockToF18()
                if let port = self.eventTapPort {
                    CGEvent.tapEnable(tap: port, enable: true)
                }
            }
        }
    }
    
    // MARK: - Event Tap Processing
    public func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Auto-recover tap if disabled by system load
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let port = eventTapPort {
                CGEvent.tapEnable(tap: port, enable: true)
                TelemetryBuffer.shared.append(category: "engine", level: "WARN", message: "Auto-recovered disabled event tap (\(type.rawValue)).")
            }
            return nil
        }
        
        // Ignore synthetic events generated by our own engine to prevent loops
        if event.getIntegerValueField(.eventSourceUserData) == Self.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }
        
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        
        // 1. F18 KeyDown: Caps Lock held down (remapped by hidutil)
        if type == .keyDown && keyCode == Self.f18KeyCode {
            if !isCapsHeld {
                isCapsHeld = true
                capsUsedAsModifier = false
            }
            return nil // Swallow F18 down
        }
        
        // 2. F18 KeyUp: Caps Lock released
        if type == .keyUp && keyCode == Self.f18KeyCode {
            let wasUsed = capsUsedAsModifier
            isCapsHeld = false
            capsUsedAsModifier = false
            
            if wasUsed {
                onModifierReleased?()
            }
            return nil // Swallow F18 up
        }
        
        // 3. Fallback for unremapped Caps Lock (flagsChanged on keycode 57)
        if type == .flagsChanged && keyCode == Self.capsLockKeyCode {
            let isDown = event.flags.contains(.maskAlphaShift)
            if isDown {
                isCapsHeld = true
                capsUsedAsModifier = false
            } else {
                let wasUsed = capsUsedAsModifier
                isCapsHeld = false
                capsUsedAsModifier = false
                if wasUsed {
                    onModifierReleased?()
                }
            }
            return nil
        }
        
        // 4. Fallback check for external multi-modifiers (Cmd + Opt + Ctrl + Shift)
        let multiModifierFlagsMask: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
        let isMultiModifiers = event.flags.contains(multiModifierFlagsMask)
        if type == .flagsChanged && keyCode != Self.capsLockKeyCode {
            if isMultiModifiers {
                if !isExternalHyperHeld {
                    isExternalHyperHeld = true
                    capsUsedAsModifier = false
                }
            } else if isExternalHyperHeld {
                let wasUsed = capsUsedAsModifier
                isExternalHyperHeld = false
                capsUsedAsModifier = false
                if wasUsed {
                    onModifierReleased?()
                }
            }
        }
        
        // 5. Intercept key combinations when Caps Lock or external multi-modifier is held
        if isCapsHeld || isExternalHyperHeld || isMultiModifiers {
            if type == .keyDown {
                // Ignore key autorepeat
                if event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
                    return nil
                }
                
                let uKeyCode = UInt32(keyCode)
                
                // Dynamic hotkey triggers (app-name letter shortcuts)
                if let dynamicTrigger = dynamicKeyTriggers[uKeyCode] {
                    capsUsedAsModifier = true
                    dynamicTrigger()
                    return nil // Swallow dynamic shortcut key
                }
                
                // Check for primary browser trigger (C for Chrome, B for Brave, etc.)
                let browserKeyCode = ChromeProfileEngine.shared.primaryShortcutKeyCode
                if uKeyCode == browserKeyCode {
                    capsUsedAsModifier = true
                    onChromeTrigger?()
                    return nil // Swallow primary browser shortcut
                }
                
                // Check for '1'..'8' (focus specific profile)
                if let char = KeyCodes.character(for: uKeyCode),
                   let digit = Int(char), digit >= 1 && digit <= 8 {
                    capsUsedAsModifier = true
                    onProfileTrigger?(digit)
                    return nil // Swallow number key
                }
                
                // Check for Escape (cancel HUD)
                if uKeyCode == KeyCodes.kVK_Escape {
                    capsUsedAsModifier = true
                    onCancelTrigger?()
                    return nil // Swallow Escape
                }
                
                // Check for Left / Up Arrow (previous profile)
                if uKeyCode == KeyCodes.kVK_LeftArrow || uKeyCode == KeyCodes.kVK_UpArrow {
                    capsUsedAsModifier = true
                    onNavigateLeft?()
                    return nil
                }
                
                // Check for Right / Down Arrow (next profile)
                if uKeyCode == KeyCodes.kVK_RightArrow || uKeyCode == KeyCodes.kVK_DownArrow {
                    capsUsedAsModifier = true
                    onNavigateRight?()
                    return nil
                }
                
                // Check for Tab / Shift-Tab
                if uKeyCode == KeyCodes.kVK_Tab {
                    capsUsedAsModifier = true
                    if event.flags.contains(.maskShift) {
                        onNavigateLeft?()
                    } else {
                        onNavigateRight?()
                    }
                    return nil
                }
                
                // Other keys: passthrough with Hyper flags
                capsUsedAsModifier = true
                let hyperFlags: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
                event.flags = CGEventFlags(rawValue: event.flags.rawValue | hyperFlags.rawValue)
                return Unmanaged.passUnretained(event)
            } else if type == .keyUp {
                // Swallow keyUp for intercepted keys so no stray events are sent
                let uKeyCode = UInt32(keyCode)
                let browserKeyCode = ChromeProfileEngine.shared.primaryShortcutKeyCode
                if dynamicKeyTriggers[uKeyCode] != nil ||
                   uKeyCode == browserKeyCode ||
                   uKeyCode == KeyCodes.kVK_Escape ||
                   uKeyCode == KeyCodes.kVK_Tab ||
                   uKeyCode == KeyCodes.kVK_LeftArrow ||
                   uKeyCode == KeyCodes.kVK_RightArrow ||
                   uKeyCode == KeyCodes.kVK_DownArrow ||
                   uKeyCode == KeyCodes.kVK_UpArrow {
                    return nil
                }
                if let char = KeyCodes.character(for: uKeyCode),
                   let digit = Int(char), digit >= 1 && digit <= 8 {
                    return nil
                }
                
                let hyperFlags: CGEventFlags = [.maskCommand, .maskAlternate, .maskControl, .maskShift]
                event.flags = CGEventFlags(rawValue: event.flags.rawValue | hyperFlags.rawValue)
                return Unmanaged.passUnretained(event)
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
}
