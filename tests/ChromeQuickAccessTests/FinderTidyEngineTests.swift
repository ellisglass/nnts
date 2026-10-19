import Foundation
import Testing
import AppKit
@testable import ChromeQuickAccess

extension ChromeQuickAccessUnitTests {
    @Test @MainActor
    func testFinderAndSystemSettingsDiscoveryAndPinning() {
        // 1. Finder discovery
        let apps = AppGroupEngine.scanInstalledApplications(forceRefresh: true)
        let finderApp = apps.first(where: { $0.bundleID == "com.apple.finder" })
        #expect(finderApp != nil)
        #expect(finderApp?.name == "Finder")
        #expect(finderApp?.path == "/System/Library/CoreServices/Finder.app")
        
        // 2. Search filtering for Finder and Settings
        let finderResults = AppGroupEngine.searchInstalledApplications(query: "Finder")
        #expect(finderResults.contains(where: { $0.bundleID == "com.apple.finder" }))
        
        let settingsResults = AppGroupEngine.searchInstalledApplications(query: "Settings")
        #expect(settingsResults.contains(where: { $0.bundleID == "com.apple.systempreferences" }))
        
        // 3. Custom Engine candidate reloading and persistence across refreshItems
        let prevCustomPaths = UserDefaults.standard.stringArray(forKey: "CustomAppPaths")
        let prevSelected = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            if let prev = prevCustomPaths {
                UserDefaults.standard.set(prev, forKey: "CustomAppPaths")
            } else {
                UserDefaults.standard.removeObject(forKey: "CustomAppPaths")
            }
            if let prev = prevSelected {
                UserDefaults.standard.set(prev, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
            AppGroupEngine.custom.refreshItems()
        }
        
        let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        let registeredFinder = AppGroupEngine.registerCustomApp(url: finderURL)
        #expect(registeredFinder != nil)
        #expect(registeredFinder?.bundleID == "com.apple.finder")
        
        // Ensure refreshItems() preserves Finder in custom.items
        AppGroupEngine.custom.refreshItems()
        #expect(AppGroupEngine.custom.items.contains(where: { $0.bundleID == "com.apple.finder" }))
        
        // 4. pinnedAppItems retains Finder and preserves order
        AppGroupEngine.selectApp(bundleID: "com.apple.finder")
        let pinned = AppGroupEngine.pinnedAppItems()
        #expect(pinned.contains(where: { $0.bundleID == "com.apple.finder" }))
    }
    

    @Test @MainActor
    func testFinderWindowMaxCeilingEnforcement() {
        let engine = FinderTidyEngine.shared
        
        var closedWindowIDs: [String] = []
        FinderTidyEngine.mockCloseHandler = { win in
            closedWindowIDs.append(win.id)
            return true
        }
        defer {
            FinderTidyEngine.mockWindowsProvider = nil
            FinderTidyEngine.mockCloseHandler = nil
        }
        
        // 8 windows: Window 0 is main active, 1..7 are background windows ordered front to back
        let mockWindows = (0..<8).map { i in
            FinderWindowInfo(
                id: "win_\(i)",
                title: "Folder \(i)",
                isMain: i == 0,
                zIndex: i
            )
        }
        FinderTidyEngine.mockWindowsProvider = { mockWindows }
        
        // Enforce ceiling of 3 windows
        let closedCount = engine.enforceMaxWindows(limit: 3)
        
        // Total excess: 8 - 3 = 5 windows closed
        #expect(closedCount == 5)
        // Eviction order: highest zIndex (oldest background windows) first: win_7, win_6, win_5, win_4, win_3
        #expect(closedWindowIDs == ["win_7", "win_6", "win_5", "win_4", "win_3"])
        // Active window (win_0) was NEVER closed!
        #expect(!closedWindowIDs.contains("win_0"))
    }
    

    @Test @MainActor
    func testFinderWindowActiveWindowImmunity() {
        let engine = FinderTidyEngine.shared
        
        var closedIDs: [String] = []
        FinderTidyEngine.mockCloseHandler = { win in
            closedIDs.append(win.id)
            return true
        }
        defer {
            FinderTidyEngine.mockWindowsProvider = nil
            FinderTidyEngine.mockCloseHandler = nil
        }
        
        // Only 1 window open, and it is the active main window
        let singleActive = [
            FinderWindowInfo(id: "main_win", title: "Active Project", isMain: true, zIndex: 0)
        ]
        FinderTidyEngine.mockWindowsProvider = { singleActive }
        
        // Enforce ceiling of 0 or tidy down
        let closedCount = engine.enforceMaxWindows(limit: 1)
        #expect(closedCount == 0)
        #expect(closedIDs.isEmpty)
        
        let tidyClosed = engine.tidyNow(keepCount: 1)
        #expect(tidyClosed == 0)
        #expect(closedIDs.isEmpty)
    }
    

    @Test @MainActor
    func testFinderWindowDuplicateFolderPruning() {
        let engine = FinderTidyEngine.shared
        
        var closedIDs: [String] = []
        FinderTidyEngine.mockCloseHandler = { win in
            closedIDs.append(win.id)
            return true
        }
        defer {
            FinderTidyEngine.mockWindowsProvider = nil
            FinderTidyEngine.mockCloseHandler = nil
        }
        
        // 5 windows with duplicates:
        // [0] Downloads (Active, z:0)
        // [1] Code (z:1)
        // [2] Downloads (Duplicate 1, z:2)
        // [3] Downloads (Duplicate 2, z:3)
        // [4] Code (Duplicate 1, z:4)
        let dupWindows = [
            FinderWindowInfo(id: "dl_0", title: "Downloads", isMain: true, zIndex: 0),
            FinderWindowInfo(id: "code_1", title: "Code", isMain: false, zIndex: 1),
            FinderWindowInfo(id: "dl_2", title: "Downloads", isMain: false, zIndex: 2),
            FinderWindowInfo(id: "dl_3", title: "Downloads", isMain: false, zIndex: 3),
            FinderWindowInfo(id: "code_4", title: "Code", isMain: false, zIndex: 4)
        ]
        FinderTidyEngine.mockWindowsProvider = { dupWindows }
        
        let closed = engine.closeDuplicateWindows()
        #expect(closed == 3) // dl_2, dl_3, code_4
        #expect(closedIDs.contains("dl_2"))
        #expect(closedIDs.contains("dl_3"))
        #expect(closedIDs.contains("code_4"))
        // Main active dl_0 and frontmost code_1 must NOT be closed!
        #expect(!closedIDs.contains("dl_0"))
        #expect(!closedIDs.contains("code_1"))
    }
    

    @Test @MainActor
    func testFinderWindowModalSheetProtection() {
        let engine = FinderTidyEngine.shared
        
        var closedIDs: [String] = []
        FinderTidyEngine.mockCloseHandler = { win in
            closedIDs.append(win.id)
            return true
        }
        defer {
            FinderTidyEngine.mockWindowsProvider = nil
            FinderTidyEngine.mockCloseHandler = nil
        }
        
        // Window with modal sheet (e.g. file copying dialog)
        let windows = [
            FinderWindowInfo(id: "win_active", title: "Active", isMain: true, zIndex: 0),
            FinderWindowInfo(id: "win_copying", title: "Copying 10GB", isMain: false, hasModalSheet: true, zIndex: 1),
            FinderWindowInfo(id: "win_old", title: "Old Folder", isMain: false, hasModalSheet: false, zIndex: 2)
        ]
        FinderTidyEngine.mockWindowsProvider = { windows }
        
        // Enforce ceiling of 1
        let closed = engine.enforceMaxWindows(limit: 1)
        #expect(closed == 1)
        #expect(closedIDs == ["win_old"])
        #expect(!closedIDs.contains("win_copying"))
    }
    

    @Test @MainActor
    func testFinderTidyUserDefaultsPersistence() {
        let engine = FinderTidyEngine.shared
        
        let oldMax = engine.maxWindows
        let oldDup = engine.closeDuplicates
        let oldTTL = engine.inactivityMinutes
        let oldEnabled = engine.isEnabled
        
        defer {
            engine.maxWindows = oldMax
            engine.closeDuplicates = oldDup
            engine.inactivityMinutes = oldTTL
            engine.isEnabled = oldEnabled
        }
        
        engine.maxWindows = 8
        #expect(UserDefaults.standard.integer(forKey: FinderTidyEngine.keyMaxWindows) == 8)
        #expect(engine.maxWindows == 8)
        
        engine.closeDuplicates = false
        #expect(UserDefaults.standard.bool(forKey: FinderTidyEngine.keyCloseDuplicates) == false)
        #expect(engine.closeDuplicates == false)
        
        engine.inactivityMinutes = 30
        #expect(UserDefaults.standard.integer(forKey: FinderTidyEngine.keyInactivityMinutes) == 30)
        #expect(engine.inactivityMinutes == 30)
        
        engine.isEnabled = false
        #expect(UserDefaults.standard.bool(forKey: FinderTidyEngine.keyIsEnabled) == false)
        #expect(engine.isEnabled == false)
    }
    

    @Test @MainActor
    func testAppDelegateStatusMenuFinderTidyItems() {
        let appDelegate = AppDelegate()
        
        // Mock 4 open windows
        let mockWindows = (0..<4).map { i in
            FinderWindowInfo(id: "w_\(i)", title: "Doc \(i)", isMain: i == 0, zIndex: i)
        }
        FinderTidyEngine.mockWindowsProvider = { mockWindows }
        defer { FinderTidyEngine.mockWindowsProvider = nil }
        
        let menu = appDelegate.buildStatusMenu()
        let tidyItem = menu.items.first(where: { $0.title.hasPrefix("Finder Window Tidy") })
        #expect(tidyItem != nil)
        #expect(tidyItem?.submenu != nil)
        
        let sub = tidyItem?.submenu
        let tidyNow = sub?.items.first(where: { $0.title.contains("Tidy") })
        #expect(tidyNow != nil)
        #expect(tidyNow?.isEnabled == true)
        
        let dupes = sub?.items.first(where: { $0.title.contains("Duplicate") })
        #expect(dupes != nil)
        
        let autoItem = sub?.items.first(where: { $0.title.contains("Auto-Tidy") })
        #expect(autoItem != nil)
    }
    
}
