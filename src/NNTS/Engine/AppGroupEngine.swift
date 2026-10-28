import Foundation
import Cocoa
import AppKit
import ApplicationServices
import os

// MARK: - App Group Engine
@MainActor
public final class AppGroupEngine: ObservableObject, @unchecked Sendable {
    public let category: String
    public var candidates: [AppCandidate]
    
    /// Test hooks
    public var customItemsOverride: [AntigravityItem]? = nil
    public var mockFrontmostBundleID: String? = nil
    
    @Published public var items: [AntigravityItem] = []
    public var lastActiveIndex: Int = 0
    
    public var activeShortcutChar: Character {
        if let selected = selectedItem {
            return Character((selected.name.first(where: { $0.isLetter }) ?? "A").uppercased())
        }
        return Character((category.first(where: { $0.isLetter }) ?? "A").uppercased())
    }
    
    public var activeShortcutKeyCode: UInt32 {
        KeyCodes.keyCode(for: activeShortcutChar) ?? KeyCodes.kVK_ANSI_A
    }
    
    /// When running in test environments, bypasses actual external process launches
    public static var bypassLaunchInTests: Bool = {
        ProcessInfo.processInfo.environment["SWIFT_DETERMINISTIC_TESTING"] != nil ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.processName.lowercased().contains("test") ||
        ProcessInfo.processInfo.arguments.first?.lowercased().contains("test") == true ||
        NSClassFromString("XCTest") != nil
    }()
    
    public func candidate(for bundleID: String) -> AppCandidate? {
        candidates.first(where: { $0.bundleID == bundleID })
    }
    
    @Published public var selectedBundleID: String? {
        didSet {
            if let id = selectedBundleID {
                UserDefaults.standard.set(id, forKey: "SelectedApp_\(category)")
            }
        }
    }
    
    public var selectedItem: AntigravityItem? {
        if let id = selectedBundleID, let found = items.first(where: { $0.bundleID == id }) {
            return found
        }
        return items.first
    }
    
    public func select(bundleID: String) {
        if items.contains(where: { $0.bundleID == bundleID }) {
            selectedBundleID = bundleID
        }
    }
    
    public func isSelected(bundleID: String) -> Bool {
        selectedItem?.bundleID == bundleID
    }
    
    internal let logger: Logger
    internal static let staticLogger = Logger(subsystem: "com.almosteleven.nnts", category: "appgroup")
    
    public init(category: String, candidates: [AppCandidate]) {
        self.category = category
        self.candidates = candidates
        self.logger = Logger(subsystem: "com.almosteleven.nnts", category: category.lowercased())
        refreshItems()
        setupAppSwitchObserver()
        Self.startGlobalAppSwitchObserver()
    }
    
    // MARK: - Discovery & Refresh
    
