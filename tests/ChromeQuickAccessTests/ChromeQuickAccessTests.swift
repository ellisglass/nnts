import Foundation
import Testing
import AppKit
@testable import ChromeQuickAccess

@Suite(.serialized)
struct ChromeQuickAccessUnitTests {
    
    @Test @MainActor
    func testKeyCodes() {
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_A) == "a")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_C) == "c")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_1) == "1")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_2) == "2")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_3) == "3")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_4) == "4")
        #expect(KeyCodes.character(for: KeyCodes.kVK_Escape) == "escape")
        #expect(KeyCodes.character(for: 0xFFFF) == nil)
    }
    
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
    func testHIDMappingConstants() {
        #expect(HIDMappingService.hidCapsLock == 0x700000039)
        #expect(HIDMappingService.hidF18 == 0x70000006D)
    }
    
    @Test @MainActor
    func testKeyCodesExtended() {
        #expect(KeyCodes.kVK_LeftArrow == 0x7B)
        #expect(KeyCodes.kVK_RightArrow == 0x7C)
        #expect(KeyCodes.kVK_DownArrow == 0x7D)
        #expect(KeyCodes.kVK_UpArrow == 0x7E)
        #expect(KeyCodes.kVK_Tab == 0x30)
    }
    
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
    func testChromeAppIconHelper() {
        let icon = ChromeAppIconHelper.chromeIcon()
        #expect(icon.size.width > 0)
        #expect(icon.size.height > 0)
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
    func testCopyOnSelectDefaultParameters() {
        let engine = CopyOnSelectEngine()
        #expect(engine.isEnabled == true)
        #expect(engine.dragThreshold == 10.0)
        #expect(engine.copyDelayMs == 150)
    }
    
    @Test @MainActor
    func testCopyOnSelectDragDistanceTrigger() {
        let engine = CopyOnSelectEngine()
        
        // Horizontal drag exceeding threshold (dx = 15 > 10)
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 115, y: 100), clickCount: 1) == true)
        
        // Vertical drag exceeding threshold (dy = 12 > 10)
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 100, y: 112), clickCount: 1) == true)
        
        // Negative direction drag exceeding threshold (dx = 15 > 10)
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 85, y: 100), clickCount: 1) == true)
        
        // Sub-threshold movement (dx = 5 <= 10, dy = 5 <= 10)
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 105, y: 105), clickCount: 1) == false)
    }
    
    @Test @MainActor
    func testCopyOnSelectMultiClickTrigger() {
        let engine = CopyOnSelectEngine()
        
        // Double-click at same position (word selection)
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 100, y: 100), clickCount: 2) == true)
        
        // Triple-click at same position (paragraph selection)
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 100, y: 100), clickCount: 3) == true)
    }
    
    @Test @MainActor
    func testCopyOnSelectSingleClickNoTrigger() {
        let engine = CopyOnSelectEngine()
        
        // Normal single click with zero displacement
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 250, y: 300), end: CGPoint(x: 250, y: 300), clickCount: 1) == false)
    }
    
    @Test @MainActor
    func testCopyOnSelectDisabledState() {
        let engine = CopyOnSelectEngine()
        engine.isEnabled = false
        
        // Exceeding drag threshold must be ignored when disabled
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 200, y: 200), clickCount: 1) == false)
        
        // Multi-click must be ignored when disabled
        #expect(engine.shouldTriggerCopy(start: CGPoint(x: 100, y: 100), end: CGPoint(x: 100, y: 100), clickCount: 2) == false)
    }
    
    @Test @MainActor
    func testCopyOnSelectPostKeystrokeCallback() {
        let engine = CopyOnSelectEngine()
        var callbackFired = false
        engine.onCopyKeystrokePosted = {
            callbackFired = true
        }
        
        engine.postCopyKeystroke()
        #expect(callbackFired == true)
    }
    
    @Test @MainActor
    func testCopyOnSelectLifecycleAndToggle() {
        let engine = CopyOnSelectEngine()
        #expect(engine.isEnabled == true)
        
        engine.isEnabled.toggle()
        #expect(engine.isEnabled == false)
        
        engine.isEnabled.toggle()
        #expect(engine.isEnabled == true)
        
        engine.stop()
        #expect(engine.isStarted == false)
    }
    
    @Test @MainActor
    func testCopyOnSelectEmptyStringFilteringHelper() {
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace("") == true)
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace("   ") == true)
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace("\n\t\r ") == true)
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace(nil) == true)
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace("hello") == false)
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace("  hello  ") == false)
    }
    
    @Test @MainActor
    func testCopyOnSelectPreFlightAXEmptyStringFiltering() {
        CopyOnSelectEngine.mockFocusedSelectedText = "   "
        defer { CopyOnSelectEngine.mockFocusedSelectedText = nil }
        
        let engine = CopyOnSelectEngine()
        let selected = engine.focusedElementSelectedText()
        #expect(selected == "   ")
        #expect(CopyOnSelectEngine.isStringEmptyOrWhitespace(selected) == true)
    }
    
    @Test @MainActor
    func testCopyOnSelectPasteboardEmptyStringSuppressionAndRestoration() {
        let pboard = NSPasteboard.general
        pboard.clearContents()
        pboard.setString("Preserved Clipboard Content", forType: .string)
        
        // Snapshot existing clipboard state
        let snapshot: [[NSPasteboard.PasteboardType: Data]] = pboard.pasteboardItems?.compactMap { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        } ?? []
        
        let initialChangeCount = pboard.changeCount
        
        // Target app copies empty string or whitespace into pasteboard
        pboard.clearContents()
        pboard.setString("   \n", forType: .string)
        
        let engine = CopyOnSelectEngine()
        let didCopy = engine.evaluateCopiedContent(
            initialChangeCount: initialChangeCount,
            previousItems: snapshot,
            mousePos: CGPoint(x: 100, y: 100)
        )
        
        // Should suppress the copy and restore previous content
        #expect(didCopy == false)
        #expect(pboard.string(forType: .string) == "Preserved Clipboard Content")
    }
    
    @Test @MainActor
    func testCopyOnSelectPasteboardValidStringAcceptance() {
        let pboard = NSPasteboard.general
        pboard.clearContents()
        pboard.setString("Old Content", forType: .string)
        
        let snapshot: [[NSPasteboard.PasteboardType: Data]] = pboard.pasteboardItems?.compactMap { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        } ?? []
        
        let initialChangeCount = pboard.changeCount
        
        // Target app copies valid non-empty string
        pboard.clearContents()
        pboard.setString("Valid Selected Text", forType: .string)
        
        let engine = CopyOnSelectEngine()
        let didCopy = engine.evaluateCopiedContent(
            initialChangeCount: initialChangeCount,
            previousItems: snapshot,
            mousePos: CGPoint(x: 100, y: 100)
        )
        
        #expect(didCopy == true)
        #expect(pboard.string(forType: .string) != nil)
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
    func testCapsLockHoldingWithShiftFlagsDoesNotPrematurelyRelease() {
        let engine = CapsLockEngine()
        let proxy = unsafeBitCast(1, to: CGEventTapProxy.self)
        
        var modifierReleasedCalled = false
        engine.onModifierReleased = {
            modifierReleasedCalled = true
        }
        
        // 1. User holds CapsLock (F18 KeyDown)
        let f18Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: true)!
        let resDown = engine.handleEvent(proxy: proxy, type: .keyDown, event: f18Down)
        #expect(resDown == nil) // F18 down swallowed
        #expect(engine.isCapsHeld == true)
        #expect(engine.capsUsedAsModifier == false)
        
        // 2. User presses Shift while holding CapsLock (e.g. preparing for Shift-Tab navigation)
        let shiftEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x38, keyDown: true)!
        shiftEvent.flags = [.maskShift]
        let resShift = engine.handleEvent(proxy: proxy, type: .flagsChanged, event: shiftEvent)
        #expect(resShift != nil) // Shift passthrough
        
        // CRITICAL BUG VERIFICATION: Shift MUST NOT cause premature modifier release!
        #expect(engine.isCapsHeld == true)
        #expect(modifierReleasedCalled == false)
        
        // 3. User releases CapsLock (F18 KeyUp)
        let f18Up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: false)!
        let resUp = engine.handleEvent(proxy: proxy, type: .keyUp, event: f18Up)
        #expect(resUp == nil) // F18 up swallowed
        #expect(engine.isCapsHeld == false)
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
    func testCapsLockTapWithoutModifierDoesNotTriggerEscapeOrModifierReleased() {
        let engine = CapsLockEngine()
        let proxy = unsafeBitCast(1, to: CGEventTapProxy.self)
        
        var modifierReleased = false
        engine.onModifierReleased = { modifierReleased = true }
        
        // 1. User taps Caps Lock (F18 KeyDown)
        let f18Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: true)!
        let resDown = engine.handleEvent(proxy: proxy, type: .keyDown, event: f18Down)
        #expect(resDown == nil) // F18 down swallowed
        #expect(engine.isCapsHeld == true)
        #expect(engine.capsUsedAsModifier == false)
        
        // 2. User immediately releases Caps Lock (F18 KeyUp) without pressing any other key
        let f18Up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: false)!
        let resUp = engine.handleEvent(proxy: proxy, type: .keyUp, event: f18Up)
        #expect(resUp == nil) // F18 up swallowed
        #expect(engine.isCapsHeld == false)
        #expect(engine.capsUsedAsModifier == false)
        // Verify modifierReleased callback is NOT triggered since no action occurred
        #expect(modifierReleased == false)
    }
    
    @Test @MainActor
    func testCapsLockAntigravityTrigger() {
        let engine = CapsLockEngine()
        let proxy = unsafeBitCast(1, to: CGEventTapProxy.self)
        
        var antigravityTriggered = false
        engine.dynamicKeyTriggers[KeyCodes.kVK_ANSI_A] = { antigravityTriggered = true }
        
        // Hold F18
        let f18Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: true)!
        _ = engine.handleEvent(proxy: proxy, type: .keyDown, event: f18Down)
        
        // Press 'A'
        let aDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_A), keyDown: true)!
        let resA = engine.handleEvent(proxy: proxy, type: .keyDown, event: aDown)
        #expect(resA == nil) // 'A' swallowed
        #expect(antigravityTriggered == true)
        #expect(engine.capsUsedAsModifier == true)
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
    func testCopyOnSelectIgnoresCommandOrControlDrags() {
        let engine = CopyOnSelectEngine()
        
        var copyPosted = false
        engine.onCopyKeystrokePosted = { copyPosted = true }
        
        // MouseDown with Command modifier held (e.g. moving background window)
        let cmdDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: 100, y: 100), mouseButton: .left)!
        cmdDown.flags = [.maskCommand]
        engine.handleTapEvent(type: .leftMouseDown, event: cmdDown)
        
        // MouseUp with Command modifier held
        let cmdUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: 300, y: 300), mouseButton: .left)!
        cmdUp.flags = [.maskCommand]
        engine.handleTapEvent(type: .leftMouseUp, event: cmdUp)
        
        #expect(copyPosted == false)
        
        // MouseDown with Control modifier held (e.g. connecting Xcode IBOutlet)
        let ctrlDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: 100, y: 100), mouseButton: .left)!
        ctrlDown.flags = [.maskControl]
        engine.handleTapEvent(type: .leftMouseDown, event: ctrlDown)
        
        let ctrlUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: 300, y: 300), mouseButton: .left)!
        ctrlUp.flags = [.maskControl]
        engine.handleTapEvent(type: .leftMouseUp, event: ctrlUp)
        
        #expect(copyPosted == false)
    }
    
    @Test @MainActor
    func testCopyOnSelectTapDisablementRecovery() {
        let engine = CopyOnSelectEngine()
        let dummy = CGEvent(source: nil)!
        
        // Must handle disabled by timeout without throwing or crashing
        engine.handleTapEvent(type: .tapDisabledByTimeout, event: dummy)
        engine.handleTapEvent(type: .tapDisabledByUserInput, event: dummy)
        #expect(engine.isEnabled == true)
    }
    
    @Test @MainActor
    func testCopyOnSelectPendingCopyCancellation() async throws {
        let engine = CopyOnSelectEngine()
        var copyKeystrokes = 0
        engine.onCopyKeystrokePosted = {
            copyKeystrokes += 1
        }
        engine.copyDelayMs = 40 // short delay for test
        
        // 1. Trigger a double-click to schedule a copy
        let doubleClickUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: 100, y: 100), mouseButton: .left)!
        doubleClickUp.setIntegerValueField(.mouseEventClickState, value: 2)
        
        let dummyDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: 100, y: 100), mouseButton: .left)!
        engine.handleTapEvent(type: .leftMouseDown, event: dummyDown)
        engine.handleTapEvent(type: .leftMouseUp, event: doubleClickUp)
        
        #expect(engine.hasPendingCopy == true)
        
        // 2. User immediately clicks down somewhere else (e.g. to deselect or click button)
        let deselectDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: 200, y: 200), mouseButton: .left)!
        engine.handleTapEvent(type: .leftMouseDown, event: deselectDown)
        
        // The pending copy must be cancelled!
        #expect(engine.hasPendingCopy == false)
        
        // Wait longer than copyDelayMs to confirm keystroke was NEVER posted
        try await Task.sleep(nanoseconds: 80_000_000)
        #expect(copyKeystrokes == 0)
    }
    
    @Test @MainActor
    func testCapsLockEngineIsStartedState() {
        let engine = CapsLockEngine()
        #expect(engine.isStarted == false)
        #expect(engine.isCapsHeld == false)
        #expect(engine.capsUsedAsModifier == false)
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
    func testMinimalHUDWindowIsPanel() {
        let window = MinimalHUDWindow.shared
        #expect(window.isFloatingPanel == true)
        #expect(window.level == .floating)
    }
    
    @Test @MainActor
    func testKeyCodesTerminalNotesIde() {
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_T) == "t")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_N) == "n")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_I) == "i")
        #expect(KeyCodes.kVK_ANSI_T == 0x11)
        #expect(KeyCodes.kVK_ANSI_N == 0x2D)
        #expect(KeyCodes.kVK_ANSI_I == 0x22)
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
    func testCapsLockDynamicLetterTriggers() {
        let engine = CapsLockEngine()
        let proxy = unsafeBitCast(1, to: CGEventTapProxy.self)
        
        var terminalTriggered = false
        var obsidianTriggered = false
        var ideTriggered = false
        
        engine.dynamicKeyTriggers[KeyCodes.kVK_ANSI_T] = { terminalTriggered = true }
        engine.dynamicKeyTriggers[KeyCodes.kVK_ANSI_O] = { obsidianTriggered = true }
        engine.dynamicKeyTriggers[KeyCodes.kVK_ANSI_I] = { ideTriggered = true }
        
        // Hold F18
        let f18Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: true)!
        _ = engine.handleEvent(proxy: proxy, type: .keyDown, event: f18Down)
        
        // Press 'T' (Terminal)
        let tDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_T), keyDown: true)!
        let resT = engine.handleEvent(proxy: proxy, type: .keyDown, event: tDown)
        #expect(resT == nil) // Swallowed
        #expect(terminalTriggered == true)
        
        // Press 'O' (Obsidian)
        let oDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_O), keyDown: true)!
        let resO = engine.handleEvent(proxy: proxy, type: .keyDown, event: oDown)
        #expect(resO == nil) // Swallowed
        #expect(obsidianTriggered == true)
        
        // Press 'I' (IDE)
        let iDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_I), keyDown: true)!
        let resI = engine.handleEvent(proxy: proxy, type: .keyDown, event: iDown)
        #expect(resI == nil) // Swallowed
        #expect(ideTriggered == true)
        
        // Check keyUp swallowed
        let tUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_T), keyDown: false)!
        let resTUp = engine.handleEvent(proxy: proxy, type: .keyUp, event: tUp)
        #expect(resTUp == nil)
        
        let oUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_O), keyDown: false)!
        let resOUp = engine.handleEvent(proxy: proxy, type: .keyUp, event: oUp)
        #expect(resOUp == nil)
        
        let iUp = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_I), keyDown: false)!
        let resIUp = engine.handleEvent(proxy: proxy, type: .keyUp, event: iUp)
        #expect(resIUp == nil)
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
                    "Profile 5": { "name": "Profile 6" }
                }
            }
        }
        """
        try mockJson.write(to: localStateUrl, atomically: true, encoding: .utf8)
        
        ChromeProfileEngine.localStatePathOverride = localStateUrl.path
        defer { ChromeProfileEngine.localStatePathOverride = nil }
        
        let engine = ChromeProfileEngine()
        #expect(engine.profiles.count == 6)
        
        // Initial selection should default to first 4
        #expect(engine.selectedProfiles.count == 4)
        #expect(engine.selectedProfiles[0].dir == "Default")
        #expect(engine.selectedProfiles[1].dir == "Profile 1")
        #expect(engine.selectedProfiles[2].dir == "Profile 2")
        #expect(engine.selectedProfiles[3].dir == "Profile 3")
        
        // Selecting 5th replaces 4th profile (max 4)
        engine.selectProfile(dir: "Profile 4")
        #expect(engine.selectedProfiles.count == 4)
        #expect(engine.isProfileSelected(dir: "Profile 4") == true)
        #expect(engine.isProfileSelected(dir: "Profile 3") == false)
        
        // Toggle selection (deselecting if > 1)
        engine.toggleProfileSelection(dir: "Profile 4")
        #expect(engine.selectedProfiles.count == 3)
        #expect(engine.isProfileSelected(dir: "Profile 4") == false)
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
    
    @Test
    func testKeyCodesFullAlphabetAndLookup() {
        #expect(KeyCodes.keyCode(for: "A") == KeyCodes.kVK_ANSI_A)
        #expect(KeyCodes.keyCode(for: "i") == KeyCodes.kVK_ANSI_I)
        #expect(KeyCodes.keyCode(for: "O") == KeyCodes.kVK_ANSI_O)
        #expect(KeyCodes.keyCode(for: "t") == KeyCodes.kVK_ANSI_T)
        #expect(KeyCodes.keyCode(for: "c") == KeyCodes.kVK_ANSI_C)
        #expect(KeyCodes.keyCode(for: "D") == KeyCodes.kVK_ANSI_D)
        #expect(KeyCodes.keyCode(for: "v") == KeyCodes.kVK_ANSI_V)
        #expect(KeyCodes.keyCode(for: "x") == KeyCodes.kVK_ANSI_X)
        #expect(KeyCodes.keyCode(for: "g") == KeyCodes.kVK_ANSI_G)
        #expect(KeyCodes.keyCode(for: "w") == KeyCodes.kVK_ANSI_W)
        
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_I) == "i")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_O) == "o")
        #expect(KeyCodes.character(for: KeyCodes.kVK_ANSI_D) == "d")
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
    func testCapsLockEngineDynamicKeyTriggers() {
        let engine = CapsLockEngine.shared
        let proxy = unsafeBitCast(1, to: CGEventTapProxy.self)
        var triggeredKey: UInt32? = nil
        
        engine.dynamicKeyTriggers[KeyCodes.kVK_ANSI_I] = {
            triggeredKey = KeyCodes.kVK_ANSI_I
        }
        defer { engine.dynamicKeyTriggers.removeAll() }
        
        // Simulate Caps Lock held down (F18 down)
        let f18Down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: true)!
        _ = engine.handleEvent(proxy: proxy, type: .keyDown, event: f18Down)
        #expect(engine.isCapsHeld == true)
        
        // Simulate pressing 'I' (iTerm2 dynamic shortcut)
        let iDown = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_ANSI_I), keyDown: true)!
        let result = engine.handleEvent(proxy: proxy, type: .keyDown, event: iDown)
        
        // Event should be swallowed and dynamic trigger executed
        #expect(result == nil)
        #expect(triggeredKey == KeyCodes.kVK_ANSI_I)
        #expect(engine.capsUsedAsModifier == true)
        
        // Clean up Caps Lock release
        let f18Up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(KeyCodes.kVK_F18), keyDown: false)!
        _ = engine.handleEvent(proxy: proxy, type: .keyUp, event: f18Up)
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
        
        // Refresh Profiles & Apps and Quit Xomsky use native keyEquivalent with ⌘ modifier
        let refreshItem = menu.items.first(where: { $0.title.contains("Refresh Profiles & Apps") })
        #expect(refreshItem != nil)
        #expect(refreshItem?.keyEquivalent == "r")
        #expect(refreshItem?.keyEquivalentModifierMask == [.command])
        
        let quitItem = menu.items.first(where: { $0.title == "Quit Xomsky" })
        #expect(quitItem != nil)
        #expect(quitItem?.keyEquivalent == "q")
        #expect(quitItem?.keyEquivalentModifierMask == [.command])
        
        // Section 1: Browsers & Profiles section header present and strictly non-clickable
        let browserSectionHeader = menu.items.first(where: { $0.title.contains("Browsers & Profiles") })
        #expect(browserSectionHeader != nil)
        #expect(browserSectionHeader?.isSectionHeader == true)
        #expect(browserSectionHeader?.isEnabled == false)
        #expect(browserSectionHeader?.action == nil)
        
        let chromeItem = menu.items.first(where: { $0.title.hasPrefix("Chrome") })
        #expect(chromeItem != nil)
        #expect(chromeItem?.keyEquivalent == "c")
        #expect(chromeItem?.action != nil)
        
        // Mascot Separator present between sections
        let mascotSeparator = menu.items.first(where: { $0.view is AppDelegate.MascotSeparatorView })
        #expect(mascotSeparator != nil)
        #expect(mascotSeparator?.isEnabled == false)
        
        // Section 2: Quick Apps header present and strictly non-clickable
        let quickAppsHeader = menu.items.first(where: { $0.title == "Quick Apps (Caps-Lock)" })
        #expect(quickAppsHeader != nil)
        #expect(quickAppsHeader?.isSectionHeader == true)
        #expect(quickAppsHeader?.isEnabled == false)
        #expect(quickAppsHeader?.action == nil)
        
        // Active Quick Apps items present with valid keyEquivalent
        let termMatch = menu.items.first(where: { $0.title.contains("iTerm") || $0.title.contains("Terminal") })
        #expect(termMatch != nil)
        #expect(termMatch?.keyEquivalent.isEmpty == false)
        
        // Every pinned app is listed directly in the menu without being hidden in submenus
        let antigravityItem = menu.items.first(where: { $0.title.hasPrefix("Antigravity") && !$0.title.contains("IDE") })
        #expect(antigravityItem != nil)
        #expect(antigravityItem?.keyEquivalent == "a")
        #expect(antigravityItem?.submenu == nil)
        
        let ideItem = menu.items.first(where: { $0.title.contains("Antigravity IDE") })
        #expect(ideItem != nil)
        #expect(ideItem?.keyEquivalent == "a")
        #expect(ideItem?.submenu == nil)
        
        let notesMatch = menu.items.first(where: { $0.title.contains("Notes") })
        #expect(notesMatch != nil)
        #expect(notesMatch?.keyEquivalent.isEmpty == false)
        
        // Manage Quick Apps item with submenu present
        let changeAppItem = menu.items.first(where: { $0.title == "Manage Quick Apps..." })
        #expect(changeAppItem != nil)
        #expect(changeAppItem?.submenu != nil)
        
        guard let submenu = changeAppItem?.submenu else { return }
        let subTitles = submenu.items.map { $0.title }
        
        // Headers and Actions present in Change App submenu
        #expect(subTitles.contains("Search & Add Application..."))
        #expect(subTitles.contains(where: { $0.contains("Profiles (up to 4):") }))
        #expect(subTitles.contains(where: { $0.contains("Pinned Quick Apps") }))
        #expect(subTitles.contains("Choose Other App..."))
        
        // App shortcuts derive strictly from first letter of app name (or slot digit for Chrome)
        for item in menu.items {
            if item.isSeparatorItem || item.title.hasSuffix(":") || item.title.hasPrefix("Chrome") || item.title == "Quick Apps (Caps-Lock)" || item.title.contains("Browsers & Profiles") || item.title == "Manage Quick Apps..." || item.view is AppDelegate.MascotSeparatorView { continue }
            if !item.keyEquivalent.isEmpty && item.keyEquivalentModifierMask == [] {
                let appName = item.title.trimmingCharacters(in: .whitespaces)
                let key = item.keyEquivalent
                if let firstChar = key.first, firstChar.isLetter {
                    let expectedChar = String((appName.first(where: { $0.isLetter }) ?? "A").lowercased())
                    #expect(key == expectedChar)
                } else if let firstChar = key.first, firstChar.isNumber {
                    #expect("1234".contains(firstChar))
                }
            }
        }
    }
    
    @Test @MainActor
    func testTwoTierMenuLayoutWithMascotBetween() {
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
            AppGroupEngine.selectedBundleIDs = Set(AppGroupEngine.defaultPinnedBundleIDs)
        }
        
        let appDelegate = AppDelegate()
        
        // Mock a pinned set of applications
        let mockPinned = [
            "com.google.antigravity",
            "com.google.antigravity-ide",
            "com.apple.finder",
            "com.apple.systempreferences"
        ]
        UserDefaults.standard.set(mockPinned, forKey: "SelectedAppBundleIDs")
        AppGroupEngine.selectedBundleIDs = Set(mockPinned)
        
        let menu = appDelegate.buildStatusMenu()
        
        let browserHeaderIdx = menu.items.firstIndex(where: { $0.title.contains("Browsers & Profiles") })
        let mascotSeparatorIdx = menu.items.firstIndex(where: { $0.view is AppDelegate.HamsterSeparatorView })
        let quickHeaderIdx = menu.items.firstIndex(where: { $0.title.contains("Quick Apps") })
        
        #expect(browserHeaderIdx != nil, "Browsers & Profiles header must exist")
        #expect(mascotSeparatorIdx != nil, "Hamster mascot separator must exist")
        #expect(quickHeaderIdx != nil, "Quick Apps header must exist")
        
        if let bIdx = browserHeaderIdx, let mIdx = mascotSeparatorIdx, let qIdx = quickHeaderIdx {
            // Mascot sits as the elegant bridge between Browsers & Profiles and Quick Apps
            #expect(bIdx < mIdx, "Browser section must appear before mascot separator")
            #expect(mIdx < qIdx, "Mascot separator must appear before Quick Apps section")
        }
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
    func testProfileExplicitReplacement() {
        let engine = ChromeProfileEngine.shared
        let savedDirs = engine.selectedProfileDirs
        defer {
            engine.selectedProfileDirs = savedDirs
        }
        
        engine.selectedProfileDirs = ["Default", "Profile 1", "Profile 2", "Profile 3"]
        #expect(engine.selectedProfileDirs.count == 4)
        
        // Replace slot without silent overflow
        engine.replaceProfile(oldDir: "Profile 3", newDir: "Profile 4")
        #expect(engine.selectedProfileDirs == ["Default", "Profile 1", "Profile 2", "Profile 4"])
        #expect(engine.isProfileSelected(dir: "Profile 4") == true)
        #expect(engine.isProfileSelected(dir: "Profile 3") == false)
    }
    
    @Test @MainActor
    func testLicenseEngineValidationAndConstants() {
        let engine = LicenseEngine.shared
        
        #expect(LicenseEngine.freeSlotsLimit == 5)
        #expect(LicenseEngine.freePinnedAppsLimit == 4)
        #expect(LicenseEngine.proPrice == "$19 Lifetime")
        #expect(LicenseEngine.productionServiceName == "com.almosteleven.xomsky.license")
        #expect(LicenseEngine.serviceName == "com.almosteleven.xomsky.license.test")
        #expect(LicenseEngine.licenseAccount == "pro_license_key")
        
        // Invalid key checks: empty or whitespace
        #expect(engine.validateLicenseKey("") == false)
        #expect(engine.validateLicenseKey("   ") == false)
        #expect(engine.validateLicenseKey("\n\t") == false)
        
        // Invalid key checks: shorter than 8 characters or missing XOMSKY/KHOMYAK prefix
        #expect(engine.validateLicenseKey("ABC") == false)
        #expect(engine.validateLicenseKey("1234567") == false)
        #expect(engine.validateLicenseKey("   short   ") == false)
        #expect(engine.validateLicenseKey("12345678") == false)
        #expect(engine.validateLicenseKey("RANDOM-KEY-123") == false)
        #expect(engine.validateLicenseKey("XOMSKY-PRO-LICENSE-001") == true)
        #expect(engine.validateLicenseKey("  XOMSKY-VALID-KEY  ") == true)
        #expect(engine.validateLicenseKey("XOMSKY-OWNER-KEY-001") == true)
        #expect(engine.validateLicenseKey("KHOMYAK-VIP-KEY") == true)
    }
    
    @Test @MainActor
    func testLicenseEngineActivationAndDeactivation() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        defer {
            engine.testOverrideProStatus = originalOverride
            engine.deactivate()
        }
        
        // Ensure clean state
        engine.testOverrideProStatus = nil
        engine.deactivate()
        #expect(engine.isPro == false)
        #expect(engine.activeLicenseKey == nil)
        
        // Attempt activation with invalid key
        let invalidResult = engine.activate(key: "bad")
        #expect(invalidResult == false)
        #expect(engine.isPro == false)
        #expect(engine.activeLicenseKey == nil)
        
        // Attempt activation with valid key via mocked Polar validation
        engine.testMockOnlineValidationResult = true
        let validKey = "XOMSKY-TEST-MOCKED-LICENSE"
        let validResult = engine.activate(key: "  \(validKey)  ")
        #expect(validResult == true)
        #expect(engine.isPro == true)
        #expect(engine.activeLicenseKey == validKey)
        
        // Verify persistent fallback in isolated test storage
        #expect(LicenseEngine.storage.string(forKey: "XomskyProLicenseKey") == validKey)
        
        // Deactivation clears state
        engine.deactivate()
        #expect(engine.isPro == false)
        #expect(engine.activeLicenseKey == nil)
        #expect(LicenseEngine.storage.string(forKey: "XomskyProLicenseKey") == nil)
        engine.testMockOnlineValidationResult = nil
    }
    
    @Test @MainActor
    func testLicenseEngineTestOverride() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        defer {
            engine.testOverrideProStatus = originalOverride
        }
        
        engine.testOverrideProStatus = true
        #expect(engine.isPro == true)
        
        engine.testOverrideProStatus = false
        #expect(engine.isPro == false)
        
        engine.testOverrideProStatus = nil
    }
    
    @Test @MainActor
    func testSlotLimitRulesFreeVsPro() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        let originalSaved = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            engine.testOverrideProStatus = originalOverride
            if let saved = originalSaved {
                UserDefaults.standard.set(saved, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
        }
        
        // 1. Free Tier verification: 4 pinned apps + 1 browser = 5 free slots total
        engine.testOverrideProStatus = false
        #expect(LicenseEngine.freeSlotsLimit == 5)
        #expect(LicenseEngine.freePinnedAppsLimit == 4)
        #expect(AppGroupEngine.maxPinnedQuickApps == 4)
        
        // Free tier enforces 4-slot ceiling on selected bundle IDs
        let testSixIDs = Set([
            "com.google.antigravity",
            "com.google.antigravity-ide",
            "com.googlecode.iterm2",
            "com.apple.Notes",
            "com.tdesktop.Telegram",
            "com.tinyspeck.slackmacgap"
        ])
        AppGroupEngine.selectedBundleIDs = testSixIDs
        #expect(AppGroupEngine.selectedBundleIDs.count <= 4)
        #expect(AppGroupEngine.pinnedAppItems().count <= 4)
        
        // 2. Pro Tier verification: unlimited/26 pinned quick apps
        engine.testOverrideProStatus = true
        #expect(AppGroupEngine.maxPinnedQuickApps == 26)
        
        AppGroupEngine.selectedBundleIDs = testSixIDs
        #expect(AppGroupEngine.selectedBundleIDs.count == 6)
        #expect(AppGroupEngine.canPinMoreApps == true)
    }
    
    @Test @MainActor
    func testLicenseEngineActivationWithOverrideClearing() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        defer {
            engine.testOverrideProStatus = originalOverride
            engine.deactivate()
        }
        
        // If an override was set to false, activate() should clear the override and make isPro true
        engine.testOverrideProStatus = false
        #expect(engine.isPro == false)
        
        engine.testMockOnlineValidationResult = true
        let success = engine.activate(key: "XOMSKY-OVERRIDE-CLEAR-KEY")
        #expect(success == true)
        #expect(engine.isPro == true)
        #expect(engine.testOverrideProStatus == nil)
        engine.testMockOnlineValidationResult = nil
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
    func testLicenseEngineRejectsUnmockedKeysWithoutPolar() {
        let engine = LicenseEngine.shared
        defer {
            engine.testMockOnlineValidationResult = nil
            engine.deactivate()
        }
        
        // 1. Format validation: XOMSKY- and KHOMYAK- prefixes pass basic format check
        #expect(engine.validateLicenseKey("XOMSKY-OWNER-KEY-001") == true)
        #expect(engine.validateLicenseKey("xomsky-owner-lowercase") == true)
        #expect(engine.validateLicenseKey("XOMSKY-VIP-CHAMPION-2026") == true)
        #expect(engine.validateLicenseKey("XOMSKY-GIVEAWAY-FREE-ACCESS") == true)
        #expect(engine.validateLicenseKey("KHOMYAK-OWNER-RETRO") == true)
        #expect(engine.validateLicenseKey("KHOMYAK-VIP-RETRO") == true)
        #expect(engine.validateLicenseKey("RANDOM-KEY-123") == false)
        #expect(engine.validateLicenseKey("XOMSKY") == false) // too short (< 8 chars)
        
        // 2. Unmocked backdoor keys MUST NOT activate offline without Polar validation
        engine.deactivate()
        engine.testMockOnlineValidationResult = nil
        #expect(engine.isPro == false)
        
        let formerBackdoorKeys = [
            "XOMSKY-OWNER-DIRECT-ACCESS",
            "XOMSKY-VIP-CONTEST-WINNER",
            "XOMSKY-GIVEAWAY-OFFLINE",
            "KHOMYAK-OWNER-RETRO",
            "KHOMYAK-GIVEAWAY-TEST"
        ]
        
        for key in formerBackdoorKeys {
            let res = engine.activate(key: key)
            #expect(res == false)
            #expect(engine.isPro == false)
            #expect(engine.activeLicenseKey == nil)
        }
    }
    
    @Test @MainActor
    func testLicenseEnginePolarValidationMockAndAsync() async {
        let engine = LicenseEngine.shared
        let originalMock = engine.testMockOnlineValidationResult
        defer {
            engine.testMockOnlineValidationResult = originalMock
            engine.deactivate()
        }
        
        // Verify polar constants
        #expect(LicenseEngine.polarCheckoutUrl == "https://buy.polar.sh/polar_cl_v5lBa882Ea4dkTo9gvABMVxVbMgRyjkkhUcY43ktCAo")
        #expect(LicenseEngine.polarActivateEndpoint == "https://api.polar.sh/v1/customer-portal/license-keys/activate")
        #expect(LicenseEngine.polarDeactivateEndpoint == "https://api.polar.sh/v1/customer-portal/license-keys/deactivate")
        #expect(LicenseEngine.polarOrganizationId == "fabcbc99-df59-4b60-9485-20a8dddca3c3")
        
        // 1. Unmocked customer key in tests fails cleanly without bypass cheat
        engine.deactivate()
        engine.testMockOnlineValidationResult = nil
        let unmockedResult = engine.activate(key: "XOMSKY-UNMOCKED-CUSTOMER-KEY")
        #expect(unmockedResult == false)
        #expect(engine.isPro == false)
        
        // 2. Mock failure: online validation fails (e.g. invalid customer key on Polar)
        engine.deactivate()
        engine.testMockOnlineValidationResult = false
        let failedResult = engine.activate(key: "XOMSKY-INVALID-CUSTOMER-KEY")
        #expect(failedResult == false)
        #expect(engine.isPro == false)
        
        // 3. Mock success: online validation passes (valid customer key on Polar)
        engine.testMockOnlineValidationResult = true
        let validCustomerKey = "XOMSKY-CUSTOMER-VALID-KEY"
        let successResult = engine.activate(key: validCustomerKey)
        #expect(successResult == true)
        #expect(engine.isPro == true)
        #expect(engine.activeLicenseKey == validCustomerKey)
        
        // 4. Async activation test (Bool and Detailed)
        engine.deactivate()
        engine.testMockOnlineValidationResult = false
        let asyncFail = await engine.activateOnline(key: "XOMSKY-ASYNC-FAIL")
        #expect(asyncFail == false)
        #expect(engine.isPro == false)
        
        let detailedFail = await engine.activateOnlineDetailed(key: "XOMSKY-ASYNC-FAIL")
        #expect(detailedFail != .success)
        
        engine.testMockOnlineValidationResult = true
        let asyncSuccess = await engine.activateOnline(key: "XOMSKY-ASYNC-SUCCESS")
        #expect(asyncSuccess == true)
        #expect(engine.isPro == true)
        #expect(engine.activeLicenseKey == "XOMSKY-ASYNC-SUCCESS")
        
        let detailedSuccess = await engine.activateOnlineDetailed(key: "XOMSKY-ASYNC-SUCCESS")
        #expect(detailedSuccess == .success)
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
        let menu = appDelegate.buildStatusMenu()
        
        // 1. Cyclic signifiers for shared letters ('A') with single-line compactness
        let antigravityItem = menu.items.first(where: { $0.title.hasPrefix("Antigravity") && !$0.title.contains("IDE") })
        let ideItem = menu.items.first(where: { $0.title.contains("Antigravity IDE") })
        #expect(antigravityItem != nil)
        #expect(ideItem != nil)
        
        #expect(antigravityItem?.toolTip?.contains("cycle") == true)
        #expect(antigravityItem?.toolTip?.contains("1 of 2") == true)
        #expect(ideItem?.toolTip?.contains("cycle") == true)
        #expect(ideItem?.toolTip?.contains("2 of 2") == true)
        
        // Single-line compact affordance: inline in title, NO double-height subtitle expansion
        #expect(antigravityItem?.title.contains("1/2 ↻") == true)
        #expect(ideItem?.title.contains("2/2 ↻") == true)
        if #available(macOS 14.4, *) {
            #expect(antigravityItem?.subtitle == nil, "Single-line compact menu items must not use subtitle")
            #expect(ideItem?.subtitle == nil, "Single-line compact menu items must not use subtitle")
        }
        
        // 2. Profile Indentation
        let profileItems = menu.items.filter { item in
            item.indentationLevel == 1
        }
        #expect(!profileItems.isEmpty, "Profile items should have indentationLevel = 1 for Gestalt hierarchy")
        
        // 3. Settings Menu Item with ⌘,
        let settingsItem = menu.items.first(where: { $0.title == "Settings..." })
        #expect(settingsItem != nil)
        #expect(settingsItem?.keyEquivalent == ",")
        #expect(settingsItem?.keyEquivalentModifierMask == [.command])
        #expect(settingsItem?.action != nil)
        
        // 4. Utility section ordering and checkmark hygiene
        let copyItem = menu.items.first(where: { $0.title.hasPrefix("Copy on Select") })
        let refreshItem = menu.items.first(where: { $0.title.contains("Refresh Profiles & Apps") })
        let quitItem = menu.items.first(where: { $0.title.contains("Quit Xomsky") })
        #expect(copyItem != nil)
        #expect(copyItem?.state == .off, "Copy on Select must not use gutter checkmark to prevent left margin collision")
        #expect(copyItem?.title.contains("· On") == true || copyItem?.title.contains("· Off") == true, "Copy on Select must display inline state badge")
        #expect(refreshItem != nil)
        #expect(quitItem != nil)
        
        if let copyIdx = menu.items.firstIndex(where: { $0.title.hasPrefix("Copy on Select") }),
           let manageAppIdx = menu.items.firstIndex(where: { $0.title.contains("Manage Quick Apps") || $0.title == "Change App" }),
           let settingsIdx = menu.items.firstIndex(where: { $0.title == "Settings..." }),
           let refreshIdx = menu.items.firstIndex(where: { $0.title.contains("Refresh Profiles & Apps") }),
           let quitIdx = menu.items.firstIndex(where: { $0.title.contains("Quit Xomsky") }) {
            #expect(copyIdx < manageAppIdx)
            #expect(manageAppIdx < settingsIdx)
            #expect(settingsIdx < refreshIdx)
            #expect(refreshIdx < quitIdx)
        }
        
        // Ensure Pro item (when active) does not carry a conflicting trailing checkmark
        let proItem = menu.items.first(where: { $0.title.contains("Xomsky Pro") })
        #expect(proItem != nil)
        #expect(proItem?.title.hasSuffix("✓") == false, "Xomsky Pro must not carry trailing checkmark to prevent clash with Copy on Select")
        
        // Ensure Manage Quick Apps is not isolated by a redundant preceding separator
        if let changeAppIdx = menu.items.firstIndex(where: { $0.title.contains("Manage Quick Apps") || $0.title == "Change App" }), changeAppIdx > 0 {
            #expect(!menu.items[changeAppIdx - 1].isSeparatorItem, "Manage Quick Apps must not be preceded by a separator creating a 1-item island")
        }
    }
    
    @Test @MainActor
    func testCopyToastWindowProperties() {
        let toast = CopyToastWindow.shared
        #expect(toast.isFloatingPanel == true)
        #expect(toast.isOpaque == false)
        #expect(toast.ignoresMouseEvents == true)
        
        toast.show(at: CGPoint(x: 200, y: 200))
        #expect(CopyToastState.shared.isVisible == true)
        toast.hideImmediate()
        #expect(CopyToastState.shared.isVisible == false)
    }
    
    @Test
    func testXomskyMotionConstants() {
        _ = XomskyMotion.interactiveSnap
        _ = XomskyMotion.magneticGlide
        _ = XomskyMotion.tactileBop
        _ = XomskyMotion.cardMorph
        _ = XomskyMotion.microPress
    }
    
    @Test @MainActor
    func testMascotProceduralIconGenerationAndBlinking() {
        let normalIcon = AppDelegate.makeMascotStatusIcon()
        #expect(normalIcon.size.width == 18)
        #expect(normalIcon.size.height == 18)
        
        let blinkingIcon = AppDelegate.makeMascotStatusIcon(blinkProgress: 1.0)
        #expect(blinkingIcon.size.width == 18)
        
        let gazeLeftIcon = AppDelegate.makeMascotStatusIcon(eyeGazeX: -0.8)
        #expect(gazeLeftIcon.size.width == 18)
        
        let gazeRightIcon = AppDelegate.makeMascotStatusIcon(eyeGazeX: 0.8)
        #expect(gazeRightIcon.size.width == 18)
    }
    
    @Test @MainActor
    func testMascotPeekAndSeparatorBounceProperties() {
        #expect(ChromeSwitcherState.shared.isMascotPeeking == false)
        ChromeSwitcherState.shared.isMascotPeeking = true
        #expect(ChromeSwitcherState.shared.isMascotPeeking == true)
        MinimalHUDWindow.shared.hideImmediate()
        #expect(ChromeSwitcherState.shared.isMascotPeeking == false)
        
        let separatorView = AppDelegate.MascotSeparatorView(icon: AppDelegate.makeMascotStatusIcon())
        #expect(separatorView.intrinsicContentSize.height == 20)
    }
    
    @Test @MainActor
    func testAboutAndCheckForUpdatesMenuItems() {
        #expect(!AppDelegate.appVersion.isEmpty)
        #expect(!AppDelegate.appBuild.isEmpty)
        
        let appDelegate = AppDelegate()
        let menu = appDelegate.buildStatusMenu()
        
        let aboutItem = menu.items.first(where: { $0.title.contains("About Xomsky") })
        #expect(aboutItem != nil, "About Xomsky menu item must exist")
        #expect(aboutItem?.attributedTitle?.string.contains("v\(AppDelegate.appVersion)") == true)
        #expect(aboutItem?.action == #selector(AppDelegate.handleAbout))
        
        let updateItem = menu.items.first(where: { $0.title.contains("Check for Updates") })
        #expect(updateItem != nil, "Check for Updates menu item must exist")
        #expect(updateItem?.action == #selector(AppDelegate.handleCheckForUpdates))
    }
    
    // MARK: - UpdateEngine Tests
    @Test
    func testUpdateEngineDetectsHomebrewViaBundlePath() {
        let bundlePath = "/opt/homebrew/Caskroom/xomsky/1.1.1/Xomsky.app"
        let source = UpdateEngine.detectInstallationSource(bundlePath: bundlePath) { _ in false }
        #expect(source == .homebrew)
    }

    @Test
    func testUpdateEngineDetectsHomebrewViaCaskroomDirectory() {
        let bundlePath = "/Applications/Xomsky.app"
        let source = UpdateEngine.detectInstallationSource(bundlePath: bundlePath) { path in
            path == "/opt/homebrew/Caskroom/xomsky"
        }
        #expect(source == .homebrew)

        let sourceIntel = UpdateEngine.detectInstallationSource(bundlePath: bundlePath) { path in
            path == "/usr/local/Caskroom/xomsky"
        }
        #expect(sourceIntel == .homebrew)
    }

    @Test
    func testUpdateEngineDetectsDirectDownloadWhenNoCaskroom() {
        let bundlePath = "/Applications/Xomsky.app"
        let source = UpdateEngine.detectInstallationSource(bundlePath: bundlePath) { _ in false }
        #expect(source == .directDownload)
    }

    @Test
    func testUpdateEngineDownloadUrlAndCommand() {
        #expect(UpdateEngine.directDmgDownloadUrl.absoluteString == "https://github.com/unacau/xomsky/releases/latest/download/Xomsky.dmg")
        #expect(UpdateEngine.homebrewUpgradeCommand == "brew update && brew upgrade --cask xomsky")
    }

    @Test
    func testRunHomebrewUpgradeInTerminalUsesWorkspaceWithoutTouchingPasteboard() {
        var openedUrl: URL?
        let success = UpdateEngine.runHomebrewUpgradeInTerminal { url in
            openedUrl = url
            return true
        }
        
        #expect(success == true)
        #expect(openedUrl?.pathExtension == "command")
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
        
        Full Changelog: https://github.com/unacau/xomsky/compare/v1.1.4...v1.1.5
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
    @Test
    func testTelemetryBufferRingCapacityAndFIFO() {
        let buffer = TelemetryBuffer.shared
        buffer.clear()
        #expect(buffer.getAll().isEmpty)

        // Append 350 items to verify 300-capacity FIFO truncation
        for i in 1...350 {
            buffer.append(category: "test", level: "INFO", message: "Event #\(i)")
        }

        let events = buffer.getAll()
        #expect(events.count == 300)
        #expect(events.first?.message == "Event #51")
        #expect(events.last?.message == "Event #350")

        let exportText = buffer.exportTimelineText()
        #expect(exportText.contains("Event #51"))
        #expect(exportText.contains("Event #350"))
        #expect(!exportText.contains("Event #1\n") && !exportText.contains("Event #50\n"))
    }

    @Test @MainActor
    func testDiagnosticArchiveCreation() throws {
        TelemetryBuffer.shared.clear()
        TelemetryBuffer.shared.append(category: "engine", level: "INFO", message: "Diagnostic test start")

        let zipURL = try DiagnosticBundleService.createDiagnosticArchive()
        defer { try? FileManager.default.removeItem(at: zipURL) }

        #expect(FileManager.default.fileExists(atPath: zipURL.path))
        #expect(zipURL.lastPathComponent == "xomsky-diagnostic.zip")
        #expect(zipURL.path.contains("Downloads"))

        let attr = try FileManager.default.attributesOfItem(atPath: zipURL.path)
        let size = attr[.size] as? Int64 ?? 0
        #expect(size > 0, "ZIP archive must not be empty")

        let ghURL = DiagnosticBundleService.makeGitHubIssueURL(description: "Test issue")
        #expect(ghURL != nil)
        #expect(ghURL?.host == "github.com")
        #expect(ghURL?.path.contains("unacau/xomsky/issues/new") == true)
        #expect(ghURL?.absoluteString.contains("%5BBug%20Report%5D") == true || ghURL?.absoluteString.contains("[Bug") == true)
    }

    @Test @MainActor
    func testFullDiagnosticReportIncludesSystemSummaryAndTimeline() {
        TelemetryBuffer.shared.clear()
        TelemetryBuffer.shared.append(category: "switcher", level: "INFO", message: "User triggered CapsLock+C")
        TelemetryBuffer.shared.append(category: "copy-on-select", level: "INFO", message: "Selection evaluated")

        let report = DiagnosticBundleService.makeFullDiagnosticReport()
        #expect(report.contains("=== Xomsky System Diagnostic Summary ==="))
        #expect(report.contains("App Version:"))
        #expect(report.contains("macOS Version:"))
        #expect(report.contains("Accessibility Permissions:"))
        #expect(report.contains("License Status:"))
        #expect(report.contains("Copy-on-Select:"))
        #expect(report.contains("=== Event Timeline ==="))
        #expect(report.contains("User triggered CapsLock+C"))
        #expect(report.contains("Selection evaluated"))
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

        let testURL = URL(fileURLWithPath: "/tmp/xomsky-diagnostic.zip")
        let provider = NSItemProvider(object: testURL as NSURL)
        provider.suggestedName = "xomsky-diagnostic.zip"
        #expect(provider.registeredTypeIdentifiers.contains("public.file-url"))
    }

    @Test @MainActor
    func testCopyOnSelectXomskyWindowDetection() {
        let engine = CopyOnSelectEngine()
        _ = engine.isInteractingWithXomskyWindow
        #expect(engine.dragThreshold == 10.0)
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
        
        let calcItem = menuWithC.items.first(where: { $0.title.contains("Calculator") || $0.attributedTitle?.string.contains("Calculator") == true })
        #expect(calcItem != nil)
        let calcTitle = calcItem?.attributedTitle?.string ?? calcItem?.title ?? ""
        #expect(calcTitle.contains("· 2/2 ↻"), "Calculator must display 2/2 cyclic badge")
        
        // 2. Without any app sharing letter 'C'
        UserDefaults.standard.set(["com.apple.Notes", "com.apple.Terminal"], forKey: "SelectedAppBundleIDs")
        let menuWithoutC = appDelegate.buildStatusMenu()
        let soloChromeItem = menuWithoutC.items.first(where: { $0.title.hasPrefix("Chrome") || $0.attributedTitle?.string.hasPrefix("Chrome") == true })
        let soloChromeTitle = soloChromeItem?.attributedTitle?.string ?? soloChromeItem?.title ?? ""
        #expect(!soloChromeTitle.contains("↻"), "Solo Chrome must NOT display cyclic badge when no pinned apps share letter C")
    }

    @Test @MainActor
    func testAppGroupEngineFocusItemSupportsBrowsersAndSystemApps() {
        // Must not crash or fail when focusing browser or system apps
        AppGroupEngine.focusItem(bundleID: "com.google.Chrome")
        AppGroupEngine.focusItem(bundleID: "com.apple.finder")
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
        // 1. Deterministic size invariance: HUD must always be fixed 300pt x 270pt
        #expect(MinimalHUDView.hudWidth == 300)
        #expect(MinimalHUDView.hudHeight == 270)
        
        let dummyIcon = NSImage(size: NSSize(width: 32, height: 32))
        let appItem = AntigravityItem(name: "Telegram", bundleID: "ru.keepcoder.Telegram", path: "/Applications/Telegram.app", icon: dummyIcon, index: 1)
        
        // 2. Channel item view creation and rendering
        let channelItem = AppChannelItemView(item: appItem, isSelected: true, channelIndex: 1)
        #expect(channelItem.isSelected == true)
        #expect(channelItem.channelIndex == 1)
        
        // 3. CRT Chromatic Aberration and Vector Arc components
        let aberrationView = CRTChromaticAberrationIcon(icon: dummyIcon, size: 84)
        #expect(aberrationView.size == 84)
        
        let arcView = CRTVectorArcView()
        #expect(arcView != nil)
        
        let leftArcShape = CRTLeftEdgeArcShape(insetAmount: 1.0)
        let arcPath = leftArcShape.path(in: CGRect(x: 0, y: 0, width: 300, height: 270))
        #expect(!arcPath.isEmpty)
        #expect(arcPath.boundingRect.minX >= 0.5)
        #expect(arcPath.boundingRect.minX <= 25.0)
        
        // 4. CRT scanlines view
        let scanlines = CRTScanlinesView()
        #expect(scanlines != nil)
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
    func testTelemetryBufferPIISanitization() {
        let input = "Switched to Chrome profile 'john.appleseed@company.com' (Profile 1) for user alice.smith+work@gmail.com"
        let sanitized = TelemetryBuffer.sanitizePII(input)
        #expect(!sanitized.contains("john.appleseed@company.com"))
        #expect(!sanitized.contains("alice.smith+work@gmail.com"))
        #expect(sanitized.contains("[REDACTED_EMAIL]"))
    }

    @Test @MainActor
    func testCopyOnSelectSensitiveBundleIDsProtection() {
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.apple.Passwords"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.1password.1password"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.bitwarden.desktop"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.apple.keychainaccess"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.apple.Terminal"))
    }

    @Test @MainActor
    func testCopyOnSelectEnhancedSensitiveBundleIDsProtection() {
        // Modern Terminal Emulators
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.mitchellh.ghostty"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("net.kovidgoyal.kitty"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("org.alacritty"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.github.wez.wezterm"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("dev.warp.Warp-Stable"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.googlecode.iterm2"))
        
        // Password Managers & Vaults
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.dashlane.dashlanephone"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.enpass.Enpass-Desktop"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("com.nordpass.macos"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("org.keepassxc.keepassxc"))
        #expect(CopyOnSelectEngine.sensitiveBundleIDs.contains("org.whispersystems.signal-desktop"))
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
    func testLicenseEngineRejectsTamperedKeychainLicense() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        defer {
            LicenseEngine.testIgnoreReceiptCheckInTests = true
            engine.testOverrideProStatus = originalOverride
            engine.deactivate()
        }
        
        engine.testOverrideProStatus = nil
        // When receipt check is enforced, a raw key without valid receipt is rejected
        LicenseEngine.testIgnoreReceiptCheckInTests = false
        _ = engine.saveKeychainLicense(key: "XOMSKY-PIRATED-KEY-12345")
        engine.deleteKeychainReceipt()
        engine.deleteKeychainActivationId()
        LicenseEngine.storage.removeObject(forKey: "XomskyProReceiptToken")
        LicenseEngine.storage.removeObject(forKey: "XomskyProActivationId")
        LicenseEngine.storage.removeObject(forKey: "XomskyProLicenseKey")
        
        engine.checkLicenseStatus()
        #expect(engine.isPro == false, "Tampered license without cryptographic receipt must be rejected")
    }

    @Test @MainActor
    func testUnifiedLicenseBundleKeychainStorageAndTamperProtection() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        defer {
            LicenseEngine.testIgnoreReceiptCheckInTests = true
            engine.testOverrideProStatus = originalOverride
            engine.deactivate()
        }
        
        engine.testOverrideProStatus = nil
        LicenseEngine.testIgnoreReceiptCheckInTests = false
        
        let testKey = "XOMSKY-BUNDLE-TEST-KEY-1"
        let testAid = "act_bundle_\(UUID().uuidString)"
        let validReceipt = LicenseEngine.computeReceiptToken(key: testKey, activationId: testAid)
        
        // 1. Valid bundle in Keychain enables Pro
        let validBundle = LicenseBundle(key: testKey, activationId: testAid, receipt: validReceipt)
        let saved = engine.saveKeychainBundle(validBundle)
        #expect(saved == true)
        
        engine.checkLicenseStatus()
        #expect(engine.isPro == true)
        #expect(engine.activeLicenseKey == testKey)
        #expect(engine.activeActivationId == testAid)
        
        // 2. Tampered receipt in bundle must be rejected
        let tamperedBundle = LicenseBundle(key: testKey, activationId: testAid, receipt: "bogus_receipt_token")
        _ = engine.saveKeychainBundle(tamperedBundle)
        engine.checkLicenseStatus()
        #expect(engine.isPro == false, "Tampered receipt token in unified bundle must be rejected")
    }

    @Test @MainActor
    func testLegacyKeychainItemsMigrateToUnifiedBundle() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        defer {
            LicenseEngine.testIgnoreReceiptCheckInTests = true
            engine.testOverrideProStatus = originalOverride
            engine.deactivate()
        }
        
        engine.deactivate()
        engine.testOverrideProStatus = nil
        LicenseEngine.testIgnoreReceiptCheckInTests = false
        
        let legacyKey = "XOMSKY-LEGACY-MIGRATION-KEY"
        let legacyAid = "act_legacy_\(UUID().uuidString)"
        let legacyReceipt = LicenseEngine.computeReceiptToken(key: legacyKey, activationId: legacyAid)
        
        // Setup legacy separate items
        _ = engine.saveKeychainLicense(key: legacyKey)
        _ = engine.saveKeychainActivationId(id: legacyAid)
        _ = engine.saveKeychainReceipt(receipt: legacyReceipt)
        engine.deleteKeychainBundle()
        
        // Verify legacy items are present initially
        #expect(engine.readKeychainLicense() == legacyKey)
        #expect(engine.readKeychainBundle() == nil)
        
        // Run checkLicenseStatus - should migrate legacy items to unified bundle
        engine.checkLicenseStatus()
        #expect(engine.isPro == true)
        #expect(engine.activeLicenseKey == legacyKey)
        #expect(engine.activeActivationId == legacyAid)
        
        // Verify migration result: bundle created, legacy items purged
        let migratedBundle = engine.readKeychainBundle()
        #expect(migratedBundle != nil)
        #expect(migratedBundle?.key == legacyKey)
        #expect(migratedBundle?.activationId == legacyAid)
        #expect(migratedBundle?.receipt == legacyReceipt)
        
        #expect(engine.readKeychainLicense() == nil)
        #expect(engine.readKeychainActivationId() == nil)
        #expect(engine.readKeychainReceipt() == nil)
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
        let menu = appDelegate.buildStatusMenu()
        
        let sItems = menu.items.filter { $0.keyEquivalent == "s" }
        #expect(sItems.count == 2, "Both S-apps must appear in menu with key 's'")
        
        let firstS = sItems[0]
        let secondS = sItems[1]
        #expect(firstS.attributedTitle?.string.contains("1/2 ↻") == true || firstS.title.contains("1/2 ↻") || firstS.toolTip?.contains("1 of 2") == true)
        #expect(secondS.attributedTitle?.string.contains("2/2 ↻") == true || secondS.title.contains("2/2 ↻") || secondS.toolTip?.contains("2 of 2") == true)
        
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
        
        // Section headers must strictly contain ONLY Browsers & Profiles and Quick Apps (Caps-Lock)
        #expect(headerTitles.contains(where: { $0.contains("Browsers & Profiles") }))
        #expect(headerTitles.contains(where: { $0 == "Quick Apps (Caps-Lock)" }))
        
        // Strictly forbidden legacy category header titles
        let forbiddenHeaders = ["Core Toolset", "Toolkit", "Toolset Shortcuts", "Quick Shortcuts"]
        for forbidden in forbiddenHeaders {
            #expect(!headerTitles.contains(where: { $0.contains(forbidden) }), "Header must not contain '\(forbidden)'")
        }
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


