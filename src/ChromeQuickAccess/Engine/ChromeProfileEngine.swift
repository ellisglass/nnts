import Foundation
import Cocoa
import AppKit
import ApplicationServices
import os

// MARK: - Chrome Profile Model
public struct ChromeProfile: Identifiable, Equatable, @unchecked Sendable {
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
    @Published public private(set) var isLocalStateBlocked: Bool = false
    
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
        ProcessInfo.processInfo.processName.lowercased().contains("test") ||
        ProcessInfo.processInfo.arguments.first?.lowercased().contains("test") == true ||
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
        // If saved was only ["Default"] while multiple profiles are available (e.g. recovering from fallback), expand to prefix(4)
        if !validSaved.isEmpty && !(validSaved.count == 1 && validSaved.first == "Default" && profiles.count > 1) {
            self.selectedProfileDirs = Array(validSaved.prefix(4))
        } else {
            self.selectedProfileDirs = Array(profiles.prefix(4).map { $0.dir })
        }
    }
    
    /// Discovers active browser profiles directly from the running browser's native macOS menu bar.
    /// Provides zero-permission resilience on macOS 27 when direct disk access to 'Local State' is denied.
    public func discoverProfilesViaAccessibility(bundleID: String) -> [ChromeProfile] {
        let menuItems = getProfilesMenuItems(bundleID: bundleID)
        guard !menuItems.isEmpty else { return [] }
        
        var profileNames: [String] = []
        for item in menuItems {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Filter out empty items and actions (Edit, Add Profile, Guest, separators)
            if title.isEmpty || title.hasPrefix("Edit") || title.hasPrefix("Add Profile") || title.hasPrefix("Guest") ||
               title.hasPrefix("Изменить") || title.hasPrefix("Добавить") || title.hasPrefix("Гость") {
                if !profileNames.isEmpty && (title.isEmpty || title.hasPrefix("Edit") || title.hasPrefix("Add Profile") || title.hasPrefix("Изменить") || title.hasPrefix("Добавить")) {
                    break
                }
                continue
            }
            profileNames.append(title)
        }
        
        guard !profileNames.isEmpty else { return [] }
        
        var discovered: [ChromeProfile] = []
        for (idx, name) in profileNames.enumerated() {
            let dir = idx == 0 ? "Default" : "Profile \(idx)"
            let avatar: NSImage
            if let customImg = Self.loadStoredAvatar(dirKey: dir, name: name) {
                avatar = makeCircularImage(image: customImg)
            } else {
                avatar = makeMonogramImage(name: name, colorSeed: idx + 1)
            }
            discovered.append(
                ChromeProfile(
                    index: idx + 1,
                    dir: dir,
                    name: name,
                    email: nil,
                    gaiaName: nil,
                    gaiaGivenName: nil,
                    avatarImage: avatar
                )
            )
            if discovered.count >= 8 { break }
        }
        
        return discovered
    }
    
    public func saveCachedProfiles(_ profiles: [ChromeProfile], bundleID: String) {
        guard !profiles.isEmpty else { return }
        let records: [[String: Any]] = profiles.map { p in
            [
                "index": p.index,
                "dir": p.dir,
                "name": p.name
            ]
        }
        UserDefaults.standard.set(records, forKey: "CachedProfiles_\(bundleID)")
    }
    
    public func loadCachedProfiles(bundleID: String) -> [ChromeProfile] {
        guard let records = UserDefaults.standard.array(forKey: "CachedProfiles_\(bundleID)") as? [[String: Any]],
              !records.isEmpty else {
            return []
        }
        return records.compactMap { dict in
            guard let index = dict["index"] as? Int,
                  let dir = dict["dir"] as? String,
                  let name = dict["name"] as? String else {
                return nil
            }
            let avatar: NSImage
            if let customImg = Self.loadStoredAvatar(dirKey: dir, name: name) {
                avatar = makeCircularImage(image: customImg)
            } else {
                avatar = makeMonogramImage(name: name, colorSeed: index)
            }
            return ChromeProfile(
                index: index,
                dir: dir,
                name: name,
                email: nil,
                gaiaName: nil,
                gaiaGivenName: nil,
                avatarImage: avatar
            )
        }
    }
    
    public func clearAvatarCache() {
        self.cachedAvatars.removeAll()
    }
    
    // MARK: - Local Custom & Imported Avatar Storage
    public static var localAvatarStorageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let nntsDir = appSupport.appendingPathComponent("NNTS/Avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: nntsDir, withIntermediateDirectories: true)
        return nntsDir
    }
    
    public static func loadStoredAvatar(dirKey: String, name: String) -> NSImage? {
        let storage = localAvatarStorageURL
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        var candidatePaths: [String] = []
        let extensions = ["png", "jpg", "jpeg", "heic", "webp"]
        for ext in extensions {
            candidatePaths.append(storage.appendingPathComponent("\(dirKey).\(ext)").path)
            candidatePaths.append(storage.appendingPathComponent("\(name).\(ext)").path)
            if safeName != name {
                candidatePaths.append(storage.appendingPathComponent("\(safeName).\(ext)").path)
            }
        }
        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path),
               let img = NSImage(contentsOfFile: path) {
                return img
            }
        }
        return nil
    }
    
    private var isRestoringBookmark = false
    
    @MainActor
    public func importAvatarsFromFolder(url: URL) -> Int {
        let isAccessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessGranted { url.stopAccessingSecurityScopedResource() }
        }
        
        let fileManager = FileManager.default
        let storage = Self.localAvatarStorageURL
        var importedCount = 0
        
        var targetURL = url
        if fileManager.fileExists(atPath: url.appendingPathComponent("Chrome/Local State").path) {
            targetURL = url.appendingPathComponent("Chrome")
        } else if url.lastPathComponent.hasPrefix("Profile") || url.lastPathComponent == "Default" {
            targetURL = url.deletingLastPathComponent()
        }
        
        // Save bookmark for persistence across app restarts
        if let bookmarkData = try? targetURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmarkData, forKey: "ChromeFolderSecurityScopedBookmark")
        }
        
        func saveCroppedImage(_ image: NSImage, primaryKey: String, secondaryKey: String? = nil) {
            let circular = makeCircularImage(image: image)
            cachedAvatars[primaryKey] = circular
            if let tiff = circular.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                let destURL = storage.appendingPathComponent("\(primaryKey).png")
                try? pngData.write(to: destURL)
                if let sec = secondaryKey {
                    let safeSec = sec.replacingOccurrences(of: "/", with: "-")
                    if safeSec != primaryKey {
                        try? pngData.write(to: storage.appendingPathComponent("\(safeSec).png"))
                    }
                }
                importedCount += 1
            }
        }
        
        // 1. Try reading Local State now that we have permission
        let localStateURL = targetURL.appendingPathComponent("Local State")
        if fileManager.fileExists(atPath: localStateURL.path),
           let data = try? Data(contentsOf: localStateURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let profileObj = json["profile"] as? [String: Any],
           let infoCache = profileObj["info_cache"] as? [String: [String: Any]] {
            for (dirKey, info) in infoCache {
                let name = (info["name"] as? String) ?? (info["gaia_name"] as? String) ?? dirKey
                let profileDir = targetURL.appendingPathComponent(dirKey)
                var picCandidates = [
                    profileDir.appendingPathComponent("Google Profile Picture.png"),
                    profileDir.appendingPathComponent("Google Profile Picture.jpg"),
                    profileDir.appendingPathComponent("Edge Profile Picture.png"),
                    profileDir.appendingPathComponent("Custom Profile Picture.png")
                ]
                if let gaiaName = info["gaia_picture_file_name"] as? String, !gaiaName.isEmpty {
                    let sanitized = (gaiaName as NSString).lastPathComponent
                    if !sanitized.isEmpty && !sanitized.contains("/") && !sanitized.contains("\\") && !sanitized.contains("..") {
                        picCandidates.insert(profileDir.appendingPathComponent(sanitized), at: 0)
                    }
                }
                if let subfiles = try? fileManager.contentsOfDirectory(atPath: profileDir.path) {
                    for f in subfiles {
                        let lower = f.lowercased()
                        if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") {
                            if lower.contains("profile") || lower.contains("avatar") || lower.contains("picture") {
                                picCandidates.append(profileDir.appendingPathComponent(f))
                            }
                        }
                    }
                }
                for pic in picCandidates {
                    if fileManager.fileExists(atPath: pic.path),
                       let imgData = try? Data(contentsOf: pic),
                       let image = NSImage(data: imgData) {
                        saveCroppedImage(image, primaryKey: dirKey, secondaryKey: name)
                        break
                    }
                }
            }
        } else {
            let candidateDirs = ["Default"] + (1...20).map { "Profile \($0)" }
            for dir in candidateDirs {
                let profileDir = url.appendingPathComponent(dir)
                var picCandidates = [
                    profileDir.appendingPathComponent("Google Profile Picture.png"),
                    profileDir.appendingPathComponent("Google Profile Picture.jpg")
                ]
                if let subfiles = try? fileManager.contentsOfDirectory(atPath: profileDir.path) {
                    for f in subfiles {
                        let lower = f.lowercased()
                        if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") {
                            if lower.contains("profile") || lower.contains("avatar") || lower.contains("picture") {
                                picCandidates.append(profileDir.appendingPathComponent(f))
                            }
                        }
                    }
                }
                for pic in picCandidates {
                    if fileManager.fileExists(atPath: pic.path),
                       let imgData = try? Data(contentsOf: pic),
                       let image = NSImage(data: imgData) {
                        saveCroppedImage(image, primaryKey: dir)
                        break
                    }
                }
            }
        }
        
        // Also check if user selected a folder containing loose image files
        if let directFiles = try? fileManager.contentsOfDirectory(atPath: url.path) {
            for f in directFiles {
                let lower = f.lowercased()
                if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".heic") {
                    let fileURL = url.appendingPathComponent(f)
                    let baseName = (f as NSString).deletingPathExtension
                    if let image = NSImage(contentsOf: fileURL) {
                        saveCroppedImage(image, primaryKey: baseName)
                    }
                }
            }
        }
        
        self.cachedAvatars.removeAll()
        if !isRestoringBookmark {
            refreshProfiles()
        }
        return importedCount
    }
    
    public func restoreSecurityScopedFolderAccessIfNeeded() {
        guard !isRestoringBookmark else { return }
        guard let bookmarkData = UserDefaults.standard.data(forKey: "ChromeFolderSecurityScopedBookmark") else { return }
        isRestoringBookmark = true
        defer { isRestoringBookmark = false }
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            let _ = importAvatarsFromFolder(url: url)
        }
    }
    
    // MARK: - User-Assisted & Clipboard Avatar Capture
    private var pasteboardWatcherTimer: Timer?
    
    @discardableResult
    @MainActor
    public func saveCapturedAvatar(image: NSImage, forProfileDir dirKey: String, name: String) -> Bool {
        let circular = makeCircularImage(image: image)
        guard let tiff = circular.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return false
        }
        let dest1 = Self.localAvatarStorageURL.appendingPathComponent("\(dirKey).png")
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let dest2 = Self.localAvatarStorageURL.appendingPathComponent("\(safeName).png")
        do {
            try pngData.write(to: dest1)
            if safeName != dirKey {
                try pngData.write(to: dest2)
            }
            cachedAvatars[dirKey] = circular
            cachedAvatars[name] = circular
            if safeName != name {
                cachedAvatars[safeName] = circular
            }
            refreshProfiles()
            logger.info("Saved user-captured avatar for profile '\(name)' (\(dirKey)).")
            return true
        } catch {
            logger.error("Failed to save captured avatar: \(error.localizedDescription)")
            return false
        }
    }
    
    public static func getImageFromPasteboard(_ pboard: NSPasteboard = .general) -> NSImage? {
        if let img = NSImage(pasteboard: pboard) {
            return img
        }
        if let objects = pboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], let first = objects.first {
            return first
        }
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let first = urls.first {
            if let img = NSImage(contentsOf: first) {
                return img
            }
        }
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pboard.data(forType: type), let img = NSImage(data: data) {
                return img
            }
        }
        return nil
    }
    
    @discardableResult
    @MainActor
    public func saveCapturedAvatarFromPasteboard(forProfileDir dirKey: String, name: String) -> Bool {
        guard let img = Self.getImageFromPasteboard() else { return false }
        return saveCapturedAvatar(image: img, forProfileDir: dirKey, name: name)
    }
    
    @MainActor
    public func startPasteboardAvatarWatcher(
        forProfileDir dirKey: String,
        name: String,
        timeoutSeconds: TimeInterval = 45.0,
        onCapture: @escaping (Bool) -> Void
    ) {
        pasteboardWatcherTimer?.invalidate()
        let startChangeCount = NSPasteboard.general.changeCount
        let startTime = Date()
        
        pasteboardWatcherTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                
                if NSPasteboard.general.changeCount != startChangeCount {
                    if let img = NSImage(pasteboard: NSPasteboard.general) {
                        timer.invalidate()
                        self.pasteboardWatcherTimer = nil
                        let success = self.saveCapturedAvatar(image: img, forProfileDir: dirKey, name: name)
                        onCapture(success)
                        return
                    }
                }
                
                if Date().timeIntervalSince(startTime) >= timeoutSeconds {
                    timer.invalidate()
                    self.pasteboardWatcherTimer = nil
                    onCapture(false)
                }
            }
        }
    }
    
    @MainActor
    public func cancelPasteboardAvatarWatcher() {
        pasteboardWatcherTimer?.invalidate()
        pasteboardWatcherTimer = nil
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
        
        // 0. Priority: Use locally stored or Smart-Snapped avatar if available
        if let stored = Self.loadStoredAvatar(dirKey: dirKey, name: name) {
            let circular = makeCircularImage(image: stored)
            cachedAvatars[dirKey] = circular
            return circular
        }
        
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
        
        let hasAuthorizedFolder = UserDefaults.standard.data(forKey: "ChromeFolderSecurityScopedBookmark") != nil
        if hasAuthorizedFolder || Self.bypassLaunchInTests {
            let canonicalBase = URL(fileURLWithPath: profileDir).resolvingSymlinksInPath().path
            for picPath in candidatePics {
                let canonicalPic = URL(fileURLWithPath: picPath).resolvingSymlinksInPath().path
                guard canonicalPic.hasPrefix(canonicalBase) else { continue }
                if FileManager.default.fileExists(atPath: canonicalPic),
                   let image = NSImage(contentsOfFile: canonicalPic) {
                    let circular = makeCircularImage(image: image)
                    cachedAvatars[dirKey] = circular
                    if let tiff = circular.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiff),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        let dest = Self.localAvatarStorageURL.appendingPathComponent("\(dirKey).png")
                        try? pngData.write(to: dest)
                        let safeName = name.replacingOccurrences(of: "/", with: "-")
                        if safeName != dirKey {
                            try? pngData.write(to: Self.localAvatarStorageURL.appendingPathComponent("\(safeName).png"))
                        }
                    }
                    return circular
                }
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
        
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleanName.lowercased()
        
        // 1. Check for parenthesized tag e.g. "Igor (Al11)" -> "Al11", "Igor (GCP Free 2)" -> "GCP Free 2"
        var tag: String? = nil
        if let openParen = cleanName.firstIndex(of: "("),
           let closeParen = cleanName.lastIndex(of: ")"),
           openParen < closeParen {
            let inner = String(cleanName[cleanName.index(after: openParen)..<closeParen]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !inner.isEmpty {
                tag = inner
            }
        }
        
        let tagLower = tag?.lowercased() ?? ""
        
        // 2. Determine contextual gradient colors and distinct token badge
        let bgGradient: (top: NSColor, bottom: NSColor)
        var badgeText: String = ""
        
        if lower.contains("al11") || tagLower.contains("al11") {
            // Almost Eleven / Work: Deep Indigo to Violet
            bgGradient = (
                top: NSColor(red: 0.40, green: 0.35, blue: 0.95, alpha: 1.0),
                bottom: NSColor(red: 0.28, green: 0.20, blue: 0.78, alpha: 1.0)
            )
            badgeText = "11"
        } else if lower.contains("gcp") || tagLower.contains("gcp") || lower.contains("cloud") || tagLower.contains("cloud") {
            if lower.contains("2") || tagLower.contains("2") {
                // GCP Project 2: Radiant Amber to Warm Tangerine
                bgGradient = (
                    top: NSColor(red: 0.98, green: 0.65, blue: 0.15, alpha: 1.0),
                    bottom: NSColor(red: 0.88, green: 0.45, blue: 0.05, alpha: 1.0)
                )
                badgeText = "GC2"
            } else {
                // GCP Free / Primary Cloud: Electric Cyan to Azure
                bgGradient = (
                    top: NSColor(red: 0.12, green: 0.70, blue: 0.92, alpha: 1.0),
                    bottom: NSColor(red: 0.02, green: 0.48, blue: 0.78, alpha: 1.0)
                )
                badgeText = "GCP"
            }
        } else if lower.contains("nastya") || lower.contains("anastasia") || lower.contains("kate") || lower.contains("anna") {
            // Partner / Warm Coral Rose
            bgGradient = (
                top: NSColor(red: 0.95, green: 0.35, blue: 0.52, alpha: 1.0),
                bottom: NSColor(red: 0.82, green: 0.18, blue: 0.38, alpha: 1.0)
            )
            badgeText = "NA"
        } else if lower.contains("work") || tagLower.contains("work") || lower.contains("corp") || tagLower.contains("corp") || lower.contains("office") {
            // Corporate / Work: Slate Purple to Deep Indigo
            bgGradient = (
                top: NSColor(red: 0.48, green: 0.38, blue: 0.92, alpha: 1.0),
                bottom: NSColor(red: 0.32, green: 0.22, blue: 0.72, alpha: 1.0)
            )
            badgeText = "WK"
        } else if lower.contains("dev") || tagLower.contains("dev") || lower.contains("code") || tagLower.contains("code") {
            // Developer: Vivid Emerald to Forest Teal
            bgGradient = (
                top: NSColor(red: 0.15, green: 0.75, blue: 0.50, alpha: 1.0),
                bottom: NSColor(red: 0.05, green: 0.55, blue: 0.35, alpha: 1.0)
            )
            badgeText = "DEV"
        } else if lower.contains("test") || tagLower.contains("test") || lower.contains("qa") || tagLower.contains("qa") {
            // QA / Testing: Burnt Orange to Rust
            bgGradient = (
                top: NSColor(red: 0.95, green: 0.50, blue: 0.20, alpha: 1.0),
                bottom: NSColor(red: 0.80, green: 0.35, blue: 0.10, alpha: 1.0)
            )
            badgeText = "QA"
        } else if lower.contains("igor") || lower == "personal" || lower == "default" || lower == "default profile" {
            // Igor / Primary Personal: Vibrant Royal Blue
            bgGradient = (
                top: NSColor(red: 0.25, green: 0.55, blue: 0.98, alpha: 1.0),
                bottom: NSColor(red: 0.12, green: 0.38, blue: 0.85, alpha: 1.0)
            )
            badgeText = "IG"
        } else {
            // Fallback: Harmonious macOS palette based on hash or colorSeed
            let palette: [(top: NSColor, bottom: NSColor)] = [
                (NSColor(red: 0.25, green: 0.55, blue: 0.98, alpha: 1.0), NSColor(red: 0.12, green: 0.38, blue: 0.85, alpha: 1.0)),
                (NSColor(red: 0.58, green: 0.35, blue: 0.92, alpha: 1.0), NSColor(red: 0.42, green: 0.20, blue: 0.75, alpha: 1.0)),
                (NSColor(red: 0.95, green: 0.45, blue: 0.25, alpha: 1.0), NSColor(red: 0.82, green: 0.30, blue: 0.12, alpha: 1.0)),
                (NSColor(red: 0.18, green: 0.72, blue: 0.48, alpha: 1.0), NSColor(red: 0.08, green: 0.55, blue: 0.35, alpha: 1.0)),
                (NSColor(red: 0.92, green: 0.65, blue: 0.15, alpha: 1.0), NSColor(red: 0.80, green: 0.50, blue: 0.08, alpha: 1.0)),
                (NSColor(red: 0.12, green: 0.70, blue: 0.92, alpha: 1.0), NSColor(red: 0.02, green: 0.50, blue: 0.75, alpha: 1.0)),
                (NSColor(red: 0.92, green: 0.30, blue: 0.45, alpha: 1.0), NSColor(red: 0.78, green: 0.18, blue: 0.32, alpha: 1.0))
            ]
            let idx = abs(colorSeed ?? cleanName.hashValue) % palette.count
            bgGradient = palette[idx]
            
            if let tag = tag, !tag.isEmpty, tag.count <= 3 {
                badgeText = tag.uppercased()
            } else {
                let parts = cleanName.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "()-"))).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    let first = parts[0].prefix(1).uppercased()
                    let second = parts[1].prefix(1).uppercased()
                    badgeText = "\(first)\(second)"
                } else if let single = parts.first, single.count >= 2 {
                    badgeText = String(single.prefix(2)).uppercased()
                } else {
                    badgeText = String(cleanName.prefix(1)).uppercased()
                }
            }
        }
        
        let rect = NSRect(origin: .zero, size: size)
        let circlePath = NSBezierPath(ovalIn: rect)
        
        let gradient = NSGradient(starting: bgGradient.top, ending: bgGradient.bottom)
        gradient?.draw(in: circlePath, angle: 300)
        
        // Inner specular ring for modern glass depth
        let innerRing = NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
        NSColor.white.withAlphaComponent(0.35).setStroke()
        innerRing.lineWidth = 1.5
        innerRing.stroke()
        
        let text = badgeText.isEmpty ? "C" : badgeText
        let fontSize: CGFloat = text.count > 2 ? 30 : (text.count == 2 ? 36 : 42)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
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
