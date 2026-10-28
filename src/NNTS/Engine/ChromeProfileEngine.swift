import Foundation
import Cocoa
import AppKit
import ApplicationServices
import os

// MARK: - Chrome Profile Model
public struct ChromeProfile: Identifiable, Equatable, @unchecked Sendable {
    public var id: String { "\(dir)::\(name)" }
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
    
    @Published public internal(set) var profiles: [ChromeProfile] = []
    @Published public internal(set) var availableBrowsers: [ChromiumBrowserCandidate] = []
    @Published public var browserBundleID: String = "com.google.Chrome"
    @Published public internal(set) var isLocalStateBlocked: Bool = false
    
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
    
    public static let maxProfileSlots: Int = 8
    
    /// Returns the active selected profiles (up to 8), re-indexed 1...8 for hotkeys and HUD
    public var selectedProfiles: [ChromeProfile] {
        let chosen: [ChromeProfile]
        if !selectedProfileDirs.isEmpty {
            var ordered: [ChromeProfile] = []
            for dir in selectedProfileDirs {
                if let found = profiles.first(where: { $0.dir == dir }) {
                    ordered.append(found)
                }
            }
            chosen = ordered.isEmpty ? Array(profiles.prefix(Self.maxProfileSlots)) : Array(ordered.prefix(Self.maxProfileSlots))
        } else {
            chosen = Array(profiles.prefix(Self.maxProfileSlots))
        }
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
        if !selectedProfileDirs.isEmpty {
            return selectedProfileDirs.contains(dir)
        }
        return selectedProfiles.contains(where: { $0.dir == dir })
    }
    
    public func selectProfile(dir: String) {
        if !selectedProfileDirs.contains(dir) {
            if selectedProfileDirs.count < Self.maxProfileSlots {
                selectedProfileDirs.append(dir)
            } else {
                selectedProfileDirs[Self.maxProfileSlots - 1] = dir
            }
        }
    }
    
    public func moveProfile(fromOffsets source: IndexSet, toOffset destination: Int) {
        var updated = selectedProfileDirs
        updated.move(fromOffsets: source, toOffset: destination)
        self.selectedProfileDirs = updated
    }
    
    public func setProfileOrder(_ orderedDirs: [String]) {
        self.selectedProfileDirs = Array(orderedDirs.prefix(Self.maxProfileSlots))
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
        if isProfileSelected(dir: dir) {
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
        ProcessInfo.processInfo.processName.lowercased().contains("test") ||
        ProcessInfo.processInfo.arguments.first?.lowercased().contains("test") == true ||
        NSClassFromString("XCTest") != nil
    }()
    
    internal var cachedAvatars: [String: NSImage] = [:]
    internal let logger = Logger(subsystem: "com.almosteleven.nnts", category: "profiles")
    internal var isRestoringBookmark = false
    internal var pasteboardWatcherTimer: Timer?
    
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
    
    // MARK: - Discovery & Refresh
    
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
        
        // 3. Determine active browser choice (Multi-browser priority hierarchy)
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
            if cachedAvatars.isEmpty {
                restoreSecurityScopedFolderAccessIfNeeded()
            }
            var loaded = parseProfiles(from: chosen.localStatePath)
            
            // Resilient fallback for macOS 27: if Local State is blocked, discover via Accessibility or load cache
            if loaded.isEmpty {
                let axProfiles = discoverProfilesViaAccessibility(bundleID: chosen.bundleID)
                if !axProfiles.isEmpty {
                    logger.info("Discovered \(axProfiles.count) profiles via Accessibility menu for \(chosen.name).")
                    loaded = axProfiles
                    saveCachedProfiles(axProfiles, bundleID: chosen.bundleID)
                } else {
                    let cached = loadCachedProfiles(bundleID: chosen.bundleID)
                    if !cached.isEmpty {
                        logger.info("Loaded \(cached.count) cached profiles for \(chosen.name).")
                        loaded = cached
                    }
                }
            } else {
                saveCachedProfiles(loaded, bundleID: chosen.bundleID)
            }
            
            self.profiles = loaded.isEmpty ? [makeFallbackProfile()] : loaded
        } else {
            self.browserBundleID = "com.google.Chrome"
            let axProfiles = discoverProfilesViaAccessibility(bundleID: self.browserBundleID)
            if !axProfiles.isEmpty {
                self.profiles = axProfiles
                saveCachedProfiles(axProfiles, bundleID: self.browserBundleID)
            } else {
                let cached = loadCachedProfiles(bundleID: self.browserBundleID)
                self.profiles = cached.isEmpty ? [makeFallbackProfile()] : cached
            }
        }
        
