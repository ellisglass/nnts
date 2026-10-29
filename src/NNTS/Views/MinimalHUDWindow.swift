import Cocoa
import AppKit
import SwiftUI

// MARK: - Chrome App Icon Helper
public enum ChromeAppIconHelper {
    public static func chromeIcon() -> NSImage {
        let chromeAppPath = "/Applications/Google Chrome.app"
        if FileManager.default.fileExists(atPath: chromeAppPath) {
            return NSWorkspace.shared.icon(forFile: chromeAppPath)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let icon = NSImage(named: NSImage.applicationIconName) {
            return icon
        }
        return NSWorkspace.shared.icon(for: .application)
    }
}

// MARK: - Switcher Mode
public enum SwitcherMode: Equatable, Sendable {
    case chrome
    case antigravity
    case terminal
    case notes
    case ide
}

// MARK: - Switcher HUD State
@MainActor
public final class ChromeSwitcherState: ObservableObject {
    public static let shared = ChromeSwitcherState()
    
    @Published public var mode: SwitcherMode = .chrome
    @Published public var profiles: [ChromeProfile] = []
    @Published public var antigravityItems: [AntigravityItem] = []
    @Published public var activeProfileDir: String? = nil
    @Published public var selectedIndex: Int = 0 {
        didSet {
            if mode == .chrome {
                selectedProfileIndex = selectedIndex
            }
        }
    }
    @Published public var selectedProfileIndex: Int = 0
    @Published public var isVisible: Bool = false
    
    public var selectedProfile: ChromeProfile? {
        guard !profiles.isEmpty else { return nil }
        if mode == .chrome {
            let idx = max(0, min(selectedIndex, profiles.count - 1))
            return profiles[idx]
        }
        let idx = max(0, min(selectedProfileIndex, profiles.count - 1))
        return profiles[idx]
    }
    
    public var selectedAppItem: AntigravityItem? {
        guard !antigravityItems.isEmpty, selectedIndex >= 0, selectedIndex < antigravityItems.count else {
            return antigravityItems.first
        }
        return antigravityItems[selectedIndex]
    }
    
    public var selectedAntigravityItem: AntigravityItem? {
        selectedAppItem
    }
    
    public var hasBrothers: Bool {
        if mode == .chrome {
            return profiles.count > 1
        } else {
            return antigravityItems.count > 1
        }
    }
    
    public func selectNext() {
        if mode == .chrome {
            guard !profiles.isEmpty else { return }
            withAnimation(NNTSMotion.magneticGlide) {
                selectedIndex = (selectedIndex + 1) % profiles.count
                selectedProfileIndex = selectedIndex
            }
            return
        }
        
        guard !antigravityItems.isEmpty else { return }
        withAnimation(NNTSMotion.magneticGlide) {
            selectedIndex = (selectedIndex + 1) % antigravityItems.count
        }
    }
    
    public func selectPrevious() {
        if mode == .chrome {
            guard !profiles.isEmpty else { return }
            withAnimation(NNTSMotion.magneticGlide) {
                selectedIndex = (selectedIndex - 1 + profiles.count) % profiles.count
                selectedProfileIndex = selectedIndex
            }
            return
        }
        
        guard !antigravityItems.isEmpty else { return }
        withAnimation(NNTSMotion.magneticGlide) {
            selectedIndex = (selectedIndex - 1 + antigravityItems.count) % antigravityItems.count
        }
    }
    
    public func selectNextCard() {
        selectNext()
    }
    
    public func selectPreviousCard() {
        selectPrevious()
    }
    
    public func selectIndex(_ index: Int) {
        if mode == .chrome {
            guard !profiles.isEmpty else { return }
            let clamped = max(0, min(index, profiles.count - 1))
            withAnimation(NNTSMotion.magneticGlide) {
                selectedIndex = clamped
                selectedProfileIndex = clamped
            }
        } else {
            guard !antigravityItems.isEmpty else { return }
            let clamped = max(0, min(index, antigravityItems.count - 1))
            withAnimation(NNTSMotion.magneticGlide) {
                selectedIndex = clamped
            }
        }
    }
    
