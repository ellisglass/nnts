import Cocoa
import AppKit
import SwiftUI

// MARK: - Hotkey Engine Callbacks & Dynamic Shortcut Routing
extension AppDelegate {
    internal func handleAppLetterTrigger(char: Character, items: [AntigravityItem]) {
        statusItem?.menu?.cancelTracking()
        logger.info("Caps-Lock + \(char) triggered for \(items.map { $0.name }).")
        TelemetryBuffer.shared.append(category: "switcher", level: "INFO", message: "Caps-Lock + \(char) letter cycle.")
        guard !items.isEmpty else { return }
        
        let targetMode = ActiveSwitcherMode.appLetter(char)
        if !isCyclingHUDActive || activeMode != targetMode {
            isCyclingHUDActive = true
            activeMode = targetMode
            
            let profileEngine = ChromeProfileEngine.shared
            let containsBrowser = items.contains(where: { item in
                item.bundleID == profileEngine.browserBundleID ||
                ChromeProfileEngine.supportedBrowsers.contains(where: { b in b.bundleID == item.bundleID })
            })
            
            var initialIdx = 0
            var initialProfIdx = 0
            
            if containsBrowser {
                let profiles = profileEngine.selectedProfiles
                let activeDir = profileEngine.getActiveProfileDir()
                initialProfIdx = profiles.firstIndex(where: { $0.dir == activeDir }) ?? 0
            }
            
            let frontBundleID = AppGroupEngine.mockFrontmostBundleID ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            initialIdx = AppGroupEngine.prioritizedItemIndex(for: items, letter: char, frontmostBundleID: frontBundleID)
            
            MinimalHUDWindow.shared.showAppGroup(mode: .antigravity, items: items, selectedIndex: initialIdx, profileIndex: initialProfIdx)
        } else {
            MinimalHUDWindow.shared.selectNext()
        }
    }
    
