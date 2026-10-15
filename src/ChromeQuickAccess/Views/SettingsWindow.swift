//
//  SettingsWindow.swift
//  NNTS (macOS Productivity Suite)
//
//  Clean, simplified native macOS Settings Window with 3 focused tabs:
//  General, Shortcuts (Quick Apps & Profiles), and License.
//

import SwiftUI
import AppKit
import Cocoa
import UniformTypeIdentifiers
import os

// MARK: - Settings Tab Enumeration

public enum SettingsTab: String, CaseIterable, Identifiable, Sendable {
    case general = "General"
    case shortcuts = "Shortcuts"
    case license = "License"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .shortcuts: return "command"
        case .license: return "checkmark.seal"
        }
    }
    
    // Backward compatibility aliases
    public static let profiles: SettingsTab = .shortcuts
    public static let quickApps: SettingsTab = .shortcuts
    public static let copyOnSelect: SettingsTab = .general
    public static let finderTidy: SettingsTab = .general
}

// MARK: - Settings View Model

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var selectedTab: SettingsTab = .general
    
    // General Tab State
    @Published public var isCapsLockRemapped: Bool = false
    @Published public var isAccessibilityTrusted: Bool = false
    @Published public var statusMessage: String? = nil
    
    // Copy on Select & Finder Tidy State
    @Published public var isCopyOnSelectEnabled: Bool = true
    @Published public var isFinderTidyEnabled: Bool = true
    @Published public var finderMaxWindows: Int = 5
    
    // Shortcuts Tab State: Quick Apps
    @Published public var pinnedBundleIDs: Set<String> = []
    @Published public var pinnedApps: [AntigravityItem] = []
    @Published public var appSearchQuery: String = ""
    @Published public var appSearchResults: [InstalledAppInfo] = []
    
    // Shortcuts Tab State: Profiles
    @Published public var currentBrowserBundleID: String = "com.google.Chrome"
    @Published public var availableBrowsers: [ChromiumBrowserCandidate] = []
    @Published public var profiles: [ChromeProfile] = []
    
    // License Tab State
    @Published public var isPro: Bool = false
    @Published public var licenseKeyInput: String = ""
    @Published public var isActivating: Bool = false
    @Published public var activationMessage: String? = nil
    @Published public var isActivationError: Bool = false
    
    public init() {
        refreshAll()
    }
    
    public func refreshAll() {
        refreshGeneral()
        refreshShortcuts()
        refreshLicense()
    }
    
    public func refreshGeneral() {
        self.isAccessibilityTrusted = AXIsProcessTrusted()
        self.isCapsLockRemapped = CapsLockEngine.shared.isStarted
        
        let copyEngine = CopyOnSelectEngine.shared
        self.isCopyOnSelectEnabled = copyEngine.isEnabled
        
        let tidyEngine = FinderTidyEngine.shared
        self.isFinderTidyEnabled = tidyEngine.isEnabled
        self.finderMaxWindows = tidyEngine.maxWindows
    }
    
    public func refreshShortcuts() {
        // Quick Apps
        self.pinnedBundleIDs = AppGroupEngine.selectedBundleIDs
        self.pinnedApps = AppGroupEngine.pinnedAppItems()
        self.appSearchResults = AppGroupEngine.searchInstalledApplications(query: appSearchQuery)
        
        // Profiles
        let engine = ChromeProfileEngine.shared
        self.currentBrowserBundleID = engine.browserBundleID
        self.availableBrowsers = engine.availableBrowsers
        self.profiles = engine.selectedProfiles
    }
    
    public func refreshLicense() {
        self.isPro = LicenseEngine.shared.isPro
    }
    
    // MARK: - Actions: General
    
    public func reapplyCapsLockRemapping() {
        let success = HIDMappingService.applyCapsLockToF18()
        if success {
            if !CapsLockEngine.shared.isStarted {
                CapsLockEngine.shared.start()
            }
            self.statusMessage = "caps lock hardware remapping applied."
        } else {
            self.statusMessage = "Failed to apply remapping."
        }
        refreshGeneral()
    }
    
    public func restoreDefaultCapsLock() {
        let success = HIDMappingService.restoreDefaultMapping()
        if success {
            CapsLockEngine.shared.stop()
            self.statusMessage = "Restored default system caps lock mapping."
        } else {
            self.statusMessage = "Failed to restore default mapping."
        }
        refreshGeneral()
    }
    
    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func setCopyOnSelectEnabled(_ enabled: Bool) {
        CopyOnSelectEngine.shared.isEnabled = enabled
        if enabled {
            CopyOnSelectEngine.shared.start()
        } else {
            CopyOnSelectEngine.shared.stop()
        }
        AppDelegate.shared?.updateMenu()
        self.isCopyOnSelectEnabled = enabled
    }
    
    public func setFinderTidyEnabled(_ enabled: Bool) {
        FinderTidyEngine.shared.isEnabled = enabled
        if enabled {
            FinderTidyEngine.shared.start()
        } else {
            FinderTidyEngine.shared.stop()
        }
        AppDelegate.shared?.updateMenu()
        self.isFinderTidyEnabled = enabled
    }
    
    public func setFinderMaxWindows(_ limit: Int) {
        FinderTidyEngine.shared.maxWindows = limit
        self.finderMaxWindows = limit
        AppDelegate.shared?.updateMenu()
    }
    
    // MARK: - Actions: Shortcuts
    
    public func unpinApp(bundleID: String) {
        AppGroupEngine.deselectApp(bundleID: bundleID)
        AppDelegate.shared?.updateDynamicShortcuts()
        AppDelegate.shared?.updateMenu()
        refreshShortcuts()
    }
    
    public func pinApp(app: InstalledAppInfo) {
        let success = AppGroupEngine.toggleInstalledAppPin(app: app)
        if success {
            AppDelegate.shared?.updateDynamicShortcuts()
            AppDelegate.shared?.updateMenu()
            refreshShortcuts()
        } else {
            AppDelegate.shared?.promptAppReplacement(newBundleID: app.bundleID)
            refreshShortcuts()
        }
    }
    
    public func chooseBrowser(bundleID: String) {
        let engine = ChromeProfileEngine.shared
        engine.preferredBrowserBundleID = bundleID
        engine.browserBundleID = bundleID
        engine.refreshProfiles()
        AppDelegate.shared?.updateDynamicShortcuts()
        AppDelegate.shared?.updateMenu()
        refreshShortcuts()
    }
    
    public func refreshBrowserProfiles() {
        AppDelegate.shared?.handleRefreshProfiles()
        refreshShortcuts()
    }
    
    public func pasteProfileAvatar(dir: String) {
        let fakeItem = NSMenuItem()
        fakeItem.representedObject = dir
        AppDelegate.shared?.handlePasteAvatarFromClipboard(fakeItem)
        refreshShortcuts()
    }
    
    public func resetProfileAvatar(dir: String) {
        ChromeProfileEngine.shared.deleteCustomAvatar(profileDir: dir)
        AppDelegate.shared?.updateMenu()
        refreshShortcuts()
    }
    
    // MARK: - Actions: License
    
    public func activateLicenseKey() {
        let trimmed = licenseKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.activationMessage = "Please enter a valid license key."
            self.isActivationError = true
            return
        }
        
        self.isActivating = true
        self.activationMessage = nil
        
        Task { [weak self] in
            guard let self = self else { return }
            let result = await LicenseEngine.shared.activateOnlineDetailed(key: trimmed)
            self.isActivating = false
            switch result {
            case .success:
                self.activationMessage = "NNTS Pro activated successfully! All limits unlocked."
                self.isActivationError = false
                self.licenseKeyInput = ""
                self.refreshLicense()
                self.refreshShortcuts()
            case .invalidKey(let msg):
                self.activationMessage = msg
                self.isActivationError = true
            case .activationLimitReached:
                self.activationMessage = "Activation limit reached for this key."
                self.isActivationError = true
            case .networkError(let msg):
                self.activationMessage = "Network error: \(msg)"
                self.isActivationError = true
            }
            AppDelegate.shared?.updateMenu()
        }
    }
    
    public func deactivateLicense() {
        LicenseEngine.shared.deactivate()
        self.activationMessage = "License deactivated. NNTS is now in Free edition."
        self.isActivationError = false
        refreshLicense()
        refreshShortcuts()
        AppDelegate.shared?.updateMenu()
    }
    
    public func openPolarCheckout() {
        if let url = URL(string: LicenseEngine.polarCheckoutUrl) {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Shared Settings Section Box

private struct SettingsSectionBox<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    
    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.accentColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(nsColor: .labelColor))
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.40), lineWidth: 0.5)
        )
    }
}

