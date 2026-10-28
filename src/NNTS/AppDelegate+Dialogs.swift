//
//  AppDelegate+Dialogs.swift
//  NNTS (macOS Productivity Suite)
//
//  Dialogs, Alerts, Modal Prompts, and External Action Presentation.
//

import Cocoa
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import os

// MARK: - Dialogs & User Prompts
extension AppDelegate {
    
    // MARK: - Profile Replacement Dialog
    
    internal func promptProfileReplacement(newDir: String) {
        let profileEngine = ChromeProfileEngine.shared
        let newProfileName = profileEngine.profiles.first(where: { $0.dir == newDir })?.effectiveName ?? newDir
        
        let alert = NSAlert()
        alert.messageText = "Browser Profiles Limit Reached (\(ChromeProfileEngine.maxProfileSlots) of \(ChromeProfileEngine.maxProfileSlots))"
        alert.informativeText = "NNTS supports up to \(ChromeProfileEngine.maxProfileSlots) quick profiles (caps lock + 1..8).\n\nAll \(ChromeProfileEngine.maxProfileSlots) profile slots are currently in use. Choose which profile slot to replace with '\(newProfileName)':"
        alert.alertStyle = .informational
        
        let popUp = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 300, height: 26))
        for p in profileEngine.selectedProfiles {
            popUp.addItem(withTitle: "Slot \(p.index): \(p.effectiveName)")
            popUp.lastItem?.representedObject = p.dir
            if let avatar = p.avatarImage?.copy() as? NSImage {
                avatar.size = NSSize(width: 16, height: 16)
                popUp.lastItem?.image = avatar
                popUp.lastItem?.ensureImageVisibleOnMacOS27()
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
    
    // MARK: - App Replacement Dialog
    
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
                popUp.lastItem?.ensureImageVisibleOnMacOS27()
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
    
    // MARK: - License Dialogs & Prompts
    
    @objc public func handleManageLicense() {
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
    
    internal func promptEnterLicenseKey(thenPinBundleID: String? = nil) {
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
    
    internal func showActivationSuccess(thenPinBundleID: String?) {
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
    
    internal func showActivationError(message: String) {
        let errorAlert = NSAlert()
        errorAlert.messageText = "Activation Failed"
        errorAlert.informativeText = message
        errorAlert.alertStyle = .warning
        errorAlert.addButton(withTitle: "OK")
        errorAlert.runModal()
    }
    
    // MARK: - About & Updates
    
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
    
    internal func showUpdateAvailableAlert(latestVersion: String, releaseUrl: String, releaseNotes: String? = nil) {
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
    
    internal func showUpToDateAlert(currentVersion: String) {
        let alert = NSAlert()
        alert.messageText = "NNTS is Up to Date"
        alert.informativeText = "Version \(currentVersion) is currently the newest version available."
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage ?? AppDelegate.makeStatusIcon()
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    // MARK: - Accessibility Permissions Prompt
    
    internal func promptForAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    // MARK: - Feedback & Diagnostics Window
    
    @objc public func handleReportIssue() {
        if let existing = feedbackWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hostingView = NSHostingView(rootView: FeedbackWindowView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.level = .floating
        
        self.feedbackWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