    internal func promptForMissingApp(bundleID: String) {
        if let hook = onPromptForMissingApp {
            hook(bundleID)
            return
        }
        guard NSApp.activationPolicy() == .regular else {
            logger.warning("Application \(bundleID) is not installed; skipping prompt in non-regular app environment.")
            return
        }
        
        let appName = AppGroupEngine.allDiscoveredItems().first(where: { $0.bundleID == bundleID })?.name
            ?? AppGroupEngine.allEngines.flatMap({ $0.candidates }).first(where: { $0.bundleID == bundleID })?.name
            ?? bundleID
        
        let alert = NSAlert()
        alert.messageText = "\(appName) is not installed"
        alert.informativeText = "'\(appName)' is pinned to your Quick Apps, but it is not installed on this Mac. Would you like to choose a replacement application?"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Choose Replacement...")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            self.handleOpenAppSearch()
        }
    }
    
    internal func focusApp(bundleID: String) {
        AppGroupEngine.recordActiveApp(bundleID: bundleID)
        if bundleID == ChromeProfileEngine.shared.browserBundleID ||
           ChromeProfileEngine.supportedBrowsers.contains(where: { $0.bundleID == bundleID }) {
            ChromeProfileEngine.shared.focusChrome()
        } else {
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) == nil,
               !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleID }) {
                promptForMissingApp(bundleID: bundleID)
                return
            }
            AppGroupEngine.focusItem(bundleID: bundleID)
        }
    }
    
    internal func handleChromeTrigger() {
        statusItem?.menu?.cancelTracking()
        let profileEngine = ChromeProfileEngine.shared
        logger.info("Caps-Lock + C triggered.")
        TelemetryBuffer.shared.append(category: "switcher", level: "INFO", message: "Caps-Lock + C triggered.")
        profileEngine.syncProfilesFromRunningBrowser()
        
        let profiles = profileEngine.selectedProfiles
        guard !profiles.isEmpty else {
            profileEngine.focusChrome()
            return
        }
        
        if !self.isCyclingHUDActive || self.activeMode != .chrome {
            self.isCyclingHUDActive = true
            self.activeMode = .chrome
            
            let frontApp = NSWorkspace.shared.frontmostApplication
            let isChromeFront = frontApp?.bundleIdentifier == profileEngine.browserBundleID
            
            let activeDir = profileEngine.getActiveProfileDir()
            let currentIdx = profiles.firstIndex(where: { $0.dir == activeDir }) ?? 0
            
            let initialIdx: Int
            if isChromeFront {
                initialIdx = (currentIdx + 1) % profiles.count
            } else {
                initialIdx = currentIdx
            }
            
            MinimalHUDWindow.shared.show(profiles: profiles, selectedIndex: initialIdx)
        } else {
            MinimalHUDWindow.shared.selectNext()
        }
    }
    
    /// Re-evaluates and binds dynamic hotkeys based strictly on the first letter of each pinned application's name.
    public func updateDynamicShortcuts() {
        let groups = AppGroupEngine.pinnedAppsGroupedByLetter()
        var triggers: [UInt32: @MainActor () -> Void] = [:]
        
        let browserChar = ChromeProfileEngine.shared.primaryShortcutChar
        let browserCode = ChromeProfileEngine.shared.primaryShortcutKeyCode
        let browserGroup = groups.first(where: { $0.letter == browserChar })
        
        // 1. Primary browser trigger (Unified ring if pinned apps share browser letter; classic profile HUD otherwise)
        if let browserGroup = browserGroup, !browserGroup.items.isEmpty {
            let browserItem = AppGroupEngine.browserAsAntigravityItem()
            let unifiedItems = [browserItem] + browserGroup.items
            let indexedItems = unifiedItems.enumerated().map { idx, item in
                AntigravityItem(name: item.name, bundleID: item.bundleID, path: item.path, icon: item.icon, index: idx + 1)
            }
            triggers[browserCode] = { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.handleAppLetterTrigger(char: browserChar, items: indexedItems)
                }
            }
        } else {
            triggers[browserCode] = { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.handleChromeTrigger()
                }
            }
        }
        
        // 2. Register every other pinned letter's items
        for group in groups {
            let char = group.letter
            if char == browserChar { continue } // Handled above in unified ring
            
            if let code = KeyCodes.keyCode(for: char) {
                let items = group.items
                triggers[code] = { [weak self] in
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        self.handleAppLetterTrigger(char: char, items: items)
                    }
                }
            }
        }
        
        CapsLockEngine.shared.dynamicKeyTriggers = triggers
        logger.info("Dynamic app shortcuts updated for pinned apps: \(groups.map { "\($0.letter): \($0.items.map { $0.name })" })")
    }
    
    internal func setupEngineCallbacks() {
        let profileEngine = ChromeProfileEngine.shared
        let capsEngine = CapsLockEngine.shared
        
        updateDynamicShortcuts()
        capsEngine.onChromeTrigger = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.handleChromeTrigger()
            }
        }
        
        capsEngine.onProfileTrigger = { [weak self] digit in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.logger.info("Caps-Lock + \(digit) triggered.")
                TelemetryBuffer.shared.append(category: "switcher", level: "INFO", message: "Caps-Lock + \(digit) profile select triggered.")
                self.triggerMascotGaze(offset: digit <= 2 ? -0.8 : 0.8)
                profileEngine.syncProfilesFromRunningBrowser()
                
                if self.isCyclingHUDActive && self.activeMode != .chrome && !ChromeSwitcherState.shared.antigravityItems.isEmpty {
                    let isCurrentBrowser = ChromeSwitcherState.shared.selectedAppItem.map { item in
                        item.bundleID == profileEngine.browserBundleID ||
                        ChromeProfileEngine.supportedBrowsers.contains(where: { b in b.bundleID == item.bundleID })
                    } ?? false
                    
                    if isCurrentBrowser && !profileEngine.selectedProfiles.isEmpty {
                        let targetProfileIdx = max(0, min(digit - 1, profileEngine.selectedProfiles.count - 1))
                        MinimalHUDWindow.shared.selectChromeProfile(index: targetProfileIdx)
                        return
                    } else {
                        let appItems = ChromeSwitcherState.shared.antigravityItems
                        let targetAppIdx = max(0, min(digit - 1, appItems.count - 1))
                        MinimalHUDWindow.shared.updateSelection(to: targetAppIdx)
                        return
                    }
                }
                
                let profiles = profileEngine.selectedProfiles
                guard !profiles.isEmpty else { return }
                let targetIdx = max(0, min(digit - 1, profiles.count - 1))
                if !self.isCyclingHUDActive {
                    self.isCyclingHUDActive = true
                    self.activeMode = .chrome
                    MinimalHUDWindow.shared.show(profiles: profiles, selectedIndex: targetIdx)
                } else if self.activeMode == .chrome {
                    MinimalHUDWindow.shared.updateSelection(to: targetIdx)
                } else {
                    MinimalHUDWindow.shared.selectChromeProfile(index: targetIdx)
                }
            }
        }
        
        capsEngine.onNavigateLeft = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.isCyclingHUDActive else { return }
                self.triggerMascotGaze(offset: -0.8)
                MinimalHUDWindow.shared.selectPreviousCard()
            }
        }
        
        capsEngine.onNavigateRight = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self, self.isCyclingHUDActive else { return }
                self.triggerMascotGaze(offset: 0.8)
                MinimalHUDWindow.shared.selectNextCard()
            }
        }
        
        capsEngine.onCancelTrigger = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.logger.info("Escape pressed: cancelling switcher HUD.")
                TelemetryBuffer.shared.append(category: "switcher", level: "INFO", message: "Switcher HUD cancelled via Escape.")
                self.isCyclingHUDActive = false
                self.activeMode = .none
                MinimalHUDWindow.shared.hideImmediate()
            }
        }
        
        capsEngine.onModifierReleased = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard self.isCyclingHUDActive else { return }
                
                let mode = self.activeMode
                self.isCyclingHUDActive = false
                self.activeMode = .none
                
                // RULE 9: ALWAYS hide HUD before triggering application focus!
                MinimalHUDWindow.shared.hideImmediate()
                
                switch mode {
                case .chrome:
                    let targetProfile = ChromeSwitcherState.shared.selectedProfile
                    if let target = targetProfile {
                        self.logger.info("Caps-Lock released: switching to profile '\(target.effectiveName)' (\(target.dir)).")
                        TelemetryBuffer.shared.append(category: "switcher", level: "INFO", message: "Switched to Chrome profile '\(target.effectiveName)' (\(target.dir)).")
                        profileEngine.focusProfile(target)
                    } else {
                        TelemetryBuffer.shared.append(category: "switcher", level: "INFO", message: "Switched to Chrome.")
                        profileEngine.focusChrome()
                    }
                case .appLetter(let char):
                    if let target = ChromeSwitcherState.shared.selectedAppItem {
                        let isBrowser = target.bundleID == profileEngine.browserBundleID ||
                                        ChromeProfileEngine.supportedBrowsers.contains(where: { $0.bundleID == target.bundleID })
                        if isBrowser {
                            let targetProfile = ChromeSwitcherState.shared.selectedProfile
                            if let prof = targetProfile {
                                self.logger.info("Caps-Lock released: switching to Chrome profile '\(prof.effectiveName)' (\(prof.dir)).")
                                TelemetryBuffer.shared.append(category: "switcher", level: "INFO", message: "Switched to browser profile '\(prof.effectiveName)' (\(prof.dir)).")
                                profileEngine.focusProfile(dir: prof.dir)
                            } else {
                                TelemetryBuffer.shared.append(category: "switcher", level: "INFO", message: "Switched to browser.")
                                profileEngine.focusChrome()
                            }
                        } else {
                            self.logger.info("Caps-Lock released: switching to '\(target.name)' (\(target.bundleID)) for key \(char).")
                            TelemetryBuffer.shared.append(category: "switcher", level: "INFO", message: "Switched to '\(target.name)' (\(target.bundleID)) for key \(char).")
                            self.focusApp(bundleID: target.bundleID)
                        }
                    }
                case .none:
                    break
                }
            }
        }
    }
}
