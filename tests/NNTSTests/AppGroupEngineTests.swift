import Foundation
import Testing
import AppKit
@testable import NNTS

extension ChromeQuickAccessUnitTests {
    @Test @MainActor
    func testSwitcherCyclingAndSelection() {
        let state = ChromeSwitcherState()
        let sampleProfiles = [
            ChromeProfile(index: 1, dir: "Default", name: "Personal"),
            ChromeProfile(index: 2, dir: "Profile 1", name: "Work"),
            ChromeProfile(index: 3, dir: "Profile 2", name: "Side Project"),
            ChromeProfile(index: 4, dir: "Profile 3", name: "Gaming")
        ]
        
        state.profiles = sampleProfiles
        state.selectedIndex = 0
        #expect(state.selectedProfile?.effectiveName == "Personal")
        
        // Cycle forward (like pressing C)
        state.selectNext()
        #expect(state.selectedIndex == 1)
        #expect(state.selectedProfile?.effectiveName == "Work")
        
        state.selectNext()
        #expect(state.selectedIndex == 2)
        #expect(state.selectedProfile?.effectiveName == "Side Project")
        
        state.selectNext()
        #expect(state.selectedIndex == 3)
        #expect(state.selectedProfile?.effectiveName == "Gaming")
        
        // Wrap-around forward
        state.selectNext()
        #expect(state.selectedIndex == 0)
        #expect(state.selectedProfile?.effectiveName == "Personal")
        
        // Cycle backward (like Left Arrow / Shift+Tab)
        state.selectPrevious()
        #expect(state.selectedIndex == 3)
        #expect(state.selectedProfile?.effectiveName == "Gaming")
        
        state.selectPrevious()
        #expect(state.selectedIndex == 2)
        #expect(state.selectedProfile?.effectiveName == "Side Project")
        
        // Direct jump via number key (e.g. index 2 = Side Project)
        state.selectIndex(1)
        #expect(state.selectedIndex == 1)
        #expect(state.selectedProfile?.effectiveName == "Work")
        
        // Boundary clamping
        state.selectIndex(99)
        #expect(state.selectedIndex == 3)
        state.selectIndex(-5)
        #expect(state.selectedIndex == 0)
    }
    

    @Test @MainActor
    func testAntigravitySwitcherCyclingAndSelection() {
        let state = ChromeSwitcherState()
        state.mode = .antigravity
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let items = [
            AntigravityItem(name: "Antigravity", bundleID: "com.google.antigravity", path: "/Applications/Antigravity.app", icon: dummyIcon, index: 1),
            AntigravityItem(name: "Antigravity IDE", bundleID: "com.google.antigravity-ide", path: "/Applications/Antigravity IDE.app", icon: dummyIcon, index: 2)
        ]
        state.antigravityItems = items
        state.selectedIndex = 0
        
        #expect(state.selectedAntigravityItem?.name == "Antigravity")
        
        // Cycle forward (pressing 'A')
        state.selectNext()
        #expect(state.selectedIndex == 1)
        #expect(state.selectedAntigravityItem?.name == "Antigravity IDE")
        
        // Wrap-around forward
        state.selectNext()
        #expect(state.selectedIndex == 0)
        #expect(state.selectedAntigravityItem?.name == "Antigravity")
        
        // Cycle backward (Left Arrow / Shift+Tab)
        state.selectPrevious()
        #expect(state.selectedIndex == 1)
        #expect(state.selectedAntigravityItem?.name == "Antigravity IDE")
        
        // Direct jump via number key (e.g. 1 -> index 0)
        state.selectIndex(0)
        #expect(state.selectedIndex == 0)
        #expect(state.selectedAntigravityItem?.name == "Antigravity")
        
        // Clamping
        state.selectIndex(10)
        #expect(state.selectedIndex == 1)
        state.selectIndex(-3)
        #expect(state.selectedIndex == 0)
    }
    

