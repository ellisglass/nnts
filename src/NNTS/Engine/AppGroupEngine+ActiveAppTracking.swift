import Foundation
import Cocoa
import AppKit
import ApplicationServices
import os

// MARK: - Last Active Window & Open App Prioritization
extension AppGroupEngine {
    public static var lastActiveBundleIDByLetter: [Character: String] = [:]
    public static var lastActiveTimestamps: [String: Date] = [:]
    public static var testOpenWindowsOverride: [String: Bool]? = nil
    
    internal static var globalAppSwitchObserver: NSObjectProtocol? = nil
    
    public static func startGlobalAppSwitchObserver() {
        guard globalAppSwitchObserver == nil else { return }
        globalAppSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { notif in
            guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            Task { @MainActor in
                recordActiveApp(bundleID: bundleID)
                let profileEngine = ChromeProfileEngine.shared
                if bundleID == profileEngine.browserBundleID ||
                   ChromeProfileEngine.supportedBrowsers.contains(where: { $0.bundleID == bundleID }) {
                    if profileEngine.profiles.count <= 1 || profileEngine.isLocalStateBlocked {
                        let prevCount = profileEngine.profiles.count
                        profileEngine.refreshProfiles()
                        if profileEngine.profiles.count != prevCount {
                            AppDelegate.shared?.updateDynamicShortcuts()
                            AppDelegate.shared?.updateMenu()
                        }
                    }
                }
            }
        }
    }
    
    public static func shortcutLetter(for bundleID: String) -> Character {
        if bundleID == ChromeProfileEngine.shared.browserBundleID ||
           ChromeProfileEngine.supportedBrowsers.contains(where: { $0.bundleID == bundleID }) {
            return ChromeProfileEngine.shared.primaryShortcutChar
        }
        if let pinned = pinnedAppItems().first(where: { $0.bundleID == bundleID }) {
            return Character((pinned.name.first(where: { $0.isLetter }) ?? "A").uppercased())
        }
        if let item = allDiscoveredItems().first(where: { $0.bundleID == bundleID }) {
            return Character((item.name.first(where: { $0.isLetter }) ?? "A").uppercased())
        }
        if let candidate = allEngines.flatMap({ $0.candidates }).first(where: { $0.bundleID == bundleID }) {
            return Character((candidate.name.first(where: { $0.isLetter }) ?? "A").uppercased())
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let name = (url.path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
            return Character((name.first(where: { $0.isLetter }) ?? "A").uppercased())
        }
        return "A"
    }
    
    public static func recordActiveApp(bundleID: String) {
        let now = Date()
        lastActiveTimestamps[bundleID] = now
        let char = shortcutLetter(for: bundleID)
        lastActiveBundleIDByLetter[char] = bundleID
        UserDefaults.standard.set(bundleID, forKey: "LastActiveApp_\(char)")
    }
    
    public static func lastActiveApp(for letter: Character) -> String? {
        if let inMemory = lastActiveBundleIDByLetter[letter] {
            return inMemory
        }
        return UserDefaults.standard.string(forKey: "LastActiveApp_\(letter)")
    }
    
    public static func hasOpenWindows(bundleID: String) -> Bool {
        if let override = testOpenWindowsOverride?[bundleID] {
            return override
        }
        if bypassLaunchInTests {
            return false
        }
        guard let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else {
            return false
        }
        let appElement = AXUIElementCreateApplication(running.processIdentifier)
        var windowsRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
           let windows = windowsRef as? [AXUIElement], !windows.isEmpty {
            for win in windows {
                var isMinRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &isMinRef) == .success,
                   let isMin = isMinRef as? Bool, isMin {
                    continue
                }
                return true
            }
        }
        return false
    }
    
    public static func resetActiveAppTrackingForTesting() {
        lastActiveBundleIDByLetter.removeAll()
        lastActiveTimestamps.removeAll()
        testOpenWindowsOverride = nil
        mockFrontmostBundleID = nil
        for k in UserDefaults.standard.dictionaryRepresentation().keys where k.hasPrefix("LastActiveApp_") {
            UserDefaults.standard.removeObject(forKey: k)
        }
    }
    
