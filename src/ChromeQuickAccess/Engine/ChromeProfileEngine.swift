import Foundation
import Cocoa
import AppKit
import ApplicationServices
import os

// MARK: - Chrome Profile Model
public struct ChromeProfile: Identifiable, Equatable {
    public var id: String { dir }
    public let index: Int
    public let dir: String
    public let name: String
    public let email: String?
    public let gaiaName: String?
    public let gaiaGivenName: String?
    public let avatarImage: NSImage?
    
    public var effectiveName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        if let g = gaiaGivenName?.trimmingCharacters(in: .whitespacesAndNewlines), !g.isEmpty { return g }
        if let gn = gaiaName?.trimmingCharacters(in: .whitespacesAndNewlines), !gn.isEmpty { return gn }
        if let u = email?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty { return u }
        return dir == "Default" ? "Personal" : dir
    }
    
    public var expectedMenuTitle: String {
        let cleanName = effectiveName
        if let given = gaiaGivenName?.trimmingCharacters(in: .whitespacesAndNewlines), !given.isEmpty {
            if cleanName.lowercased() != given.lowercased() {
                return "\(given) (\(cleanName))"
            }
        }
        return cleanName
    }
    
    public init(
        index: Int,
        dir: String,
        name: String,
        email: String? = nil,
        gaiaName: String? = nil,
        gaiaGivenName: String? = nil,
        avatarImage: NSImage? = nil
    ) {
        self.index = index
        self.dir = dir
        self.name = name
        self.email = email
        self.gaiaName = gaiaName
        self.gaiaGivenName = gaiaGivenName
        self.avatarImage = avatarImage
    }
}

// MARK: - Chromium Browser Candidate Model
public struct ChromiumBrowserCandidate: Identifiable, Equatable, Sendable {
    public let name: String
    public let bundleID: String
    public let localStatePath: String
    public let appPath: String
    public var id: String { bundleID }
    
    public init(name: String, bundleID: String, localStatePath: String, appPath: String) {
        self.name = name
        self.bundleID = bundleID
        self.localStatePath = localStatePath
        self.appPath = appPath
    }
}

// MARK: - Chrome Profile Engine
@MainActor
public final class ChromeProfileEngine: ObservableObject {
    public static let shared = ChromeProfileEngine()
    
    @Published public private(set) var profiles: [ChromeProfile] = []
    @Published public private(set) var availableBrowsers: [ChromiumBrowserCandidate] = []
    @Published public var browserBundleID: String = "com.google.Chrome"
    
    public var preferredBrowserBundleID: String? {
        get { UserDefaults.standard.string(forKey: "PreferredBrowserBundleID") }
        set {
            if let val = newValue {
                UserDefaults.standard.set(val, forKey: "PreferredBrowserBundleID")
            } else {
                UserDefaults.standard.removeObject(forKey: "PreferredBrowserBundleID")
            }
        }
    }
    
    public var activeBrowserName: String {
        if let found = Self.supportedBrowsers.first(where: { $0.bundleID == browserBundleID }) {
            return found.name
        }
        return "Chrome"
    }
    
    public var primaryShortcutChar: Character {
        if browserBundleID.lowercased().contains("brave") {
            return "B"
        } else if browserBundleID.lowercased().contains("edgemac") {
            return "E"
        }
        return "C"
    }
    
    public var primaryShortcutKeyCode: UInt32 {
        switch primaryShortcutChar {
        case "B": return KeyCodes.kVK_ANSI_B
        case "E": return KeyCodes.kVK_ANSI_E
        default: return KeyCodes.kVK_ANSI_C
        }
    }
    