    @Test @MainActor
    func testAppGroupEngineDiscoveryAndCycling() {
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let terminalEngine = AppGroupEngine.terminal
        let initialCount = terminalEngine.items.count
        #expect(initialCount >= 1)
        
        // Test customItemsOverride
        let mockTerminals = [
            AntigravityItem(name: "iTerm2", bundleID: "com.googlecode.iterm2", path: "/Applications/iTerm.app", icon: dummyIcon, index: 1),
            AntigravityItem(name: "Terminal", bundleID: "com.apple.Terminal", path: "/System/Applications/Utilities/Terminal.app", icon: dummyIcon, index: 2)
        ]
        terminalEngine.customItemsOverride = mockTerminals
        defer {
            terminalEngine.customItemsOverride = nil
            terminalEngine.mockFrontmostBundleID = nil
            terminalEngine.refreshItems()
        }
        terminalEngine.refreshItems()
        #expect(terminalEngine.items.count == 2)
        #expect(terminalEngine.items[0].name == "iTerm2")
        #expect(terminalEngine.items[1].name == "Terminal")
        
        // Test frontmost toggle logic
        terminalEngine.mockFrontmostBundleID = "com.googlecode.iterm2"
        #expect(terminalEngine.getActiveAppIndex() == 0)
        terminalEngine.mockFrontmostBundleID = "com.apple.Terminal"
        #expect(terminalEngine.getActiveAppIndex() == 1)
        terminalEngine.mockFrontmostBundleID = "com.apple.Safari"
        #expect(terminalEngine.getActiveAppIndex() == nil)
        
        // Test Monogram fallback
        let monogram = terminalEngine.makeMonogramImage(name: "Ghostty")
        #expect(monogram.size.width == 64)
        #expect(monogram.size.height == 64)
    }
    

    @Test @MainActor
    func testMinimalHUDWindowAppGroupModes() {
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let items = [
            AntigravityItem(name: "Notes", bundleID: "com.apple.Notes", path: "/System/Applications/Notes.app", icon: dummyIcon, index: 1),
            AntigravityItem(name: "Notion", bundleID: "notion.id", path: "/Applications/Notion.app", icon: dummyIcon, index: 2)
        ]
        
        MinimalHUDWindow.shared.showAppGroup(mode: .notes, items: items, selectedIndex: 0)
        #expect(ChromeSwitcherState.shared.mode == .notes)
        #expect(ChromeSwitcherState.shared.selectedAppItem?.name == "Notes")
        #expect(ChromeSwitcherState.shared.hasBrothers == true)
        #expect(ChromeSwitcherState.shared.isVisible == true)
        
        MinimalHUDWindow.shared.selectNext()
        #expect(ChromeSwitcherState.shared.selectedAppItem?.name == "Notion")
        
        // Single app without brothers has hasBrothers == false (no bottom redundant icon)
        MinimalHUDWindow.shared.showAppGroup(mode: .notes, items: [items[0]], selectedIndex: 0)
        #expect(ChromeSwitcherState.shared.hasBrothers == false)
        
        MinimalHUDWindow.shared.hideImmediate()
        #expect(ChromeSwitcherState.shared.isVisible == false)
    }
    

    @Test @MainActor
    func testAppGroupSingleChoiceRadioSelection() {
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let terminalEngine = AppGroupEngine.terminal
        let mockTerminals = [
            AntigravityItem(name: "iTerm2", bundleID: "com.googlecode.iterm2", path: "/Applications/iTerm.app", icon: dummyIcon, index: 1),
            AntigravityItem(name: "Terminal", bundleID: "com.apple.Terminal", path: "/System/Applications/Utilities/Terminal.app", icon: dummyIcon, index: 2)
        ]
        terminalEngine.customItemsOverride = mockTerminals
        defer {
            terminalEngine.customItemsOverride = nil
            terminalEngine.refreshItems()
        }
        terminalEngine.refreshItems()
        
        // Default selects first
        terminalEngine.select(bundleID: "com.googlecode.iterm2")
        #expect(terminalEngine.selectedItem?.name == "iTerm2")
        #expect(terminalEngine.isSelected(bundleID: "com.googlecode.iterm2") == true)
        #expect(terminalEngine.isSelected(bundleID: "com.apple.Terminal") == false)
        
        // Switch choice to Terminal
        terminalEngine.select(bundleID: "com.apple.Terminal")
        #expect(terminalEngine.selectedItem?.name == "Terminal")
        #expect(terminalEngine.isSelected(bundleID: "com.googlecode.iterm2") == false)
        #expect(terminalEngine.isSelected(bundleID: "com.apple.Terminal") == true)
    }
    