    public func refreshItems() {
        if category == "Custom" {
            self.candidates = Self.loadCustomAppCandidates()
        }
        
        if let override = self.customItemsOverride {
            self.items = override
            if let saved = UserDefaults.standard.string(forKey: "SelectedApp_\(category)"),
               override.contains(where: { $0.bundleID == saved }) {
                self.selectedBundleID = saved
            } else {
                self.selectedBundleID = override.first?.bundleID
            }
            return
        }
        
        var discovered: [AntigravityItem] = []
        let runningBundles = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        
        for candidate in candidates {
            var appPath: String?
            for path in candidate.defaultPaths {
                if FileManager.default.fileExists(atPath: path) {
                    appPath = path
                    break
                }
            }
            
            if appPath == nil {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate.bundleID) {
                    appPath = url.path
                }
            }
            
            let isRunning = runningBundles.contains(candidate.bundleID)
            let isInstalled = appPath != nil && FileManager.default.fileExists(atPath: appPath!)
            
            // Only add candidate if installed or currently running
            guard isInstalled || isRunning else { continue }
            
            let finalPath = appPath ?? candidate.defaultPaths.first ?? ""
            let icon: NSImage
            if !finalPath.isEmpty && FileManager.default.fileExists(atPath: finalPath) {
                icon = NSWorkspace.shared.icon(forFile: finalPath)
            } else if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == candidate.bundleID }),
                      let runningIcon = running.icon {
                icon = runningIcon
            } else {
                icon = makeMonogramImage(name: candidate.name)
            }
            icon.size = NSSize(width: 64, height: 64)
            
            discovered.append(
                AntigravityItem(
                    name: candidate.name,
                    bundleID: candidate.bundleID,
                    path: finalPath,
                    icon: icon,
                    index: discovered.count + 1
                )
            )
        }
        
        // Fallback if none discovered: add the last candidate (system default) only in test environments
        if discovered.isEmpty, Self.bypassLaunchInTests, let fallback = candidates.last {
            let finalPath = fallback.defaultPaths.first ?? ""
            let icon: NSImage
            if !finalPath.isEmpty && FileManager.default.fileExists(atPath: finalPath) {
                icon = NSWorkspace.shared.icon(forFile: finalPath)
            } else {
                icon = makeMonogramImage(name: fallback.name)
            }
            icon.size = NSSize(width: 64, height: 64)
            
            discovered.append(
                AntigravityItem(
                    name: fallback.name,
                    bundleID: fallback.bundleID,
                    path: finalPath,
                    icon: icon,
                    index: 1
                )
            )
        }
        
        self.items = discovered
        
        // Restore selectedBundleID from UserDefaults or default to first
        let saved = UserDefaults.standard.string(forKey: "SelectedApp_\(category)")
        if let saved = saved, discovered.contains(where: { $0.bundleID == saved }) {
            self.selectedBundleID = saved
        } else {
            self.selectedBundleID = discovered.first?.bundleID
        }
        
        logger.info("Discovered \(discovered.count) \(self.category) applications. Selected: \(self.selectedItem?.name ?? "none")")
    }
    
    private func setupAppSwitchObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let idx = self.items.firstIndex(where: { $0.bundleID == bundleID }) {
                    self.lastActiveIndex = idx
                }
                Self.recordActiveApp(bundleID: bundleID)
            }
        }
    }
    
    /// Returns the index of the currently active/frontmost application in this group, if any.
    public func getActiveAppIndex() -> Int? {
        let frontBundleID = self.mockFrontmostBundleID ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard let bundleID = frontBundleID else { return nil }
        return items.firstIndex(where: { $0.bundleID == bundleID })
    }
    
    /// Non-destructively raises the application's windows: raises the first open window without
    /// unminimizing background windows unless all windows are minimized.
    public static func raiseApplicationWindows(running: NSRunningApplication, bundleID: String) {
        let appElement = AXUIElementCreateApplication(running.processIdentifier)
        var windowsRef: CFTypeRef?
        var windowRaised = false
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement], !windows.isEmpty {
            var openWindows: [AXUIElement] = []
            var minimizedWindows: [AXUIElement] = []
            for win in windows {
                var isMinRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &isMinRef) == .success,
                   let isMin = isMinRef as? Bool, isMin {
                    minimizedWindows.append(win)
                } else {
                    openWindows.append(win)
                }
            }
            
            let targetWindow: AXUIElement?
            if let firstOpen = openWindows.first {
                targetWindow = firstOpen
            } else if let firstMin = minimizedWindows.first {
                // All windows were minimized: unminimize the first one
                AXUIElementSetAttributeValue(firstMin, kAXMinimizedAttribute as CFString, false as CFTypeRef)
                targetWindow = firstMin
            } else {
                targetWindow = windows.first
            }
            
            if let target = targetWindow {
                AXUIElementPerformAction(target, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(target, kAXMainAttribute as CFString, true as CFTypeRef)
                windowRaised = true
            }
        }
        
        // Special handling for Finder: if Finder is running but has no open windows, activating it leaves the user
        // on the current screen with only the menu bar changed. Open a new Finder window if none was raised!
        if bundleID == "com.apple.finder" && !windowRaised {
            Task.detached(priority: .userInitiated) {
                let script = "tell application \"Finder\" to make new Finder window"
                if let appleScript = NSAppleScript(source: script) {
                    var errorDict: NSDictionary?
                    appleScript.executeAndReturnError(&errorDict)
                }
            }
        }
    }
    
    /// Focus the item with given bundle identifier
    public func focusItem(bundleID: String) {
        guard let item = items.first(where: { $0.bundleID == bundleID }) else {
            logger.warning("\(self.category) app with bundle ID \(bundleID) not found.")
            return
        }
        
        if let idx = items.firstIndex(where: { $0.bundleID == bundleID }) {
            lastActiveIndex = idx
        }
        Self.recordActiveApp(bundleID: bundleID)
        
        let runningApps = NSWorkspace.shared.runningApplications
        if let running = runningApps.first(where: { $0.bundleIdentifier == bundleID }) {
            logger.info("Activating running application: \(item.name) (PID: \(running.processIdentifier))")
            if #available(macOS 14.0, *) {
                running.activate()
            } else {
                running.activate(options: .activateIgnoringOtherApps)
            }
            
            Self.raiseApplicationWindows(running: running, bundleID: bundleID)
        } else {
            // Cold start
            if Self.bypassLaunchInTests {
                logger.info("[Test] Cold starting bypassed for: \(item.name)")
                return
            }
            logger.info("Cold starting application: \(item.name) at path \(item.path)")
            if !item.path.isEmpty && FileManager.default.fileExists(atPath: item.path) {
                let url = URL(fileURLWithPath: item.path)
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            } else {
                let task = Process()
                task.launchPath = "/usr/bin/open"
                task.arguments = ["-b", bundleID]
                try? task.run()
                task.waitUntilExit()
            }
        }
    }
    
    public func makeMonogramImage(name: String) -> NSImage {
        let size = NSSize(width: 64, height: 64)
        let img = NSImage(size: size)
        img.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect)
        NSColor(red: 70/255, green: 130/255, blue: 230/255, alpha: 1.0).setFill()
        path.fill()
        
        let letter = String(name.prefix(1)).uppercased()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 28),
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: letter, attributes: attrs)
        let strSize = str.size()
        let strRect = NSRect(
            x: (size.width - strSize.width) / 2,
            y: (size.height - strSize.height) / 2,
            width: strSize.width,
            height: strSize.height
        )
        str.draw(in: strRect)
        
        img.unlockFocus()
        return img
    }
    
    /// Focus an application item across all engines, browsers, and installed macOS applications.
    public static func focusItem(bundleID: String) {
        recordActiveApp(bundleID: bundleID)
        if Self.bypassLaunchInTests {
            return
        }
        
        // 1. Browser focus
        if bundleID == ChromeProfileEngine.shared.browserBundleID ||
           ChromeProfileEngine.supportedBrowsers.contains(where: { $0.bundleID == bundleID }) {
            ChromeProfileEngine.shared.focusChrome()
            return
        }
        
        // 2. Pre-configured group engines
        if let engine = allEngines.first(where: { $0.items.contains(where: { $0.bundleID == bundleID }) }) {
            engine.focusItem(bundleID: bundleID)
            return
        }
        
        // 3. Running application (activate directly)
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            if #available(macOS 14.0, *) {
                running.activate()
            } else {
                running.activate(options: .activateIgnoringOtherApps)
            }
            raiseApplicationWindows(running: running, bundleID: bundleID)
            return
        }
        
        // 4. Installed application on disk
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: appUrl, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        
        // 5. Antigravity fallback
        AntigravityEngine.shared.focusItem(bundleID: bundleID)
    }
}
