import Foundation
import CoreGraphics
import AppKit
import Cocoa
import Carbon
import os

// MARK: - Copy on Select Filter Rules & Protective Heuristics
extension CopyOnSelectEngine {
    
    /// Inviolable password managers, vaults, and authenticators where automated copy-on-select
    /// must NEVER trigger under ANY circumstances, even if allowEverywhere is enabled.
    public static let immutableVaultBundleIDs: Set<String> = [
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.apple.PasskeysCredentialProvider",
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
        "me.proton.pass",
        "com.proton.pass",
        "com.yubico.authenticator",
        "com.authy",
        "com.authy.authy-mac",
        "com.2fas.desktop",
        "com.strongbox.mac",
        "com.elpass.app",
        "org.whispersystems.signal-desktop"
    ]
    
    /// Terminal emulators where copy is disabled by default, but allowed if the user explicitly enables allowEverywhere.
    public static let developerTerminalBundleIDs: Set<String> = [
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
    
    /// Combined blacklisted applications where automated copy-on-select is restricted.
    public static var sensitiveBundleIDs: Set<String> {
        return immutableVaultBundleIDs.union(developerTerminalBundleIDs)
    }
    
    /// Native creative, CAD, DAW, design, whiteboard, and 3D applications where mouse dragging
    /// is primarily drawing, sculpting, timeline scrubbing, or canvas navigation — never text selection.
    public static var canvasAndDrawingBundleIDs: Set<String> = [
        // Vector, Drawing & Whiteboard Apps
        "com.apple.freeform",
        "com.figma.Desktop",
        "com.bohemiancoding.sketch3",
        "com.adobe.Photoshop",
        "com.adobe.Illustrator",
        "com.seriflabs.affinitydesigner2",
        "com.seriflabs.affinitydesigner",
        "com.seriflabs.affinityphoto2",
        "com.seriflabs.affinityphoto",
        "com.seriflabs.affinitypublisher2",
        "com.seriflabs.affinitypublisher",
        "com.pixelmatorteam.pixelmator.x",
        "org.inkscape.Inkscape",
        "com.canva.CanvaDesktop",
        "com.electron.realtimeboard",
        "com.miro.mac",
        "com.goodnotes.GoodNotes5",
        "com.goodnotes.goodnotes6",
        "com.gingerlabs.Notability",
        // 3D, CAD & Animation
        "org.blenderfoundation.blender",
        "org.blender.blender",
        "com.autodesk.Fusion360",
        "com.shapr3d.shapr",
        "com.maxon.cinema4d",
        // Digital Audio Workstations & Video Editors (timeline scrubbing & fader dragging)
        "com.apple.FinalCut",
        "com.apple.logic10",
        "com.apple.garageband10",
        "com.ableton.live",
        "com.blackmagic-design.DaVinciResolve",
        "com.adobe.PremierePro",
        "com.adobe.AfterEffects",
        "com.cockos.reaper",
        "com.bitwig.studio"
    ]
    
    /// Desktop spreadsheet applications where double clicks and drags are grid/cell navigation
    public static let spreadsheetBundleIDs: Set<String> = [
        "com.microsoft.Excel",
        "com.apple.iWork.Numbers",
        "org.libreoffice.script",
        "org.openoffice.script"
    ]
    
    /// Accessibility roles for UI controls where dragging adjusts values, position, or dividers, or clicks buttons
    public static let nonTextControlRoles: Set<String> = [
        "AXSlider",
        "AXScrollBar",
        "AXSplitter",
        "AXSplitGroup",
        "AXColorWell",
        "AXProgressIndicator",
        "AXValueIndicator",
        "AXCanvas",
        "AXColumnHeader",
        "AXRowHeader",
        "AXHeader",
        "AXTableColumn",
        "AXRulerMarker",
        "AXRuler",
        "AXHandle",
        "AXDockItem",
        "AXButton",
        "AXCheckBox",
        "AXRadioButton",
        "AXPopUpButton",
        "AXTab",
        "AXSegmentedControl",
        "AXSwitch",
        "AXMenuItem"
    ]
    
    /// Accessibility subroles for dividers, sort buttons, and resize handles
    public static let nonTextSubroles: Set<String> = [
        "AXSortButton",
        "AXHeaderButton",
        "AXResizeHandle",
        "AXDivider",
        "AXColumnSplitter"
    ]
    
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
    
    public func isPointOnNonTextControl(cgPoint: CGPoint) -> Bool {
        if let mock = Self.mockNonTextControlDetected {
            return mock
        }
        let systemWide = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(cgPoint.x), Float(cgPoint.y), &element) == .success,
              let el = element else {
            return false
        }
        
        func matchesNonTextRoleOrSubrole(_ target: AXUIElement) -> Bool {
            var roleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(target, kAXRoleAttribute as CFString, &roleRef) == .success,
               let role = roleRef as? String {
                if role == "AXCanvas" {
                    if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier?.lowercased() {
                        let knownBrowsers = ["chrome", "safari", "brave", "edge", "arc", "firefox", "orion", "opera", "vivaldi", "zen", "tor", "browser"]
                        if knownBrowsers.contains(where: { bundleID.contains($0) }) {
                            return false
                        }
                    }
                }
                if Self.nonTextControlRoles.contains(role) {
                    return true
                }
            }
            var subroleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(target, kAXSubroleAttribute as CFString, &subroleRef) == .success,
               let subrole = subroleRef as? String {
                if Self.nonTextSubroles.contains(subrole) {
                    return true
                }
            }
            return false
        }
        
        // 1. Direct hit on control
        if matchesNonTextRoleOrSubrole(el) {
            return true
        }
        
        // 2. Traversal up parent hierarchy (up to 2 levels) for nested header items or divider handles
        var current: AXUIElement = el
        for _ in 0..<2 {
            var parentRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(current, kAXParentAttribute as CFString, &parentRef) == .success,
                  let parent = parentRef,
                  CFGetTypeID(parent) == AXUIElementGetTypeID() else {
                break
            }
            let parentEl = parent as! AXUIElement
            if matchesNonTextRoleOrSubrole(parentEl) {
                return true
            }
            current = parentEl
        }
        
        return false
    }
    
