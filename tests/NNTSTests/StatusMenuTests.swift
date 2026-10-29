import Foundation
import Testing
import AppKit
@testable import NNTS

extension ChromeQuickAccessUnitTests {
    @Test @MainActor
    func testStatusMenuStructure() {
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let mockAiAgent = [
            AntigravityItem(name: "Antigravity", bundleID: "com.google.antigravity", path: "/Applications/Antigravity.app", icon: dummyIcon, index: 1)
        ]
        let mockIde = [
            AntigravityItem(name: "Antigravity IDE", bundleID: "com.google.antigravity-ide", path: "/Applications/Antigravity IDE.app", icon: dummyIcon, index: 1)
        ]
        let mockTerminal = [
            AntigravityItem(name: "iTerm2", bundleID: "com.googlecode.iterm2", path: "/Applications/iTerm.app", icon: dummyIcon, index: 1),
            AntigravityItem(name: "Terminal", bundleID: "com.apple.Terminal", path: "/System/Applications/Utilities/Terminal.app", icon: dummyIcon, index: 2)
        ]
        let mockNotes = [
            AntigravityItem(name: "Notes", bundleID: "com.apple.Notes", path: "/System/Applications/Notes.app", icon: dummyIcon, index: 1)
        ]
        
        AppGroupEngine.aiAgent.customItemsOverride = mockAiAgent
        AppGroupEngine.ide.customItemsOverride = mockIde
        AppGroupEngine.terminal.customItemsOverride = mockTerminal
        AppGroupEngine.notes.customItemsOverride = mockNotes
        
        AppGroupEngine.aiAgent.refreshItems()
        AppGroupEngine.ide.refreshItems()
        AppGroupEngine.terminal.refreshItems()
        AppGroupEngine.notes.refreshItems()
        
        let previousSelected = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            AppGroupEngine.aiAgent.customItemsOverride = nil
            AppGroupEngine.ide.customItemsOverride = nil
            AppGroupEngine.terminal.customItemsOverride = nil
            AppGroupEngine.notes.customItemsOverride = nil
            AppGroupEngine.aiAgent.refreshItems()
            AppGroupEngine.ide.refreshItems()
            AppGroupEngine.terminal.refreshItems()
            AppGroupEngine.notes.refreshItems()
            
            if let prev = previousSelected {
                UserDefaults.standard.set(prev, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
        }

        UserDefaults.standard.set(AppGroupEngine.defaultPinnedBundleIDs, forKey: "SelectedAppBundleIDs")
        let appDelegate = AppDelegate()
        let menu = appDelegate.buildStatusMenu()
        
        // 1. Browsers & Profiles section header removed for clean HUD layout
        let browserSectionHeader = menu.items.first(where: { $0.title.contains("Browsers & Profiles") })
        #expect(browserSectionHeader == nil, "Browsers & Profiles header must be removed")
        
        let chromeItem = menu.items.first(where: { $0.title.contains("Chrome") })
        #expect(chromeItem != nil)
        #expect(chromeItem?.keyEquivalent == "c")
        #expect(chromeItem?.action != nil)
        #expect(chromeItem?.view is ProfileStripView, "Chrome item hosts the unified HUD-style ProfileStripView")
        
        // 2. Preferences: Copy on Select & Settings...
        let copyItem = menu.items.first(where: { $0.title.hasPrefix("Copy on Select") })
        #expect(copyItem != nil)
        #expect(copyItem?.state == .off)
        #expect(copyItem?.title.contains("· On") == true || copyItem?.title.contains("· Off") == true)
        
        let settingsItem = menu.items.first(where: { $0.title == "Settings..." })
        #expect(settingsItem != nil)
        #expect(settingsItem?.keyEquivalent == ",")
        #expect(settingsItem?.keyEquivalentModifierMask == [.command])
        #expect(settingsItem?.action != nil)
        
        // 3. System & Lifecycle items
        let aboutItem = menu.items.first(where: { $0.title.contains("About NNTS") })
        #expect(aboutItem != nil)
        
        let reportItem = menu.items.first(where: { $0.title.contains("Report an Issue") })
        #expect(reportItem != nil)
        
        let quitItem = menu.items.first(where: { $0.title == "Quit NNTS" })
        #expect(quitItem != nil)
        #expect(quitItem?.keyEquivalent == "q")
        #expect(quitItem?.keyEquivalentModifierMask == [.command])
        
        // 4. Quick Apps are streamlined into a compact Cheat Sheet submenu and NOT cluttering the root status menu
        let quickAppsHeader = menu.items.first(where: { $0.isSectionHeader && $0.title.contains("Quick Apps") })
        #expect(quickAppsHeader == nil, "Quick Apps section header must not be in root menu")
        
        let cheatSheetItem = menu.items.first(where: { $0.title.contains("Quick Apps Cheat Sheet") })
        #expect(cheatSheetItem != nil, "Quick Apps Cheat Sheet submenu must be present in menu")
        #expect(cheatSheetItem?.hasSubmenu == true, "Cheat sheet must host a dropdown submenu")
        
        let changeAppItem = menu.items.first(where: { $0.title == "Manage Quick Apps..." })
        #expect(changeAppItem == nil, "Manage Quick Apps must not be in root menu")
    }

    @Test @MainActor
    func testTwoTierMenuLayoutWithMascotBetween() {
        let appDelegate = AppDelegate()
        let menu = appDelegate.buildStatusMenu()
        
        let profileStripIdx = menu.items.firstIndex(where: { $0.view is ProfileStripView })
        let copyIdx = menu.items.firstIndex(where: { $0.title.hasPrefix("Copy on Select") })
        let settingsIdx = menu.items.firstIndex(where: { $0.title == "Settings..." })
        let aboutIdx = menu.items.firstIndex(where: { $0.title.contains("About NNTS") })
        let reportIdx = menu.items.firstIndex(where: { $0.title.contains("Report an Issue") })
        let quitIdx = menu.items.firstIndex(where: { $0.title.contains("Quit NNTS") })
        
        #expect(profileStripIdx != nil, "ProfileStripView must exist")
        #expect(copyIdx != nil, "Copy on Select must exist")
        #expect(settingsIdx != nil, "Settings... must exist")
        #expect(aboutIdx != nil, "About NNTS must exist")
        #expect(reportIdx != nil, "Report an Issue must exist")
        #expect(quitIdx != nil, "Quit NNTS must exist")
        
        if let pIdx = profileStripIdx, let cIdx = copyIdx,
           let sIdx = settingsIdx, let aIdx = aboutIdx, let rIdx = reportIdx, let qIdx = quitIdx {
            #expect(pIdx < cIdx)
            #expect(cIdx < sIdx)
            #expect(sIdx < aIdx)
            #expect(aIdx < rIdx)
            #expect(rIdx < qIdx)
        }
    }

    @Test @MainActor
    func testStreamlinedMenuHierarchyAndCyclicAffordance() {
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let mockAiAgent = [
            AntigravityItem(name: "Antigravity", bundleID: "com.google.antigravity", path: "/Applications/Antigravity.app", icon: dummyIcon, index: 1)
        ]
        let mockIde = [
            AntigravityItem(name: "Antigravity IDE", bundleID: "com.google.antigravity-ide", path: "/Applications/Antigravity IDE.app", icon: dummyIcon, index: 1)
        ]
        AppGroupEngine.aiAgent.customItemsOverride = mockAiAgent
        AppGroupEngine.ide.customItemsOverride = mockIde
        AppGroupEngine.aiAgent.refreshItems()
        AppGroupEngine.ide.refreshItems()
        
        let previousSelected = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            AppGroupEngine.aiAgent.customItemsOverride = nil
            AppGroupEngine.ide.customItemsOverride = nil
            AppGroupEngine.aiAgent.refreshItems()
            AppGroupEngine.ide.refreshItems()
            if let prev = previousSelected {
                UserDefaults.standard.set(prev, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
        }
        
        UserDefaults.standard.set(["com.google.antigravity", "com.google.antigravity-ide"], forKey: "SelectedAppBundleIDs")
        let appDelegate = AppDelegate()
        appDelegate.updateDynamicShortcuts()
        let menu = appDelegate.buildStatusMenu()
        
        // 1. Cyclic trigger registered for 'A' in CapsLockEngine
        let aTrigger = CapsLockEngine.shared.dynamicKeyTriggers[KeyCodes.kVK_ANSI_A]
        #expect(aTrigger != nil, "Trigger for 'A' must be registered in dynamic triggers")
        
        // 2. Profile Strip View (Concept 2 + 3 horizontal strip)
        let profileStripItem = menu.items.first(where: { $0.view is ProfileStripView })
        #expect(profileStripItem != nil, "Profile strip custom view should exist for compact horizontal layout")
        
        // 3. Settings Menu Item with ⌘,
        let settingsItem = menu.items.first(where: { $0.title == "Settings..." })
        #expect(settingsItem != nil)
        #expect(settingsItem?.keyEquivalent == ",")
        #expect(settingsItem?.keyEquivalentModifierMask == [.command])
        #expect(settingsItem?.action != nil)
        
        // 4. Utility section ordering and checkmark hygiene
        let copyItem = menu.items.first(where: { $0.title.hasPrefix("Copy on Select") })
        let quitItem = menu.items.first(where: { $0.title.contains("Quit NNTS") })
        #expect(copyItem != nil)
        #expect(copyItem?.state == .off, "Copy on Select must not use gutter checkmark to prevent left margin collision")
        #expect(copyItem?.title.contains("· On") == true || copyItem?.title.contains("· Off") == true, "Copy on Select must display inline state badge")
        #expect(quitItem != nil)
        
        if let copyIdx = menu.items.firstIndex(where: { $0.title.hasPrefix("Copy on Select") }),
           let settingsIdx = menu.items.firstIndex(where: { $0.title == "Settings..." }),
           let quitIdx = menu.items.firstIndex(where: { $0.title.contains("Quit NNTS") }) {
            #expect(copyIdx < settingsIdx)
            #expect(settingsIdx < quitIdx)
        }
    }

    @Test @MainActor
    func testStatusMenuCyclicBadgesIncludeBrowser() {
        let prev = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            if let p = prev {
                UserDefaults.standard.set(p, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
        }
        
        // 1. With an app sharing the browser letter 'C' (e.g. Calculator)
        let calcBundle = "com.apple.calculator"
        UserDefaults.standard.set([calcBundle, "com.apple.Notes"], forKey: "SelectedAppBundleIDs")
        
        let appDelegate = AppDelegate()
        let menuWithC = appDelegate.buildStatusMenu()
        
        let chromeItem = menuWithC.items.first(where: { $0.view is ProfileStripView || $0.title.contains("Chrome") })
        #expect(chromeItem != nil)
        let chromeTitle = chromeItem?.attributedTitle?.string ?? chromeItem?.title ?? ""
        #expect(chromeTitle.contains("· 1/2 ↻"), "Chrome must display 1/2 cyclic badge when Calculator shares letter C")
        
        // Calculator is registered in pinned apps and shares letter C
        let calcPinned = AppGroupEngine.pinnedAppItems().first(where: { $0.bundleID == calcBundle })
        #expect(calcPinned != nil)
        
        // 2. Without any app sharing letter 'C'
        UserDefaults.standard.set(["com.apple.Notes", "com.apple.Terminal"], forKey: "SelectedAppBundleIDs")
        let menuWithoutC = appDelegate.buildStatusMenu()
        let soloChromeItem = menuWithoutC.items.first(where: { $0.view is ProfileStripView || $0.title.contains("Chrome") })
        let soloChromeTitle = soloChromeItem?.attributedTitle?.string ?? soloChromeItem?.title ?? ""
        #expect(!soloChromeTitle.contains("↻"), "Solo Chrome must NOT display cyclic badge when no pinned apps share letter C")
    }

    @Test @MainActor
    func testUnifiedMenuLayoutHasNoCategorySplits() {
        let prevSelected = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            if let prev = prevSelected {
                UserDefaults.standard.set(prev, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
        }
        
        UserDefaults.standard.set(AppGroupEngine.defaultPinnedBundleIDs, forKey: "SelectedAppBundleIDs")
        AppGroupEngine.selectedBundleIDs = Set(AppGroupEngine.defaultPinnedBundleIDs)
        
        let appDelegate = AppDelegate()
        let menu = appDelegate.buildStatusMenu()
        
        // Scan all section headers
        let sectionHeaders = menu.items.filter { $0.isSectionHeader }
        let headerTitles = sectionHeaders.map { $0.title }
        
        // Root menu must have no distracting category split headers
        #expect(!headerTitles.contains(where: { $0.contains("Quick Apps") }))
        #expect(sectionHeaders.count == 0, "There should be 0 category section headers in the unified card layout")
        
        // Strictly forbidden legacy category header titles
        let forbiddenHeaders = ["Core Toolset", "Toolkit", "Toolset Shortcuts", "Quick Shortcuts"]
        for forbidden in forbiddenHeaders {
            #expect(!headerTitles.contains(where: { $0.contains(forbidden) }), "Header must not contain '\(forbidden)'")
        }
    }

    @Test @MainActor
    func testQuickAppsCheatSheetSubmenuStructureAndReadOnlyInvariants() {
        let appDelegate = AppDelegate()
        let menu = appDelegate.buildStatusMenu()
        
        let cheatSheetItem = menu.items.first(where: { $0.title.contains("Quick Apps Cheat Sheet") })
        #expect(cheatSheetItem != nil, "Quick Apps Cheat Sheet item must exist in root menu")
        guard let submenu = cheatSheetItem?.submenu else {
            Issue.record("Submenu missing on cheat sheet item")
            return
        }
        
        // Invariant 1: Root menu does NOT contain individual app launch buttons
        #expect(menu.items.first(where: { $0.action == #selector(AppDelegate.handleCoreAppClick(_:)) }) == nil)
        
        // Invariant 2: Cheat sheet entries are read-only reference rows (action is nil)
        let referenceRows = submenu.items.filter { !$0.isSeparatorItem && $0.action != #selector(AppDelegate.handleOpenShortcutsSettings) }
        for row in referenceRows {
            #expect(row.action == nil, "Cheat sheet entries must be strictly read-only without launch actions")
            #expect(row.isEnabled == false, "Cheat sheet entries must be disabled from mouse click actions")
            #expect(row.attributedTitle != nil, "Cheat sheet entries must provide formatted keycap badges")
        }
        
        // Invariant 3: Submenu contains direct shortcut to Settings Shortcuts tab
        let configItem = submenu.items.first(where: { $0.title.contains("Configure Quick Apps") })
        #expect(configItem != nil, "Configure Quick Apps entry must exist in cheat sheet submenu")
        #expect(configItem?.action == #selector(AppDelegate.handleOpenShortcutsSettings))
    }

    @Test @MainActor
    func testMacOS27MenuItemImageVisibility() {
        let appDelegate = AppDelegate()
        let menu = appDelegate.buildStatusMenu()
        
        // Ensure menu contains items
        #expect(!menu.items.isEmpty)
        
        let selector = NSSelectorFromString("preferredImageVisibility")
        for item in menu.items {
            if item.image != nil && item.responds(to: selector) {
                let val = item.value(forKey: "preferredImageVisibility") as? Int
                #expect(val == 1)
            }
        }
    }
}
