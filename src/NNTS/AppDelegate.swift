import Cocoa
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import os

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    public static var shared: AppDelegate?
    
    internal var statusItem: NSStatusItem?
    internal let logger = Logger(subsystem: "com.almosteleven.nnts", category: "app")
    internal var accessibilityPollTimer: Timer?
    internal var appSwitchObserver: Any?
    internal var mascotBlinkTimer: Timer?
    internal var mascotGazeResetTask: Task<Void, Never>?
    
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
        FinderTidyEngine.shared.stop()
    }
    
    public func startServices() {
        if !CapsLockEngine.shared.isStarted {
            CapsLockEngine.shared.start()
        }
        if CopyOnSelectEngine.shared.isEnabled && !CopyOnSelectEngine.shared.isStarted {
            CopyOnSelectEngine.shared.start()
        }
        if FinderTidyEngine.shared.isEnabled && !FinderTidyEngine.shared.isRunning {
            FinderTidyEngine.shared.start()
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
    
    internal enum ActiveSwitcherMode: Equatable {
        case none
        case chrome
        case appLetter(Character)
    }
    
    internal var isCyclingHUDActive = false
    internal var activeMode: ActiveSwitcherMode = .none
    public var onPromptForMissingApp: ((String) -> Void)? = nil
    
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
    
    
    public func updateMenu() {
        let menu = buildStatusMenu()
        menu.delegate = self
        statusItem?.menu = menu
    }
    
    internal var feedbackWindow: NSWindow?
}

// MARK: - NSMenuDelegate

extension AppDelegate: NSMenuDelegate {
    public func menuWillOpen(_ menu: NSMenu) {
        let activeDir = ChromeProfileEngine.shared.getActiveProfileDir()
        for item in menu.items {
            if let stripView = item.view as? ProfileStripView {
                stripView.updateActiveDir(activeDir)
            }
        }
    }
}

// MARK: - NSMenuItem macOS 27 Compatibility Extension

extension NSMenuItem {
    /// Ensures item image remains visible on macOS 27+ without introducing compile-time SDK coupling for older Xcode runners.
    @MainActor
    public func ensureImageVisibleOnMacOS27() {
        let selector = NSSelectorFromString("setPreferredImageVisibility:")
        if self.responds(to: selector) {
            self.setValue(1, forKey: "preferredImageVisibility")
        }
    }
}

