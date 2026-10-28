import Foundation
import Testing
import AppKit
@testable import NNTS

extension ChromeQuickAccessUnitTests {
    @Test @MainActor
    func testMinimalHUDWindowIsPanel() {
        let window = MinimalHUDWindow.shared
        #expect(window.isFloatingPanel == true)
        #expect(window.level == .floating)
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
        
        _ = CRTVectorArcView()
        
        let leftArcShape = CRTLeftEdgeArcShape(insetAmount: 1.0)
        let arcPath = leftArcShape.path(in: CGRect(x: 0, y: 0, width: 300, height: 270))
        #expect(!arcPath.isEmpty)
        #expect(arcPath.boundingRect.minX >= 0.5)
        #expect(arcPath.boundingRect.minX <= 25.0)
        
        // 4. CRT scanlines view
        _ = CRTScanlinesView()
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
}