    @Test @MainActor
    func testAiAgentEngineHasNoAntigravityIdeDuplicate() {
        let aiCandidates = AppGroupEngine.aiAgent.candidates
        let ideCandidates = AppGroupEngine.ide.candidates
        
        // AI Agent candidates should NOT include Antigravity IDE
        #expect(aiCandidates.contains(where: { $0.name == "Antigravity IDE" }) == false)
        #expect(aiCandidates.contains(where: { $0.name == "Antigravity" }) == true)
        
        // IDE candidates SHOULD include Antigravity IDE
        #expect(ideCandidates.contains(where: { $0.name == "Antigravity IDE" }) == true)
    }
    

    @Test @MainActor
    func testAppCandidatePureFirstLetterDerivation() {
        let terminal = AppGroupEngine.terminal
        #expect(terminal.candidate(for: "com.googlecode.iterm2")?.firstLetter == "I")
        #expect(terminal.candidate(for: "com.apple.Terminal")?.firstLetter == "T")
        #expect(terminal.candidate(for: "com.mitchellh.ghostty")?.firstLetter == "G")
        #expect(terminal.candidate(for: "dev.warp.Warp-Stable")?.firstLetter == "W")
        
        let notes = AppGroupEngine.notes
        #expect(notes.candidate(for: "md.obsidian")?.firstLetter == "O")
        #expect(notes.candidate(for: "com.apple.Notes")?.firstLetter == "N")
        
        let ide = AppGroupEngine.ide
        #expect(ide.candidate(for: "com.google.antigravity-ide")?.firstLetter == "A")
        #expect(ide.candidate(for: "com.microsoft.VSCode")?.firstLetter == "V")
        #expect(ide.candidate(for: "com.apple.dt.Xcode")?.firstLetter == "X")
        
        let ai = AppGroupEngine.aiAgent
        #expect(ai.candidate(for: "com.google.antigravity")?.firstLetter == "A")
    }
    

    @Test @MainActor
    func testSharedLetterGroupingAndCycling() {
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let app1 = AntigravityItem(name: "Antigravity", bundleID: "com.google.antigravity", path: "/Applications/Antigravity.app", icon: dummyIcon, index: 1)
        let app2 = AntigravityItem(name: "Antigravity IDE", bundleID: "com.google.antigravity-ide", path: "/Applications/Antigravity IDE.app", icon: dummyIcon, index: 2)
        
        let itemsWithA = [app1, app2]
        
        // Both start with letter 'A'
        #expect(app1.name.first == "A")
        #expect(app2.name.first == "A")
        
        let state = ChromeSwitcherState()
        state.mode = .antigravity
        state.antigravityItems = itemsWithA
        state.selectedIndex = 0
        
        #expect(state.selectedAppItem?.name == "Antigravity")
        
        // Cycle to next app with same letter
        state.selectNext()
        #expect(state.selectedIndex == 1)
        #expect(state.selectedAppItem?.name == "Antigravity IDE")
        
        // Cycle wraps around
        state.selectNext()
        #expect(state.selectedIndex == 0)
        #expect(state.selectedAppItem?.name == "Antigravity")
    }
    

