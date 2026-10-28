import Foundation
import Cocoa
import AppKit
import ApplicationServices
import os

// MARK: - Filtered Profile Menu Item
public struct FilteredProfileMenuItem {
    public let element: AXUIElement
    public let title: String
    public let isMarked: Bool
    
    public init(element: AXUIElement, title: String, isMarked: Bool) {
        self.element = element
        self.title = title
        self.isMarked = isMarked
    }
}

// MARK: - macOS Accessibility Menu Bar Traversal & Active Profile Discovery
extension ChromeProfileEngine {
    
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
        var usedDirs = Set<String>()
        for (idx, name) in profileNames.enumerated() {
            var candidateDir = self.profiles.first(where: { $0.name == name || $0.effectiveName == name })?.dir
            if let c = candidateDir, usedDirs.contains(c) {
                candidateDir = nil
            }
            let baseDir = candidateDir ?? (idx == 0 ? "Default" : "Profile \(idx)")
            var dir = baseDir
            var counter = idx
            while usedDirs.contains(dir) {
                counter += 1
                dir = "Profile \(counter)"
            }
            usedDirs.insert(dir)
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
    
    public func getFilteredProfileMenuItems(bundleID: String) -> [FilteredProfileMenuItem] {
        let menuItems = getProfilesMenuItems(bundleID: bundleID)
        guard !menuItems.isEmpty else { return [] }
        
        var result: [FilteredProfileMenuItem] = []
        for item in menuItems {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
            let title = (titleRef as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            if title.isEmpty || title.hasPrefix("Edit") || title.hasPrefix("Add Profile") || title.hasPrefix("Guest") ||
               title.hasPrefix("Изменить") || title.hasPrefix("Добавить") || title.hasPrefix("Гость") {
                if !result.isEmpty && (title.isEmpty || title.hasPrefix("Edit") || title.hasPrefix("Add Profile") || title.hasPrefix("Изменить") || title.hasPrefix("Добавить")) {
                    break
                }
                continue
            }
            var markRef: CFTypeRef?
            AXUIElementCopyAttributeValue(item, ("AXMenuItemMarkChar" as NSString) as CFString, &markRef)
            let mark = markRef as? String ?? ""
            result.append(FilteredProfileMenuItem(element: item, title: title, isMarked: mark == "✓"))
        }
        return result
    }
    
    @discardableResult
    public func syncProfilesFromRunningBrowser() -> Bool {
        let bundleID = self.browserBundleID
        let runningApps = NSWorkspace.shared.runningApplications
        guard runningApps.contains(where: { $0.bundleIdentifier == bundleID }) else {
            return false
        }
        
        let axProfiles = discoverProfilesViaAccessibility(bundleID: bundleID)
        guard !axProfiles.isEmpty else { return false }
        
        let currentNames = self.profiles.map { $0.name }
        let newNames = axProfiles.map { $0.name }
        if currentNames != newNames {
            logger.info("Syncing \(axProfiles.count) profiles from running browser (\(bundleID)).")
            self.profiles = axProfiles
            saveCachedProfiles(axProfiles, bundleID: bundleID)
            applySavedProfileSelection()
            return true
        }
        return false
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
    
    public func findMenuItem(for profile: ChromeProfile, in menuItems: [AXUIElement]) -> AXUIElement? {
        let targetNorm = profile.expectedMenuTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let effNorm = profile.effectiveName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let nameNorm = profile.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        for item in menuItems {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleRef)
            guard let title = titleRef as? String else { continue }
            let norm = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            if norm == targetNorm || norm == effNorm || norm == nameNorm {
                return item
            }
            if !effNorm.isEmpty && (norm.contains("(\(effNorm))") || norm.hasSuffix(" (\(effNorm))")) {
                return item
            }
            if !nameNorm.isEmpty && (norm.contains("(\(nameNorm))") || norm.hasSuffix(" (\(nameNorm))")) {
                return item
            }
            if let email = profile.email?.lowercased(), !email.isEmpty, norm.contains(email) {
                return item
            }
        }
        return nil
    }
    
    public func getActiveProfileDir() -> String? {
        let filtered = getFilteredProfileMenuItems(bundleID: self.browserBundleID)
        if let activeItem = filtered.first(where: { $0.isMarked }) {
            let activeTitleNorm = activeItem.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            func matchInProfiles(_ list: [ChromeProfile]) -> String? {
                list.first(where: {
                    let nameNorm = $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let effNorm = $0.effectiveName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    let expNorm = $0.expectedMenuTitle.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    return activeTitleNorm == nameNorm || activeTitleNorm == effNorm || activeTitleNorm == expNorm || activeTitleNorm.contains("(\(effNorm))") || activeTitleNorm.contains("(\(nameNorm))")
                })?.dir
            }
            
            if let dir = matchInProfiles(self.profiles) {
                return dir
            }
            
            if syncProfilesFromRunningBrowser() {
                if let dir = matchInProfiles(self.profiles) {
                    return dir
                }
            }
        }
        return nil
    }
}
