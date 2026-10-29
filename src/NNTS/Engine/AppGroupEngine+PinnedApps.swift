import Foundation
import Cocoa
import AppKit
import CoreServices
import os

// MARK: - Pinned Apps & Slot Management
extension AppGroupEngine {
    
    /// Maximum number of non-browser pinned quick apps (4 pinned + 1 Chrome/browser = 5 quick apps total in Free tier; unlimited in Pro)
    public static var maxPinnedQuickApps: Int {
        LicenseEngine.shared.isPro ? 26 : LicenseEngine.freePinnedAppsLimit
    }
    
    public static let freePinnedAppsLimit = 4
    
    /// Default pinned quick apps fallback (4 core apps + 1 Chrome/browser = 5 quick apps total)
    public static let defaultPinnedBundleIDs: [String] = [
        "com.google.antigravity",
        "com.google.antigravity-ide",
        "com.googlecode.iterm2",
        "com.apple.Notes"
    ]
    
    /// Discovers smart default pinned application bundle IDs on fresh installations.
    /// Prioritizes verified installed developer/workstation applications and user Dock favorites,
    /// ensuring zero dashed placeholder ('app.dashed') icons on clean macOS machines.
    public static func discoverSmartDefaultPinnedBundleIDs() -> [String] {
        var chosen: [String] = []
        let activeBrowserBundleID = ChromeProfileEngine.shared.browserBundleID
        
        // Helper to check if an app is installed on this Mac
        func isInstalled(_ bundleID: String) -> Bool {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
        }
        
        // Helper to query launch count from Spotlight metadata
        func usageCount(for bundleID: String) -> Int {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
                  let item = MDItemCreate(kCFAllocatorDefault, url.path as CFString),
                  let count = MDItemCopyAttribute(item, "kMDItemUseCount" as CFString) as? Int else {
                return 0
            }
            return count
        }
        
        // 1. Core workstation category preferences: select the best installed app per slot
        let workstationCategories: [[String]] = [
            // Terminal slot: Ghostty -> iTerm2 -> Warp -> Terminal.app (Terminal.app always present on macOS)
            ["com.mitchellh.ghostty", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.apple.Terminal"],
            // IDE / Code editor slot: Antigravity IDE -> VSCode -> Cursor -> Xcode -> Zed -> TextEdit
            ["com.google.antigravity-ide", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "com.apple.dt.Xcode", "dev.zed.Zed", "com.sublimetext.4", "com.apple.TextEdit"],
            // AI Assistant / Communication slot: Antigravity -> Telegram -> Slack -> Discord -> Messages
            ["com.google.antigravity", "com.tdesktop.Telegram", "com.tinyspeck.slackmacgap", "com.hnc.Discord", "com.apple.MobileSMS"],
            // Notes & Knowledge slot: Notes.app -> Obsidian -> Notion -> Bear
            ["com.apple.Notes", "md.obsidian", "notion.id", "net.shinyfrog.bear-mac"]
        ]
        
        for category in workstationCategories {
            for bundle in category {
                if bundle != activeBrowserBundleID && isInstalled(bundle) {
                    if !chosen.contains(bundle) {
                        chosen.append(bundle)
                        break
                    }
                }
            }
        }
        
        // 2. If slots remain (< 4), inspect user's Dock persistent-apps (user-curated favorites)
        if chosen.count < freePinnedAppsLimit {
            let dockPlistPath = ("~/Library/Preferences/com.apple.dock.plist" as NSString).expandingTildeInPath
            if let dict = NSDictionary(contentsOfFile: dockPlistPath),
               let persistentApps = dict["persistent-apps"] as? [[String: Any]] {
                var dockCandidates: [(bundle: String, count: Int)] = []
                for item in persistentApps {
                    if let tileData = item["tile-data"] as? [String: Any],
                       let bundle = tileData["bundle-identifier"] as? String {
                        if bundle != activeBrowserBundleID &&
                           !bundle.lowercased().contains("chrome") &&
                           !bundle.lowercased().contains("safari") &&
                           !chosen.contains(bundle) &&
                           isInstalled(bundle) {
                            dockCandidates.append((bundle: bundle, count: usageCount(for: bundle)))
                        }
                    }
                }
                dockCandidates.sort(by: { $0.count > $1.count })
                for candidate in dockCandidates {
                    chosen.append(candidate.bundle)
                    if chosen.count >= freePinnedAppsLimit { break }
                }
            }
        }
        
        // 3. Fallback: if still fewer than 4, check defaultPinnedBundleIDs that are actually installed
        if chosen.count < freePinnedAppsLimit {
            for bundle in defaultPinnedBundleIDs {
                if !chosen.contains(bundle) && isInstalled(bundle) {
                    chosen.append(bundle)
                    if chosen.count >= freePinnedAppsLimit { break }
                }
            }
        }
        
        // 4. Guaranteed macOS native fallbacks
        let nativeFallbacks = ["com.apple.Terminal", "com.apple.Notes", "com.apple.TextEdit", "com.apple.calculator"]
        if chosen.count < freePinnedAppsLimit {
            for bundle in nativeFallbacks {
                if !chosen.contains(bundle) && isInstalled(bundle) {
                    chosen.append(bundle)
                    if chosen.count >= freePinnedAppsLimit { break }
                }
            }
        }
        
        // 5. Ultimate fallback for headless test runners with mocked candidates
        if chosen.isEmpty {
            return defaultPinnedBundleIDs
        }
        
        return Array(chosen.prefix(freePinnedAppsLimit))
    }
    
    /// Known phantom/fallback bundle IDs produced by legacy versions when categories were empty.
    public static let legacyPhantomBundleIDs: Set<String> = [
        "com.openai.chat",
        "com.apple.dt.Xcode",
        "com.google.antigravity",
        "com.google.antigravity-ide",
        "com.googlecode.iterm2"
    ]
    
    public static let migrationV116Key = "DidMigrateLegacyPinnedAppsV116"
    
    /// Migrates saved pinned apps by stripping legacy phantom fallback apps that are not installed on this machine,
    /// seamlessly backfilling empty slots with genuine workstation apps from discoverSmartDefaultPinnedBundleIDs().
    public static func migrateLegacyPinnedAppsIfNeeded(force: Bool = false) {
        if !force {
            guard !bypassLaunchInTests else { return }
            guard !UserDefaults.standard.bool(forKey: migrationV116Key) else { return }
        }
        
        defer {
            UserDefaults.standard.set(true, forKey: migrationV116Key)
        }
        
        guard let saved = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs"), !saved.isEmpty else {
            return
        }
        
        func isInstalled(_ bundleID: String) -> Bool {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
        }
        
        // Check if any saved bundle ID is an uninstalled legacy phantom
        let hasUninstalledLegacyPhantom = saved.contains { bundleID in
            legacyPhantomBundleIDs.contains(bundleID) && !isInstalled(bundleID)
        }
        guard hasUninstalledLegacyPhantom else { return }
        
        // Keep all installed saved apps
        var validApps = saved.filter { isInstalled($0) }
        
        // If slots are below limit, backfill with smart defaults that are actually installed
        if validApps.count < freePinnedAppsLimit {
            let smartDefaults = discoverSmartDefaultPinnedBundleIDs()
            for candidate in smartDefaults {
                if !validApps.contains(candidate) && isInstalled(candidate) {
                    validApps.append(candidate)
                    if validApps.count >= freePinnedAppsLimit { break }
                }
            }
        }
        
        if validApps.isEmpty {
            validApps = defaultPinnedBundleIDs
        }
        
        let cleaned = Array(validApps.prefix(maxPinnedQuickApps))
        UserDefaults.standard.set(cleaned, forKey: "SelectedAppBundleIDs")
        staticLogger.info("Migrated legacy pinned apps. Cleaned list: \(cleaned)")
    }
    