    public func selectChromeProfile(index: Int) {
        guard !profiles.isEmpty else { return }
        let clamped = max(0, min(index, profiles.count - 1))
        if let browserIdx = antigravityItems.firstIndex(where: { item in
            item.bundleID == ChromeProfileEngine.shared.browserBundleID ||
            ChromeProfileEngine.supportedBrowsers.contains(where: { b in b.bundleID == item.bundleID })
        }) {
            withAnimation(NNTSMotion.magneticGlide) {
                selectedIndex = browserIdx
                selectedProfileIndex = clamped
            }
        } else {
            withAnimation(NNTSMotion.magneticGlide) {
                mode = .chrome
                selectedIndex = clamped
                selectedProfileIndex = clamped
            }
        }
    }
}





// MARK: - Modern Switcher HUD View (Retro TV Channel Switcher)
public struct MinimalHUDView: View {
    @ObservedObject var state = ChromeSwitcherState.shared
    @Namespace private var selectionNamespace
    
    /// Deterministic size-invariant screen frame matching 2026 Master Design
    public static let hudWidth: CGFloat = NNTSGeometry.hudWidth
    public static let hudHeight: CGFloat = NNTSGeometry.hudHeight
    
    public init() {}
    
    private func isBrowser(_ item: AntigravityItem) -> Bool {
        let browserBundleID = ChromeProfileEngine.shared.browserBundleID
        if item.bundleID == browserBundleID { return true }
        return ChromeProfileEngine.supportedBrowsers.contains(where: { b in b.bundleID == item.bundleID })
    }
    
    private var activeIcon: NSImage {
        if state.mode == .chrome {
            return ChromeProfileEngine.shared.activeBrowserIcon
        }
        if let item = state.selectedAppItem {
            return item.icon
        }
        return NSWorkspace.shared.icon(for: .application)
    }
    
    private var activeName: String {
        if state.mode == .chrome {
            return ChromeProfileEngine.shared.activeBrowserName
        }
        if let item = state.selectedAppItem {
            return item.name
        }
        return "Application"
    }
    
    private var activeProfile: ChromeProfile? {
        if state.mode == .chrome {
            return state.selectedProfile
        }
        if let item = state.selectedAppItem, isBrowser(item) {
            return state.selectedProfile
        }
        return nil
    }
    
    private var isCurrentBrowser: Bool {
        if state.mode == .chrome { return true }
        guard let item = state.selectedAppItem else { return false }
        return isBrowser(item)
    }
    
    private var hasMultipleApps: Bool {
        state.antigravityItems.count > 1
    }
    
    private var isProfileMode: Bool {
        state.mode == .chrome || (isCurrentBrowser && !state.profiles.isEmpty)
    }
    
    private var cycleIndicator: String? {
        guard state.antigravityItems.count > 1 else { return nil }
        let current = state.selectedIndex + 1
        let total = state.antigravityItems.count
        return "\(current)/\(total) ↻"
    }
    
    private var shortcutChar: Character {
        if let item = state.selectedAppItem {
            return item.name.first(where: { $0.isLetter }) ?? "C"
        }
        return "C"
    }
    