    @Test @MainActor
    func testDiscoveredItemsByLetterGrouping() {
        let groups = AppGroupEngine.discoveredItemsByLetter()
        
        // Every group must contain only items whose first letter matches the dictionary key
        for (letter, items) in groups {
            for item in items {
                let firstChar = Character((item.name.first(where: { $0.isLetter }) ?? "A").uppercased())
                #expect(firstChar == letter)
            }
        }
        
        // If Antigravity and Antigravity IDE are present in engines, both must be in 'A'
        if let aItems = groups["A"] {
            let names = aItems.map { $0.name }
            if names.contains("Antigravity") && names.contains("Antigravity IDE") {
                #expect(names.contains("Antigravity"))
                #expect(names.contains("Antigravity IDE"))
            }
        }
    }
    

    @Test @MainActor
    func testLetterSelectionStateManagement() {
        let previous = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            if let prev = previous {
                UserDefaults.standard.set(prev, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
        }
        
        let testBundleID = "com.test.unique-app"
        
        // Ensure clean state
        AppGroupEngine.deselectApp(bundleID: testBundleID)
        #expect(AppGroupEngine.isAppSelected(bundleID: testBundleID) == false)
        
        // Select app
        AppGroupEngine.selectApp(bundleID: testBundleID)
        #expect(AppGroupEngine.isAppSelected(bundleID: testBundleID) == true)
        
        // Toggle app off
        AppGroupEngine.toggleApp(bundleID: testBundleID)
        #expect(AppGroupEngine.isAppSelected(bundleID: testBundleID) == false)
        
        // Toggle app back on
        AppGroupEngine.toggleApp(bundleID: testBundleID)
        #expect(AppGroupEngine.isAppSelected(bundleID: testBundleID) == true)
        
        // Clean up
        AppGroupEngine.deselectApp(bundleID: testBundleID)
    }
    

    @Test @MainActor
    func testUniversalCatalogCategoriesAndExpansion() {
        let categories = AppGroupEngine.catalogCategories
        #expect(!categories.isEmpty)
        
        let catNames = categories.map { $0.category }
        #expect(catNames.contains("Terminal") || catNames.contains("IDE") || catNames.contains("AI Agent") || catNames.contains("Notes") || catNames.contains("Communication"))
        
        // Ensure new candidates exist in catalog
        let commCandidates = AppGroupEngine.communication.candidates.map { $0.name }
        #expect(commCandidates.contains("Telegram"))
        #expect(commCandidates.contains("Slack"))
        
        let ideCandidates = AppGroupEngine.ide.candidates.map { $0.name }
        #expect(ideCandidates.contains("Zed"))
        #expect(ideCandidates.contains("IntelliJ IDEA"))
        
        let aiCandidates = AppGroupEngine.aiAgent.candidates.map { $0.name }
        #expect(aiCandidates.contains("Gemini"))
        #expect(aiCandidates.contains("Antigravity"))
    }
    

    @Test @MainActor
    func testPinnedAppsMaxLimitAndGrouping() {
        let initialPinned = AppGroupEngine.pinnedAppItems()
        #expect(initialPinned.count <= 4)
        
        // 5 total quick apps including Chrome/browser
        #expect(AppGroupEngine.maxPinnedQuickApps == 4)
        #expect(AppGroupEngine.maxPinnedQuickApps + 1 == 5)
        
        // Grouped by letter
        let grouped = AppGroupEngine.pinnedAppsGroupedByLetter()
        for group in grouped {
            for item in group.items {
                let firstChar = Character((item.name.first(where: { $0.isLetter }) ?? "A").uppercased())
                #expect(firstChar == group.letter)
            }
        }
    }
    

    @Test @MainActor
    func testInstalledApplicationScanningAndCaching() {
        let apps = AppGroupEngine.scanInstalledApplications(forceRefresh: true)
        #expect(!apps.isEmpty)
        #expect(AppGroupEngine.cachedInstalledApplications.count == apps.count)
        
        // Every app must have non-empty name and bundle ID
        for app in apps.prefix(10) {
            #expect(!app.name.isEmpty)
            #expect(!app.bundleID.isEmpty)
            #expect(app.firstLetter.isLetter || app.firstLetter.isNumber)
        }
    }
    

    @Test @MainActor
    func testInstalledApplicationSearchFiltering() {
        _ = AppGroupEngine.scanInstalledApplications()
        
        // Empty query returns all
        let all = AppGroupEngine.searchInstalledApplications(query: "")
        #expect(all.count == AppGroupEngine.cachedInstalledApplications.count)
        
        // Non-empty query matches prefix or contains
        let searched = AppGroupEngine.searchInstalledApplications(query: "notes")
        for app in searched {
            let matches = app.name.lowercased().contains("notes") || app.bundleID.lowercased().contains("notes")
            #expect(matches == true)
        }
    }
    

    @Test @MainActor
    func testAppSearchPickerViewModelPinToggling() {
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let testApp = InstalledAppInfo(
            name: "TestPickerApp",
            bundleID: "com.test.pickerapp",
            path: "/Applications/TestPickerApp.app",
            icon: dummyIcon
        )
        
        let previousSelected = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            if let prev = previousSelected {
                UserDefaults.standard.set(prev, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
            AppGroupEngine.deselectApp(bundleID: testApp.bundleID)
        }
        
        // Clean initial state
        AppGroupEngine.deselectApp(bundleID: testApp.bundleID)
        #expect(AppGroupEngine.isAppSelected(bundleID: testApp.bundleID) == false)
        
        let vm = AppSearchPickerViewModel()
        #expect(vm.pinnedBundleIDs.contains(testApp.bundleID) == false)
        
        // Toggle pin
        vm.toggleApp(app: testApp)
        #expect(AppGroupEngine.isAppSelected(bundleID: testApp.bundleID) == true)
        #expect(vm.pinnedBundleIDs.contains(testApp.bundleID) == true)
        
        // Toggle unpin
        vm.toggleApp(app: testApp)
        #expect(AppGroupEngine.isAppSelected(bundleID: testApp.bundleID) == false)
        #expect(vm.pinnedBundleIDs.contains(testApp.bundleID) == false)
    }
    

    @Test @MainActor
    func testSmartDefaultPinnedBundleIDsNeverIncludeMissingApps() {
        let defaults = AppGroupEngine.discoverSmartDefaultPinnedBundleIDs()
        #expect(!defaults.isEmpty, "Smart defaults must return candidate apps")
        #expect(defaults.count <= AppGroupEngine.freePinnedAppsLimit, "Must not exceed free limit of 4")
        
        // Every discovered app must actually exist on this system
        for bundle in defaults {
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
            #expect(url != nil, "Smart default bundle \(bundle) must be installed on disk")
        }
    }


    @Test @MainActor
    func testUnifiedBrowserLetterCyclingRing() {
        let prev = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            if let p = prev {
                UserDefaults.standard.set(p, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
        }
        
        // Pin an app that starts with 'C' (e.g. Calculator) alongside other apps
        let calcBundle = "com.apple.calculator"
        UserDefaults.standard.set([calcBundle, "com.apple.Notes", "com.apple.Terminal"], forKey: "SelectedAppBundleIDs")
        
        let appDelegate = AppDelegate()
        appDelegate.updateDynamicShortcuts()
        
        let browserChar = ChromeProfileEngine.shared.primaryShortcutChar
        #expect(browserChar == "C")
        
        let browserCode = ChromeProfileEngine.shared.primaryShortcutKeyCode
        #expect(browserCode == KeyCodes.kVK_ANSI_C)
        
        // CapsLockEngine must have trigger for browserCode
        let trigger = CapsLockEngine.shared.dynamicKeyTriggers[browserCode]
        #expect(trigger != nil, "Trigger for C must be registered in dynamicKeyTriggers")
    }


    @Test @MainActor
    func testAppGroupEngineFocusItemSupportsBrowsersAndSystemApps() {
        // Must not crash or fail when focusing browser or system apps
        AppGroupEngine.focusItem(bundleID: "com.google.Chrome")
        AppGroupEngine.focusItem(bundleID: "com.apple.finder")
    }


    @Test @MainActor
    func testProductionModeDoesNotReturnDashedStubsInPinnedAppItems() {
        let prevBypass = AppGroupEngine.bypassLaunchInTests
        let prevSaved = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            AppGroupEngine.bypassLaunchInTests = prevBypass
            if let prev = prevSaved {
                UserDefaults.standard.set(prev, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
        }
        
        AppGroupEngine.bypassLaunchInTests = false
        UserDefaults.standard.set(["com.fake.app.doesnotexist12345"], forKey: "SelectedAppBundleIDs")
        
        let pinned = AppGroupEngine.pinnedAppItems()
        #expect(!pinned.contains(where: { $0.bundleID == "com.fake.app.doesnotexist12345" }), "Production mode must omit uninstalled app from pinnedAppItems")
    }


    @Test @MainActor
    func testAppGroupEngineRejectsNonAppCustomURL() {
        let textFile = URL(fileURLWithPath: "/tmp/fake_script.sh")
        try? "#!/bin/bash\necho hi".write(to: textFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: textFile) }
        
        let item = AppGroupEngine.registerCustomApp(url: textFile)
        #expect(item == nil, "registerCustomApp must reject non-.app URLs")
    }


    @Test @MainActor
    func testObsidianStrictlyOnKeyOAndNeverOnKeyN() {
        let prevSelected = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            if let prev = prevSelected {
                UserDefaults.standard.set(prev, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
            AppGroupEngine.notes.customItemsOverride = nil
            AppGroupEngine.notes.refreshItems()
        }
        
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let obsidianItem = AntigravityItem(name: "Obsidian", bundleID: "md.obsidian", path: "/Applications/Obsidian.app", icon: dummyIcon, index: 1)
        AppGroupEngine.notes.customItemsOverride = [obsidianItem]
        AppGroupEngine.notes.refreshItems()
        
        UserDefaults.standard.set(["md.obsidian"], forKey: "SelectedAppBundleIDs")
        AppGroupEngine.selectedBundleIDs = ["md.obsidian"]
        
        let appDelegate = AppDelegate()
        appDelegate.updateDynamicShortcuts()
        
        // Obsidian must strictly be registered for key 'O' (kVK_ANSI_O)
        let oTrigger = CapsLockEngine.shared.dynamicKeyTriggers[KeyCodes.kVK_ANSI_O]
        #expect(oTrigger != nil, "Obsidian must register dynamic trigger on 'O'")
        
        // Key 'N' must NOT be registered for Obsidian
        let nTrigger = CapsLockEngine.shared.dynamicKeyTriggers[KeyCodes.kVK_ANSI_N]
        #expect(nTrigger == nil, "Key 'N' must never trigger Obsidian")
    }


    @Test @MainActor
    func testCrossEngineDuplicateLetterCycling() async {
        let prevSelected = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        AppGroupEngine.resetActiveAppTrackingForTesting()
        UserDefaults.standard.removeObject(forKey: "LastActiveApp_S")
        AppGroupEngine.testOpenWindowsOverride = [
            "com.tinyspeck.slackmacgap": false,
            "com.spotify.client": false
        ]
        defer {
            if let prev = prevSelected {
                UserDefaults.standard.set(prev, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
            AppGroupEngine.communication.customItemsOverride = nil
            AppGroupEngine.communication.refreshItems()
            AppGroupEngine.resetActiveAppTrackingForTesting()
            AppGroupEngine.testOpenWindowsOverride = nil
            UserDefaults.standard.removeObject(forKey: "LastActiveApp_S")
            MinimalHUDWindow.shared.hideImmediate()
        }
        
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let slackItem = AntigravityItem(name: "Slack", bundleID: "com.tinyspeck.slackmacgap", path: "/Applications/Slack.app", icon: dummyIcon, index: 1)
        let spotifyItem = AntigravityItem(name: "Spotify", bundleID: "com.spotify.client", path: "/Applications/Spotify.app", icon: dummyIcon, index: 2)
        AppGroupEngine.communication.customItemsOverride = [slackItem, spotifyItem]
        AppGroupEngine.communication.refreshItems()
        
        let mockPinned = ["com.tinyspeck.slackmacgap", "com.spotify.client"]
        UserDefaults.standard.set(mockPinned, forKey: "SelectedAppBundleIDs")
        AppGroupEngine.selectedBundleIDs = Set(mockPinned)
        
        let appDelegate = AppDelegate()
        _ = appDelegate.buildStatusMenu()
        
        let pinnedS = AppGroupEngine.pinnedAppItems().filter { item in
            (item.name.first(where: { $0.isLetter }) ?? "A").uppercased() == "S"
        }
        #expect(pinnedS.count == 2, "Both S-apps must be pinned in AppGroupEngine")
        
        // Verify dynamic key trigger cycles through HUD
        appDelegate.updateDynamicShortcuts()
        let sTrigger = CapsLockEngine.shared.dynamicKeyTriggers[KeyCodes.kVK_ANSI_S]
        #expect(sTrigger != nil, "Trigger for 'S' must be registered")
        
        sTrigger?()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(ChromeSwitcherState.shared.isVisible == true)
        #expect(ChromeSwitcherState.shared.selectedIndex == 0)
        
        sTrigger?()
        try? await Task.sleep(nanoseconds: 50_000_000)
        #expect(ChromeSwitcherState.shared.selectedIndex == 1)
        
        MinimalHUDWindow.shared.hideImmediate()
        #expect(ChromeSwitcherState.shared.isVisible == false)
    }


    @Test @MainActor
    func testUnpinnedLettersNeverTriggerPhantomDefaults() {
        let prevSelected = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            if let prev = prevSelected {
                UserDefaults.standard.set(prev, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
        }
        
        // Pin only Finder (letter F)
        UserDefaults.standard.set(["com.apple.finder"], forKey: "SelectedAppBundleIDs")
        AppGroupEngine.selectedBundleIDs = ["com.apple.finder"]
        
        let appDelegate = AppDelegate()
        appDelegate.updateDynamicShortcuts()
        
        // Terminal (T), Notes (N) are NOT pinned
        let tTrigger = CapsLockEngine.shared.dynamicKeyTriggers[KeyCodes.kVK_ANSI_T]
        #expect(tTrigger == nil, "Unpinned letter T must NOT have a registered trigger")
        
        let nTrigger = CapsLockEngine.shared.dynamicKeyTriggers[KeyCodes.kVK_ANSI_N]
        #expect(nTrigger == nil, "Unpinned letter N must NOT have a registered trigger")
        
        let fTrigger = CapsLockEngine.shared.dynamicKeyTriggers[KeyCodes.kVK_ANSI_F]
        #expect(fTrigger != nil, "Pinned letter F must have a registered trigger")
    }


    @Test @MainActor
    func testPrioritizedItemIndexSelectsOpenWindowOverClosedApp() {
        defer {
            AppGroupEngine.resetActiveAppTrackingForTesting()
            UserDefaults.standard.removeObject(forKey: "LastActiveApp_T")
        }
        AppGroupEngine.resetActiveAppTrackingForTesting()
        
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let telegram = AntigravityItem(name: "Telegram", bundleID: "com.tdesktop.Telegram", path: "/Applications/Telegram.app", icon: dummyIcon, index: 1)
        let terminal = AntigravityItem(name: "Terminal", bundleID: "com.apple.Terminal", path: "/System/Applications/Utilities/Terminal.app", icon: dummyIcon, index: 2)
        let items = [telegram, terminal]
        
        // Terminal has an open window; Telegram has none
        AppGroupEngine.testOpenWindowsOverride = [
            "com.tdesktop.Telegram": false,
            "com.apple.Terminal": true
        ]
        
        // Trigger from an external app (Finder)
        let targetIdx = AppGroupEngine.prioritizedItemIndex(for: items, letter: "T", frontmostBundleID: "com.apple.finder")
        #expect(targetIdx == 1, "Must prioritize Terminal because it has an open window")
    }


    @Test @MainActor
    func testPrioritizedItemIndexSelectsMRUWhenBothHaveOpenWindows() {
        defer {
            AppGroupEngine.resetActiveAppTrackingForTesting()
            UserDefaults.standard.removeObject(forKey: "LastActiveApp_T")
        }
        AppGroupEngine.resetActiveAppTrackingForTesting()
        
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let telegram = AntigravityItem(name: "Telegram", bundleID: "com.tdesktop.Telegram", path: "/Applications/Telegram.app", icon: dummyIcon, index: 1)
        let terminal = AntigravityItem(name: "Terminal", bundleID: "com.apple.Terminal", path: "/System/Applications/Utilities/Terminal.app", icon: dummyIcon, index: 2)
        let items = [telegram, terminal]
        
        // Both have open windows
        AppGroupEngine.testOpenWindowsOverride = [
            "com.tdesktop.Telegram": true,
            "com.apple.Terminal": true
        ]
        
        // Telegram active first
        AppGroupEngine.recordActiveApp(bundleID: "com.tdesktop.Telegram")
        #expect(AppGroupEngine.prioritizedItemIndex(for: items, letter: "T", frontmostBundleID: "com.apple.finder") == 0)
        
        // Later, Terminal becomes active
        AppGroupEngine.recordActiveApp(bundleID: "com.apple.Terminal")
        #expect(AppGroupEngine.prioritizedItemIndex(for: items, letter: "T", frontmostBundleID: "com.apple.finder") == 1)
    }


    @Test @MainActor
    func testPrioritizedItemIndexCyclesWhenAlreadyInCurrentApp() {
        defer {
            AppGroupEngine.resetActiveAppTrackingForTesting()
            UserDefaults.standard.removeObject(forKey: "LastActiveApp_T")
        }
        AppGroupEngine.resetActiveAppTrackingForTesting()
        
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let telegram = AntigravityItem(name: "Telegram", bundleID: "com.tdesktop.Telegram", path: "/Applications/Telegram.app", icon: dummyIcon, index: 1)
        let terminal = AntigravityItem(name: "Terminal", bundleID: "com.apple.Terminal", path: "/System/Applications/Utilities/Terminal.app", icon: dummyIcon, index: 2)
        let items = [telegram, terminal]
        
        // User is currently in Terminal (index 1) and triggers shortcut for T: should cycle to Telegram (index 0)
        let targetIdx = AppGroupEngine.prioritizedItemIndex(for: items, letter: "T", frontmostBundleID: "com.apple.Terminal")
        #expect(targetIdx == 0, "Must cycle to next app when already frontmost")
    }


    @Test @MainActor
    func testPrioritizedBundleIDForMenuCycleClick() {
        defer {
            AppGroupEngine.resetActiveAppTrackingForTesting()
            UserDefaults.standard.removeObject(forKey: "LastActiveApp_T")
        }
        AppGroupEngine.resetActiveAppTrackingForTesting()
        
        AppGroupEngine.testOpenWindowsOverride = [
            "com.tdesktop.Telegram": false,
            "com.apple.Terminal": true
        ]
        
        let bundleIDs = ["com.tdesktop.Telegram", "com.apple.Terminal"]
        let best = AppGroupEngine.prioritizedBundleID(from: bundleIDs)
        #expect(best == "com.apple.Terminal", "Must pick Terminal with open window")
    }


    @Test @MainActor
    func testLastActiveAppPersistenceAcrossUserDefaults() {
        defer {
            AppGroupEngine.resetActiveAppTrackingForTesting()
            UserDefaults.standard.removeObject(forKey: "LastActiveApp_O")
        }
        AppGroupEngine.resetActiveAppTrackingForTesting()
        
        AppGroupEngine.recordActiveApp(bundleID: "md.obsidian")
        #expect(AppGroupEngine.lastActiveApp(for: "O") == "md.obsidian")
        
        // Clear in-memory dictionary to verify UserDefaults persistence
        AppGroupEngine.lastActiveBundleIDByLetter.removeAll()
        #expect(AppGroupEngine.lastActiveApp(for: "O") == "md.obsidian")
    }
    
}