    public static var selectedBundleIDs: Set<String> {
        get {
            if let saved = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs"), !saved.isEmpty {
                return Set(saved.prefix(maxPinnedQuickApps))
            }
            var initial: [String] = []
            let legacyKeys = [
                "SelectedApp_AI Agent",
                "SelectedApp_IDE",
                "SelectedApp_Terminal",
                "SelectedApp_Notes"
            ]
            for key in legacyKeys {
                if let val = UserDefaults.standard.string(forKey: key), !initial.contains(val) {
                    if Self.bypassLaunchInTests || NSWorkspace.shared.urlForApplication(withBundleIdentifier: val) != nil {
                        initial.append(val)
                    }
                }
            }
            if initial.isEmpty {
                initial = discoverSmartDefaultPinnedBundleIDs()
            }
            let list = Array(initial.prefix(maxPinnedQuickApps))
            UserDefaults.standard.set(list, forKey: "SelectedAppBundleIDs")
            return Set(list)
        }
        set {
            let list = Array(newValue.prefix(maxPinnedQuickApps))
            UserDefaults.standard.set(list, forKey: "SelectedAppBundleIDs")
        }
    }
    
    /// Whether more quick apps can be pinned (max 4 pinned apps + 1 Chrome/browser = 5 quick apps total)
    public static var canPinMoreApps: Bool {
        pinnedAppItems().count < maxPinnedQuickApps
    }
    
    /// Explicitly replace an existing pinned app with a new app
    public static func replaceApp(oldBundleID: String, newBundleID: String) {
        var list = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs") ?? Array(selectedBundleIDs)
        if let idx = list.firstIndex(of: oldBundleID) {
            list[idx] = newBundleID
        } else {
            list.removeAll(where: { $0 == oldBundleID })
            list.append(newBundleID)
        }
        let capped = Array(list.prefix(maxPinnedQuickApps))
        UserDefaults.standard.set(capped, forKey: "SelectedAppBundleIDs")
    }
    
    public static func isAppSelected(bundleID: String) -> Bool {
        selectedBundleIDs.contains(bundleID)
    }
    
    public static func selectApp(bundleID: String) {
        var list = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs") ?? Array(selectedBundleIDs)
        if !list.contains(bundleID) {
            if list.count >= maxPinnedQuickApps {
                list.removeLast()
            }
            list.append(bundleID)
            selectedBundleIDs = Set(list)
        }
    }
    
    public static func deselectApp(bundleID: String) {
        var set = selectedBundleIDs
        if set.count > 1 {
            set.remove(bundleID)
            selectedBundleIDs = set
            var list = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs") ?? []
            list.removeAll(where: { $0 == bundleID })
            UserDefaults.standard.set(list, forKey: "SelectedAppBundleIDs")
        }
    }
    
    public static func toggleApp(bundleID: String) {
        if isAppSelected(bundleID: bundleID) {
            deselectApp(bundleID: bundleID)
        } else {
            selectApp(bundleID: bundleID)
        }
    }
    
    /// Moves a pinned application up within its letter group.
    /// Swaps the app's position with the previous app sharing the same first letter.
    @discardableResult
    public static func movePinnedAppUp(bundleID: String) -> Bool {
        let pinned = pinnedAppItems()
        guard let currentItem = pinned.first(where: { $0.bundleID == bundleID }) else { return false }
        let letter = currentItem.firstLetter
        
        var list = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs") ?? pinned.map { $0.bundleID }
        guard let currentIdx = list.firstIndex(of: bundleID) else { return false }
        
        // Find preceding app in list with the same first letter
        var prevIdx: Int? = nil
        for i in stride(from: currentIdx - 1, through: 0, by: -1) {
            let bID = list[i]
            if let item = pinned.first(where: { $0.bundleID == bID }), item.firstLetter == letter {
                prevIdx = i
                break
            }
        }
        guard let targetIdx = prevIdx else { return false }
        list.swapAt(currentIdx, targetIdx)
        let capped = Array(list.prefix(maxPinnedQuickApps))
        UserDefaults.standard.set(capped, forKey: "SelectedAppBundleIDs")
        return true
    }
    
    /// Moves a pinned application down within its letter group.
    /// Swaps the app's position with the next app sharing the same first letter.
    @discardableResult
    public static func movePinnedAppDown(bundleID: String) -> Bool {
        let pinned = pinnedAppItems()
        guard let currentItem = pinned.first(where: { $0.bundleID == bundleID }) else { return false }
        let letter = currentItem.firstLetter
        
        var list = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs") ?? pinned.map { $0.bundleID }
        guard let currentIdx = list.firstIndex(of: bundleID) else { return false }
        
        // Find succeeding app in list with the same first letter
        var nextIdx: Int? = nil
        for i in (currentIdx + 1)..<list.count {
            let bID = list[i]
            if let item = pinned.first(where: { $0.bundleID == bID }), item.firstLetter == letter {
                nextIdx = i
                break
            }
        }
        guard let targetIdx = nextIdx else { return false }
        list.swapAt(currentIdx, targetIdx)
        let capped = Array(list.prefix(maxPinnedQuickApps))
        UserDefaults.standard.set(capped, forKey: "SelectedAppBundleIDs")
        return true
    }
    
    public static func allDiscoveredItems() -> [AntigravityItem] {
        var seen = Set<String>()
        var result: [AntigravityItem] = []
        for engine in allEngines {
            for item in engine.items {
                guard !seen.contains(item.bundleID) else { continue }
                seen.insert(item.bundleID)
                result.append(item)
            }
        }
        return result
    }
    
    public static func pinnedAppItems() -> [AntigravityItem] {
        let savedList = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs") ?? Array(selectedBundleIDs)
        let all = allDiscoveredItems()
        var allMap = Dictionary(all.map { ($0.bundleID, $0) }, uniquingKeysWith: { first, _ in first })
        
        var result: [AntigravityItem] = []
        for bundleID in savedList {
            if let item = allMap[bundleID] {
                if !result.contains(where: { $0.bundleID == bundleID }) {
                    result.append(item)
                }
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                // Resilient on-the-fly resolution for system/custom apps (Finder, Settings, etc.)
                let path = url.path
                let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 64, height: 64)
                let item = AntigravityItem(
                    name: name,
                    bundleID: bundleID,
                    path: path,
                    icon: icon,
                    index: result.count + 1
                )
                result.append(item)
                allMap[bundleID] = item
                if !custom.items.contains(where: { $0.bundleID == bundleID }) {
                    custom.items.append(item)
                }
            } else if Self.bypassLaunchInTests, let candidate = allEngines.flatMap({ $0.candidates }).first(where: { $0.bundleID == bundleID }) {
                // Resilient fallback for catalog candidates (e.g. headless/CI environments or uninstalled defaults)
                let icon = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
                icon.size = NSSize(width: 64, height: 64)
                let item = AntigravityItem(
                    name: candidate.name,
                    bundleID: candidate.bundleID,
                    path: candidate.defaultPaths.first ?? "",
                    icon: icon,
                    index: result.count + 1
                )
                result.append(item)
                allMap[bundleID] = item
            }
        }
        return Array(result.prefix(maxPinnedQuickApps))
    }
    
    /// Returns pinned apps grouped by their first letter, sorted alphabetically.
    public static func pinnedAppsGroupedByLetter() -> [(letter: Character, items: [AntigravityItem])] {
        let pinned = pinnedAppItems()
        var letterMap: [Character: [AntigravityItem]] = [:]
        for item in pinned {
            let char = Character((item.name.first(where: { $0.isLetter }) ?? "A").uppercased())
            if letterMap[char] == nil {
                letterMap[char] = []
            }
            letterMap[char]!.append(item)
        }
        
        return letterMap.keys.sorted().map { char in
            (letter: char, items: letterMap[char]!)
        }
    }
    
    /// Discovers and groups all available application items strictly by their first letter.
    public static func discoveredItemsByLetter() -> [Character: [AntigravityItem]] {
        var seen = Set<String>()
        var result: [Character: [AntigravityItem]] = [:]
        
        for engine in allEngines {
            for item in engine.items {
                guard !seen.contains(item.bundleID) else { continue }
                seen.insert(item.bundleID)
                
                let char = Character((item.name.first(where: { $0.isLetter }) ?? "A").uppercased())
                if result[char] == nil {
                    result[char] = []
                }
                result[char]?.append(item)
            }
        }
        
        return result
    }
    
    /// Groups registered and discovered applications by letter for the status menu.
    /// Prioritizes letters with multiple applications (cyclic groups like A, S, T) and user-pinned apps.
    public static func statusMenuLetterGroups() -> [(letter: Character, items: [AntigravityItem])] {
        var letterMap: [Character: [AntigravityItem]] = [:]
        var seenBundleIDs = Set<String>()
        
        // 1. Antigravity Engine (letter 'A' items: Antigravity, Antigravity IDE)
        for item in AntigravityEngine.shared.items {
            let char = item.firstLetter
            if !seenBundleIDs.contains(item.bundleID) {
                seenBundleIDs.insert(item.bundleID)
                if letterMap[char] == nil { letterMap[char] = [] }
                letterMap[char]!.append(item)
            }
        }
        
        // 2. User-Pinned Apps
        for item in pinnedAppItems() {
            let char = item.firstLetter
            if !seenBundleIDs.contains(item.bundleID) {
                seenBundleIDs.insert(item.bundleID)
                if letterMap[char] == nil { letterMap[char] = [] }
                letterMap[char]!.append(item)
            }
        }
        
        // 3. Multi-app discovered groups from pre-configured engines
        let discovered = discoveredItemsByLetter()
        for (char, items) in discovered {
            for item in items {
                if !seenBundleIDs.contains(item.bundleID) {
                    seenBundleIDs.insert(item.bundleID)
                    if letterMap[char] == nil { letterMap[char] = [] }
                    letterMap[char]!.append(item)
                }
            }
        }
        
        // Filter and sort:
        // Prioritize letters with multiple applications (cyclic groups), then alphabetical
        let sortedKeys = letterMap.keys.sorted { char1, char2 in
            let count1 = letterMap[char1]?.count ?? 0
            let count2 = letterMap[char2]?.count ?? 0
            if count1 != count2 {
                return count1 > count2
            }
            return char1 < char2
        }
        
        var result: [(letter: Character, items: [AntigravityItem])] = []
        for key in sortedKeys {
            guard let rawItems = letterMap[key], !rawItems.isEmpty else { continue }
            let reindexed = rawItems.enumerated().map { (idx, item) in
                AntigravityItem(
                    name: item.name,
                    bundleID: item.bundleID,
                    path: item.path,
                    icon: item.icon,
                    index: idx + 1
                )
            }
            result.append((letter: key, items: reindexed))
        }
        
        // Return all letter groups to ensure all pinned and discovered quick apps are displayed
        return result
    }
    
    /// Register an external custom app by URL and pin it immediately.
    @discardableResult
    public static func registerCustomApp(url: URL) -> AntigravityItem? {
        let path = url.path
        guard url.isFileURL,
              url.pathExtension.lowercased() == "app",
              FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        var paths = UserDefaults.standard.stringArray(forKey: "CustomAppPaths") ?? []
        if !paths.contains(path) {
            paths.append(path)
            UserDefaults.standard.set(paths, forKey: "CustomAppPaths")
        }
        
        let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let bundleID = Bundle(path: path)?.bundleIdentifier ?? "custom.\(name.lowercased())"
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 64, height: 64)
        
        let item = AntigravityItem(
            name: name,
            bundleID: bundleID,
            path: path,
            icon: icon,
            index: custom.items.count + 1
        )
        
        // Sync candidates and refresh custom engine
        custom.candidates = loadCustomAppCandidates()
        custom.refreshItems()
        
        if !custom.items.contains(where: { $0.bundleID == bundleID }) {
            custom.items.append(item)
        }
        
        if canPinMoreApps {
            selectApp(bundleID: bundleID)
        }
        return item
    }
    
    /// Returns an AntigravityItem representation of the active browser from ChromeProfileEngine.
    public static func browserAsAntigravityItem() -> AntigravityItem {
        let profileEngine = ChromeProfileEngine.shared
        return AntigravityItem(
            name: profileEngine.activeBrowserName,
            bundleID: profileEngine.browserBundleID,
            path: profileEngine.activeBrowserAppPath,
            icon: profileEngine.activeBrowserIcon,
            index: 1
        )
    }
}