    public var body: some View {
        Group {
            if isProfileMode {
                // Profile Switcher View (Focused on large avatars and prominent profile identity)
                let activeDir = state.activeProfileDir ?? ChromeProfileEngine.shared.getActiveProfileDir()
                let count = state.profiles.count
                let useCompact = count > 6
                let spacing: CGFloat = useCompact ? 5 : (count <= 4 ? 14 : 8)
                
                VStack(spacing: 0) {
                    // 1. Browser context header
                    HStack(spacing: 7) {
                        Image(nsImage: activeIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 18, height: 18)
                            .shadow(color: Color.black.opacity(0.30), radius: 2, y: 1)
                        
                        Text(activeName)
                            .font(NNTSFont.display(size: 13))
                            .foregroundColor(NNTSColors.warmCream.opacity(0.70))
                            .shadow(color: Color.black.opacity(0.40), radius: 2, y: 1)
                        
                        if hasMultipleApps, let cycle = cycleIndicator {
                            Text(cycle)
                                .font(NNTSFont.display(size: 10.5))
                                .foregroundColor(NNTSColors.cadmiumYellow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.12))
                                )
                        }
                    }
                    .padding(.top, 20)
                    
                    Spacer(minLength: 8)
                    
                    // 2. Large Profile Avatars (Big, vibrant icons front and center)
                    HStack(spacing: spacing) {
                        ForEach(Array(state.profiles.enumerated()), id: \.element.id) { idx, profile in
                            ProfileAvatarView(
                                profile: profile,
                                isSelected: idx == state.selectedProfileIndex,
                                slotIndex: idx + 1,
                                isLarge: !useCompact && count <= 4,
                                isCompact: useCompact,
                                showBadge: true,
                                isCurrentActive: profile.dir == activeDir,
                                namespace: selectionNamespace
                            )
                        }
                    }
                    .id("profiles_strip_\(count)")
                    
                    Spacer(minLength: 8)
                    
                    // 3. Prominent Selected Profile Name & Contextual Subtitle
                    VStack(spacing: 4) {
                        if let prof = activeProfile {
                            Text(prof.effectiveName)
                                .font(NNTSFont.display(size: 24))
                                .foregroundColor(NNTSColors.warmCream)
                                .shadow(color: Color.black.opacity(0.60), radius: 6, y: 2)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 340)
                                .id("profile_name_\(prof.effectiveName)")
                                .transition(.identity)
                            
                            HStack(spacing: 5) {
                                if prof.dir == activeDir {
                                    Circle()
                                        .fill(NNTSColors.appleEmerald)
                                        .frame(width: 5, height: 5)
                                        .shadow(color: NNTSColors.appleEmerald.opacity(0.8), radius: 2)
                                    Text("Active Now • caps lock + \(prof.index)")
                                        .font(NNTSFont.display(size: 11.5))
                                        .foregroundColor(NNTSColors.appleEmerald.opacity(0.90))
                                } else {
                                    Text("caps lock + \(prof.index) • release to switch")
                                        .font(NNTSFont.display(size: 11.5))
                                        .foregroundColor(NNTSColors.warmCream.opacity(0.50))
                                }
                            }
                        } else {
                            Text(activeName)
                                .font(NNTSFont.display(size: 24))
                                .foregroundColor(NNTSColors.warmCream)
                                .shadow(color: Color.black.opacity(0.60), radius: 6, y: 2)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer(minLength: 6)
                    
                    // 4. Subtle Bauhaus Navigation Hints Footer
                    HStack(spacing: 12) {
                        if count > 1 {
                            HStack(spacing: 4) {
                                Text("1–\(count)")
                                    .font(NNTSFont.slotDigit(size: 10))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.white.opacity(0.10))
                                    )
                                Text("jump")
                                    .font(NNTSFont.display(size: 10))
                            }
                            
                            Text("•")
                                .opacity(0.3)
                            
                            HStack(spacing: 4) {
                                Text("⇥ / →")
                                    .font(NNTSFont.slotDigit(size: 10))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.white.opacity(0.10))
                                    )
                                Text("cycle")
                                    .font(NNTSFont.display(size: 10))
                            }
                            
                            Text("•")
                                .opacity(0.3)
                        }
                        
