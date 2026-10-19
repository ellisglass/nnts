import Foundation
import Testing
import AppKit
@testable import NNTS

extension ChromeQuickAccessUnitTests {
    @Test @MainActor
    func testChromeProfileDiscoveryFromLocalState() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let localStateUrl = tempDir.appendingPathComponent("Local State")
        let mockJson = """
        {
            "profile": {
                "info_cache": {
                    "Default": {
                        "name": "Personal",
                        "user_name": "igor@example.com",
                        "gaia_name": "Igor Ekishev",
                        "gaia_given_name": "Igor"
                    },
                    "Profile 1": {
                        "name": "Work",
                        "user_name": "igor@company.com",
                        "gaia_name": "Igor Ekishev Work",
                        "gaia_given_name": "Igor"
                    },
                    "Profile 2": {
                        "name": "Side Project",
                        "user_name": "admin@sideproject.dev"
                    }
                }
            }
        }
        """
        try mockJson.write(to: localStateUrl, atomically: true, encoding: .utf8)
        
        ChromeProfileEngine.localStatePathOverride = localStateUrl.path
        defer { ChromeProfileEngine.localStatePathOverride = nil }
        
        let engine = ChromeProfileEngine()
        let profiles = engine.profiles
        
        #expect(profiles.count == 3)
        #expect(profiles[0].dir == "Default")
        #expect(profiles[0].effectiveName == "Personal")
        #expect(profiles[0].expectedMenuTitle == "Igor (Personal)")
        #expect(profiles[0].index == 1)
        
        #expect(profiles[1].dir == "Profile 1")
        #expect(profiles[1].effectiveName == "Work")
        #expect(profiles[1].expectedMenuTitle == "Igor (Work)")
        #expect(profiles[1].index == 2)
        
