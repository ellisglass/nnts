import Foundation
import Testing
import AppKit
@testable import ChromeQuickAccess

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
    func testMinimalHUDWindowIsPanel() {
        let window = MinimalHUDWindow.shared
        #expect(window.isFloatingPanel == true)
        #expect(window.level == .floating)
    }
    

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
        
        // 1. Browsers & Profiles section header present and strictly non-clickable
        let browserSectionHeader = menu.items.first(where: { $0.title.contains("Browsers & Profiles") })
        #expect(browserSectionHeader != nil)
        #expect(browserSectionHeader?.isSectionHeader == true)
        #expect(browserSectionHeader?.isEnabled == false)
        #expect(browserSectionHeader?.action == nil)
        
        let chromeItem = menu.items.first(where: { $0.title.hasPrefix("Chrome") })
        #expect(chromeItem != nil)
        #expect(chromeItem?.keyEquivalent == "c")
        #expect(chromeItem?.action != nil)
        
        // Profile Strip View custom view present
        let profileStripItem = menu.items.first(where: { $0.view is ProfileStripView })
        #expect(profileStripItem != nil, "Profile strip custom view should exist for compact horizontal layout")
        
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
        
        // 4. Quick Apps are streamlined into Settings and NOT cluttering the root status menu
        let quickAppsHeader = menu.items.first(where: { $0.title.contains("Quick Apps") })
        #expect(quickAppsHeader == nil, "Quick Apps section header must not be in root menu")
        
        let changeAppItem = menu.items.first(where: { $0.title == "Manage Quick Apps..." })
        #expect(changeAppItem == nil, "Manage Quick Apps must not be in root menu")
    }
    

    @Test @MainActor
    func testTwoTierMenuLayoutWithMascotBetween() {
        let appDelegate = AppDelegate()
        let menu = appDelegate.buildStatusMenu()
        
        let browserHeaderIdx = menu.items.firstIndex(where: { $0.title.contains("Browsers & Profiles") })
        let profileStripIdx = menu.items.firstIndex(where: { $0.view is ProfileStripView })
        let copyIdx = menu.items.firstIndex(where: { $0.title.hasPrefix("Copy on Select") })
        let settingsIdx = menu.items.firstIndex(where: { $0.title == "Settings..." })
        let aboutIdx = menu.items.firstIndex(where: { $0.title.contains("About NNTS") })
        let reportIdx = menu.items.firstIndex(where: { $0.title.contains("Report an Issue") })
        let quitIdx = menu.items.firstIndex(where: { $0.title.contains("Quit NNTS") })
        
        #expect(browserHeaderIdx != nil, "Browsers & Profiles header must exist")
        #expect(profileStripIdx != nil, "ProfileStripView must exist")
        #expect(copyIdx != nil, "Copy on Select must exist")
        #expect(settingsIdx != nil, "Settings... must exist")
        #expect(aboutIdx != nil, "About NNTS must exist")
        #expect(reportIdx != nil, "Report an Issue must exist")
        #expect(quitIdx != nil, "Quit NNTS must exist")
        
        if let bIdx = browserHeaderIdx, let pIdx = profileStripIdx, let cIdx = copyIdx,
           let sIdx = settingsIdx, let aIdx = aboutIdx, let rIdx = reportIdx, let qIdx = quitIdx {
            #expect(bIdx < pIdx)
            #expect(pIdx < cIdx)
            #expect(cIdx < sIdx)
            #expect(sIdx < aIdx)
            #expect(aIdx < rIdx)
            #expect(rIdx < qIdx)
        }
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
    

    @Test @MainActor
    func testDynamicHUDAppTitleAndIconForBrave() {
        let engine = ChromeProfileEngine.shared
        let originalBrowser = engine.browserBundleID
        defer {
            engine.selectBrowser(bundleID: originalBrowser)
        }
        
        engine.selectBrowser(bundleID: "com.brave.Browser")
        #expect(engine.activeBrowserName == "Brave Browser")
        let icon = engine.activeBrowserIcon
        #expect(icon.size.width > 0)
        #expect(icon.size.height > 0)
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
    

    @Test
    func testNNTSMotionConstants() {
        _ = NNTSMotion.interactiveSnap
        _ = NNTSMotion.magneticGlide
        _ = NNTSMotion.tactileBop
        _ = NNTSMotion.cardMorph
        _ = NNTSMotion.microPress
    }
    

    @Test @MainActor
    func testMascotProceduralIconGenerationAndBlinking() {
        let normalIcon = AppDelegate.makeMascotStatusIcon()
        #expect(normalIcon.size.width == 29)
        #expect(normalIcon.size.height == 18)
        
        let blinkingIcon = AppDelegate.makeMascotStatusIcon(blinkProgress: 1.0)
        #expect(blinkingIcon.size.width == 29)
        #expect(blinkingIcon.size.height == 18)
        
        let gazeLeftIcon = AppDelegate.makeMascotStatusIcon(eyeGazeX: -0.8)
        #expect(gazeLeftIcon.size.width == 29)
        #expect(gazeLeftIcon.size.height == 18)
        
        let gazeRightIcon = AppDelegate.makeMascotStatusIcon(eyeGazeX: 0.8)
        #expect(gazeRightIcon.size.width == 29)
        #expect(gazeRightIcon.size.height == 18)
    }
    

    @Test @MainActor
    func testStatusIconStylesAndPersistence() {
        let icon = AppDelegate.makeStatusIcon()
        #expect(icon.size.width == 29)
        #expect(icon.size.height == 18)
        #expect(icon.isTemplate == true)
        
        let pressedIcon = AppDelegate.makeStatusIcon(pressed: true)
        #expect(pressedIcon.size.width == 29)
        #expect(pressedIcon.size.height == 18)
        #expect(pressedIcon.isTemplate == true)
        
        let nntsIcon = AppDelegate.makeNNTSKeycapIcon()
        #expect(nntsIcon.size.width == 29)
        #expect(nntsIcon.isTemplate == true)
    }
    

    @Test @MainActor
    func testMascotPeekAndSeparatorBounceProperties() {
        
        
        
        MinimalHUDWindow.shared.hideImmediate()
        
        
        let separatorView = AppDelegate.MascotSeparatorView(icon: AppDelegate.makeMascotStatusIcon())
        #expect(separatorView.intrinsicContentSize.height == 20)
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

    // MARK: - Telemetry & Diagnostics Tests

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
        
        let chromeItem = menuWithC.items.first(where: { $0.title.hasPrefix("Chrome") || $0.attributedTitle?.string.hasPrefix("Chrome") == true })
        #expect(chromeItem != nil)
        let chromeTitle = chromeItem?.attributedTitle?.string ?? chromeItem?.title ?? ""
        #expect(chromeTitle.contains("· 1/2 ↻"), "Chrome must display 1/2 cyclic badge when Calculator shares letter C")
        
        // Calculator is registered in pinned apps and shares letter C
        let calcPinned = AppGroupEngine.pinnedAppItems().first(where: { $0.bundleID == calcBundle })
        #expect(calcPinned != nil)
        
        // 2. Without any app sharing letter 'C'
        UserDefaults.standard.set(["com.apple.Notes", "com.apple.Terminal"], forKey: "SelectedAppBundleIDs")
        let menuWithoutC = appDelegate.buildStatusMenu()
        let soloChromeItem = menuWithoutC.items.first(where: { $0.title.hasPrefix("Chrome") || $0.attributedTitle?.string.hasPrefix("Chrome") == true })
        let soloChromeTitle = soloChromeItem?.attributedTitle?.string ?? soloChromeItem?.title ?? ""
        #expect(!soloChromeTitle.contains("↻"), "Solo Chrome must NOT display cyclic badge when no pinned apps share letter C")
    }


    @Test @MainActor
    func testHUDCardViewInitialization() {
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let sampleProfiles = [
            ChromeProfile(index: 1, dir: "Default", name: "Personal"),
            ChromeProfile(index: 2, dir: "Profile 1", name: "Work")
        ]
        let chromeCard = HUDCardView(
            name: "Google Chrome",
            icon: dummyIcon,
            isSelected: true,
            isBrowser: true,
            profiles: sampleProfiles,
            selectedProfileIndex: 0
        )
        let clockCard = HUDCardView(
            name: "Clock",
            icon: dummyIcon,
            isSelected: false,
            isBrowser: false,
            profiles: [],
            selectedProfileIndex: 0
        )
        
        #expect(chromeCard.name == "Google Chrome")
        #expect(chromeCard.isSelected == true)
        #expect(chromeCard.isBrowser == true)
        #expect(chromeCard.profiles.count == 2)
        
        // Uniform card width invariant
        #expect(chromeCard.cardWidth == HUDCardView.standardCardWidth)
        #expect(clockCard.cardWidth == HUDCardView.standardCardWidth)
        #expect(chromeCard.cardWidth == clockCard.cardWidth, "All application cards must have identical width")
        #expect(HUDCardView.standardCardWidth == 132)
        
        // 1.7x scaled app icon size invariant (54pt * 1.7 -> 92pt)
        #expect(chromeCard.iconSize == 92)
        #expect(clockCard.iconSize == 92)
    }
    

    @Test @MainActor
    func testHUDCardViewExpandedSingleModeAndFocusTitleInvariant() {
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let sampleProfiles = [
            ChromeProfile(index: 1, dir: "Default", name: "Personal"),
            ChromeProfile(index: 2, dir: "Profile 1", name: "Work")
        ]
        
        let singleExpandedCard = HUDCardView(
            name: "Google Chrome",
            icon: dummyIcon,
            isSelected: true,
            isBrowser: true,
            profiles: sampleProfiles,
            selectedProfileIndex: 0,
            hasRowProfiles: true,
            isSingleCard: true
        )
        
        #expect(singleExpandedCard.isSingleCard == true)
        #expect(singleExpandedCard.cardWidth == 240, "Single mode hero card must have expanded width (240pt)")
        #expect(singleExpandedCard.cardWidth > HUDCardView.standardCardWidth)
        
        let unfocusedCard = HUDCardView(
            name: "Terminal",
            icon: dummyIcon,
            isSelected: false,
            isBrowser: false,
            profiles: [],
            selectedProfileIndex: 0,
            hasRowProfiles: false,
            isSingleCard: false
        )
        
        #expect(unfocusedCard.isSelected == false)
        #expect(unfocusedCard.cardWidth == 132)
        
        let singleNonBrowserCard = HUDCardView(
            name: "Finder",
            icon: dummyIcon,
            isSelected: true,
            isBrowser: false,
            profiles: [],
            selectedProfileIndex: 0,
            hasRowProfiles: false,
            isSingleCard: true
        )
        #expect(singleNonBrowserCard.cardWidth == 190, "Single mode non-browser card must have balanced width (190pt)")
        
        // 1.7x scaled app icon size invariants (single mode: 68pt * 1.7 -> 116pt; standard: 54pt * 1.7 -> 92pt)
        #expect(singleExpandedCard.iconSize == 116)
        #expect(unfocusedCard.iconSize == 92)
        #expect(singleNonBrowserCard.iconSize == 116)
    }
    

    @Test
    func testKinescopeShapeConvexGeometryAndPathGeneration() {
        let shape = KinescopeShape(cornerRadius: 32, bulge: 7)
        #expect(shape.cornerRadius == 32)
        #expect(shape.bulge == 7)
        #expect(shape.insetAmount == 0)
        
        let testRect = CGRect(x: 0, y: 0, width: 300, height: 240)
        let path = shape.path(in: testRect)
        #expect(!path.isEmpty, "KinescopeShape must generate a valid non-empty vector path")
        
        let pathBounds = path.boundingRect
        #expect(pathBounds.width > 0 && pathBounds.height > 0)
        #expect(pathBounds.minX >= testRect.minX - 1.0)
        #expect(pathBounds.maxX <= testRect.maxX + 1.0)
        #expect(pathBounds.minY >= testRect.minY - 1.0)
        #expect(pathBounds.maxY <= testRect.maxY + 1.0)
        
        // Test insetting behavior
        let insetShape = shape.inset(by: 2.5)
        #expect(insetShape.insetAmount == 2.5)
        let insetPath = insetShape.path(in: testRect)
        #expect(!insetPath.isEmpty)
        #expect(insetPath.boundingRect.width < pathBounds.width)
    }


    @Test @MainActor
    func testRetroCRTChannelSwitcherHUDInvariants() {
        // 1. Deterministic size invariance: HUD must always be fixed 320pt x 270pt
        #expect(MinimalHUDView.hudWidth == 320)
        #expect(MinimalHUDView.hudHeight == 270)
        
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let appItem = AntigravityItem(name: "Telegram", bundleID: "ru.keepcoder.Telegram", path: "/Applications/Telegram.app", icon: dummyIcon, index: 1)
        
        // 2. Channel item view creation and rendering
        let channelItem = AppChannelItemView(item: appItem, isSelected: true, channelIndex: 1)
        #expect(channelItem.isSelected == true)
        #expect(channelItem.channelIndex == 1)
        
        let arcView = CRTVectorArcView()
        
        
        let leftArcShape = CRTLeftEdgeArcShape(insetAmount: 1.0)
        let arcPath = leftArcShape.path(in: CGRect(x: 0, y: 0, width: 300, height: 270))
        #expect(!arcPath.isEmpty)
        #expect(arcPath.boundingRect.minX >= 0.5)
        #expect(arcPath.boundingRect.minX <= 25.0)
        
        // 4. CRT scanlines view
        let scanlines = CRTScanlinesView()
        
    }


    @Test @MainActor
    func testTwoTierHUDChannelsAndProfilesCoexistence() {
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let sampleProfile = ChromeProfile(index: 1, dir: "Default", name: "Personal")
        
        // Compact ProfileAvatarView check
        let compactAvatar = ProfileAvatarView(profile: sampleProfile, isSelected: true, slotIndex: 1, isCompact: true)
        #expect(compactAvatar.isCompact == true)
        #expect(compactAvatar.slotIndex == 1)
        
        let standardAvatar = ProfileAvatarView(profile: sampleProfile, isSelected: false, slotIndex: 1, isCompact: false)
        #expect(standardAvatar.isCompact == false)
        
        // State coexistence check: apps on letter 'C' alongside Chrome profiles
        let state = ChromeSwitcherState()
        state.mode = .antigravity
        
        let browserItem = AntigravityItem(name: "Google Chrome", bundleID: "com.google.Chrome", path: "/Applications/Google Chrome.app", icon: dummyIcon, index: 1)
        let calendarItem = AntigravityItem(name: "Calendar", bundleID: "com.apple.iCal", path: "/System/Applications/Calendar.app", icon: dummyIcon, index: 2)
        state.antigravityItems = [browserItem, calendarItem]
        state.profiles = [
            sampleProfile,
            ChromeProfile(index: 2, dir: "Profile 1", name: "Work")
        ]
        state.selectedIndex = 0
        state.selectedProfileIndex = 0
        
        #expect(state.selectedAppItem?.name == "Google Chrome")
        #expect(state.selectedProfile?.effectiveName == "Personal")
        #expect(state.antigravityItems.count == 2)
        #expect(state.profiles.count == 2)
        
        // Cycle to Calendar
        state.selectNext()
        #expect(state.selectedIndex == 1)
        #expect(state.selectedAppItem?.name == "Calendar")
        
        // Direct jump to Chrome Profile 2
        state.selectChromeProfile(index: 1)
        #expect(state.selectedIndex == 0)
        #expect(state.selectedProfileIndex == 1)
        #expect(state.selectedProfile?.effectiveName == "Work")
    }


    @Test @MainActor
    func testMacNativeLiquidGlassInvariants() {
        // 1. Verify MacNativeLiquidGlassBackground initialization and parameters
        let glassDefault = MacNativeLiquidGlassBackground()
        #expect(glassDefault.cornerRadius == 28)
        #expect(glassDefault.material == .popover)
        
        let glassCustom = MacNativeLiquidGlassBackground(cornerRadius: 32, material: .popover)
        #expect(glassCustom.cornerRadius == 32)
        #expect(glassCustom.material == .popover)
        
        // 2. Verify VisualEffectBlur wrapper properties
        let blur = VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
        #expect(blur.material == .hudWindow)
        #expect(blur.blendingMode == .behindWindow)
        #expect(blur.state == .active)
        
        // 3. Verify MinimalHUDView fixed dimensions and glass integration
        #expect(MinimalHUDView.hudWidth == 320)
        #expect(MinimalHUDView.hudHeight == 270)
        
        // 4. Verify CopyToastView integration
        let toastView = CopyToastView(isVisible: true)
        #expect(toastView.isVisible == true)
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
        
        // Section headers must strictly contain ONLY Browsers & Profiles
        #expect(headerTitles.contains(where: { $0.contains("Browsers & Profiles") }))
        #expect(!headerTitles.contains(where: { $0.contains("Quick Apps") }))
        #expect(sectionHeaders.count == 1, "There should be exactly 1 section header in the root menu")
        
        // Strictly forbidden legacy category header titles
        let forbiddenHeaders = ["Core Toolset", "Toolkit", "Toolset Shortcuts", "Quick Shortcuts"]
        for forbidden in forbiddenHeaders {
            #expect(!headerTitles.contains(where: { $0.contains(forbidden) }), "Header must not contain '\(forbidden)'")
        }
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