                        HStack(spacing: 4) {
                            Text("esc")
                                .font(NNTSFont.slotDigit(size: 10))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.10))
                                )
                            Text("cancel")
                                .font(NNTSFont.display(size: 10))
                        }
                    }
                    .foregroundColor(NNTSColors.warmCream.opacity(0.40))
                    .padding(.bottom, 16)
                }
                .transition(.identity)
            } else {
                // Application Switcher View
                VStack(spacing: 0) {
                    // 1. Top Apps Row (Clear indicator of apps assigned to the same key)
                    if hasMultipleApps {
                        HStack(spacing: 14) {
                            ForEach(Array(state.antigravityItems.enumerated()), id: \.element.id) { idx, item in
                                let isCurrent = idx == state.selectedIndex
                                Image(nsImage: item.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: isCurrent ? 32 : 24, height: isCurrent ? 32 : 24)
                                    .opacity(isCurrent ? 1.0 : 0.45)
                                    .shadow(color: Color.black.opacity(isCurrent ? 0.30 : 0), radius: 3, y: 1.5)
                                    .background(
                                        isCurrent ?
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color.white.opacity(0.24))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.0)
                                                )
                                                .frame(width: 42, height: 42)
                                            : nil
                                    )
                            }
                        }
                        .padding(.top, 18)
                        .transition(.identity)
                    } else {
                        Color.clear.frame(height: 18)
                    }
                    
                    Spacer()
                    
                    // 2. Center Hero Display (Large App Icon + Zero-Overlap Space Grotesk Title)
                    VStack(spacing: 8) {
                        Image(nsImage: activeIcon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 96, height: 96)
                            .id("hero_icon_\(activeName)")
                            .transition(.identity)
                            .shadow(color: Color.black.opacity(0.35), radius: 14, x: 0, y: 7)
                        
                        Text(activeName)
                            .font(NNTSFont.display(size: 22))
                            .foregroundColor(NNTSColors.warmCream)
                            .shadow(color: Color.black.opacity(0.45), radius: 4, y: 2)
                            .lineLimit(1)
                            .id("hero_title_\(activeName)")
                            .transition(.identity)
                        
                        if let cycle = cycleIndicator {
                            Text(cycle)
                                .font(NNTSFont.display(size: 11.5))
                                .foregroundColor(NNTSColors.warmCream.opacity(0.45))
                        }
                    }
                    
                    Spacer()
                    
                    Color.clear.frame(height: 18)
                }
                .transition(.identity)
            }
        }
        .animation(nil, value: isProfileMode)
        .transition(.identity)
        .frame(width: Self.hudWidth, height: Self.hudHeight)
        .background(
            MacNativeLiquidGlassBackground(cornerRadius: NNTSGeometry.hudCornerRadius, material: .popover)
        )
        .scaleEffect(state.isVisible ? 1.0 : 0.95)
        .opacity(state.isVisible ? 1.0 : 0.0)
        .animation(nil, value: state.isVisible)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Minimal HUD Window
@MainActor
public final class MinimalHUDWindow: NSPanel {

    public static let shared = MinimalHUDWindow()
    
    private let hostingView: NSHostingView<MinimalHUDView>
    