    /// Detects whether the frontmost application is a native spreadsheet or web spreadsheet (Google Sheets / Microsoft 365)
    public static func isSpreadsheetEnvironmentActive() -> Bool {
        if let mock = mockSpreadsheetEnvironment {
            return mock
        }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return false }
        let bundleID = frontApp.bundleIdentifier ?? ""
        
        // 1. Desktop spreadsheet applications
        if Self.spreadsheetBundleIDs.contains(bundleID) {
            return true
        }
        
        // 2. Web browser running Google Sheets or Microsoft 365 / Excel Online
        let lowerID = bundleID.lowercased()
        let knownBrowsers = ["chrome", "safari", "brave", "edge", "arc", "firefox", "orion", "opera", "vivaldi", "zen", "tor", "browser"]
        if knownBrowsers.contains(where: { lowerID.contains($0) }) {
            let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
            var windowRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
               let window = windowRef,
               CFGetTypeID(window) == AXUIElementGetTypeID() {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let title = titleRef as? String {
                    let lowerTitle = title.lowercased()
                    if lowerTitle.contains("google sheets") ||
                       lowerTitle.contains("google таблицы") ||
                       lowerTitle.contains("google spreadsheets") ||
                       lowerTitle.contains("excel online") ||
                       lowerTitle.contains("excel |") ||
                       (lowerTitle.contains("excel") && (lowerTitle.contains("microsoft 365") || lowerTitle.contains("sharepoint") || lowerTitle.contains("onedrive") || lowerTitle.contains("office.com") || lowerTitle.contains("office365"))) {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    /// Checks whether the user is actively editing text in a spreadsheet cell or formula bar
    public func isEditingTextInSpreadsheet() -> Bool {
        if let mock = Self.mockEditingTextInSpreadsheet {
            return mock
        }
        if focusedElementSelectedText() != nil {
            return true
        }
        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedUIElementAttribute as CFString, &focusedElement) == .success,
              let element = focusedElement,
              CFGetTypeID(element) == AXUIElementGetTypeID() else {
            return false
        }
        let axElement = element as! AXUIElement
        var roleRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXRoleAttribute as CFString, &roleRef) == .success,
           let role = roleRef as? String {
            if role == "AXTextField" || role == "AXTextArea" {
                return true
            }
        }
        return false
    }
}