    public static func prioritizedBundleID(from bundleIDs: [String]) -> String? {
        guard !bundleIDs.isEmpty else { return nil }
        guard bundleIDs.count > 1 else { return bundleIDs.first }
        
        let char = shortcutLetter(for: bundleIDs[0])
        
        // 1. Check open windows
        let openBundleIDs = bundleIDs.filter { hasOpenWindows(bundleID: $0) }
        if !openBundleIDs.isEmpty {
            if let lastActive = lastActiveApp(for: char), openBundleIDs.contains(lastActive) {
                return lastActive
            }
            return openBundleIDs.max(by: { (lastActiveTimestamps[$0] ?? .distantPast) < (lastActiveTimestamps[$1] ?? .distantPast) }) ?? openBundleIDs.first
        }
        
        // 2. Fallback to MRU / last active
        if let lastActive = lastActiveApp(for: char), bundleIDs.contains(lastActive) {
            return lastActive
        }
        if let mostRecent = bundleIDs.max(by: { (lastActiveTimestamps[$0] ?? .distantPast) < (lastActiveTimestamps[$1] ?? .distantPast) }),
           lastActiveTimestamps[mostRecent] != nil {
            return mostRecent
        }
        
        return bundleIDs.first
    }
    
    public static func prioritizedItemIndex(for items: [AntigravityItem], letter: Character, frontmostBundleID: String?) -> Int {
        guard !items.isEmpty else { return 0 }
        guard items.count > 1 else { return 0 }
        
        let profileEngine = ChromeProfileEngine.shared
        
        // 1. If currently inside one of the items, cycle to the NEXT item
        if let currentIdx = items.firstIndex(where: { item in
            if item.bundleID == frontmostBundleID { return true }
            let itemIsBrowser = item.bundleID == profileEngine.browserBundleID ||
                                ChromeProfileEngine.supportedBrowsers.contains(where: { b in b.bundleID == item.bundleID })
            let frontIsBrowser = frontmostBundleID == profileEngine.browserBundleID ||
                                 (frontmostBundleID != nil && ChromeProfileEngine.supportedBrowsers.contains(where: { b in b.bundleID == frontmostBundleID! }))
            return itemIsBrowser && frontIsBrowser
        }) {
            return (currentIdx + 1) % items.count
        }
        
        // 2. Coming from outside: prioritize the last opened window / active app
        let openItems = items.filter { hasOpenWindows(bundleID: $0.bundleID) }
        if !openItems.isEmpty {
            if let lastActive = lastActiveApp(for: letter),
               let idx = openItems.firstIndex(where: { $0.bundleID == lastActive }) {
                let targetBundleID = openItems[idx].bundleID
                return items.firstIndex(where: { $0.bundleID == targetBundleID }) ?? 0
            }
            if let mostRecent = openItems.max(by: { (lastActiveTimestamps[$0.bundleID] ?? .distantPast) < (lastActiveTimestamps[$1.bundleID] ?? .distantPast) }),
               lastActiveTimestamps[mostRecent.bundleID] != nil,
               let idx = items.firstIndex(where: { $0.bundleID == mostRecent.bundleID }) {
                return idx
            }
            return items.firstIndex(where: { $0.bundleID == openItems.first!.bundleID }) ?? 0
        }
        
        // 3. Neither has open windows: check last active app or MRU timestamp
        if let lastActive = lastActiveApp(for: letter),
           let idx = items.firstIndex(where: { $0.bundleID == lastActive }) {
            return idx
        }
        
        if let mostRecent = items.max(by: { (lastActiveTimestamps[$0.bundleID] ?? .distantPast) < (lastActiveTimestamps[$1.bundleID] ?? .distantPast) }),
           lastActiveTimestamps[mostRecent.bundleID] != nil,
           let idx = items.firstIndex(where: { $0.bundleID == mostRecent.bundleID }) {
            return idx
        }
        
        return 0
    }
}
