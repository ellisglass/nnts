import Cocoa
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import os

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static var shared: AppDelegate?
    
    private var statusItem: NSStatusItem?
    private let logger = Logger(subsystem: "com.almosteleven.nnts", category: "app")
    private var accessibilityPollTimer: Timer?
    private var appSwitchObserver: Any?
    private var mascotBlinkTimer: Timer?
    private var mascotGazeResetTask: Task<Void, Never>?
    
    public override init() {
        super.init()
        AppDelegate.shared = self
    }
    
    public static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
    }
    
    public static var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "11"
    }
    
    public func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Starting NNTS...")
        
        // 0. Migrate any legacy phantom pinned apps from older versions
        AppGroupEngine.migrateLegacyPinnedAppsIfNeeded()
        ChromeProfileEngine.shared.restoreSecurityScopedFolderAccessIfNeeded()
        
        // 1. Setup Menu Bar Status Item
        setupStatusItem()
        
        // 2. Wire Engine Actions
        setupEngineCallbacks()
        
        // 3. Check Accessibility & Start Services
        if AXIsProcessTrusted() {
            startServices()
        } else {
            logger.warning("Accessibility permission missing on launch. Prompting user and beginning background polling...")
            promptForAccessibilityPermissions()
            startAccessibilityPolling()
        }
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        logger.info("Terminating NNTS: cleaning up event taps and restoring HID mapping.")
        stopMascotBlinkTimer()
        stopAccessibilityPolling()
        CapsLockEngine.shared.stop()
        CopyOnSelectEngine.shared.stop()
    }
    
    public func startServices() {
        if !CapsLockEngine.shared.isStarted {
            CapsLockEngine.shared.start()
        }
        if CopyOnSelectEngine.shared.isEnabled && !CopyOnSelectEngine.shared.isStarted {
            CopyOnSelectEngine.shared.start()
        }
        AppGroupEngine.startGlobalAppSwitchObserver()
        updateDynamicShortcuts()
        updateMenu()
    }
    
    private func startAccessibilityPolling() {
        guard accessibilityPollTimer == nil else { return }
        
        // Polling timer: check every 1.0s
        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    timer.invalidate()
                    return
                }
                if AXIsProcessTrusted() {
                    self.logger.info("Accessibility permission granted via polling! Initializing services.")
                    self.stopAccessibilityPolling()
                    self.startServices()
                    ChromeProfileEngine.shared.refreshProfiles()
                    AntigravityEngine.shared.refreshItems()
                    for engine in AppGroupEngine.allEngines {
                        engine.refreshItems()
                    }
                }
            }
        }
        
        // Also listen for app activation events (e.g. user toggles setting and switches back)
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if AXIsProcessTrusted() && !CapsLockEngine.shared.isStarted {
                    self.logger.info("Accessibility permission granted via app switch! Initializing services.")
                    self.stopAccessibilityPolling()
                    self.startServices()
                    ChromeProfileEngine.shared.refreshProfiles()
                    AntigravityEngine.shared.refreshItems()
                    for engine in AppGroupEngine.allEngines {
                        engine.refreshItems()
                    }
                }
            }
        }
    }
    
    private func stopAccessibilityPolling() {
        accessibilityPollTimer?.invalidate()
        accessibilityPollTimer = nil
        if let observer = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            appSwitchObserver = nil
        }
    }
    
    private enum ActiveSwitcherMode: Equatable {
        case none
        case chrome
        case appLetter(Character)
    }
    
    private var isCyclingHUDActive = false
    private var activeMode: ActiveSwitcherMode = .none
    
    private func handleAppLetterTrigger(char: Character, items: [AntigravityItem]) {
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
            
            let frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            initialIdx = AppGroupEngine.prioritizedItemIndex(for: items, letter: char, frontmostBundleID: frontBundleID)
            
            MinimalHUDWindow.shared.showAppGroup(mode: .antigravity, items: items, selectedIndex: initialIdx, profileIndex: initialProfIdx)
        } else {
            MinimalHUDWindow.shared.selectNext()
        }
    }
    
    public var onPromptForMissingApp: ((String) -> Void)? = nil
    
    private func promptForMissingApp(bundleID: String) {
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
    
    private func focusApp(bundleID: String) {
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
    
    private func handleChromeTrigger() {
        let profileEngine = ChromeProfileEngine.shared
        logger.info("Caps-Lock + C triggered.")
        TelemetryBuffer.shared.append(category: "switcher", level: "INFO", message: "Caps-Lock + C triggered.")
        
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
    
    private func setupEngineCallbacks() {
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
                        profileEngine.focusProfile(dir: target.dir)
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
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        
        let icon = AppDelegate.makeStatusIcon()
        button.image = icon
        button.imagePosition = .imageOnly
        button.toolTip = "NNTS — App & Profile Switcher"
        
        startMascotBlinkTimer()
        updateMenu()
    }
    
    // MARK: - Mascot Animation Engine
    public func startMascotBlinkTimer() {
        scheduleNextBlink()
    }
    
    public func stopMascotBlinkTimer() {
        mascotBlinkTimer?.invalidate()
        mascotBlinkTimer = nil
        mascotGazeResetTask?.cancel()
        mascotGazeResetTask = nil
    }
    
    private func scheduleNextBlink() {
        mascotBlinkTimer?.invalidate()
        let interval = Double.random(in: 7.0...12.0)
        mascotBlinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.performMascotBlink()
            }
        }
    }
    
    public func performMascotBlink() {
        guard let button = self.statusItem?.button else { return }
        button.image = AppDelegate.makeStatusIcon(pressed: true)
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard let self = self else { return }
            self.statusItem?.button?.image = AppDelegate.makeStatusIcon(pressed: false)
            self.scheduleNextBlink()
        }
    }
    
    public func triggerMascotGaze(offset: CGFloat) {
        mascotGazeResetTask?.cancel()
        guard let button = self.statusItem?.button else { return }
        button.image = AppDelegate.makeStatusIcon(pressed: true)
        
        mascotGazeResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self = self else { return }
            self.statusItem?.button?.image = AppDelegate.makeStatusIcon(pressed: false)
        }
    }
    
    public func updateStatusIcon() {
        guard let button = self.statusItem?.button else { return }
        button.image = AppDelegate.makeStatusIcon()
    }
    
    // MARK: - NNTS Status Bar Icon
    public static func makeStatusIcon(pressed: Bool = false) -> NSImage {
        let size = NSSize(width: 29, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            
            let dy: CGFloat = pressed ? -0.8 : 0.0
            let keyRect = CGRect(x: 1.25, y: 1.25 + dy, width: 26.5, height: 15.5)
            let path = CGPath(roundedRect: keyRect, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
            cg.addPath(path)
            cg.setLineWidth(1.25)
            cg.setStrokeColor(NSColor.black.cgColor)
            cg.strokePath()
            
            let text = "NNTS" as NSString
            let font = NSFont.systemFont(ofSize: 7.2, weight: .black)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let strSize = text.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (29 - strSize.width) / 2.0,
                y: (18 - strSize.height) / 2.0 + dy - 0.5,
                width: strSize.width,
                height: strSize.height
            )
            text.draw(in: textRect, withAttributes: attrs)
            return true
        }
        image.isTemplate = true
        return image
    }
    
    public static func makeStatusIcon(
        eyeGazeX: CGFloat = 0.0,
        eyeGazeY: CGFloat = 0.0,
        blinkProgress: CGFloat = 0.0
    ) -> NSImage {
        return makeStatusIcon(pressed: blinkProgress >= 0.5 || abs(eyeGazeX) > 0.1)
    }
    
    public static func makeNNTSKeycapIcon(pressed: Bool = false) -> NSImage {
        return makeStatusIcon(pressed: pressed)
    }
    
    public static func makeMascotStatusIcon(
        eyeGazeX: CGFloat = 0.0,
        eyeGazeY: CGFloat = 0.0,
        blinkProgress: CGFloat = 0.0
    ) -> NSImage {
        return makeStatusIcon(pressed: blinkProgress >= 0.5 || abs(eyeGazeX) > 0.1)
    }
    
    public func updateMenu() {
        let menu = buildStatusMenu()
        statusItem?.menu = menu
    }
    
    // MARK: - Mascot Separator View
    @MainActor
    public final class MascotSeparatorView: NSView {
        private let icon: NSImage
        private var bounceOffset: CGFloat = 0.0
        
        public init(icon: NSImage) {
            self.icon = icon
            super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 20))
            self.autoresizingMask = [.width]
            self.setAccessibilityElement(false)
        }
        
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public override var intrinsicContentSize: NSSize {
            return NSSize(width: NSView.noIntrinsicMetric, height: 20)
        }
        
        public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            return false
        }
        
        public override var acceptsFirstResponder: Bool {
            return false
        }
        
        public override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            self.bounceOffset = -3.5
            self.needsDisplay = true
            
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 25_000_000)
                guard let self = self else { return }
                self.bounceOffset = 1.0
                self.needsDisplay = true
                
                try? await Task.sleep(nanoseconds: 50_000_000)
                self.bounceOffset = 0.0
                self.needsDisplay = true
            }
        }
        
        public override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            
            let bounds = self.bounds
            let midY = bounds.midY
            let midX = bounds.midX
            let iconSize: CGFloat = 16
            let iconRect = NSRect(x: midX - iconSize / 2.0, y: midY - iconSize / 2.0 + bounceOffset, width: iconSize, height: iconSize)
            
            let margin: CGFloat = 14
            let spacing: CGFloat = 8
            
            // Accessible system-adaptive separator lines flanking the mascot icon (WCAG 1.4.11 compliant)
            let leftLineRect = NSRect(x: margin, y: midY - 0.5, width: max(0, iconRect.minX - spacing - margin), height: 1.0)
            if leftLineRect.width > 0 {
                NSColor.separatorColor.set()
                NSBezierPath.fill(leftLineRect)
            }
            
            let rightLineStart = iconRect.maxX + spacing
            let rightLineWidth = max(0, bounds.maxX - margin - rightLineStart)
            let rightLineRect = NSRect(x: rightLineStart, y: midY - 0.5, width: rightLineWidth, height: 1.0)
            if rightLineRect.width > 0 {
                NSColor.separatorColor.set()
                NSBezierPath.fill(rightLineRect)
            }
            
            // Center: Draw NNTS Mascot
            icon.draw(in: iconRect)
        }
    }
    
    public typealias HamsterSeparatorView = MascotSeparatorView
    
    private func makeMascotSeparatorItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.title = ""
        item.isEnabled = false
        item.view = MascotSeparatorView(icon: AppDelegate.makeMascotStatusIcon())
        return item
    }
    
    private func makeHamsterSeparatorItem() -> NSMenuItem {
        return makeMascotSeparatorItem()
    }
    
    private func makeAlignedMenuItem(
        title: String,
        keyEquivalent: String = "",
        modifierMask: NSEvent.ModifierFlags = [],
        isHeader: Bool = false,
        icon: NSImage? = nil,
        accessibilityLabel: String? = nil,
        accessibilityHelp: String? = nil,
        action: Selector? = nil,
        target: AnyObject? = nil,
        representedObject: Any? = nil
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = modifierMask
        item.target = target
        item.representedObject = representedObject
        
        if isHeader {
            let attr = NSMutableAttributedString(string: title)
            attr.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: 13), range: NSRange(location: 0, length: (title as NSString).length))
            item.attributedTitle = attr
        }
        
        if let icon = icon {
            let small = NSImage(size: NSSize(width: 18, height: 18))
            small.lockFocus()
            icon.draw(in: NSRect(x: 0, y: 0, width: 18, height: 18))
            small.unlockFocus()
            if icon.isTemplate {
                small.isTemplate = true
            }
            item.image = small
            if #available(macOS 27.0, *) {
                item.preferredImageVisibility = .visible
            }
        }
        
        if let aLabel = accessibilityLabel {
            item.setAccessibilityLabel(aLabel)
        }
        if let aHelp = accessibilityHelp {
            item.setAccessibilityHelp(aHelp)
        }
        
        return item
    }
    
    @discardableResult
    public func buildStatusMenu() -> NSMenu {
        updateDynamicShortcuts()
        let menu = NSMenu()
        
        let profileEngine = ChromeProfileEngine.shared
        let selectedList = profileEngine.selectedProfiles
        
        let rawPinned = AppGroupEngine.pinnedAppItems()
        
        // Group items so cyclic siblings (apps sharing the same shortcut letter)
        // are placed directly adjacent to each other for clear Gestalt proximity.
        func groupCyclicSiblings(_ items: [AntigravityItem]) -> [AntigravityItem] {
            var letterGroups: [Character: [AntigravityItem]] = [:]
            var orderedLetters: [Character] = []
            for item in items {
                let char = Character((item.name.first(where: { $0.isLetter }) ?? "A").uppercased())
                if letterGroups[char] == nil {
                    orderedLetters.append(char)
                }
                letterGroups[char, default: []].append(item)
            }
            return orderedLetters.flatMap { letterGroups[$0] ?? [] }
        }
        
        let allPinned = groupCyclicSiblings(rawPinned)
        
        // Track letter frequency to display cyclic signifiers for shared letters
        var letterCounts: [Character: Int] = [:]
        for item in allPinned {
            let char = Character((item.name.first(where: { $0.isLetter }) ?? "A").uppercased())
            letterCounts[char, default: 0] += 1
        }
        
        let browserChar = profileEngine.primaryShortcutChar
        let browserCharStr = String(browserChar).lowercased()
        let hasBrowserLetterSiblings = (letterCounts[browserChar] ?? 0) > 0
        if hasBrowserLetterSiblings {
            letterCounts[browserChar, default: 0] += 1
        }
        
        var letterSeenIndices: [Character: Int] = [:]
        if hasBrowserLetterSiblings {
            letterSeenIndices[browserChar] = 1
        }
        
        // 1. Chrome / Browser section (caps lock + browser shortcut)
        let browserName = profileEngine.activeBrowserName
        let chromeIcon: NSImage
        if let candidate = ChromeProfileEngine.supportedBrowsers.first(where: { $0.bundleID == profileEngine.browserBundleID }),
           let appIcon = NSWorkspace.shared.icon(forFile: candidate.appPath) as NSImage? {
            chromeIcon = appIcon
        } else if let appIcon = NSWorkspace.shared.icon(forFile: "/Applications/Google Chrome.app") as NSImage? {
            chromeIcon = appIcon
        } else if let firstAvatar = profileEngine.profiles.first?.avatarImage {
            chromeIcon = firstAvatar
        } else {
            chromeIcon = NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()
        }
        
        let browserSectionHeader = NSMenuItem.sectionHeader(title: "Browsers & Profiles")
        browserSectionHeader.isEnabled = false
        menu.addItem(browserSectionHeader)
        
        let browserTitle = profileEngine.browserBundleID == "com.google.Chrome" ? "Chrome" : browserName
        let chromeItem = makeAlignedMenuItem(
            title: browserTitle,
            keyEquivalent: browserCharStr,
            isHeader: false,
            icon: chromeIcon,
            accessibilityLabel: "\(browserName)",
            accessibilityHelp: "Hold Caps-Lock and press \(browserChar) to switch to \(browserName)",
            action: #selector(handleActivateBrowserClick(_:)),
            target: self
        )
        
        if let total = letterCounts[browserChar], total > 1 {
            let attr = NSMutableAttributedString(string: browserTitle)
            let badge = NSAttributedString(
                string: " · 1/\(total) ↻",
                attributes: [
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular)
                ]
            )
            attr.append(badge)
            chromeItem.attributedTitle = attr
            chromeItem.toolTip = "Hold Caps-Lock and press \(browserChar) to cycle (1 of \(total): \(browserName))"
        } else {
            chromeItem.toolTip = "Hold Caps-Lock and press \(browserChar) to switch to \(browserName)"
        }
        menu.addItem(chromeItem)
        
        let activeProfileDir = profileEngine.getActiveProfileDir()
        if !selectedList.isEmpty {
            for p in selectedList {
                let isActive = p.dir == activeProfileDir
                let pItem = makeAlignedMenuItem(
                    title: p.effectiveName,
                    keyEquivalent: "\(p.index)",
                    icon: p.avatarImage,
                    accessibilityLabel: "\(p.effectiveName)",
                    accessibilityHelp: "Hold Caps-Lock and press \(p.index) to switch to \(p.effectiveName) (Profile \(p.index) of \(selectedList.count))",
                    action: #selector(handleProfileClick(_:)),
                    target: self,
                    representedObject: p.dir
                )
                pItem.indentationLevel = 1
                if isActive {
                    let attr = NSMutableAttributedString(string: p.effectiveName)
                    let activeBadge = NSAttributedString(
                        string: "  ✓",
                        attributes: [
                            .foregroundColor: NSColor.secondaryLabelColor,
                            .font: NSFont.systemFont(ofSize: 11, weight: .semibold)
                        ]
                    )
                    attr.append(activeBadge)
                    pItem.attributedTitle = attr
                }
                menu.addItem(pItem)
            }
        } else if let firstProfile = profileEngine.profiles.first {
            let pItem = makeAlignedMenuItem(
                title: firstProfile.effectiveName,
                keyEquivalent: "1",
                icon: firstProfile.avatarImage,
                accessibilityLabel: "\(firstProfile.effectiveName)",
                accessibilityHelp: "Hold Caps-Lock and press 1 to switch to \(firstProfile.effectiveName)",
                action: #selector(handleProfileClick(_:)),
                target: self,
                representedObject: firstProfile.dir
            )
            pItem.indentationLevel = 1
            menu.addItem(pItem)
        }
        
        func appendAppRow(item: AntigravityItem) {
            let char = Character((item.name.first(where: { $0.isLetter }) ?? "A").uppercased())
            let charStr = String(char).lowercased()
            
            letterSeenIndices[char, default: 0] += 1
            let index = letterSeenIndices[char]!
            let total = letterCounts[char] ?? 1
            
            let rowItem = makeAlignedMenuItem(
                title: item.name,
                keyEquivalent: charStr,
                icon: item.icon,
                accessibilityLabel: "\(item.name)",
                accessibilityHelp: total > 1
                    ? "Hold Caps-Lock and press \(char) to cycle (\(item.name), \(index) of \(total))"
                    : "Hold Caps-Lock and press \(char) to switch to \(item.name)",
                action: #selector(handleCoreAppClick(_:)),
                target: self,
                representedObject: item.bundleID
            )
            
            if total > 1 {
                let attr = NSMutableAttributedString(string: item.name)
                let badge = NSAttributedString(
                    string: " · \(index)/\(total) ↻",
                    attributes: [
                        .foregroundColor: NSColor.secondaryLabelColor,
                        .font: NSFont.systemFont(ofSize: 11, weight: .regular)
                    ]
                )
                attr.append(badge)
                rowItem.attributedTitle = attr
                rowItem.toolTip = "Hold Caps-Lock and press \(char) to cycle (\(index) of \(total): \(item.name))"
            } else {
                rowItem.toolTip = "Hold Caps-Lock and press \(char) to switch to \(item.name)"
            }
            
            menu.addItem(rowItem)
        }
        
        // Signature Mascot Divider bridging Browsers/Profiles and Quick Apps
        menu.addItem(makeMascotSeparatorItem())
        
        // Section 2: Quick Apps (Caps-Lock)
        if !allPinned.isEmpty {
            let quickAppsHeader = NSMenuItem.sectionHeader(title: "Quick Apps (Caps-Lock)")
            quickAppsHeader.isEnabled = false
            menu.addItem(quickAppsHeader)
            for item in allPinned {
                appendAppRow(item: item)
            }
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Zone 3: Preferences & System Controls
        // 3.1 Manage Quick Apps submenu
        let changeAppItem = makeAlignedMenuItem(
            title: "Manage Quick Apps...",
            icon: NSImage(systemSymbolName: "arrow.triangle.swap", accessibilityDescription: "Manage Quick Apps"),
            accessibilityHelp: "Configure pinned apps, installed applications, and browser profiles",
            action: nil,
            target: nil
        )
        let changeAppSubmenu = NSMenu(title: "Manage Quick Apps")
        
        let transparentOffImage = NSImage(size: NSSize(width: 14, height: 14))
        
        // 3.0 Search & Add Application... (⌘F)
        let searchAppItem = makeAlignedMenuItem(
            title: "Search & Add Application...",
            keyEquivalent: "f",
            modifierMask: [.command],
            icon: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search Applications"),
            accessibilityHelp: "Search installed applications to pin to Quick Apps",
            action: #selector(handleOpenAppSearch),
            target: self
        )
        changeAppSubmenu.addItem(searchAppItem)
        changeAppSubmenu.addItem(NSMenuItem.separator())
        
        // 3a. Active Browser Selection (when multiple browsers available)
        if profileEngine.availableBrowsers.count > 1 {
            let browserCatHeader = NSMenuItem(title: "Active Browser:", action: nil, keyEquivalent: "")
            browserCatHeader.attributedTitle = NSAttributedString(
                string: "Active Browser:",
                attributes: [.font: NSFont.boldSystemFont(ofSize: 11)]
            )
            browserCatHeader.isEnabled = false
            changeAppSubmenu.addItem(browserCatHeader)
            
            for b in profileEngine.availableBrowsers {
                let isCurrent = profileEngine.browserBundleID == b.bundleID
                let bItem = makeAlignedMenuItem(
                    title: b.name,
                    icon: NSWorkspace.shared.icon(forFile: b.appPath),
                    action: #selector(handleSelectBrowserClick(_:)),
                    target: self,
                    representedObject: b.bundleID
                )
                bItem.state = isCurrent ? .on : .off
                if !isCurrent {
                    bItem.offStateImage = transparentOffImage
                }
                changeAppSubmenu.addItem(bItem)
            }
            changeAppSubmenu.addItem(NSMenuItem.separator())
        }
        
        // 3b. Chrome / Browser Profiles in Change App
        let chromeCatHeader = NSMenuItem(title: "\(profileEngine.activeBrowserName) Profiles (up to 4):", action: nil, keyEquivalent: "")
        chromeCatHeader.attributedTitle = NSAttributedString(
            string: "\(profileEngine.activeBrowserName) Profiles (up to 4):",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 11)]
        )
        chromeCatHeader.isEnabled = false
        changeAppSubmenu.addItem(chromeCatHeader)
        
        for p in profileEngine.profiles {
            let isSelected = selectedList.contains(where: { $0.dir == p.dir })
            let slot = selectedList.first(where: { $0.dir == p.dir })?.index
            let pItem = makeAlignedMenuItem(
                title: p.effectiveName,
                keyEquivalent: slot != nil ? "\(slot!)" : "",
                icon: p.avatarImage,
                action: #selector(handleChangeProfileClick(_:)),
                target: self,
                representedObject: p.dir
            )
            pItem.state = isSelected ? .on : .off
            if !isSelected {
                pItem.offStateImage = transparentOffImage
            }
            changeAppSubmenu.addItem(pItem)
        }
        
        // 3c. Pinned Quick Apps Header
        changeAppSubmenu.addItem(NSMenuItem.separator())
        let submenuPinned = AppGroupEngine.pinnedAppItems()
        let pinnedTitle = LicenseEngine.shared.isPro ? "Pinned Quick Apps (\(submenuPinned.count)):" : "Pinned Quick Apps (up to 4):"
        let pinnedHeader = NSMenuItem(title: pinnedTitle, action: nil, keyEquivalent: "")
        pinnedHeader.attributedTitle = NSAttributedString(
            string: pinnedTitle,
            attributes: [.font: NSFont.boldSystemFont(ofSize: 11)]
        )
        pinnedHeader.isEnabled = false
        changeAppSubmenu.addItem(pinnedHeader)
        
        for item in submenuPinned {
            let char = Character((item.name.first(where: { $0.isLetter }) ?? "A").uppercased())
            let pItem = makeAlignedMenuItem(
                title: "\(item.name) (\(char))",
                keyEquivalent: String(char).lowercased(),
                icon: item.icon,
                action: #selector(handleUnpinAppClick(_:)),
                target: self,
                representedObject: item.bundleID
            )
            pItem.state = NSControl.StateValue.on
            changeAppSubmenu.addItem(pItem)
        }
        
        // 3d. Choose Other App...
        changeAppSubmenu.addItem(NSMenuItem.separator())
        let customAppItem = makeAlignedMenuItem(
            title: "Choose Other App...",
            keyEquivalent: "o",
            modifierMask: [.command],
            action: #selector(handleChooseOtherApp),
            target: self
        )
        changeAppSubmenu.addItem(customAppItem)
        
        changeAppItem.submenu = changeAppSubmenu
        
        // Zone 3: Preferences & System Controls
        let isCopyEnabled = CopyOnSelectEngine.shared.isEnabled
        let copyStatusItem = makeAlignedMenuItem(
            title: "Copy on Select",
            icon: NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Copy on Select"),
            accessibilityHelp: "Toggle automatic copying of selected text to the clipboard",
            action: #selector(handleToggleCopyOnSelect),
            target: self
        )
        copyStatusItem.state = .off
        let copyAttr = NSMutableAttributedString(string: "Copy on Select")
        let copyBadgeText = isCopyEnabled ? " · On" : " · Off"
        let copyBadge = NSAttributedString(
            string: copyBadgeText,
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 11, weight: .regular)
            ]
        )
        copyAttr.append(copyBadge)
        copyStatusItem.attributedTitle = copyAttr
        copyStatusItem.toolTip = "Automatically copy selected text to the clipboard on drag selection (\(isCopyEnabled ? "Active" : "Disabled"))"
        menu.addItem(copyStatusItem)
        menu.addItem(changeAppItem)
        
        let settingsItem = makeAlignedMenuItem(
            title: "Settings...",
            keyEquivalent: ",",
            modifierMask: [.command],
            icon: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings"),
            accessibilityHelp: "Configure pinned apps, shortcuts, and browser profiles",
            action: #selector(handleOpenAppSearch),
            target: self
        )
        menu.addItem(settingsItem)
        
        let refreshItem = makeAlignedMenuItem(
            title: "Refresh Profiles & Apps",
            keyEquivalent: "r",
            modifierMask: [.command],
            icon: NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Refresh Profiles & Apps"),
            accessibilityHelp: "Reload browser profiles and installed applications",
            action: #selector(handleRefreshProfiles),
            target: self
        )
        menu.addItem(refreshItem)
        
        if !AXIsProcessTrusted() {
            let permItem = makeAlignedMenuItem(
                title: "Grant Accessibility Permissions…",
                icon: NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Accessibility Warning"),
                accessibilityHelp: "Open macOS System Settings to enable Accessibility permission",
                action: #selector(handleOpenAccessibilitySettings),
                target: self
            )
            menu.addItem(permItem)
        }
        
        let avatarSubmenu = NSMenu()
        
        let assistantItem = makeAlignedMenuItem(
            title: "Open Avatar Assistant (Clipboard Snip)...",
            icon: NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Avatar Assistant"),
            accessibilityHelp: "Open assistant to paste profile avatars from clipboard with 0 permissions",
            action: #selector(handleOpenAvatarCaptureAssistant(_:)),
            target: self
        )
        avatarSubmenu.addItem(assistantItem)
        avatarSubmenu.addItem(NSMenuItem.separator())
        
        let guideHeader = NSMenuItem(title: "Paste Avatar for Profile:", action: nil, keyEquivalent: "")
        guideHeader.attributedTitle = NSAttributedString(
            string: "Paste Avatar for Profile:",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 11)]
        )
        guideHeader.isEnabled = false
        avatarSubmenu.addItem(guideHeader)
        
        for p in profileEngine.profiles {
            let pPasteItem = makeAlignedMenuItem(
                title: "Paste Avatar for \(p.effectiveName)...",
                icon: p.avatarImage,
                accessibilityHelp: "Apply image currently in clipboard as avatar for \(p.effectiveName)",
                action: #selector(handlePasteAvatarFromClipboard(_:)),
                target: self,
                representedObject: p.dir
            )
            avatarSubmenu.addItem(pPasteItem)
        }
        
        let avatarItem = makeAlignedMenuItem(
            title: "Profile Avatars (Clipboard)...",
            icon: NSImage(systemSymbolName: "person.crop.circle", accessibilityDescription: "Profile Avatars"),
            accessibilityHelp: "Import profile avatars from clipboard with zero permissions",
            action: nil,
            target: nil
        )
        avatarItem.submenu = avatarSubmenu
        avatarItem.toolTip = "Import profile avatars from clipboard with zero permissions"
        menu.addItem(avatarItem)
        
        let hasLinkedBookmark = UserDefaults.standard.data(forKey: "ChromeFolderSecurityScopedBookmark") != nil
        if profileEngine.isLocalStateBlocked && !hasLinkedBookmark {
            let linkItem = makeAlignedMenuItem(
                title: "Link Chrome Avatars… (1-Click)",
                icon: NSImage(systemSymbolName: "person.crop.circle.badge.plus", accessibilityDescription: "Link Chrome Avatars"),
                accessibilityHelp: "Select Chrome folder once to load real profile avatars without Full Disk Access",
                action: #selector(handleLinkChromeAvatars),
                target: self
            )
            linkItem.toolTip = "1-click folder link to load real Google profile avatars into the menu bar and HUD"
            menu.addItem(linkItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // 5. License & Lifecycle
        if LicenseEngine.shared.isPro {
            let proItem = makeAlignedMenuItem(
                title: "NNTS Pro · Active",
                icon: NSImage(systemSymbolName: "checkmark.seal", accessibilityDescription: "NNTS Pro Active"),
                accessibilityHelp: "Manage your NNTS Pro license",
                action: #selector(handleManageLicense),
                target: self
            )
            let attr = NSMutableAttributedString(string: "NNTS Pro")
            let badge = NSAttributedString(
                string: " · Active",
                attributes: [
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular)
                ]
            )
            attr.append(badge)
            proItem.attributedTitle = attr
            menu.addItem(proItem)
        } else {
            let proItem = makeAlignedMenuItem(
                title: "Upgrade to NNTS Pro (\(LicenseEngine.proPrice))...",
                icon: NSImage(systemSymbolName: "star.fill", accessibilityDescription: "Upgrade to NNTS Pro"),
                accessibilityHelp: "Upgrade to NNTS Pro for unlimited app and profile slots",
                action: #selector(handleUpgradeToPro),
                target: self
            )
            menu.addItem(proItem)
            
            let enterKeyItem = makeAlignedMenuItem(
                title: "Enter License Key...",
                icon: NSImage(systemSymbolName: "key.fill", accessibilityDescription: "Enter License Key"),
                accessibilityHelp: "Activate your license key",
                action: #selector(handleEnterLicenseKeyFromMenu),
                target: self
            )
            menu.addItem(enterKeyItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let aboutItem = makeAlignedMenuItem(
            title: "About NNTS...",
            icon: NSImage(systemSymbolName: "info.circle", accessibilityDescription: "About NNTS"),
            accessibilityHelp: "View version and application information",
            action: #selector(handleAbout),
            target: self
        )
        let aboutAttr = NSMutableAttributedString(string: "About NNTS")
        let versionBadge = NSAttributedString(
            string: "  v\(AppDelegate.appVersion)",
            attributes: [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.systemFont(ofSize: 11, weight: .regular)
            ]
        )
        aboutAttr.append(versionBadge)
        aboutItem.attributedTitle = aboutAttr
        menu.addItem(aboutItem)
        
        let reportItem = makeAlignedMenuItem(
            title: "Report an Issue...",
            icon: NSImage(systemSymbolName: "ladybug", accessibilityDescription: "Report an Issue"),
            accessibilityHelp: "Open diagnostics and report an issue",
            action: #selector(handleReportIssue),
            target: self
        )
        menu.addItem(reportItem)
        
        let updateItem = makeAlignedMenuItem(
            title: "Check for Updates...",
            icon: NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Check for Updates"),
            accessibilityHelp: "Check for new versions of NNTS",
            action: #selector(handleCheckForUpdates),
            target: self
        )
        menu.addItem(updateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = makeAlignedMenuItem(
            title: "Quit NNTS",
            keyEquivalent: "q",
            modifierMask: [.command],
            icon: NSImage(systemSymbolName: "power", accessibilityDescription: "Quit NNTS"),
            accessibilityHelp: "Quit the application",
            action: #selector(handleQuit),
            target: self
        )
        menu.addItem(quitItem)
        
        return menu
    }
    
    @objc private func handleChangeProfileClick(_ sender: NSMenuItem) {
        guard let dir = sender.representedObject as? String else { return }
        let profileEngine = ChromeProfileEngine.shared
        if profileEngine.isProfileSelected(dir: dir) {
            profileEngine.deselectProfile(dir: dir)
            updateMenu()
        } else {
            if profileEngine.selectedProfiles.count < 4 {
                profileEngine.selectProfile(dir: dir)
                updateMenu()
            } else {
                promptProfileReplacement(newDir: dir)
            }
        }
    }
    
    private func promptProfileReplacement(newDir: String) {
        let profileEngine = ChromeProfileEngine.shared
        let newProfileName = profileEngine.profiles.first(where: { $0.dir == newDir })?.effectiveName ?? newDir
        
        let alert = NSAlert()
        alert.messageText = "Chrome Profiles Limit Reached (4 of 4)"
        alert.informativeText = "NNTS supports up to 4 quick profiles (Caps + 1..4).\n\nAll 4 profile slots are currently in use. Choose which profile slot to replace with '\(newProfileName)':"
        alert.alertStyle = .informational
        
        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 26))
        for p in profileEngine.selectedProfiles {
            popUp.addItem(withTitle: "Slot \(p.index): \(p.effectiveName)")
            popUp.lastItem?.representedObject = p.dir
            if let avatar = p.avatarImage?.copy() as? NSImage {
                avatar.size = NSSize(width: 16, height: 16)
                popUp.lastItem?.image = avatar
                if #available(macOS 27.0, *) {
                    popUp.lastItem?.preferredImageVisibility = .visible
                }
            }
        }
        alert.accessoryView = popUp
        
        alert.addButton(withTitle: "Replace Profile")
        alert.addButton(withTitle: "Cancel")
        
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let oldDir = popUp.selectedItem?.representedObject as? String {
                profileEngine.replaceProfile(oldDir: oldDir, newDir: newDir)
                updateMenu()
            }
        }
    }
    
    @objc private func handleActivateBrowserClick(_ sender: NSMenuItem) {
        ChromeProfileEngine.shared.focusChrome()
    }
    
    @objc private func handleProfileClick(_ sender: NSMenuItem) {
        guard let dir = sender.representedObject as? String else { return }
        let isOptionClick = NSEvent.modifierFlags.contains(.option)
        if isOptionClick {
            ChromeProfileEngine.shared.toggleProfileSelection(dir: dir)
        } else {
            ChromeProfileEngine.shared.selectProfile(dir: dir)
            ChromeProfileEngine.shared.focusProfile(dir: dir)
        }
        updateMenu()
    }
    
    @objc private func handleCoreAppClick(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        self.focusApp(bundleID: bundleID)
    }
    
    @objc private func handleChangeAppItemClick(_ sender: NSMenuItem) {
        guard let repr = sender.representedObject as? String else { return }
        let parts = repr.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let category = parts[0]
        let bundleID = parts[1]
        
        let engines = [
            AppGroupEngine.terminal,
            AppGroupEngine.aiAgent,
            AppGroupEngine.ide,
            AppGroupEngine.notes
        ]
        
        if let engine = engines.first(where: { $0.category == category }) {
            engine.select(bundleID: bundleID)
            engine.focusItem(bundleID: bundleID)
            updateDynamicShortcuts()
            updateMenu()
        }
    }
    
    @objc private func handleAppItemClick(_ sender: NSMenuItem) {
        handleCoreAppClick(sender)
    }
    
    @objc private func handleTerminalClick(_ sender: NSMenuItem) {
        handleAppItemClick(sender)
    }
    
    @objc private func handleAiAgentClick(_ sender: NSMenuItem) {
        handleAppItemClick(sender)
    }
    
    @objc private func handleAntigravityClick(_ sender: NSMenuItem) {
        handleAppItemClick(sender)
    }
    
    @objc private func handleIdeClick(_ sender: NSMenuItem) {
        handleAppItemClick(sender)
    }
    
    @objc private func handleNotesClick(_ sender: NSMenuItem) {
        handleAppItemClick(sender)
    }
    
    @objc private func handleMultiAppCycleClick(_ sender: NSMenuItem) {
        guard let repr = sender.representedObject as? String else { return }
        let bundleIDs = repr.split(separator: ",").map(String.init)
        guard let targetBundleID = AppGroupEngine.prioritizedBundleID(from: bundleIDs) ?? bundleIDs.first else { return }
        self.focusApp(bundleID: targetBundleID)
    }
    
    @objc private func handleUnpinAppClick(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        AppGroupEngine.deselectApp(bundleID: bundleID)
        updateDynamicShortcuts()
        updateMenu()
    }
    
    @objc private func handleTogglePinAppClick(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        if AppGroupEngine.isAppSelected(bundleID: bundleID) {
            AppGroupEngine.deselectApp(bundleID: bundleID)
            updateDynamicShortcuts()
            updateMenu()
        } else {
            if AppGroupEngine.canPinMoreApps {
                AppGroupEngine.selectApp(bundleID: bundleID)
                updateDynamicShortcuts()
                updateMenu()
            } else {
                promptAppReplacement(newBundleID: bundleID)
            }
        }
    }
    
    @objc private func handleSelectBrowserClick(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        ChromeProfileEngine.shared.selectBrowser(bundleID: bundleID)
        updateDynamicShortcuts()
        updateMenu()
    }
    
    @objc private func handleUpgradeToPro() {
        if let url = URL(string: LicenseEngine.polarCheckoutUrl) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func handleEnterLicenseKeyFromMenu() {
        promptEnterLicenseKey()
    }
    
    @objc private func handleManageLicense() {
        let alert = NSAlert()
        alert.messageText = "NNTS Pro Active"
        let keyText = LicenseEngine.shared.activeLicenseKey ?? "Activated via License"
        alert.informativeText = "Status: Pro (\(LicenseEngine.proPrice))\nLicense Key: \(keyText)\n\nYou have unlocked unlimited Quick App slots!"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Deactivate License")
        
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        if alert.runModal() == .alertSecondButtonReturn {
            LicenseEngine.shared.deactivate()
            updateDynamicShortcuts()
            updateMenu()
        }
    }
    
    private func promptEnterLicenseKey(thenPinBundleID: String? = nil) {
        let alert = NSAlert()
        alert.messageText = "Enter NNTS Pro License Key"
        alert.informativeText = "Please enter your license key to unlock unlimited slots:"
        alert.alertStyle = .informational
        
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "NNTS-PRO-XXXX-XXXX"
        alert.accessoryView = input
        
        alert.addButton(withTitle: "Activate")
        alert.addButton(withTitle: "Cancel")
        
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let key = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { return }
            
            // 1. Key format validation check before making network calls
            guard LicenseEngine.shared.validateLicenseKey(key) else {
                showActivationError(message: "Invalid license key format. NNTS license keys start with 'NNTS-'.")
                return
            }
            
            // 2. Online Polar activation via async Task on MainActor
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let result = await LicenseEngine.shared.activateOnlineDetailed(key: key)
                switch result {
                case .success:
                    self.showActivationSuccess(thenPinBundleID: thenPinBundleID)
                case .invalidKey(let msg):
                    self.showActivationError(message: msg)
                case .activationLimitReached:
                    self.showActivationError(message: "This license key has reached its maximum number of activated devices. Please deactivate another device or contact support.")
                case .networkError(let msg):
                    self.showActivationError(message: "Could not connect to the Polar license server. Please check your internet connection and try again.\n\nDetails: \(msg)")
                }
            }
        }
    }
    
    private func showActivationSuccess(thenPinBundleID: String?) {
        let successAlert = NSAlert()
        successAlert.messageText = "NNTS Pro Activated!"
        successAlert.informativeText = "Thank you for supporting independent software development. You now have unlimited Quick App slots!"
        successAlert.alertStyle = .informational
        successAlert.addButton(withTitle: "OK")
        successAlert.runModal()
        
        if let pinID = thenPinBundleID {
            AppGroupEngine.selectApp(bundleID: pinID)
        }
        updateDynamicShortcuts()
        updateMenu()
    }
    
    private func showActivationError(message: String) {
        let errorAlert = NSAlert()
        errorAlert.messageText = "Activation Failed"
        errorAlert.informativeText = message
        errorAlert.alertStyle = .warning
        errorAlert.addButton(withTitle: "OK")
        errorAlert.runModal()
    }
    
    public func promptAppReplacement(newBundleID: String) {
        let allDiscovered = AppGroupEngine.allDiscoveredItems()
        let newAppName = allDiscovered.first(where: { $0.bundleID == newBundleID })?.name
            ?? (Bundle(identifier: newBundleID)?.infoDictionary?["CFBundleName"] as? String)
            ?? newBundleID
        
        let alert = NSAlert()
        alert.messageText = "Free Tier Slot Limit Reached (5 of 5 Slots)"
        alert.informativeText = "NNTS Free includes 5 quick slots (1 Browser Hub + 4 Pinned Apps).\n\nSlots 6 and beyond require NNTS Pro (\(LicenseEngine.proPrice)).\n\nYou can replace an existing pinned slot or upgrade to NNTS Pro for unlimited quick app slots:"
        alert.alertStyle = .informational
        
        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 26))
        let currentPinned = AppGroupEngine.pinnedAppItems()
        for item in currentPinned {
            let char = item.name.first(where: { $0.isLetter })?.uppercased() ?? "A"
            popUp.addItem(withTitle: "\(item.name) (Caps + \(char))")
            popUp.lastItem?.representedObject = item.bundleID
            if let icon = item.icon.copy() as? NSImage {
                icon.size = NSSize(width: 16, height: 16)
                popUp.lastItem?.image = icon
                if #available(macOS 27.0, *) {
                    popUp.lastItem?.preferredImageVisibility = .visible
                }
            }
        }
        alert.accessoryView = popUp
        
        alert.addButton(withTitle: "Replace App")
        alert.addButton(withTitle: "Upgrade to Pro (\(LicenseEngine.proPrice))")
        alert.addButton(withTitle: "Enter License Key...")
        alert.addButton(withTitle: "Cancel")
        
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let oldBundleID = popUp.selectedItem?.representedObject as? String {
                let oldName = popUp.selectedItem?.title ?? oldBundleID
                logger.info("User explicitly replaced '\(oldName)' with '\(newAppName)'.")
                AppGroupEngine.replaceApp(oldBundleID: oldBundleID, newBundleID: newBundleID)
                updateDynamicShortcuts()
                updateMenu()
            }
        } else if response == .alertSecondButtonReturn {
            handleUpgradeToPro()
        } else if response == .alertThirdButtonReturn {
            promptEnterLicenseKey(thenPinBundleID: newBundleID)
        }
    }
    
    @objc public func handleOpenAppSearch() {
        MinimalHUDWindow.shared.hideImmediate()
        AppSearchPickerWindow.shared.show()
    }
    
    public func handleChooseOtherAppFromExternal() {
        handleChooseOtherApp()
    }
    
    @objc private func handleChooseOtherApp() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Pin App"
        panel.message = "Choose an application to pin to NNTS Quick Apps:"
        
        NSApp.activate(ignoringOtherApps: true)
        panel.level = .floating
        if panel.runModal() == .OK, let url = panel.url {
            if let item = AppGroupEngine.registerCustomApp(url: url) {
                if AppGroupEngine.canPinMoreApps {
                    AppGroupEngine.selectApp(bundleID: item.bundleID)
                    updateDynamicShortcuts()
                    updateMenu()
                } else if !AppGroupEngine.isAppSelected(bundleID: item.bundleID) {
                    promptAppReplacement(newBundleID: item.bundleID)
                } else {
                    updateDynamicShortcuts()
                    updateMenu()
                }
            }
        }
    }
    
    @objc private func handleRefreshProfiles() {
        if AXIsProcessTrusted() {
            if !CapsLockEngine.shared.isStarted {
                CapsLockEngine.shared.start()
            }
            if !CopyOnSelectEngine.shared.isStarted && CopyOnSelectEngine.shared.isEnabled {
                CopyOnSelectEngine.shared.start()
            }
        }
        ChromeProfileEngine.shared.clearAvatarCache()
        ChromeProfileEngine.shared.refreshProfiles()
        AntigravityEngine.shared.refreshItems()
        for engine in AppGroupEngine.allEngines {
            engine.refreshItems()
        }
        updateDynamicShortcuts()
        updateMenu()
    }
    
    @objc private func handleToggleCopyOnSelect() {
        CopyOnSelectEngine.shared.isEnabled.toggle()
        if CopyOnSelectEngine.shared.isEnabled {
            CopyOnSelectEngine.shared.start()
        } else {
            CopyOnSelectEngine.shared.stop()
        }
        updateMenu()
    }
    
    @objc private func handleOpenAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc private func handleOpenFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc public func handleLinkChromeAvatars(_ sender: Any? = nil) {
        NSApp.activate(ignoringOtherApps: true)
        
        let panel = NSOpenPanel()
        panel.title = "Link Chrome Profile Avatars"
        panel.prompt = "Link Folder"
        panel.message = "Click 'Link Folder' to connect your Google Chrome folder and display real profile photos:"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.level = .floating
        
        let defaultPath = ("~/Library/Application Support/Google/Chrome" as NSString).expandingTildeInPath
        panel.directoryURL = URL(fileURLWithPath: defaultPath)
        
        let response = panel.runModal()
        guard response == .OK, let selectedURL = panel.url else { return }
        
        let count = ChromeProfileEngine.shared.importAvatarsFromFolder(url: selectedURL)
        ChromeProfileEngine.shared.clearAvatarCache()
        ChromeProfileEngine.shared.refreshProfiles()
        self.updateDynamicShortcuts()
        self.updateMenu()
        
        let alert = NSAlert()
        if count > 0 {
            alert.messageText = "Chrome Avatars Connected!"
            alert.informativeText = "Successfully connected \(count) profile avatars. Your real Google account photos are now active in the menu bar and HUD."
            alert.alertStyle = .informational
        } else {
            alert.messageText = "Folder Connected"
            alert.informativeText = "The Chrome folder was connected. Real profile photos will display as they are cached by Google."
            alert.alertStyle = .informational
        }
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        alert.runModal()
    }
    
    @objc public func handleOpenAvatarCaptureAssistant(_ sender: Any? = nil) {
        AvatarCaptureAssistantWindow.shared.show()
    }
    
    @objc public func handlePasteAvatarFromClipboard(_ sender: NSMenuItem) {
        let profileEngine = ChromeProfileEngine.shared
        let targetDir = (sender.representedObject as? String) ?? profileEngine.getActiveProfileDir() ?? profileEngine.profiles.first?.dir ?? "Default"
        let targetProfile = profileEngine.profiles.first(where: { $0.dir == targetDir }) ?? profileEngine.profiles.first
        let name = targetProfile?.name ?? "Profile"
        
        let success = profileEngine.saveCapturedAvatarFromPasteboard(forProfileDir: targetDir, name: name)
        if success {
            if NSSound(named: "Hero")?.play() != true {
                NSSound.beep()
            }
            self.updateDynamicShortcuts()
            self.updateMenu()
            
            let alert = NSAlert()
            alert.messageText = "Avatar Applied from Clipboard!"
            alert.informativeText = "Photo for '\(targetProfile?.effectiveName ?? name)' was successfully updated from your clipboard."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.window.level = .floating
            alert.runModal()
        } else {
            let alert = NSAlert()
            alert.messageText = "No Image in Clipboard"
            alert.informativeText = "First copy an image to your clipboard (or take a screenshot with Cmd+Ctrl+Shift+4), then click here to apply it to '\(targetProfile?.effectiveName ?? name)'."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.window.level = .floating
            alert.runModal()
        }
    }
    
    @objc private func handleQuit() {
        NSApplication.shared.terminate(nil)
    }
    
    // MARK: - About & Updates Handlers
    @objc public func handleAbout() {
        let alert = NSAlert()
        alert.messageText = "NNTS"
        alert.informativeText = """
        Version \(AppDelegate.appVersion) (Build \(AppDelegate.appBuild))

        Zero-Latency Keyboard Navigation for macOS.
        Sub-16ms Context Switching • Zero-Driver • Pure Swift 6.

        Open source under MIT License.
        """
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage ?? AppDelegate.makeStatusIcon()
        
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "GitHub ↗")
        alert.addButton(withTitle: "Website ↗")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/ellisglass/nnts") {
                NSWorkspace.shared.open(url)
            }
        } else if response == .alertThirdButtonReturn {
            if let url = URL(string: "https://ellisglass.github.io/nnts") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc public func handleCheckForUpdates() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.checkForUpdates()
        }
    }
    
    public func checkForUpdates() async {
        guard let url = URL(string: "https://api.github.com/repos/ellisglass/nnts/releases/latest") else { return }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("NNTS-App", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                showUpToDateAlert(currentVersion: AppDelegate.appVersion)
                return
            }
            struct GitHubRelease: Decodable {
                let tag_name: String
                let html_url: String
                let body: String?
            }
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let current = AppDelegate.appVersion
            
            if latestVersion.compare(current, options: .numeric) == .orderedDescending {
                showUpdateAvailableAlert(latestVersion: latestVersion, releaseUrl: release.html_url, releaseNotes: release.body)
            } else {
                showUpToDateAlert(currentVersion: current)
            }
        } catch {
            showUpToDateAlert(currentVersion: AppDelegate.appVersion)
        }
    }
    
    private func showUpdateAvailableAlert(latestVersion: String, releaseUrl: String, releaseNotes: String? = nil) {
        let alert = NSAlert()
        alert.messageText = "New Update Available: v\(latestVersion)"
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage ?? AppDelegate.makeStatusIcon()
        
        let highlights = UpdateEngine.parseReleaseHighlights(from: releaseNotes, maxBullets: 4)
        var highlightsBlock = ""
        if !highlights.isEmpty {
            let bulletLines = highlights.map { "• \($0)" }.joined(separator: "\n")
            highlightsBlock = "\n\nWhat's new in v\(latestVersion):\n\(bulletLines)\n"
        }
        
        let source = UpdateEngine.detectInstallationSource()
        switch source {
        case .homebrew:
            alert.informativeText = """
            You are currently running NNTS v\(AppDelegate.appVersion).\(highlightsBlock)
            A new version is available on Homebrew.
            Click 'Update in Terminal' to upgrade automatically, or view the release notes.
            """
            alert.addButton(withTitle: "Update in Terminal")
            alert.addButton(withTitle: "View Release ↗")
            alert.addButton(withTitle: "Later")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                UpdateEngine.runHomebrewUpgradeInTerminal()
            } else if response == .alertSecondButtonReturn {
                if let url = URL(string: releaseUrl), url.scheme == "https" {
                    NSWorkspace.shared.open(url)
                }
            }
            
        case .directDownload:
            alert.informativeText = """
            You are currently running NNTS v\(AppDelegate.appVersion).\(highlightsBlock)
            A new version is available for download.
            Click 'Download DMG' to get the latest version.
            """
            alert.addButton(withTitle: "Download DMG")
            alert.addButton(withTitle: "View Release ↗")
            alert.addButton(withTitle: "Later")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                NSWorkspace.shared.open(UpdateEngine.directDmgDownloadUrl)
            } else if response == .alertSecondButtonReturn {
                if let url = URL(string: releaseUrl), url.scheme == "https" {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
    
    private func showUpToDateAlert(currentVersion: String) {
        let alert = NSAlert()
        alert.messageText = "NNTS is Up to Date"
        alert.informativeText = "Version \(currentVersion) is currently the newest version available."
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage ?? AppDelegate.makeStatusIcon()
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func promptForAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Feedback & Diagnostics Window
    private var feedbackWindow: NSWindow?

    @objc public func handleReportIssue() {
        if let existing = feedbackWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: FeedbackWindowView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Report an Issue — NNTS"
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.level = .floating

        self.feedbackWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