// MARK: - Tab 1: General Settings

private struct GeneralTabContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Hardware & System
            SettingsSectionBox(title: "System Integration", icon: "keyboard") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Circle()
                            .fill(viewModel.isCapsLockRemapped ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isCapsLockRemapped ? "caps lock mapped to virtual F18" : "caps lock not remapped")
                            .font(.system(size: 12))
                            .foregroundColor(Color(nsColor: .labelColor))
                        
                        Spacer()
                        
                        if viewModel.isCapsLockRemapped {
                            Button("Restore System Default") {
                                viewModel.restoreDefaultCapsLock()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button("Apply Remapping") {
                                viewModel.reapplyCapsLockRemapping()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: viewModel.isAccessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(viewModel.isAccessibilityTrusted ? .green : .orange)
                            .font(.system(size: 12))
                        Text(viewModel.isAccessibilityTrusted ? "Accessibility permissions granted" : "Accessibility permissions required")
                            .font(.system(size: 12))
                            .foregroundColor(Color(nsColor: .labelColor))
                        
                        Spacer()
                        
                        if !viewModel.isAccessibilityTrusted {
                            Button("Open System Settings...") {
                                viewModel.openAccessibilitySettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        } else {
                            Button("Check Again") {
                                viewModel.refreshGeneral()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            
            // Features
            SettingsSectionBox(title: "Productivity Features", icon: "sparkles") {
                VStack(alignment: .leading, spacing: 12) {
                    // Copy on Select
                    Toggle(isOn: Binding(
                        get: { viewModel.isCopyOnSelectEnabled },
                        set: { viewModel.setCopyOnSelectEnabled($0) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Copy on Select")
                                .font(.system(size: 12.5, weight: .medium))
                            Text("Automatically copies text to clipboard whenever you highlight it")
                                .font(.system(size: 11))
                                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        }
                    }
                    .toggleStyle(.switch)
                    
                    Divider()
                    
                    // Finder Window Tidy
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { viewModel.isFinderTidyEnabled },
                            set: { viewModel.setFinderTidyEnabled($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Finder Window Tidy")
                                    .font(.system(size: 12.5, weight: .medium))
                                Text("Automatically closes extra background Finder windows")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            }
                        }
                        .toggleStyle(.switch)
                        
                        if viewModel.isFinderTidyEnabled {
                            HStack {
                                Text("Window Ceiling Limit:")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                
                                Picker("", selection: Binding(
                                    get: { viewModel.finderMaxWindows },
                                    set: { viewModel.setFinderMaxWindows($0) }
                                )) {
                                    Text("1 Window").tag(1)
                                    Text("3 Windows").tag(3)
                                    Text("5 Windows (Recommended)").tag(5)
                                    Text("10 Windows").tag(10)
                                    Text("Unlimited").tag(0)
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tab 2: Shortcuts (Quick Apps & Profiles)

private struct ShortcutsTabContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Quick Apps Section
            SettingsSectionBox(title: "Quick Apps (caps lock + letter)", icon: "square.grid.2x2") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        let count = viewModel.pinnedApps.count
                        let maxSlots = AppGroupEngine.maxPinnedQuickApps
                        Text(viewModel.isPro ? "\(count) apps pinned (Unlimited)" : "\(count) of \(maxSlots) slots pinned")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        
                        Spacer()
                    }
                    
                    // Pinned list
                    if viewModel.pinnedApps.isEmpty {
                        Text("No apps pinned. Search and select apps below.")
                            .font(.system(size: 11.5))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(viewModel.pinnedApps) { app in
                                HStack(spacing: 10) {
                                    Image(nsImage: app.icon)
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                    
                                    Text(app.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(nsColor: .labelColor))
                                    
                                    Spacer()
                                    
                                    Text("caps lock + \(String(app.firstLetter).lowercased())")
                                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
                                        )
                                    
                                    Button(action: {
                                        viewModel.unpinApp(bundleID: app.bundleID)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Unpin app")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                                )
                            }
                        }
                    }
                    
                    // Search bar to add apps
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .font(.system(size: 11))
                        TextField("Search apps to pin...", text: $viewModel.appSearchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5))
                            .onChange(of: viewModel.appSearchQuery) { _, _ in
                                viewModel.refreshShortcuts()
                            }
                    }
                    .padding(7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    
                    // Search dropdown results if searching
                    if !viewModel.appSearchQuery.isEmpty && !viewModel.appSearchResults.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(viewModel.appSearchResults.prefix(4)) { app in
                                HStack {
                                    Image(nsImage: app.icon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                    Text(app.name)
                                        .font(.system(size: 11.5))
                                    Spacer()
                                    let isPinned = viewModel.pinnedBundleIDs.contains(app.bundleID)
                                    if isPinned {
                                        Text("Pinned")
                                            .font(.system(size: 10.5, weight: .medium))
                                            .foregroundColor(.green)
                                    } else {
                                        Button("Pin") {
                                            viewModel.pinApp(app: app)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.mini)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        )
                    }
                }
            }
            
            // Browser Profiles Section
            SettingsSectionBox(title: "Browser Profiles (caps lock + 1..4)", icon: "person.2") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Picker("Browser:", selection: $viewModel.currentBrowserBundleID) {
                            ForEach(viewModel.availableBrowsers) { b in
                                Text(b.name).tag(b.bundleID)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 220)
                        .onChange(of: viewModel.currentBrowserBundleID) { _, newID in
                            viewModel.chooseBrowser(bundleID: newID)
                        }
                        
                        Spacer()
                        
                        Button("Refresh Profiles") {
                            viewModel.refreshBrowserProfiles()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    if viewModel.profiles.isEmpty {
                        Text("No browser profiles detected. Ensure your browser is installed.")
                            .font(.system(size: 11.5))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(viewModel.profiles) { p in
                                HStack(spacing: 10) {
                                    // Avatar
                                    ZStack {
                                        if let img = p.avatarImage {
                                            Image(nsImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 30, height: 30)
                                                .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(Color.accentColor.opacity(0.20))
                                                .frame(width: 30, height: 30)
                                            let char = p.effectiveName.first(where: { $0.isLetter || $0.isNumber }) ?? "P"
                                            Text(String(char).uppercased())
                                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                                .foregroundColor(Color.accentColor)
                                        }
                                    }
                                    .frame(width: 30, height: 30)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.effectiveName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(Color(nsColor: .labelColor))
                                            .lineLimit(1)
                                        Text("caps lock + \(p.index)")
                                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                    }
                                    
                                    Spacer()
                                    
                                    Button("Paste Avatar") {
                                        viewModel.pasteProfileAvatar(dir: p.dir)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .help("Paste image from clipboard as avatar")
                                    
                                    Button("Reset") {
                                        viewModel.resetProfileAvatar(dir: p.dir)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                    .help("Reset to monogram avatar")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Tab 3: License Settings

private struct LicenseTabContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionBox(title: "License Status", icon: "checkmark.seal") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.isPro ? "crown.fill" : "person.fill")
                            .foregroundColor(viewModel.isPro ? .yellow : Color(nsColor: .secondaryLabelColor))
                            .font(.system(size: 15))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.isPro ? "NNTS Pro Edition" : "NNTS Free Edition")
                                .font(.system(size: 13, weight: .semibold))
                            Text(viewModel.isPro ? "Unlimited Quick Apps & priority updates unlocked" : "Limited to 4 pinned quick app slots")
                                .font(.system(size: 11))
                                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        }
                        
                        Spacer()
                        
                        if viewModel.isPro {
                            Button("Deactivate") {
                                viewModel.deactivateLicense()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button("Get Pro...") {
                                viewModel.openPolarCheckout()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    
                    if !viewModel.isPro {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Activate License Key:")
                                .font(.system(size: 11.5, weight: .medium))
                            
                            HStack {
                                TextField("XXXX-XXXX-XXXX-XXXX", text: $viewModel.licenseKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11.5, design: .monospaced))
                                
                                Button("Activate") {
                                    viewModel.activateLicenseKey()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(viewModel.isActivating || viewModel.licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            
                            if let msg = viewModel.activationMessage {
                                Text(msg)
                                    .font(.system(size: 11))
                                    .foregroundColor(viewModel.isActivationError ? .red : .green)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Main Settings View

public struct SettingsView: View {
    @ObservedObject public var viewModel: SettingsViewModel
    @Namespace private var tabNamespace
    
    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Streamlined Tab Header
            HStack(spacing: 6) {
                ForEach(SettingsTab.allCases) { tab in
                    Button(action: {
                        withAnimation(NNTSMotion.magneticGlide) {
                            viewModel.selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 11.5, weight: viewModel.selectedTab == tab ? .semibold : .medium))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: viewModel.selectedTab == tab ? .semibold : .medium))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .foregroundColor(viewModel.selectedTab == tab ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))
                        .background {
                            if viewModel.selectedTab == tab {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
            )
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            Divider()
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch viewModel.selectedTab {
                    case .general:
                        GeneralTabContent(viewModel: viewModel)
                    case .shortcuts:
                        ShortcutsTabContent(viewModel: viewModel)
                    case .license:
                        LicenseTabContent(viewModel: viewModel)
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 580, minHeight: 460)
    }
}

// MARK: - Native Settings Window Panel

@MainActor
public final class SettingsWindow: NSWindow {
    public static let shared = SettingsWindow()
    public let viewModel = SettingsViewModel()
    
    private init() {
        let contentRect = NSRect(x: 0, y: 0, width: 600, height: 480)
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "NNTS Settings"
        self.titleVisibility = .visible
        self.isReleasedWhenClosed = false
        self.center()
        self.setFrameAutosaveName("NNTSSettingsWindowFrame")
        self.minSize = NSSize(width: 560, height: 440)
        
        let rootView = SettingsView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        self.contentView = hostingView
    }
    
    public func show(tab: SettingsTab? = nil) {
        if let tab = tab {
            viewModel.selectedTab = tab
        }
        viewModel.refreshAll()
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == KeyCodes.kVK_Escape {
            orderOut(nil)
            return
        }
        if event.modifierFlags.contains(.command) {
            let chars = event.charactersIgnoringModifiers?.lowercased()
            if chars == "w" || chars == "," {
                orderOut(nil)
                return
            }
            if chars == "r" {
                viewModel.refreshAll()
                return
            }
            if let firstChar = chars?.first, let digit = Int(String(firstChar)), digit >= 1 && digit <= SettingsTab.allCases.count {
                withAnimation(NNTSMotion.magneticGlide) {
                    viewModel.selectedTab = SettingsTab.allCases[digit - 1]
                }
                return
            }
        }
        super.keyDown(with: event)
    }
}