    public var activeBrowserAppPath: String {
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: browserBundleID) {
            return appUrl.path
        }
        if let found = Self.supportedBrowsers.first(where: { $0.bundleID == browserBundleID }) {
            return found.appPath
        }
        return "/Applications/Google Chrome.app"
    }
    
    public var activeBrowserIcon: NSImage {
        let path = activeBrowserAppPath
        if FileManager.default.fileExists(atPath: path) {
            return NSWorkspace.shared.icon(forFile: path)
        }
        return ChromeAppIconHelper.chromeIcon()
    }
    
    public func selectBrowser(bundleID: String) {
        self.preferredBrowserBundleID = bundleID
        self.browserBundleID = bundleID
        refreshProfiles()
    }
    
    @Published public var selectedProfileDirs: [String] = [] {
        didSet {
            UserDefaults.standard.set(selectedProfileDirs, forKey: "SelectedBrowserProfileDirs")
        }
    }
    
    /// Returns the active selected profiles (up to 4), re-indexed 1...4 for hotkeys and HUD
    public var selectedProfiles: [ChromeProfile] {
        let selectedSet = Set(selectedProfileDirs)
        let matched = profiles.filter { selectedSet.contains($0.dir) }
        let chosen = matched.isEmpty ? Array(profiles.prefix(4)) : Array(matched.prefix(4))
        return chosen.enumerated().map { (idx, p) in
            ChromeProfile(
                index: idx + 1,
                dir: p.dir,
                name: p.name,
                email: p.email,
                gaiaName: p.gaiaName,
                gaiaGivenName: p.gaiaGivenName,
                avatarImage: p.avatarImage
            )
        }
    }
    
    public func isProfileSelected(dir: String) -> Bool {
        selectedProfiles.contains(where: { $0.dir == dir })
    }
    
    public func selectProfile(dir: String) {
        if !selectedProfileDirs.contains(dir) {
            if selectedProfileDirs.count < 4 {
                selectedProfileDirs.append(dir)
            } else {
                selectedProfileDirs[3] = dir
            }
        }
    }
    
    public func deselectProfile(dir: String) {
        if selectedProfileDirs.count > 1 {
            selectedProfileDirs.removeAll(where: { $0 == dir })
        }
    }
    
    public func replaceProfile(oldDir: String, newDir: String) {
        if let idx = selectedProfileDirs.firstIndex(of: oldDir) {
            selectedProfileDirs[idx] = newDir
        } else {
            selectedProfileDirs.removeAll(where: { $0 == oldDir })
            selectedProfileDirs.append(newDir)
        }
    }
    
    public func toggleProfileSelection(dir: String) {
        if selectedProfileDirs.contains(dir) {
            deselectProfile(dir: dir)
        } else {
            selectProfile(dir: dir)
        }
    }
    
    /// Optional override for isolated unit testing
    public static var localStatePathOverride: String? = nil
    
    /// When running in test environments, bypasses actual external process launches
    public static var bypassLaunchInTests: Bool = {
        ProcessInfo.processInfo.environment["SWIFT_DETERMINISTIC_TESTING"] != nil ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.processName.contains("Tests") ||
        ProcessInfo.processInfo.arguments.first?.contains("PackageTests") == true ||
        NSClassFromString("XCTest") != nil
    }()
    
    private var cachedAvatars: [String: NSImage] = [:]
    private let logger = Logger(subsystem: "com.almosteleven.nnts", category: "profiles")
    
    public init() {
        refreshProfiles()
    }
    
    public static var supportedBrowsers: [ChromiumBrowserCandidate] {
        let home = NSHomeDirectory()
        return [
            ChromiumBrowserCandidate(
                name: "Google Chrome",
                bundleID: "com.google.Chrome",
                localStatePath: "\(home)/Library/Application Support/Google/Chrome/Local State",
                appPath: "/Applications/Google Chrome.app"
            ),
            ChromiumBrowserCandidate(
                name: "Brave Browser",
                bundleID: "com.brave.Browser",
                localStatePath: "\(home)/Library/Application Support/BraveSoftware/Brave-Browser/Local State",
                appPath: "/Applications/Brave Browser.app"
            ),
            ChromiumBrowserCandidate(
                name: "Brave Browser Beta",
                bundleID: "com.brave.Browser.beta",
                localStatePath: "\(home)/Library/Application Support/BraveSoftware/Brave-Browser-Beta/Local State",
                appPath: "/Applications/Brave Browser Beta.app"
            ),
            ChromiumBrowserCandidate(
                name: "Brave Browser Nightly",
                bundleID: "com.brave.Browser.nightly",
                localStatePath: "\(home)/Library/Application Support/BraveSoftware/Brave-Browser-Nightly/Local State",
                appPath: "/Applications/Brave Browser Nightly.app"
            ),
            ChromiumBrowserCandidate(
                name: "Microsoft Edge",
                bundleID: "com.microsoft.edgemac",
                localStatePath: "\(home)/Library/Application Support/Microsoft Edge/Local State",
                appPath: "/Applications/Microsoft Edge.app"
            ),
            ChromiumBrowserCandidate(
                name: "Chromium",
                bundleID: "org.chromium.Chromium",
                localStatePath: "\(home)/Library/Application Support/Chromium/Local State",
                appPath: "/Applications/Chromium.app"
            )
        ]
    }
    
    public var candidateLocalStatePaths: [String] {
        if let overridePath = Self.localStatePathOverride {
            return [overridePath]
        }
        return Self.supportedBrowsers.map { $0.localStatePath }
    }
    
    public func refreshProfiles() {
        cachedAvatars.removeAll()
        let fileManager = FileManager.default
        
        // 1. If isolated test override path is set, parse directly
        if let overridePath = Self.localStatePathOverride {
            self.availableBrowsers = []
            if overridePath.contains("Brave-Browser-Beta") { self.browserBundleID = "com.brave.Browser.beta" }
            else if overridePath.contains("Brave-Browser-Nightly") { self.browserBundleID = "com.brave.Browser.nightly" }
            else if overridePath.contains("Brave-Browser") { self.browserBundleID = "com.brave.Browser" }
            else if overridePath.contains("Microsoft Edge") { self.browserBundleID = "com.microsoft.edgemac" }
            else if overridePath.contains("Chromium") { self.browserBundleID = "org.chromium.Chromium" }
            else { self.browserBundleID = "com.google.Chrome" }
            
            let loaded = parseProfiles(from: overridePath)
            self.profiles = loaded.isEmpty ? [makeFallbackProfile()] : loaded
            applySavedProfileSelection()
            return
        }
        
        // 2. Multi-browser discovery: scan all supported Chromium browsers
        var discovered: [ChromiumBrowserCandidate] = []
        for candidate in Self.supportedBrowsers {
            if fileManager.fileExists(atPath: candidate.localStatePath) {
                discovered.append(candidate)
            }
        }
        self.availableBrowsers = discovered
        
        // 3. Determine active browser choice (Multi-browser priority hierarchy):
        // Priority A: Explicit user preference in UserDefaults
        // Priority B: System Default Browser for https:// (if among discovered candidates)
        // Priority C: Currently running browser among discovered
        // Priority D: Most recently modified Local State file (user's active browser)
        // Priority E: First discovered candidate or fallback
        var chosen: ChromiumBrowserCandidate? = nil
        
        if let preferred = preferredBrowserBundleID {
            if let match = discovered.first(where: { $0.bundleID == preferred }) {
                chosen = match
            } else if let supported = Self.supportedBrowsers.first(where: { $0.bundleID == preferred }) {
                chosen = supported
            }
        } else {
            // Priority B: System Default Browser
            if let defaultBrowserURL = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "https://apple.com")!),
               let defaultBundleID = Bundle(url: defaultBrowserURL)?.bundleIdentifier,
               let defaultMatch = discovered.first(where: { $0.bundleID == defaultBundleID }) {
                chosen = defaultMatch
            } else {
                let runningApps = NSWorkspace.shared.runningApplications
                let runningBundles = Set(runningApps.compactMap { $0.bundleIdentifier })
                if let runningMatch = discovered.first(where: { runningBundles.contains($0.bundleID) }) {
                    chosen = runningMatch
                } else {
                    var latestDate: Date = .distantPast
                    var latestCandidate: ChromiumBrowserCandidate? = nil
                    for candidate in discovered {
                        if let attrs = try? fileManager.attributesOfItem(atPath: candidate.localStatePath),
                           let modDate = attrs[.modificationDate] as? Date,
                           modDate > latestDate {
                            latestDate = modDate
                            latestCandidate = candidate
                        }
                    }
                    chosen = latestCandidate ?? discovered.first
                }
            }
        }
        
        if let chosen = chosen {
            self.browserBundleID = chosen.bundleID
            let loaded = parseProfiles(from: chosen.localStatePath)
            self.profiles = loaded.isEmpty ? [makeFallbackProfile()] : loaded
        } else {
            self.browserBundleID = "com.google.Chrome"
            self.profiles = [makeFallbackProfile()]
        }
        
        applySavedProfileSelection()
        logger.info("Discovered \(self.availableBrowsers.count) browsers. Active: \(self.activeBrowserName) (\(self.browserBundleID)) with \(self.profiles.count) profiles.")
    }
    
    private func parseProfiles(from path: String) -> [ChromeProfile] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileObj = json["profile"] as? [String: Any],
              let infoCache = profileObj["info_cache"] as? [String: [String: Any]] else {
            return []
        }
        
        let baseDir = (path as NSString).deletingLastPathComponent
        var dirKeys = Array(infoCache.keys)
        dirKeys.sort { a, b in
            if a == "Default" { return true }
            if b == "Default" { return false }
            return a < b
        }
        
        var foundProfiles: [ChromeProfile] = []
        for (offset, dirKey) in dirKeys.enumerated() {
            guard let info = infoCache[dirKey] else { continue }
            let name = (info["name"] as? String)
                ?? (info["gaia_name"] as? String)
                ?? (info["user_name"] as? String)
                ?? (dirKey == "Default" ? "Personal" : dirKey)
            let email = (info["user_name"] as? String) ?? (info["email"] as? String)
            let gaiaName = info["gaia_name"] as? String
            let gaiaGivenName = info["gaia_given_name"] as? String
            let avatar = resolveAvatar(baseDir: baseDir, dirKey: dirKey, info: info)
            
            let profile = ChromeProfile(
                index: offset + 1,
                dir: dirKey,
                name: name,
                email: email,
                gaiaName: gaiaName,
                gaiaGivenName: gaiaGivenName,
                avatarImage: avatar
            )
            foundProfiles.append(profile)
            if foundProfiles.count >= 8 { break }
        }
        return foundProfiles
    }
    
    private func makeFallbackProfile() -> ChromeProfile {
        ChromeProfile(
            index: 1,
            dir: "Default",
            name: "Default Profile",
            email: nil,
            gaiaName: nil,
            gaiaGivenName: nil,
            avatarImage: makeMonogramImage(name: activeBrowserName)
        )
    }
    
    private func applySavedProfileSelection() {
        let saved = UserDefaults.standard.stringArray(forKey: "SelectedBrowserProfileDirs") ?? []
        let validSaved = saved.filter { s in profiles.contains(where: { $0.dir == s }) }
        if !validSaved.isEmpty {
            self.selectedProfileDirs = Array(validSaved.prefix(4))
        } else {
            self.selectedProfileDirs = Array(profiles.prefix(4).map { $0.dir })
        }
    }
    
    // MARK: - Profile Focus & Activation
    public func focusChrome() {
        let runningApps = NSWorkspace.shared.runningApplications
        if runningApps.contains(where: { $0.bundleIdentifier == self.browserBundleID }) {
            let targetDir = getActiveProfileDir() ?? profiles.first?.dir ?? "Default"
            focusProfile(dir: targetDir)
        } else {
            launchColdStart(profileDir: profiles.first?.dir ?? "Default")
        }
    }
    
    public func getActiveProfileDir() -> String? {
        let menuItems = getProfilesMenuItems(bundleID: self.browserBundleID)
        for item in menuItems {
            var markRef: CFTypeRef?
            AXUIElementCopyAttributeValue(item, ("AXMenuItemMarkChar" as NSString) as CFString, &markRef)
            if let mark = markRef as? String, mark == "✓" {
                var titleRef: CFTypeRef?
                AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
                if let title = titleRef as? String {
                    let norm = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    if let match = profiles.first(where: {
                        let eff = $0.effectiveName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        let exp = $0.expectedMenuTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        return norm == eff || norm == exp || norm.contains("(\(eff))")
                    }) {
                        return match.dir
                    }
                }
            }
        }
        return nil
    }
    
    public func focusProfile(dir: String) {
        let bundleID = self.browserBundleID
        guard let profile = profiles.first(where: { $0.dir == dir }) else {
            focusChrome()
            return
        }
        
        let runningApps = NSWorkspace.shared.runningApplications
        guard let chromeApp = runningApps.first(where: { $0.bundleIdentifier == bundleID }) else {
            launchColdStart(profileDir: profile.dir)
            return
        }
        
        let appElement = AXUIElementCreateApplication(chromeApp.processIdentifier)
        
        func scanProfileWindows() -> (open: [AXUIElement], minimized: [AXUIElement]) {
            var windowsRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
                  let windows = windowsRef as? [AXUIElement] else {
                return ([], [])
            }
            
            let expected = profile.expectedMenuTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let effective = profile.effectiveName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let isOnlyProfile = self.profiles.count <= 1
            
            let matching = windows.filter { window in
                if isOnlyProfile { return true }
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let title = titleRef as? String {
                    let lowerTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    return lowerTitle.hasSuffix(expected) || lowerTitle.hasSuffix(effective)
                }
                return false
            }
            
            var opens: [AXUIElement] = []
            var mins: [AXUIElement] = []
            for w in matching {
                var isMinRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &isMinRef) == .success,
                   let isMin = isMinRef as? Bool, isMin {
                    mins.append(w)
                } else {
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &titleRef) == .success,
                       let title = titleRef as? String, !title.isEmpty {
                        opens.append(w)
                    }
                }
            }
            return (opens, mins)
        }
        
        // 1. Immediate check: if open window already visible on current Space, focus instantly
        let initial = scanProfileWindows()
        if let targetWindow = initial.open.first {
            AXUIElementPerformAction(targetWindow, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(targetWindow, kAXMainAttribute as CFString, true as CFTypeRef)
            chromeApp.activate()
            logger.info("Focused existing open window for profile '\(profile.name)'.")
            return
        }
        
        // 2. No open window found on current Space.
        // We cannot see windows on other Spaces, so we rely on Chrome's Profiles menu to find and focus them.
        let minimizedBefore = initial.minimized
        let menuItems = self.getProfilesMenuItems(bundleID: bundleID)
        
        if !menuItems.isEmpty, let targetItem = self.findMenuItem(for: profile, in: menuItems) {
            let res = AXUIElementPerformAction(targetItem, kAXPressAction as CFString)
            if res == .success {
                chromeApp.activate()
                self.logger.info("Switched to profile '\(profile.name)' via Accessibility menu.")
                
                // 3. Post-Menu Cleanup: Chrome natively unminimizes a profile's minimized window when selected from the menu,
                // even if an open window existed on another Space. We revert this to respect the user's explicit preference.
                if !minimizedBefore.isEmpty {
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        // Poll for up to 1.5s (15 iterations x 100ms) to catch the space transition and unminimize animation
                        for _ in 0..<15 {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            let postState = scanProfileWindows()
                            let openNow = postState.open
                            
                            var newlyUnminimized: AXUIElement? = nil
                            for openWin in openNow {
                                for minWin in minimizedBefore {
                                    if CFEqual(openWin, minWin) {
                                        newlyUnminimized = openWin
                                        break
                                    }
                                }
                                if newlyUnminimized != nil { break }
                            }
                            
                            if let unmin = newlyUnminimized {
                                // It was unminimized! Are there OTHER open windows for this profile on this space?
                                if openNow.count > 1 {
                                    AXUIElementSetAttributeValue(unmin, kAXMinimizedAttribute as CFString, true as CFTypeRef)
                                    self.logger.info("Re-minimized window that was auto-unminimized by Chrome.")
                                    // Ensure another open window gets focus
                                    if let other = openNow.first(where: { !CFEqual($0, unmin) }) {
                                        AXUIElementPerformAction(other, kAXRaiseAction as CFString)
                                        AXUIElementSetAttributeValue(other, kAXMainAttribute as CFString, true as CFTypeRef)
                                    }
                                }
                                break
                            }
                        }
                    }
                }
                return
            }
        }
        
        // 4. Fallback: Launch via /usr/bin/open CLI
        self.launchColdStart(profileDir: profile.dir)
    }
    
    private func launchColdStart(profileDir: String) {
        if Self.bypassLaunchInTests || AppGroupEngine.bypassLaunchInTests {
            logger.info("[Test] launchColdStart bypassed for profileDir: \(profileDir)")
            return
        }
        // Sanitize profile directory name: strictly allow safe alphanumeric profile names without flag injection
        let trimmed = profileDir.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeDir: String
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " _-."))
        if !trimmed.isEmpty && !trimmed.hasPrefix("-") && trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) {
            safeDir = trimmed
        } else {
            safeDir = "Default"
        }
        
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = ["-b", self.browserBundleID, "--args", "--profile-directory=\(safeDir)"]
        do {
            try task.run()
            task.waitUntilExit()
            logger.info("Launched Chrome with profile-directory '\(safeDir)' via open.")
        } catch {
            logger.error("Failed to launch Chrome via open: \(error.localizedDescription)")
        }
    }
    
    // MARK: - macOS Accessibility Menu Bar Traversal
    public func getProfilesMenuItems(bundleID: String) -> [AXUIElement] {
        let runningApps = NSWorkspace.shared.runningApplications
        guard let chromeApp = runningApps.first(where: { $0.bundleIdentifier == bundleID }) else {
            return []
        }
        
        let appElement = AXUIElementCreateApplication(chromeApp.processIdentifier)
        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBar = menuBarRef,
              CFGetTypeID(menuBar) == AXUIElementGetTypeID() else {
            return []
        }
        let menuBarElement = menuBar as! AXUIElement
        
        var menuBarItemsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(menuBarElement, kAXChildrenAttribute as CFString, &menuBarItemsRef) == .success,
              let menuBarItems = menuBarItemsRef as? [AXUIElement] else {
            return []
        }
        
        for item in menuBarItems {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if Self.isProfileMenuTitle(title) {
                var childrenRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(item, kAXChildrenAttribute as CFString, &childrenRef) == .success,
                   let subMenus = childrenRef as? [AXUIElement], let subMenu = subMenus.first {
                    var itemsRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(subMenu, kAXChildrenAttribute as CFString, &itemsRef) == .success,
                       let items = itemsRef as? [AXUIElement] {
                        return items
                    }
                }
            }
        }
        
        return []
    }
    
    public static func isProfileMenuTitle(_ title: String) -> Bool {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = clean.lowercased()
        return lower == "profiles" || lower == "profile" ||
               lower == "profils" || lower == "perfiles" ||
               lower == "профили" || lower == "профиль" ||
               lower == "perfis" || lower == "profili" ||
               clean == "个人资料" || clean == "プロファイル"
    }
    
    private func findMenuItem(for profile: ChromeProfile, in menuItems: [AXUIElement]) -> AXUIElement? {
        let targetNorm = profile.expectedMenuTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let effNorm = profile.effectiveName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        for item in menuItems {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
            guard let title = titleRef as? String else { continue }
            let norm = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if norm == targetNorm || norm == effNorm || norm.contains("(\(effNorm))") {
                return item
            }
            if let email = profile.email?.lowercased(), !email.isEmpty, norm.contains(email) {
                return item
            }
        }
        return nil
    }
    
    // MARK: - Avatar & Monogram Helpers
    private func resolveAvatar(baseDir: String, dirKey: String, info: [String: Any]) -> NSImage {
        if let cached = cachedAvatars[dirKey] { return cached }
        
        let name = (info["name"] as? String) ?? (info["gaia_name"] as? String) ?? dirKey
        let profileDir = (baseDir as NSString).appendingPathComponent(dirKey)
        
        var candidatePics = [
            (profileDir as NSString).appendingPathComponent("Google Profile Picture.png"),
            (profileDir as NSString).appendingPathComponent("Google Profile Picture.jpg"),
            (profileDir as NSString).appendingPathComponent("Edge Profile Picture.png"),
            (profileDir as NSString).appendingPathComponent("Custom Profile Picture.png")
        ]
        // Validate gaia_picture_file_name: must be a pure basename without directory traversal components
        if let gaiaName = info["gaia_picture_file_name"] as? String, !gaiaName.isEmpty {
            let sanitized = (gaiaName as NSString).lastPathComponent
            if !sanitized.isEmpty && !sanitized.contains("/") && !sanitized.contains("\\") && !sanitized.contains("..") {
                candidatePics.insert((profileDir as NSString).appendingPathComponent(sanitized), at: 0)
            }
        }
        
        let canonicalBase = URL(fileURLWithPath: profileDir).resolvingSymlinksInPath().path
        for picPath in candidatePics {
            let canonicalPic = URL(fileURLWithPath: picPath).resolvingSymlinksInPath().path
            guard canonicalPic.hasPrefix(canonicalBase) else { continue }
            if FileManager.default.fileExists(atPath: canonicalPic),
               let image = NSImage(contentsOfFile: canonicalPic) {
                let circular = makeCircularImage(image: image)
                cachedAvatars[dirKey] = circular
                return circular
            }
        }
        
        let colorSeed = info["profile_color_seed"] as? Int
        let monogram = makeMonogramImage(name: name, colorSeed: colorSeed)
        cachedAvatars[dirKey] = monogram
        return monogram
    }
    
    public func makeCircularImage(image: NSImage) -> NSImage {
        let size = NSSize(width: 96, height: 96)
        let output = NSImage(size: size)
        output.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect)
        path.addClip()
        
        let srcSize = image.size
        let minSide = min(srcSize.width, srcSize.height)
        let srcRect = NSRect(
            x: (srcSize.width - minSide) / 2,
            y: (srcSize.height - minSide) / 2,
            width: minSide,
            height: minSide
        )
        image.draw(in: rect, from: srcRect, operation: .sourceOver, fraction: 1.0)
        
        let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
        NSColor.white.withAlphaComponent(0.3).setStroke()
        ring.lineWidth = 2
        ring.stroke()
        output.unlockFocus()
        return output
    }
    
    public func makeMonogramImage(name: String, colorSeed: Int? = nil) -> NSImage {
        let size = NSSize(width: 96, height: 96)
        let output = NSImage(size: size)
        output.lockFocus()
        
        let colors: [NSColor] = [
            NSColor(red: 0.22, green: 0.50, blue: 0.95, alpha: 1.0),
            NSColor(red: 0.58, green: 0.30, blue: 0.88, alpha: 1.0),
            NSColor(red: 0.95, green: 0.42, blue: 0.25, alpha: 1.0),
            NSColor(red: 0.18, green: 0.70, blue: 0.45, alpha: 1.0),
            NSColor(red: 0.92, green: 0.65, blue: 0.15, alpha: 1.0)
        ]
        let idx = abs(colorSeed ?? name.hashValue) % colors.count
        let bg = colors[idx]
        
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect)
        bg.setFill()
        path.fill()
        
        let initial = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1)).uppercased()
        let font = NSFont.systemFont(ofSize: 44, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: initial.isEmpty ? "C" : initial, attributes: attrs)
        let strSize = str.size()
        let strRect = NSRect(
            x: (size.width - strSize.width) / 2,
            y: (size.height - strSize.height) / 2,
            width: strSize.width,
            height: strSize.height
        )
        str.draw(in: strRect)
        output.unlockFocus()
        return output
    }
}