    public init() {
        let hosting = NSHostingView(rootView: MinimalHUDView())
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        self.hostingView = hosting
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 380),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.contentView = hosting
    }
    
    public func show(profiles: [ChromeProfile], selectedIndex: Int) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            ChromeSwitcherState.shared.mode = .chrome
            ChromeSwitcherState.shared.profiles = profiles
            ChromeSwitcherState.shared.antigravityItems = []
            ChromeSwitcherState.shared.activeProfileDir = ChromeProfileEngine.shared.getActiveProfileDir()
            let validIndex = profiles.isEmpty ? 0 : max(0, min(selectedIndex, profiles.count - 1))
            ChromeSwitcherState.shared.selectedIndex = validIndex
            ChromeSwitcherState.shared.selectedProfileIndex = validIndex
            ChromeSwitcherState.shared.isVisible = true
        }
        
        AppDelegate.shared?.statusItem?.menu?.cancelTracking()
        reposition()
        self.alphaValue = 1.0
        self.orderFrontRegardless()
        triggerSensoryFeedback()
    }
    
    public func showAntigravity(items: [AntigravityItem], selectedIndex: Int) {
        showAppGroup(mode: .antigravity, items: items, selectedIndex: selectedIndex)
    }
    
    public func showAppGroup(mode: SwitcherMode, items: [AntigravityItem], selectedIndex: Int, profileIndex: Int = 0) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            ChromeSwitcherState.shared.mode = mode
            ChromeSwitcherState.shared.antigravityItems = items
            
            let profileEngine = ChromeProfileEngine.shared
            let containsBrowser = items.contains(where: { item in
                item.bundleID == profileEngine.browserBundleID ||
                ChromeProfileEngine.supportedBrowsers.contains(where: { b in b.bundleID == item.bundleID })
            })
            if containsBrowser {
                ChromeSwitcherState.shared.profiles = profileEngine.selectedProfiles
                ChromeSwitcherState.shared.activeProfileDir = profileEngine.getActiveProfileDir()
            } else {
                ChromeSwitcherState.shared.profiles = []
                ChromeSwitcherState.shared.activeProfileDir = nil
            }
            
            let validIndex = items.isEmpty ? 0 : max(0, min(selectedIndex, items.count - 1))
            let profCount = ChromeSwitcherState.shared.profiles.count
            let validProfIndex = profCount > 0 ? max(0, min(profileIndex, profCount - 1)) : 0
            
            ChromeSwitcherState.shared.selectedIndex = validIndex
            ChromeSwitcherState.shared.selectedProfileIndex = validProfIndex
            ChromeSwitcherState.shared.isVisible = true
        }
        
        AppDelegate.shared?.statusItem?.menu?.cancelTracking()
        reposition()
        self.alphaValue = 1.0
        self.orderFrontRegardless()
        triggerSensoryFeedback()
    }
    
    private func currentScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
            ?? NSScreen()
    }
    
    private func reposition() {
        let screen = currentScreen()
        let screenRect = screen.frame
        let windowWidth: CGFloat = 880
        let windowHeight: CGFloat = 380
        let x = screenRect.midX - (windowWidth / 2)
        let y = screenRect.midY - (windowHeight / 2)
        let targetFrame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
        if self.frame != targetFrame {
            self.setFrame(targetFrame, display: true)
            self.invalidateShadow()
        }
    }
    
    private func triggerSensoryFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .default
        )
        
        let announcementText: String
        if ChromeSwitcherState.shared.mode == .chrome {
            let prof = ChromeSwitcherState.shared.selectedProfile?.effectiveName ?? "Profile"
            announcementText = "\(ChromeProfileEngine.shared.activeBrowserName), \(prof)"
        } else if let app = ChromeSwitcherState.shared.selectedAppItem {
            let profileEngine = ChromeProfileEngine.shared
            let isBrowser = app.bundleID == profileEngine.browserBundleID ||
                            ChromeProfileEngine.supportedBrowsers.contains(where: { $0.bundleID == app.bundleID })
            if isBrowser, let prof = ChromeSwitcherState.shared.selectedProfile {
                announcementText = "\(app.name), \(prof.effectiveName)"
            } else {
                announcementText = app.name
            }
        } else {
            announcementText = "Quick Switcher"
        }
        
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: announcementText]
        )
    }
    
    public func updateSelection(to index: Int) {
        ChromeSwitcherState.shared.selectIndex(index)
        triggerSensoryFeedback()
    }
    
    public func selectChromeProfile(index: Int) {
        ChromeSwitcherState.shared.selectChromeProfile(index: index)
        triggerSensoryFeedback()
    }
    
    public func selectNext() {
        ChromeSwitcherState.shared.selectNext()
        triggerSensoryFeedback()
    }
    
    public func selectPrevious() {
        ChromeSwitcherState.shared.selectPrevious()
        triggerSensoryFeedback()
    }
    
    public func selectNextCard() {
        ChromeSwitcherState.shared.selectNextCard()
        triggerSensoryFeedback()
    }
    
    public func selectPreviousCard() {
        ChromeSwitcherState.shared.selectPreviousCard()
        triggerSensoryFeedback()
    }
    
    public func hideImmediate() {
        ChromeSwitcherState.shared.isVisible = false
        self.orderOut(nil)
        self.alphaValue = 1.0
    }

}

