import Foundation
import Testing
import AppKit
@testable import NNTS

extension ChromeQuickAccessUnitTests {
    @Test @MainActor
    func testHIDMappingConstants() {
        #expect(HIDMappingService.hidCapsLock == 0x700000039)
        #expect(HIDMappingService.hidF18 == 0x70000006D)
    }

    @Test @MainActor
    func testAntigravityEngineDiscovery() {
        let engine = AntigravityEngine.shared
        engine.refreshItems()
        let items = engine.items
        #expect(items.count == 2)
        #expect(items[0].name == "Antigravity")
        #expect(items[0].bundleID == "com.google.antigravity")
        #expect(items[0].index == 1)
        #expect(items[1].name == "Antigravity IDE")
        #expect(items[1].bundleID == "com.google.antigravity-ide")
        #expect(items[1].index == 2)
        
        let monogram = engine.makeMonogramImage(name: "Antigravity")
        #expect(monogram.size.width == 64)
        #expect(monogram.size.height == 64)
    }

    @Test @MainActor
    func testAntigravityFrontmostAppToggleLogic() {
        let engine = AntigravityEngine.shared
        defer { AntigravityEngine.mockFrontmostBundleID = nil }
        
        // If Antigravity is frontmost, active index is 0
        AntigravityEngine.mockFrontmostBundleID = "com.google.antigravity"
        #expect(engine.getActiveAppIndex() == 0)
        
        // If Antigravity IDE is frontmost, active index is 1
        AntigravityEngine.mockFrontmostBundleID = "com.google.antigravity-ide"
        #expect(engine.getActiveAppIndex() == 1)
        
        // If another app (e.g. Finder) is frontmost, active index is nil
        AntigravityEngine.mockFrontmostBundleID = "com.apple.finder"
        #expect(engine.getActiveAppIndex() == nil)
    }

    @Test @MainActor
    func testCorruptedLocalStateJsonFallback() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        
        let localStateUrl = tempDir.appendingPathComponent("Local State")
        try "{ this is not valid json! }".write(to: localStateUrl, atomically: true, encoding: .utf8)
        
        ChromeProfileEngine.localStatePathOverride = localStateUrl.path
        defer { ChromeProfileEngine.localStatePathOverride = nil }
        
