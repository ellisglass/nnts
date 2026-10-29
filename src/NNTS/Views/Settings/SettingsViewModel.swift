import SwiftUI
import AppKit
import Cocoa
import UniformTypeIdentifiers
import os

// MARK: - Settings Tab Enumeration

public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case shortcuts = "Shortcuts"
    case license = "License"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "command"
        case .license: return "checkmark.seal"
        }
    }
    
    // Backward compatibility aliases
    public static let profiles: SettingsTab = .shortcuts
    public static let quickApps: SettingsTab = .shortcuts
    public static let copyOnSelect: SettingsTab = .general
    public static let finderTidy: SettingsTab = .general
}

// MARK: - Pinned App Letter Group

public struct PinnedAppGroup: Identifiable, Sendable, Equatable {
    public var id: String { String(letter) }
    public let letter: Character
    public var items: [AntigravityItem]
    
    public init(letter: Character, items: [AntigravityItem]) {
        self.letter = letter
        self.items = items
    }
}

// MARK: - Settings View Model

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var selectedTab: SettingsTab = .general
    
    // General Tab State
    @Published public var isCapsLockRemapped: Bool = false
    @Published public var isAccessibilityTrusted: Bool = false
    @Published public var statusMessage: String? = nil
    @Published public var isStatusError: Bool = false
    @Published public var testHighlightText: String = "Try highlighting this sentence to test automatic copy-on-select!"
    
    // Application Info
    public var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
    }
    
    public var installationSource: InstallationSource {
        UpdateEngine.detectInstallationSource()
    }
    
    public var isSlotLimitReached: Bool {
        !isPro && pinnedApps.count >= AppGroupEngine.freePinnedAppsLimit
    }
    
    // Copy on Select & Finder Tidy State
    @Published public var isCopyOnSelectEnabled: Bool = true
    @Published public var isCopyToastEnabled: Bool = false
    @Published public var isCopyAllowEverywhere: Bool = true
    @Published public var isFinderTidyEnabled: Bool = true
    @Published public var finderMaxWindows: Int = 5
    
    // Shortcuts Tab State: Quick Apps
    @Published public var pinnedBundleIDs: Set<String> = []
    @Published public var pinnedApps: [AntigravityItem] = []
    @Published public var appSearchQuery: String = ""
    @Published public var appSearchResults: [InstalledAppInfo] = []
    
    public var pinnedLetterGroups: [PinnedAppGroup] {
        var letterMap: [Character: [AntigravityItem]] = [:]
        for item in pinnedApps {
            let char = item.firstLetter
            if letterMap[char] == nil {
                letterMap[char] = []
            }
            letterMap[char]!.append(item)
        }
        return letterMap.keys.sorted().map { char in
            PinnedAppGroup(letter: char, items: letterMap[char]!)
        }
    }
    
    // Shortcuts Tab State: Profiles
    @Published public var currentBrowserBundleID: String = "com.google.Chrome"
    @Published public var availableBrowsers: [ChromiumBrowserCandidate] = []
    @Published public var profiles: [ChromeProfile] = []
    @Published public var allDiscoveredProfiles: [ChromeProfile] = []
    
    public var unassignedProfiles: [ChromeProfile] {
        let assignedDirs = Set(profiles.map { $0.dir })
        return allDiscoveredProfiles.filter { !assignedDirs.contains($0.dir) }
    }
    
    public var currentBrowserName: String {
        availableBrowsers.first(where: { $0.bundleID == currentBrowserBundleID })?.name ?? "Browser"
    }
    @Published public var targetedProfileDir: String? = nil
    
    // License Tab State
    @Published public var isPro: Bool = false
    @Published public var licenseKeyInput: String = ""
    @Published public var isActivating: Bool = false
    @Published public var activationMessage: String? = nil
    @Published public var isActivationError: Bool = false
    @Published public var showingDeactivateConfirm: Bool = false
    
    public init() {
        refreshAll()
    }
    
    public func refreshAll() {
        refreshGeneral()
        refreshShortcuts()
        refreshLicense()
    }
    
    public func refreshGeneral() {
        self.isAccessibilityTrusted = AXIsProcessTrusted()
        self.isCapsLockRemapped = CapsLockEngine.shared.isStarted
        
        let copyEngine = CopyOnSelectEngine.shared
        self.isCopyOnSelectEnabled = copyEngine.isEnabled
        self.isCopyToastEnabled = copyEngine.isToastEnabled
        self.isCopyAllowEverywhere = copyEngine.allowEverywhere
        
        let tidyEngine = FinderTidyEngine.shared
        self.isFinderTidyEnabled = tidyEngine.isEnabled
        self.finderMaxWindows = tidyEngine.maxWindows
    }
    
    public func refreshShortcuts() {
        // Quick Apps
        self.pinnedBundleIDs = AppGroupEngine.selectedBundleIDs
        self.pinnedApps = AppGroupEngine.pinnedAppItems()
        self.appSearchResults = AppGroupEngine.searchInstalledApplications(query: appSearchQuery)
        
        // Profiles
        let engine = ChromeProfileEngine.shared
        self.currentBrowserBundleID = engine.browserBundleID
        self.availableBrowsers = engine.availableBrowsers
        self.profiles = engine.selectedProfiles
        self.allDiscoveredProfiles = engine.profiles
    }
    
    public func refreshLicense() {
        self.isPro = LicenseEngine.shared.isPro
    }
    
    // MARK: - Actions: General
    
    public func reapplyCapsLockRemapping() {
        let success = HIDMappingService.applyCapsLockToF18()
        if success {
            if !CapsLockEngine.shared.isStarted {
                CapsLockEngine.shared.start()
            }
            self.statusMessage = "caps lock hardware remapping applied."
            self.isStatusError = false
        } else {
            self.statusMessage = "Failed to apply remapping."
            self.isStatusError = true
        }
        refreshGeneral()
    }
    
    public func restoreDefaultCapsLock() {
        let success = HIDMappingService.restoreDefaultMapping()
        if success {
            CapsLockEngine.shared.stop()
            self.statusMessage = "Restored default system caps lock mapping."
            self.isStatusError = false
        } else {
            self.statusMessage = "Failed to restore default mapping."
            self.isStatusError = true
        }
        refreshGeneral()
    }
    
    public func clearStatusMessage() {
        self.statusMessage = nil
    }
    
    public func tidyFinderWindowsNow() {
        let limit = finderMaxWindows > 0 ? finderMaxWindows : 1
        let closedCount = FinderTidyEngine.shared.enforceMaxWindows(limit: limit)
        if closedCount > 0 {
            self.statusMessage = "Tidied Finder: closed \(closedCount) background \(closedCount == 1 ? "window" : "windows")."
            self.isStatusError = false
        } else {
            self.statusMessage = "Finder is already clean and organized."
            self.isStatusError = false
        }
    }
    
    public func checkForUpdates() {
        AppDelegate.shared?.handleCheckForUpdates()
    }
    
    public func openAppPicker() {
        AppSearchPickerWindow.shared.show()
    }
    
    public func cycleBadge(for app: AntigravityItem) -> String? {
        let sharing = pinnedApps.filter { $0.firstLetter.uppercased() == app.firstLetter.uppercased() }
        guard sharing.count > 1, let idx = sharing.firstIndex(where: { $0.bundleID == app.bundleID }) else {
            return nil
        }
        return "\(idx + 1)/\(sharing.count) ↻"
    }
    
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func setCopyOnSelectEnabled(_ enabled: Bool) {
        CopyOnSelectEngine.shared.isEnabled = enabled
        if enabled {
            CopyOnSelectEngine.shared.start()
        } else {
            CopyOnSelectEngine.shared.stop()
        }
        AppDelegate.shared?.updateMenu()
        self.isCopyOnSelectEnabled = enabled
    }
    
    public func setCopyToastEnabled(_ enabled: Bool) {
        CopyOnSelectEngine.shared.isToastEnabled = enabled
        self.isCopyToastEnabled = enabled
    }
    
    public func setCopyAllowEverywhere(_ allow: Bool) {
        CopyOnSelectEngine.shared.allowEverywhere = allow
        self.isCopyAllowEverywhere = allow
    }
    
    public func setFinderTidyEnabled(_ enabled: Bool) {
        FinderTidyEngine.shared.isEnabled = enabled
        if enabled {
            FinderTidyEngine.shared.start()
        } else {
            FinderTidyEngine.shared.stop()
        }
        AppDelegate.shared?.updateMenu()
        self.isFinderTidyEnabled = enabled
    }
    
    public func setFinderMaxWindows(_ limit: Int) {
        FinderTidyEngine.shared.maxWindows = limit
        self.finderMaxWindows = limit
        AppDelegate.shared?.updateMenu()
    }
    
    // MARK: - Actions: Shortcuts
    
    public func unpinApp(bundleID: String) {
        AppGroupEngine.deselectApp(bundleID: bundleID)
        AppDelegate.shared?.updateDynamicShortcuts()
        AppDelegate.shared?.updateMenu()
        refreshShortcuts()
    }
    
    public func movePinnedAppUp(bundleID: String) {
        if AppGroupEngine.movePinnedAppUp(bundleID: bundleID) {
            withAnimation(NNTSMotion.interactiveSnap) {
                refreshShortcuts()
            }
            AppDelegate.shared?.updateDynamicShortcuts()
            AppDelegate.shared?.updateMenu()
        }
    }
    
    public func movePinnedAppDown(bundleID: String) {
        if AppGroupEngine.movePinnedAppDown(bundleID: bundleID) {
            withAnimation(NNTSMotion.interactiveSnap) {
                refreshShortcuts()
            }
            AppDelegate.shared?.updateDynamicShortcuts()
            AppDelegate.shared?.updateMenu()
        }
    }
    
    public func pinApp(app: InstalledAppInfo) {
        let success = AppGroupEngine.toggleInstalledAppPin(app: app)
        if success {
            AppDelegate.shared?.updateDynamicShortcuts()
            AppDelegate.shared?.updateMenu()
            refreshShortcuts()
        } else {
            AppDelegate.shared?.promptAppReplacement(newBundleID: app.bundleID)
            refreshShortcuts()
        }
    }
    
    public func chooseBrowser(bundleID: String) {
        let engine = ChromeProfileEngine.shared
        engine.preferredBrowserBundleID = bundleID
        engine.browserBundleID = bundleID
        engine.refreshProfiles()
        AppDelegate.shared?.updateDynamicShortcuts()
        AppDelegate.shared?.updateMenu()
        refreshShortcuts()
    }
    
    public func refreshBrowserProfiles() {
        AppDelegate.shared?.handleRefreshProfiles()
        refreshShortcuts()
    }
    
    public var isChromeFolderLinked: Bool {
        ChromeProfileEngine.shared.isChromeFolderLinked
    }
    
    public func linkChromeFolder() {
        AppDelegate.shared?.handleLinkChromeAvatars()
        refreshShortcuts()
    }
    
    public func chooseAvatarFile(dir: String) {
        let prof = profiles.first(where: { $0.dir == dir }) ?? allDiscoveredProfiles.first(where: { $0.dir == dir })
        let name = prof?.effectiveName ?? prof?.name ?? dir
        ChromeProfileEngine.shared.chooseCustomAvatarImage(forProfileDir: dir, name: name)
        refreshShortcuts()
    }
    
    public func setAvatarFromImageURL(url: URL, dir: String) {
        let prof = profiles.first(where: { $0.dir == dir }) ?? allDiscoveredProfiles.first(where: { $0.dir == dir })
        let name = prof?.effectiveName ?? prof?.name ?? dir
        ChromeProfileEngine.shared.setCustomAvatarFromURL(url, forProfileDir: dir, name: name)
        refreshShortcuts()
    }
    
    public func resetSlotsToAllDiscovered() {
        ChromeProfileEngine.shared.resetSlotsToAllDiscovered()
        AppDelegate.shared?.updateMenu()
        refreshShortcuts()
    }
    
    public func pasteProfileAvatar(dir: String) {
        let fakeItem = NSMenuItem()
        fakeItem.representedObject = dir
        AppDelegate.shared?.handlePasteAvatarFromClipboard(fakeItem)
        refreshShortcuts()
    }
    
    public func resetProfileAvatar(dir: String) {
        let prof = profiles.first(where: { $0.dir == dir }) ?? allDiscoveredProfiles.first(where: { $0.dir == dir })
        ChromeProfileEngine.shared.deleteCustomAvatar(profileDir: dir, name: prof?.name, effectiveName: prof?.effectiveName)
        AppDelegate.shared?.updateMenu()
        refreshShortcuts()
    }
    
    public func reorderProfile(draggedDir: String, targetDir: String) {
        var current = profiles
        guard let sourceIdx = current.firstIndex(where: { $0.dir == draggedDir }),
              let targetIdx = current.firstIndex(where: { $0.dir == targetDir }),
              sourceIdx != targetIdx else { return }
        let moved = current.remove(at: sourceIdx)
        current.insert(moved, at: targetIdx)
        for i in 0..<current.count {
            current[i].index = i + 1
        }
        withAnimation(NNTSMotion.interactiveSnap) {
            self.profiles = current
        }
        ChromeProfileEngine.shared.setProfileOrder(current.map { $0.dir })
        AppDelegate.shared?.updateMenu()
    }
    
    public func moveProfileUp(dir: String) {
        var current = profiles
        guard let idx = current.firstIndex(where: { $0.dir == dir }), idx > 0 else { return }
        current.swapAt(idx, idx - 1)
        for i in 0..<current.count {
            current[i].index = i + 1
        }
        withAnimation(NNTSMotion.interactiveSnap) {
            self.profiles = current
        }
        ChromeProfileEngine.shared.setProfileOrder(current.map { $0.dir })
        AppDelegate.shared?.updateMenu()
    }
    
    public func moveProfileDown(dir: String) {
        var current = profiles
        guard let idx = current.firstIndex(where: { $0.dir == dir }), idx < current.count - 1 else { return }
        current.swapAt(idx, idx + 1)
        for i in 0..<current.count {
            current[i].index = i + 1
        }
        withAnimation(NNTSMotion.interactiveSnap) {
            self.profiles = current
        }
        ChromeProfileEngine.shared.setProfileOrder(current.map { $0.dir })
        AppDelegate.shared?.updateMenu()
    }
    
    public func addProfileToActiveSlots(dir: String) {
        ChromeProfileEngine.shared.selectProfile(dir: dir)
        withAnimation(NNTSMotion.interactiveSnap) {
            self.profiles = ChromeProfileEngine.shared.selectedProfiles
            self.allDiscoveredProfiles = ChromeProfileEngine.shared.profiles
        }
        AppDelegate.shared?.updateMenu()
    }
    
    public func removeProfileFromActiveSlots(dir: String) {
        ChromeProfileEngine.shared.deselectProfile(dir: dir)
        withAnimation(NNTSMotion.interactiveSnap) {
            self.profiles = ChromeProfileEngine.shared.selectedProfiles
            self.allDiscoveredProfiles = ChromeProfileEngine.shared.profiles
        }
        AppDelegate.shared?.updateMenu()
    }
    
    // MARK: - Actions: License
    
    public func activateLicenseKey() {
        let trimmed = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.activationMessage = "Please enter a valid license key."
            self.isActivationError = true
            return
        }
        
        self.isActivating = true
        self.activationMessage = nil
        
        Task { [weak self] in
            guard let self = self else { return }
            let result = await LicenseEngine.shared.activateOnlineDetailed(key: trimmed)
            self.isActivating = false
            switch result {
            case .success:
                self.activationMessage = "NNTS Pro activated successfully! All limits unlocked."
                self.isActivationError = false
                self.licenseKeyInput = ""
                self.refreshLicense()
                self.refreshShortcuts()
            case .invalidKey(let msg):
                self.activationMessage = msg
                self.isActivationError = true
            case .activationLimitReached:
                self.activationMessage = "Activation limit reached for this key."
                self.isActivationError = true
            case .networkError(let msg):
                self.activationMessage = "Network error: \(msg)"
                self.isActivationError = true
            }
            AppDelegate.shared?.updateMenu()
        }
    }
    
    public func deactivateLicense() {
        LicenseEngine.shared.deactivate()
        self.activationMessage = "License deactivated. NNTS is now in Free edition."
        self.isActivationError = false
        refreshLicense()
        refreshShortcuts()
        AppDelegate.shared?.updateMenu()
    }
    
    public func openPolarCheckout() {
        if let url = URL(string: LicenseEngine.polarCheckoutUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}