        applySavedProfileSelection()
        logger.info("Discovered \(self.availableBrowsers.count) browsers. Active: \(self.activeBrowserName) (\(self.browserBundleID)) with \(self.profiles.count) profiles.")
    }
    
    private func parseProfiles(from path: String) -> [ChromeProfile] {
        let fileManager = FileManager.default
        
        var securityScopedURL: URL? = nil
        var isAccessGranted = false
        if Self.localStatePathOverride == nil,
           let bookmarkData = UserDefaults.standard.data(forKey: "ChromeFolderSecurityScopedBookmark") {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if resolved.startAccessingSecurityScopedResource() {
                    securityScopedURL = resolved
                    isAccessGranted = true
                }
                if isStale {
                    if let newBookmark = try? resolved.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                        UserDefaults.standard.set(newBookmark, forKey: "ChromeFolderSecurityScopedBookmark")
                    }
                }
            }
        }
        defer {
            if isAccessGranted, let url = securityScopedURL {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let targetFileURL: URL
        let baseDir: String
        if let scoped = securityScopedURL {
            targetFileURL = scoped.appendingPathComponent("Local State")
            baseDir = scoped.path
        } else {
            targetFileURL = URL(fileURLWithPath: path)
            baseDir = (path as NSString).deletingLastPathComponent
        }
        
        guard fileManager.fileExists(atPath: targetFileURL.path) else {
            return []
        }
        
        let data: Data
        do {
            data = try Data(contentsOf: targetFileURL)
            self.isLocalStateBlocked = false
        } catch {
            self.isLocalStateBlocked = true
            logger.warning("Local State file at '\(targetFileURL.path)' could not be opened (\(error.localizedDescription)). Access blocked by macOS permissions.")
            return []
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profileObj = json["profile"] as? [String: Any],
              let infoCache = profileObj["info_cache"] as? [String: [String: Any]] else {
            return []
        }
        
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
            if foundProfiles.count >= 50 { break }
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
    
    internal func applySavedProfileSelection() {
        let saved = UserDefaults.standard.stringArray(forKey: "SelectedBrowserProfileDirs") ?? []
        let validSaved = saved.filter { s in profiles.contains(where: { $0.dir == s }) }
        let targetCount = min(profiles.count, Self.maxProfileSlots)
        if validSaved.count >= targetCount && !(validSaved.count == 1 && validSaved.first == "Default" && profiles.count > 1) {
            self.selectedProfileDirs = Array(validSaved.prefix(Self.maxProfileSlots))
        } else {
            var combined = validSaved
            for p in profiles {
                if !combined.contains(p.dir) {
                    combined.append(p.dir)
                }
                if combined.count >= Self.maxProfileSlots { break }
            }
            self.selectedProfileDirs = combined.isEmpty ? Array(profiles.prefix(Self.maxProfileSlots).map { $0.dir }) : combined
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
    
    public func focusProfile(_ profile: ChromeProfile) {
        let bundleID = self.browserBundleID
        let runningApps = NSWorkspace.shared.runningApplications
        guard let chromeApp = runningApps.first(where: { $0.bundleIdentifier == bundleID }) else {
            launchColdStart(profileDir: profile.dir)
            return
        }
        
        // Automate via native macOS menu bar (kAXMenuBarAttribute) strictly adhering to profile guardrail
        let filtered = getFilteredProfileMenuItems(bundleID: bundleID)
        if !filtered.isEmpty {
            if let targetItem = findMenuItem(for: profile, in: filtered.map { $0.element }) {
                let res = AXUIElementPerformAction(targetItem, kAXPressAction as CFString)
                if res == .success {
                    chromeApp.activate()
                    logger.info("Switched to profile '\(profile.name)' via Accessibility menu item.")
                    return
                }
            }
        }
        
        // Fallback: Launch or focus via /usr/bin/open CLI
        self.launchColdStart(profileDir: profile.dir)
        chromeApp.activate()
    }
    
    public func focusProfile(dir: String) {
        if let profile = profiles.first(where: { $0.dir == dir }) ?? profiles.first(where: { $0.name == dir }) {
            focusProfile(profile)
        } else {
            focusChrome()
        }
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
}