        let engine = ChromeProfileEngine()
        #expect(engine.profiles.count == 1)
        #expect(engine.profiles.first?.dir == "Default")
        #expect(engine.profiles.first?.name == "Default Profile")
    }

    @Test @MainActor
    func testCanPinMoreAppsAndExplicitReplacement() {
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let mockAiAgent = [
            AntigravityItem(name: "Antigravity", bundleID: "com.google.antigravity", path: "/Applications/Antigravity.app", icon: dummyIcon, index: 1)
        ]
        let mockIde = [
            AntigravityItem(name: "Antigravity IDE", bundleID: "com.google.antigravity-ide", path: "/Applications/Antigravity IDE.app", icon: dummyIcon, index: 1)
        ]
        let mockTerminal = [
            AntigravityItem(name: "iTerm2", bundleID: "com.googlecode.iterm2", path: "/Applications/iTerm.app", icon: dummyIcon, index: 1)
        ]
        let mockNotes = [
            AntigravityItem(name: "Notes", bundleID: "com.apple.Notes", path: "/System/Applications/Notes.app", icon: dummyIcon, index: 1)
        ]
        let mockComm = [
            AntigravityItem(name: "Telegram", bundleID: "com.tdesktop.Telegram", path: "/Applications/Telegram.app", icon: dummyIcon, index: 1)
        ]
        
        AppGroupEngine.aiAgent.customItemsOverride = mockAiAgent
        AppGroupEngine.ide.customItemsOverride = mockIde
        AppGroupEngine.terminal.customItemsOverride = mockTerminal
        AppGroupEngine.notes.customItemsOverride = mockNotes
        AppGroupEngine.communication.customItemsOverride = mockComm
        
        AppGroupEngine.aiAgent.refreshItems()
        AppGroupEngine.ide.refreshItems()
        AppGroupEngine.terminal.refreshItems()
        AppGroupEngine.notes.refreshItems()
        AppGroupEngine.communication.refreshItems()
        
        let previous = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            AppGroupEngine.aiAgent.customItemsOverride = nil
            AppGroupEngine.ide.customItemsOverride = nil
            AppGroupEngine.terminal.customItemsOverride = nil
            AppGroupEngine.notes.customItemsOverride = nil
            AppGroupEngine.communication.customItemsOverride = nil
            
            AppGroupEngine.aiAgent.refreshItems()
            AppGroupEngine.ide.refreshItems()
            AppGroupEngine.terminal.refreshItems()
            AppGroupEngine.notes.refreshItems()
            AppGroupEngine.communication.refreshItems()
            
            if let prev = previous {
                UserDefaults.standard.set(prev, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
        }
        
        UserDefaults.standard.set(AppGroupEngine.defaultPinnedBundleIDs, forKey: "SelectedAppBundleIDs")
        #expect(AppGroupEngine.pinnedAppItems().count == 4)
        #expect(AppGroupEngine.canPinMoreApps == false)
        
        // Explicit replacement replaces target app and keeps count at 4
        let targetOld = "com.apple.Notes"
        let targetNew = "com.tdesktop.Telegram"
        AppGroupEngine.replaceApp(oldBundleID: targetOld, newBundleID: targetNew)
        
        #expect(AppGroupEngine.isAppSelected(bundleID: targetNew) == true)
        #expect(AppGroupEngine.isAppSelected(bundleID: targetOld) == false)
        #expect(AppGroupEngine.pinnedAppItems().count == 4)
        #expect(AppGroupEngine.canPinMoreApps == false)
        
        // After deselecting, canPinMoreApps becomes true
        AppGroupEngine.deselectApp(bundleID: targetNew)
        #expect(AppGroupEngine.pinnedAppItems().count == 3)
        #expect(AppGroupEngine.canPinMoreApps == true)
    }

    @Test @MainActor
    func testMultiBrowserSelectionAndDiscovery() {
        let engine = ChromeProfileEngine.shared
        let originalBrowser = engine.browserBundleID
        let originalPreferred = engine.preferredBrowserBundleID
        defer {
            engine.selectBrowser(bundleID: originalBrowser)
            engine.preferredBrowserBundleID = originalPreferred
        }
        
        #expect(!ChromeProfileEngine.supportedBrowsers.isEmpty)
        let braveCandidate = ChromeProfileEngine.supportedBrowsers.first(where: { $0.bundleID == "com.brave.Browser" })
        #expect(braveCandidate != nil)
        #expect(braveCandidate?.name == "Brave Browser")
        
        let edgeCandidate = ChromeProfileEngine.supportedBrowsers.first(where: { $0.bundleID == "com.microsoft.edgemac" })
        #expect(edgeCandidate != nil)
        #expect(edgeCandidate?.name == "Microsoft Edge")
        
        // Test explicit selection
        engine.selectBrowser(bundleID: "com.brave.Browser")
        #expect(engine.browserBundleID == "com.brave.Browser")
        #expect(engine.activeBrowserName == "Brave Browser")
        #expect(UserDefaults.standard.string(forKey: "PreferredBrowserBundleID") == "com.brave.Browser")
        
        engine.selectBrowser(bundleID: "com.google.Chrome")
        #expect(engine.browserBundleID == "com.google.Chrome")
        #expect(engine.activeBrowserName == "Google Chrome")
    }

    @Test
    func testParseReleaseHighlightsFromMarkdownBody() {
        let sampleMarkdown = """
        ## What's Changed in v1.1.5
        
        ### 🎨 Branding & Web Identity
        * **Optically Centered Brand Mark (LOD 0):** Replaced heavy macOS squircle with a crisp vector mascot.
        * **Contrast & Theme Fix:** Eliminated white container cutout in dark mode.
        * Tactile Micro-Hover: Smooth 8% scale spring on navbar branding hover.
        
        ### ⚡ Navigation & Core Engine
        * **Unified Browser Letter Cycling (C):** Seamless cyclic rotation (`· 1/2 ↻`).
        * **Smart App Discovery:** Prevented invalid missing bundle pins by @developer in https://github.com/pulls/42
        * Monolithic HUD Geometry: Standardized app cards.
        
        --------
        
        Full Changelog: https://github.com/ellisglass/nnts/compare/v2.0.0...v2.0.1
        """
        
        let highlights = UpdateEngine.parseReleaseHighlights(from: sampleMarkdown, maxBullets: 4)
        #expect(highlights.count == 4)
        #expect(highlights[0] == "Optically Centered Brand Mark (LOD 0): Replaced heavy macOS squircle with a crisp vector mascot.")
        #expect(highlights[1] == "Contrast & Theme Fix: Eliminated white container cutout in dark mode.")
        #expect(highlights[2] == "Tactile Micro-Hover: Smooth 8% scale spring on navbar branding hover.")
        #expect(highlights[3] == "Unified Browser Letter Cycling (C): Seamless cyclic rotation (· 1/2 ↻).")
        
        let emptyHighlights = UpdateEngine.parseReleaseHighlights(from: nil)
        #expect(emptyHighlights.isEmpty)
        
        let singleBullet = UpdateEngine.parseReleaseHighlights(from: "- Simple fix", maxBullets: 1)
        #expect(singleBullet == ["Simple fix"])
    }

    @Test @MainActor
    func testFeedbackWindowNativeIconsAndDragItemProvider() {
        let finderIcon = FeedbackWindowView.finderIcon
        #expect(finderIcon.isValid)
        #expect(finderIcon.size.width > 0)

        let telegramIcon = FeedbackWindowView.telegramIcon
        #expect(telegramIcon.isValid)
        #expect(telegramIcon.size.width > 0)

        let gitHubIcon = FeedbackWindowView.gitHubIcon
        #expect(gitHubIcon.isValid)
        #expect(gitHubIcon.size.width > 0)

        let testURL = URL(fileURLWithPath: "/tmp/nnts-diagnostic.zip")
        let provider = NSItemProvider(object: testURL as NSURL)
        provider.suggestedName = "nnts-diagnostic.zip"
        #expect(provider.registeredTypeIdentifiers.contains("public.file-url"))
    }

    @Test @MainActor
    func testAppDelegateHasReportIssueMenuItem() {
        let appDelegate = AppDelegate()
        let menu = appDelegate.buildStatusMenu()
        
        let reportItem = menu.items.first(where: { $0.title.contains("Report an Issue") })
        #expect(reportItem != nil, "Report an Issue menu item must exist")
        #expect(reportItem?.action == #selector(AppDelegate.handleReportIssue))
    }

    @Test @MainActor
    func testLegacyPhantomAppsMigrationCleansUninstalledApps() {
        let prevSaved = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        let prevMigration = UserDefaults.standard.bool(forKey: AppGroupEngine.migrationV116Key)
        defer {
            if let prev = prevSaved {
                UserDefaults.standard.set(prev, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
            UserDefaults.standard.set(prevMigration, forKey: AppGroupEngine.migrationV116Key)
        }
        
        // Simulate a Mac that inherited uninstalled phantom defaults
        let phantomDefaults = ["com.openai.chat", "com.apple.dt.Xcode", "com.apple.Terminal", "com.apple.Notes"]
        UserDefaults.standard.set(phantomDefaults, forKey: "SelectedAppBundleIDs")
        
        AppGroupEngine.migrateLegacyPinnedAppsIfNeeded(force: true)
        
        let cleaned = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs") ?? []
        #expect(!cleaned.isEmpty, "Cleaned list must not be empty")
        #expect(cleaned.count <= AppGroupEngine.freePinnedAppsLimit)
        
        for bundle in cleaned {
            if AppGroupEngine.legacyPhantomBundleIDs.contains(bundle) {
                // If it is in the phantom set, it must actually be installed on disk
                let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle)
                #expect(url != nil, "Retained bundle \(bundle) must be installed on disk")
            }
        }
    }

    @Test @MainActor
    func testSettingsMenuItemOpensNativeSettingsWindow() {
        let appDelegate = AppDelegate()
        let menu = appDelegate.buildStatusMenu()
        let settingsItem = menu.items.first(where: { $0.title == "Settings..." })
        #expect(settingsItem != nil)
        #expect(settingsItem?.keyEquivalent == ",")
        #expect(settingsItem?.keyEquivalentModifierMask == [.command])
        #expect(settingsItem?.action == #selector(AppDelegate.handleOpenSettings))
    }

    @Test @MainActor
    func testSettingsViewModelEngineBindingsAndTabNavigation() {
        let vm = SettingsViewModel()
        
        // Tab switching
        #expect(vm.selectedTab == .general)
        vm.selectedTab = .profiles
        #expect(vm.selectedTab == .profiles)
        vm.selectedTab = .copyOnSelect
        #expect(vm.selectedTab == .copyOnSelect)
        vm.selectedTab = .finderTidy
        #expect(vm.selectedTab == .finderTidy)
        vm.selectedTab = .license
        #expect(vm.selectedTab == .license)
        
        // Copy on Select binding
        let initialCopyState = CopyOnSelectEngine.shared.isEnabled
        vm.setCopyOnSelectEnabled(!initialCopyState)
        #expect(CopyOnSelectEngine.shared.isEnabled == !initialCopyState)
        vm.setCopyOnSelectEnabled(initialCopyState)
        
        let initialToastState = CopyOnSelectEngine.shared.isToastEnabled
        vm.setCopyToastEnabled(!initialToastState)
        #expect(CopyOnSelectEngine.shared.isToastEnabled == !initialToastState)
        #expect(vm.isCopyToastEnabled == !initialToastState)
        vm.setCopyToastEnabled(initialToastState)
        
        let initialEverywhereState = CopyOnSelectEngine.shared.allowEverywhere
        vm.setCopyAllowEverywhere(!initialEverywhereState)
        #expect(CopyOnSelectEngine.shared.allowEverywhere == !initialEverywhereState)
        #expect(vm.isCopyAllowEverywhere == !initialEverywhereState)
        vm.setCopyAllowEverywhere(initialEverywhereState)
        
        // Finder Tidy binding
        let initialTidyLimit = FinderTidyEngine.shared.maxWindows
        vm.setFinderMaxWindows(initialTidyLimit)
    }
}