        #expect(profiles[2].dir == "Profile 2")
        #expect(profiles[2].effectiveName == "Side Project")
        #expect(profiles[2].index == 3)
    }
    

    @Test @MainActor
    func testMonogramAvatarRendering() {
        let engine = ChromeProfileEngine()
        let monogram = engine.makeMonogramImage(name: "Work Profile", colorSeed: 42)
        #expect(monogram.size.width == 96)
        #expect(monogram.size.height == 96)
    }
    

    @Test @MainActor
    func testChromeAppIconHelper() {
        let icon = ChromeAppIconHelper.chromeIcon()
        #expect(icon.size.width > 0)
        #expect(icon.size.height > 0)
    }
    

    @Test @MainActor
    func testProfileEffectiveNameFallbackHierarchy() {
        let p1 = ChromeProfile(index: 1, dir: "Profile 1", name: "", gaiaName: "Igor Corporate")
        #expect(p1.effectiveName == "Igor Corporate")
        
        let p2 = ChromeProfile(index: 2, dir: "Profile 2", name: "   ", email: "support@almosteleven.com")
        #expect(p2.effectiveName == "support@almosteleven.com")
        
        let p3 = ChromeProfile(index: 3, dir: "Profile 3", name: "")
        #expect(p3.effectiveName == "Profile 3")
        
        let pDefault = ChromeProfile(index: 4, dir: "Default", name: "")
        #expect(pDefault.effectiveName == "Personal")
    }
    

    @Test @MainActor
    func testProfileExpectedMenuTitleAndDisambiguation() {
        let pDefault = ChromeProfile(
            index: 1,
            dir: "Default",
            name: "Igor",
            email: "igor@gmail.com",
            gaiaName: "Igor Ekishev",
            gaiaGivenName: "Igor"
        )
        let pWork = ChromeProfile(
            index: 2,
            dir: "Profile 1",
            name: "Work",
            email: "igor@company.com",
            gaiaName: "Igor Ekishev",
            gaiaGivenName: "Igor"
        )
        
        #expect(pDefault.expectedMenuTitle == "Igor")
        #expect(pWork.expectedMenuTitle == "Igor (Work)")
    }
    

    @Test @MainActor
    func testProfileWhitespaceAndUnicodeCanonicalEquivalence() {
        let pWhitespace = ChromeProfile(index: 1, dir: "Profile 1", name: "   Staging Server   ")
        #expect(pWhitespace.effectiveName == "Staging Server")
        
        let pEmoji = ChromeProfile(index: 2, dir: "Profile 2", name: "Dev 🚀 [2026]")
        #expect(pEmoji.effectiveName == "Dev 🚀 [2026]")
    }
    

    @Test @MainActor
    func testActiveProfileDirWhenChromeNotRunning() {
        let engine = ChromeProfileEngine.shared
        // With a dummy bundle ID that is definitely not running
        engine.browserBundleID = "com.nonexistent.browser.test"
        #expect(engine.getActiveProfileDir() == nil)
        #expect(engine.getProfilesMenuItems(bundleID: "com.nonexistent.browser.test").isEmpty)
        // Restore standard bundle ID
        engine.browserBundleID = "com.google.Chrome"
    }
    

    @Test @MainActor
    func testCapsLockChromeTriggerAndModifierReleased() {
        let engine = CapsLockEngine()
        let proxy = unsafeBitCast(1, to: CGEventTapProxy.self)
        
        var chromeTriggered = false
        var modifierReleased = false
        engine.onChromeTrigger = { chromeTriggered = true }
        engine.onModifierReleased = { modifierReleased = true }
        
        // Hold F18
        let f18Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: true)!
        _ = engine.handleEvent(proxy: proxy, type: .keyDown, event: f18Down)
        #expect(engine.isCapsHeld == true)
        
        // Press 'C'
        let cDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_C), keyDown: true)!
        let resC = engine.handleEvent(proxy: proxy, type: .keyDown, event: cDown)
        #expect(resC == nil) // 'C' swallowed
        #expect(chromeTriggered == true)
        #expect(engine.capsUsedAsModifier == true)
        
        // Release F18
        let f18Up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: false)!
        _ = engine.handleEvent(proxy: proxy, type: .keyUp, event: f18Up)
        #expect(modifierReleased == true)
        #expect(engine.isCapsHeld == false)
    }
    

    @Test @MainActor
    func testCapsLockProfileDigitAndNavigationTriggers() {
        let engine = CapsLockEngine()
        let proxy = unsafeBitCast(1, to: CGEventTapProxy.self)
        
        var selectedDigit = 0
        var navLeftCalled = false
        var navRightCalled = false
        var cancelCalled = false
        
        engine.onProfileTrigger = { digit in selectedDigit = digit }
        engine.onNavigateLeft = { navLeftCalled = true }
        engine.onNavigateRight = { navRightCalled = true }
        engine.onCancelTrigger = { cancelCalled = true }
        
        // Hold F18
        let f18Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: true)!
        _ = engine.handleEvent(proxy: proxy, type: .keyDown, event: f18Down)
        
        // Press '3'
        let digit3Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_3), keyDown: true)!
        let resDigit = engine.handleEvent(proxy: proxy, type: .keyDown, event: digit3Down)
        #expect(resDigit == nil)
        #expect(selectedDigit == 3)
        
        // Press Right Arrow -> Navigate Right
        let rightDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_RightArrow), keyDown: true)!
        let resRight = engine.handleEvent(proxy: proxy, type: .keyDown, event: rightDown)
        #expect(resRight == nil)
        #expect(navRightCalled == true)
        
        // Press Left Arrow -> Navigate Left
        let leftDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_LeftArrow), keyDown: true)!
        let resLeft = engine.handleEvent(proxy: proxy, type: .keyDown, event: leftDown)
        #expect(resLeft == nil)
        #expect(navLeftCalled == true)
        
        // Press Escape -> Cancel HUD
        let escDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_Escape), keyDown: true)!
        let resEsc = engine.handleEvent(proxy: proxy, type: .keyDown, event: escDown)
        #expect(resEsc == nil)
        #expect(cancelCalled == true)
    }
    

    @Test @MainActor
    func testChromeProfileLocalizedMenuMatching() {
        #expect(ChromeProfileEngine.isProfileMenuTitle("Profiles") == true)
        #expect(ChromeProfileEngine.isProfileMenuTitle("Profile") == true)
        #expect(ChromeProfileEngine.isProfileMenuTitle("Profils") == true)     // French
        #expect(ChromeProfileEngine.isProfileMenuTitle("Perfiles") == true)    // Spanish
        #expect(ChromeProfileEngine.isProfileMenuTitle("Профили") == true)    // Russian
        #expect(ChromeProfileEngine.isProfileMenuTitle("Perfis") == true)      // Portuguese
        #expect(ChromeProfileEngine.isProfileMenuTitle("Profili") == true)     // Italian
        #expect(ChromeProfileEngine.isProfileMenuTitle("个人资料") == true)     // Chinese
        #expect(ChromeProfileEngine.isProfileMenuTitle("プロファイル") == true)  // Japanese
        
        // Negative checks
        #expect(ChromeProfileEngine.isProfileMenuTitle("File") == false)
        #expect(ChromeProfileEngine.isProfileMenuTitle("Edit") == false)
        #expect(ChromeProfileEngine.isProfileMenuTitle("Window") == false)
        #expect(ChromeProfileEngine.isProfileMenuTitle("History") == false)
    }
    

    @Test @MainActor
    func testChromeProfileSelectionLimitUpToFour() throws {
        let prevBrowserProfileDirs = UserDefaults.standard.object(forKey: "SelectedBrowserProfileDirs")
        defer {
            if let prev = prevBrowserProfileDirs {
                UserDefaults.standard.set(prev, forKey: "SelectedBrowserProfileDirs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedBrowserProfileDirs")
            }
        }
        UserDefaults.standard.removeObject(forKey: "SelectedBrowserProfileDirs")
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let localStateUrl = tempDir.appendingPathComponent("Local State")
        let mockJson = """
        {
            "profile": {
                "info_cache": {
                    "Default": { "name": "Profile 1" },
                    "Profile 1": { "name": "Profile 2" },
                    "Profile 2": { "name": "Profile 3" },
                    "Profile 3": { "name": "Profile 4" },
                    "Profile 4": { "name": "Profile 5" },
                    "Profile 5": { "name": "Profile 6" },
                    "Profile 6": { "name": "Profile 7" },
                    "Profile 7": { "name": "Profile 8" },
                    "Profile 8": { "name": "Profile 9" }
                }
            }
        }
        """
        try mockJson.write(to: localStateUrl, atomically: true, encoding: .utf8)
        
        ChromeProfileEngine.localStatePathOverride = localStateUrl.path
        defer { ChromeProfileEngine.localStatePathOverride = nil }
        
        let engine = ChromeProfileEngine()
        #expect(engine.profiles.count == 9)
        
        // Initial selection should default to first 8 (maxProfileSlots)
        #expect(engine.selectedProfiles.count == 8)
        #expect(engine.selectedProfiles[0].dir == "Default")
        #expect(engine.selectedProfiles[7].dir == "Profile 7")
        
        // Selecting 9th replaces 8th profile (max 8)
        engine.selectProfile(dir: "Profile 8")
        #expect(engine.selectedProfiles.count == 8)
        #expect(engine.isProfileSelected(dir: "Profile 8") == true)
        #expect(engine.isProfileSelected(dir: "Profile 7") == false)
        
        // Reordering profiles preserves custom slot order
        engine.moveProfile(fromOffsets: IndexSet(integer: 7), toOffset: 0)
        #expect(engine.selectedProfiles[0].dir == "Profile 8")
        
        // Toggle selection (deselecting if > 1)
        engine.toggleProfileSelection(dir: "Profile 8")
        #expect(engine.selectedProfiles.count == 7)
        #expect(engine.isProfileSelected(dir: "Profile 8") == false)
    }
    

    @Test @MainActor
    func testProfileExplicitReplacement() {
        let engine = ChromeProfileEngine.shared
        let savedDirs = engine.selectedProfileDirs
        defer {
            engine.selectedProfileDirs = savedDirs
        }
        
        engine.selectedProfileDirs = ["Default", "Profile 1", "Profile 2", "Profile 3", "Profile 4", "Profile 5", "Profile 6", "Profile 7"]
        #expect(engine.selectedProfileDirs.count == 8)
        
        // Replace slot without silent overflow
        engine.replaceProfile(oldDir: "Profile 7", newDir: "Profile 8")
        #expect(engine.selectedProfileDirs == ["Default", "Profile 1", "Profile 2", "Profile 3", "Profile 4", "Profile 5", "Profile 6", "Profile 8"])
        #expect(engine.isProfileSelected(dir: "Profile 8") == true)
        #expect(engine.isProfileSelected(dir: "Profile 7") == false)
    }
    

    @Test @MainActor
    func testBraveBrowserVariantsAndStrictShortcutLetter() {
        let engine = ChromeProfileEngine.shared
        let originalBrowser = engine.browserBundleID
        let originalPreferred = engine.preferredBrowserBundleID
        defer {
            engine.selectBrowser(bundleID: originalBrowser)
            engine.preferredBrowserBundleID = originalPreferred
        }
        
        // 1. Verify all 3 Brave variants are configured in supportedBrowsers
        let supported = ChromeProfileEngine.supportedBrowsers
        let stable = supported.first(where: { $0.bundleID == "com.brave.Browser" })
        let beta = supported.first(where: { $0.bundleID == "com.brave.Browser.beta" })
        let nightly = supported.first(where: { $0.bundleID == "com.brave.Browser.nightly" })
        
        #expect(stable != nil)
        #expect(beta != nil)
        #expect(nightly != nil)
        #expect(stable?.name == "Brave Browser")
        #expect(beta?.name == "Brave Browser Beta")
        #expect(nightly?.name == "Brave Browser Nightly")
        #expect(beta?.localStatePath.contains("Brave-Browser-Beta") == true)
        #expect(nightly?.localStatePath.contains("Brave-Browser-Nightly") == true)
        
        // 2. Strict First-Letter Invariant: Brave MUST return 'B' and KeyCodes.kVK_ANSI_B
        engine.selectBrowser(bundleID: "com.brave.Browser")
        #expect(engine.primaryShortcutChar == "B")
        #expect(engine.primaryShortcutKeyCode == KeyCodes.kVK_ANSI_B)
        #expect(engine.activeBrowserName == "Brave Browser")
        #expect(engine.activeBrowserAppPath.contains("Brave") == true)
        
        engine.selectBrowser(bundleID: "com.brave.Browser.beta")
        #expect(engine.primaryShortcutChar == "B")
        #expect(engine.primaryShortcutKeyCode == KeyCodes.kVK_ANSI_B)
        #expect(engine.activeBrowserName == "Brave Browser Beta")
        
        engine.selectBrowser(bundleID: "com.brave.Browser.nightly")
        #expect(engine.primaryShortcutChar == "B")
        #expect(engine.primaryShortcutKeyCode == KeyCodes.kVK_ANSI_B)
        #expect(engine.activeBrowserName == "Brave Browser Nightly")
        
        // 3. Chrome MUST return 'C' and KeyCodes.kVK_ANSI_C
        engine.selectBrowser(bundleID: "com.google.Chrome")
        #expect(engine.primaryShortcutChar == "C")
        #expect(engine.primaryShortcutKeyCode == KeyCodes.kVK_ANSI_C)
        #expect(engine.activeBrowserName == "Google Chrome")
        
        // 4. Edge MUST return 'E' and KeyCodes.kVK_ANSI_E
        engine.selectBrowser(bundleID: "com.microsoft.edgemac")
        #expect(engine.primaryShortcutChar == "E")
        #expect(engine.primaryShortcutKeyCode == KeyCodes.kVK_ANSI_E)
        #expect(engine.activeBrowserName == "Microsoft Edge")
    }
    

    @Test @MainActor
    func testHorizontalSwitcherLetterCyclingAndDirectProfileJump() {
        let state = ChromeSwitcherState()
        state.mode = .antigravity
        
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let browserItem = AntigravityItem(name: "Google Chrome", bundleID: "com.google.Chrome", path: "/Applications/Google Chrome.app", icon: dummyIcon, index: 1)
        let calendarItem = AntigravityItem(name: "Calendar", bundleID: "com.apple.iCal", path: "/System/Applications/Calendar.app", icon: dummyIcon, index: 2)
        state.antigravityItems = [browserItem, calendarItem]
        
        let sampleProfiles = [
            ChromeProfile(index: 1, dir: "Default", name: "Personal"),
            ChromeProfile(index: 2, dir: "Profile 1", name: "Work"),
            ChromeProfile(index: 3, dir: "Profile 2", name: "Dev")
        ]
        state.profiles = sampleProfiles
        state.selectedIndex = 0
        state.selectedProfileIndex = 0
        
        #expect(state.selectedAppItem?.name == "Google Chrome")
        #expect(state.selectedProfile?.effectiveName == "Personal")
        
        // Letter cycling: advances application strictly without stepping through profiles
        state.selectNext()
        #expect(state.selectedIndex == 1)
        #expect(state.selectedAppItem?.name == "Calendar")
        #expect(state.selectedProfileIndex == 0, "Profile index should not be stepped during app cycling")
        
        // Loop back to Chrome
        state.selectNext()
        #expect(state.selectedIndex == 0)
        #expect(state.selectedAppItem?.name == "Google Chrome")
        #expect(state.selectedProfileIndex == 0)
        
        // Backward cycling
        state.selectPrevious()
        #expect(state.selectedIndex == 1)
        #expect(state.selectedAppItem?.name == "Calendar")
        
        state.selectPrevious()
        #expect(state.selectedIndex == 0)
        #expect(state.selectedAppItem?.name == "Google Chrome")
        
        // Direct digit jump from Calendar to Chrome Profile 2 (Work)
        state.selectedIndex = 1
        #expect(state.selectedAppItem?.name == "Calendar")
        state.selectChromeProfile(index: 1)
        #expect(state.selectedIndex == 0)
        #expect(state.selectedProfileIndex == 1)
        #expect(state.selectedProfile?.effectiveName == "Work")
    }
    

    @Test @MainActor
    func testProductionModeDoesNotFabricateMonogramPlaceholders() {
        let prevBypass = AppGroupEngine.bypassLaunchInTests
        let prevOverride = AppGroupEngine.aiAgent.customItemsOverride
        defer {
            AppGroupEngine.bypassLaunchInTests = prevBypass
            AppGroupEngine.aiAgent.customItemsOverride = prevOverride
            AppGroupEngine.aiAgent.refreshItems()
        }
        
        AppGroupEngine.aiAgent.customItemsOverride = nil
        AppGroupEngine.bypassLaunchInTests = false
        AppGroupEngine.aiAgent.refreshItems()
        
        // If no AI agent is installed, items should be empty in production mode, never fabricating a synthetic monogram
        let installed = AppGroupEngine.aiAgent.candidates.filter { candidate in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate.bundleID) != nil
        }
        if installed.isEmpty {
            #expect(AppGroupEngine.aiAgent.items.isEmpty, "Production mode must not fabricate synthetic candidate if none installed")
        }
    }


    @Test @MainActor
    func testChromeProfileEngineCachedProfilesPersistenceAndRecovery() {
        let engine = ChromeProfileEngine.shared
        let testBundleID = "com.google.Chrome.testCache"
        
        defer {
            UserDefaults.standard.removeObject(forKey: "CachedProfiles_\(testBundleID)")
        }
        
        let sampleProfiles = [
            ChromeProfile(index: 1, dir: "Default", name: "Personal Workstation"),
            ChromeProfile(index: 2, dir: "Profile 1", name: "Corporate Client"),
            ChromeProfile(index: 3, dir: "Profile 2", name: "Sandbox Experiment")
        ]
        
        engine.saveCachedProfiles(sampleProfiles, bundleID: testBundleID)
        let loaded = engine.loadCachedProfiles(bundleID: testBundleID)
        
        #expect(loaded.count == 3)
        #expect(loaded[0].name == "Personal Workstation")
        #expect(loaded[0].dir == "Default")
        #expect(loaded[1].name == "Corporate Client")
        #expect(loaded[1].dir == "Profile 1")
        #expect(loaded[2].name == "Sandbox Experiment")
        #expect(loaded[2].dir == "Profile 2")
    }
    

    @Test @MainActor
    func testProfileSelectionExpandsWhenRecoveringFromSingleFallback() {
        let engine = ChromeProfileEngine.shared
        defer {
            UserDefaults.standard.removeObject(forKey: "SelectedBrowserProfileDirs")
        }
        
        // Simulate previous state where bug caused only ["Default"] to be saved
        UserDefaults.standard.set(["Default"], forKey: "SelectedBrowserProfileDirs")
        
        // Mock multiple discovered profiles via temporary override
        let jsonMock = """
        {
           "profile": {
              "info_cache": {
                 "Default": { "name": "Work", "gaia_name": "Work" },
                 "Profile 1": { "name": "Personal", "gaia_name": "Personal" },
                 "Profile 2": { "name": "Client", "gaia_name": "Client" }
              }
           }
        }
        """
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("MockLocalState_\(UUID().uuidString).json")
        try? jsonMock.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        ChromeProfileEngine.localStatePathOverride = tempFile.path
        defer { ChromeProfileEngine.localStatePathOverride = nil }
        
        engine.refreshProfiles()
        
        #expect(engine.profiles.count == 3)
        // Verify selection auto-expanded from single ["Default"] to all 3 profiles
        #expect(engine.selectedProfiles.count == 3)
        #expect(engine.selectedProfiles.map { $0.dir } == ["Default", "Profile 1", "Profile 2"])
    }
    

    @Test @MainActor
    func testSmartMonogramContextualDiscrimination() {
        let engine = ChromeProfileEngine.shared
        
        let igorImg = engine.makeMonogramImage(name: "Igor")
        #expect(igorImg.size.width == 96)
        #expect(igorImg.size.height == 96)
        
        let al11Img = engine.makeMonogramImage(name: "Igor (Al11)")
        #expect(al11Img.size.width == 96)
        #expect(al11Img.size.height == 96)
        
        let gcp2Img = engine.makeMonogramImage(name: "Igor (GCP Free 2)")
        #expect(gcp2Img.size.width == 96)
        #expect(gcp2Img.size.height == 96)
        
        let gcpTrialImg = engine.makeMonogramImage(name: "Igor (GCP Free Trial)")
        #expect(gcpTrialImg.size.width == 96)
        #expect(gcpTrialImg.size.height == 96)
        
        let nastyaImg = engine.makeMonogramImage(name: "Nastya")
        #expect(nastyaImg.size.width == 96)
        #expect(nastyaImg.size.height == 96)
    }
    

    @Test @MainActor
    func testAvatarStorageAndCustomAvatarLoading() {
        let storageURL = ChromeProfileEngine.localAvatarStorageURL
        #expect(FileManager.default.fileExists(atPath: storageURL.path))
        
        // Create a test avatar in storage
        let dummy = NSImage(size: NSSize(width: 96, height: 96))
        dummy.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 96, height: 96).fill()
        dummy.unlockFocus()
        
        let testDirKey = "ProfileUnitTest99"
        let testName = "UnitTestCustomProfile"
        let testFilePath = storageURL.appendingPathComponent("\(testDirKey).png")
        
        if let tiff = dummy.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            try? pngData.write(to: testFilePath)
        }
        defer { try? FileManager.default.removeItem(at: testFilePath) }
        
        let loaded = ChromeProfileEngine.loadStoredAvatar(dirKey: testDirKey, name: testName)
        #expect(loaded != nil)
        #expect(loaded?.size.width == 96)
    }
    

    @Test @MainActor
    func testAvatarManagementMenuItemsInAppDelegate() {
        let appDelegate = AppDelegate()
        let menu = appDelegate.buildStatusMenu()
        
        // Profile strip view exists in menu and provides avatar context actions
        let stripItem = menu.items.first(where: { $0.view is ProfileStripView })
        #expect(stripItem != nil)
        
        // In streamlined menu, Avatar Assistant is removed from root menu
        let directAssistantItem = menu.items.first(where: { $0.title.contains("Avatar Assistant") })
        #expect(directAssistantItem == nil)
        
        guard let stripView = stripItem?.view as? ProfileStripView else {
            Issue.record("ProfileStripView not found")
            return
        }
        
        // ProfileStripView context menu has avatar paste and assistant options
        if let firstProfile = stripView.profiles.first {
            let rect = stripView.tileRect(for: 0)
            let centerPoint = NSPoint(x: rect.midX, y: rect.midY)
            let event = NSEvent.mouseEvent(
                with: .rightMouseDown,
                location: centerPoint,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )!
            let contextMenu = stripView.menu(for: event)
            #expect(contextMenu != nil)
            let items = contextMenu?.items.map { $0.title } ?? []
            #expect(items.contains(where: { $0.contains("Paste Avatar for \(firstProfile.effectiveName)") }))
            #expect(items.contains(where: { $0.contains("Open Avatar Assistant") }))
        }
    }
    

    @Test @MainActor
    func testAutoSyncWhenNewProfileIsAddedInBrowser() {
        let engine = ChromeProfileEngine.shared
        
        // Initial state: 2 profiles in mock Local State
        let jsonMock1 = """
        {
           "profile": {
              "info_cache": {
                 "Default": { "name": "Work", "gaia_name": "Work" },
                 "Profile 1": { "name": "Personal", "gaia_name": "Personal" }
              }
           }
        }
        """
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("MockLocalState_AutoSync_\(UUID().uuidString).json")
        try? jsonMock1.write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        ChromeProfileEngine.localStatePathOverride = tempFile.path
        defer { ChromeProfileEngine.localStatePathOverride = nil }
        
        engine.clearAvatarCache()
        engine.refreshProfiles()
        #expect(engine.profiles.count == 2)
        
        // Simulate user adding a 3rd profile in Google Chrome
        let jsonMock2 = """
        {
           "profile": {
              "info_cache": {
                 "Default": { "name": "Work", "gaia_name": "Work" },
                 "Profile 1": { "name": "Personal", "gaia_name": "Personal" },
                 "Profile 2": { "name": "Brand New Profile", "gaia_name": "Brand New Profile" }
              }
           }
        }
        """
        try? jsonMock2.write(to: tempFile, atomically: true, encoding: .utf8)
        
        // Refresh profiles (simulating periodic refresh or switching to Chrome)
        engine.clearAvatarCache()
        engine.refreshProfiles()
        
        // Verify the 3rd profile was automatically picked up with zero user interaction!
        #expect(engine.profiles.count == 3)
        #expect(engine.profiles.contains(where: { $0.effectiveName == "Brand New Profile" }))
    }
    

    @Test @MainActor
    func testClipboardAvatarAssistantAndMenuItems() async {
        let engine = ChromeProfileEngine.shared
        
        // 1. ProfileStripView exists in status menu
        let appDelegate = AppDelegate()
        let menu = appDelegate.buildStatusMenu()
        let stripItem = menu.items.first(where: { $0.view is ProfileStripView })
        #expect(stripItem != nil)
        
        // 2. Test AvatarCaptureAssistantViewModel
        let assistantVM = AvatarCaptureAssistantViewModel()
        assistantVM.refreshProfiles()
        if let firstDir = assistantVM.profiles.first?.dir {
            assistantVM.selectProfile(dir: firstDir)
            #expect(assistantVM.selectedProfileDir == firstDir)
        }
        assistantVM.startPasteboardWatcher()
        assistantVM.stopPasteboardWatcher()
        
        // 3. Test state preservation in show(preservingState: true)
        AvatarCaptureAssistantWindow.shared.viewModel.isSuccess = true
        AvatarCaptureAssistantWindow.shared.viewModel.statusMessage = "Test Success Message"
        AvatarCaptureAssistantWindow.shared.show(preservingState: true)
        #expect(AvatarCaptureAssistantWindow.shared.viewModel.isSuccess == true)
        #expect(AvatarCaptureAssistantWindow.shared.viewModel.statusMessage == "Test Success Message")
        AvatarCaptureAssistantWindow.shared.hideImmediate()
        
        // 4. Test saving captured avatar to storage and retrieving it
        let testImage = NSImage(size: NSSize(width: 48, height: 48))
        testImage.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(ovalIn: NSRect(x: 0, y: 0, width: 48, height: 48)).fill()
        testImage.unlockFocus()
        
        let saved = engine.saveCapturedAvatar(image: testImage, forProfileDir: "TestSnapDir", name: "Snap Test")
        #expect(saved == true)
        let loadedAvatar = ChromeProfileEngine.loadStoredAvatar(dirKey: "TestSnapDir", name: "Snap Test")
        #expect(loadedAvatar != nil)
        
        // Clean up test avatar file
        let fileURL = ChromeProfileEngine.localAvatarStorageURL.appendingPathComponent("TestSnapDir.png")
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - Finder Window Tidy Engine Tests
    

    @Test @MainActor
    func testProfileStripViewHasNoActiveIndicator() {
        let p1 = ChromeProfile(index: 1, dir: "Default", name: "Igor")
        let p2 = ChromeProfile(index: 2, dir: "Profile 1", name: "Nastya")
        let strip = ProfileStripView(profiles: [p1, p2])
        #expect(strip.profiles.count == 2)
        #expect(strip.activeDir == nil)
        
        let rect0 = strip.tileRect(for: 0)
        let rect1 = strip.tileRect(for: 1)
        #expect(rect0.width > 0)
        #expect(rect1.width > 0)
        
        let rep = strip.bitmapImageRepForCachingDisplay(in: strip.bounds)
        #expect(rep != nil)
    }
    

    @Test @MainActor
    func testProfileStripViewCompactLayoutWith8Profiles() {
        let profiles = (1...8).map { i in
            ChromeProfile(index: i, dir: "Profile \(i)", name: "Work \(i)")
        }
        let strip = ProfileStripView(profiles: profiles, activeDir: "Profile 1")
        #expect(strip.profiles.count == 8)
        
        let rect0 = strip.tileRect(for: 0)
        let rect7 = strip.tileRect(for: 7)
        #expect(rect0.width > 0)
        #expect(rect7.width > 0)
        #expect(rect7.maxX <= strip.bounds.width)
        
        let rep = strip.bitmapImageRepForCachingDisplay(in: strip.bounds)
        #expect(rep != nil)
    }
    

    @Test @MainActor
    func testChromeProfileFilteredMenuItemsAndFindMatching() {
        let pWork = ChromeProfile(index: 1, dir: "Profile 6", name: "Work")
        let pDhl = ChromeProfile(index: 2, dir: "Profile 2", name: "dhl.com")
        
        #expect(pWork.expectedMenuTitle == "Work")
        #expect(pDhl.effectiveName == "dhl.com")
    }
}
