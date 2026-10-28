import Cocoa
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import os

// MARK: - Menu Bar Status Menu & Action Routing
extension AppDelegate {
    internal func makeAlignedMenuItem(
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
            item.ensureImageVisibleOnMacOS27()
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
        
        appendBrowserAndProfileSection(to: menu)
        menu.addItem(NSMenuItem.separator())
        
        appendPreferencesSection(to: menu)
        menu.addItem(NSMenuItem.separator())
        
        appendDiagnosticsAndAboutSection(to: menu)
        
        return menu
    }
    
    // MARK: - Section Builders
    
    internal func appendBrowserAndProfileSection(to menu: NSMenu) {
        let profileEngine = ChromeProfileEngine.shared
        let selectedList = profileEngine.selectedProfiles
        
        let browserChar = profileEngine.primaryShortcutChar
        let browserCharStr = String(browserChar).lowercased()
        
        // Track whether any pinned apps share the browser's shortcut key
        let rawPinned = AppGroupEngine.pinnedAppItems()
        let matchingPinned = rawPinned.filter { item in
            Character((item.name.first(where: { $0.isLetter }) ?? "A").uppercased()) == browserChar
        }
        let totalBrowserSharing = matchingPinned.isEmpty ? 1 : 1 + matchingPinned.count
        
        // Chrome / Browser section (caps lock + browser shortcut)
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
            accessibilityHelp: "Hold caps lock and press \(browserChar) to switch to \(browserName)",
            action: #selector(handleActivateBrowserClick(_:)),
            target: self
        )
        
        if totalBrowserSharing > 1 {
            let attr = NSMutableAttributedString(string: browserTitle)
            let badge = NSAttributedString(
                string: " · 1/\(totalBrowserSharing) ↻",
                attributes: [
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular)
                ]
            )
            attr.append(badge)
            chromeItem.attributedTitle = attr
            chromeItem.toolTip = "Hold caps lock and press \(browserChar) to cycle (1 of \(totalBrowserSharing): \(browserName))"
        } else {
            chromeItem.toolTip = "Hold caps lock and press \(browserChar) to switch to \(browserName)"
        }
        menu.addItem(chromeItem)
        
        let displayProfiles = !selectedList.isEmpty ? selectedList : (profileEngine.profiles.first != nil ? [profileEngine.profiles.first!] : [])
        if !displayProfiles.isEmpty {
            let stripItem = NSMenuItem()
            stripItem.title = "Profiles"
            stripItem.view = ProfileStripView(profiles: displayProfiles, activeDir: profileEngine.getActiveProfileDir())
            menu.addItem(stripItem)
        }
    }
    
    internal func appendPreferencesSection(to menu: NSMenu) {
        // Preferences & System Controls
        let isCopyEnabled = CopyOnSelectEngine.shared.isEnabled
        let copyStatusItem = makeAlignedMenuItem(
            title: "Copy on Select",
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
        
        // Finder Window Tidy Section
        let finderTidyEngine = FinderTidyEngine.shared
        let finderWindows = finderTidyEngine.getOpenFinderWindows()
        let finderWindowCount = finderWindows.count
        
        let finderTidyItem = makeAlignedMenuItem(
            title: "Finder Window Tidy",
            icon: NSImage(systemSymbolName: "macwindow.on.rectangle", accessibilityDescription: "Finder Windows"),
            accessibilityHelp: "Manage open Finder windows",
            target: self
        )
        if finderWindowCount > 1 {
            let tidyAttr = NSMutableAttributedString(string: "Finder Window Tidy")
            let tidyBadge = NSAttributedString(
                string: " · \(finderWindowCount) open",
                attributes: [
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular)
                ]
            )
            tidyAttr.append(tidyBadge)
            finderTidyItem.attributedTitle = tidyAttr
        }
        
        let tidySubmenu = NSMenu()
        
        let tidyNowItem = NSMenuItem(
            title: "Tidy Windows Now",
            action: #selector(handleFinderTidyNow),
            keyEquivalent: ""
        )
        tidyNowItem.target = self
        tidyNowItem.isEnabled = finderWindowCount > 1
        tidySubmenu.addItem(tidyNowItem)
        
        let closeDupesItem = NSMenuItem(
            title: "Close Duplicate Windows",
            action: #selector(handleFinderCloseDuplicates),
            keyEquivalent: ""
        )
        closeDupesItem.target = self
        closeDupesItem.isEnabled = finderWindowCount > 1
        tidySubmenu.addItem(closeDupesItem)
        
        tidySubmenu.addItem(NSMenuItem.separator())
        
        let toggleAutoItem = NSMenuItem(
            title: "Auto-Tidy (Keep Max 5 Windows)",
            action: #selector(handleToggleFinderTidyEnabled),
            keyEquivalent: ""
        )
        toggleAutoItem.target = self
        toggleAutoItem.state = finderTidyEngine.isEnabled ? .on : .off
        tidySubmenu.addItem(toggleAutoItem)
        
        finderTidyItem.submenu = tidySubmenu
        menu.addItem(finderTidyItem)
        
        let settingsItem = makeAlignedMenuItem(
            title: "Settings...",
            keyEquivalent: ",",
            modifierMask: [.command],
            accessibilityHelp: "Configure quick apps, browser profiles, copy on select, and system shortcuts",
            action: #selector(handleOpenSettings),
            target: self
        )
        menu.addItem(settingsItem)
        
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
    }
    
    internal func appendDiagnosticsAndAboutSection(to menu: NSMenu) {
        // About & Diagnostics
        let aboutItem = makeAlignedMenuItem(
            title: "About NNTS...",
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
            accessibilityHelp: "Open diagnostics and report an issue",
            action: #selector(handleReportIssue),
            target: self
        )
        menu.addItem(reportItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = makeAlignedMenuItem(
            title: "Quit NNTS",
            keyEquivalent: "q",
            modifierMask: [.command],
            accessibilityHelp: "Quit the application",
            action: #selector(handleQuit),
            target: self
        )
        menu.addItem(quitItem)
    }
    
    // MARK: - Status Menu Action Handlers
    
    @objc internal func handleChangeProfileClick(_ sender: NSMenuItem) {
        guard let dir = sender.representedObject as? String else { return }
        let profileEngine = ChromeProfileEngine.shared
        if profileEngine.isProfileSelected(dir: dir) {
            profileEngine.deselectProfile(dir: dir)
            updateMenu()
        } else {
            if profileEngine.selectedProfiles.count < ChromeProfileEngine.maxProfileSlots {
                profileEngine.selectProfile(dir: dir)
                updateMenu()
            } else {
                promptProfileReplacement(newDir: dir)
            }
        }
    }
    
    @objc internal func handleActivateBrowserClick(_ sender: NSMenuItem) {
        ChromeProfileEngine.shared.focusChrome()
    }
    
    @objc internal func handleProfileClick(_ sender: NSMenuItem) {
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
    
    @objc internal func handleCoreAppClick(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        self.focusApp(bundleID: bundleID)
    }
    
    @objc internal func handleChangeAppItemClick(_ sender: NSMenuItem) {
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
    
    @objc internal func handleAppItemClick(_ sender: NSMenuItem) {
        handleCoreAppClick(sender)
    }
    
    @objc internal func handleTerminalClick(_ sender: NSMenuItem) {
        handleAppItemClick(sender)
    }
    
    @objc internal func handleAiAgentClick(_ sender: NSMenuItem) {
        handleAppItemClick(sender)
    }
    
    @objc internal func handleAntigravityClick(_ sender: NSMenuItem) {
        handleAppItemClick(sender)
    }
    
    @objc internal func handleIdeClick(_ sender: NSMenuItem) {
        handleAppItemClick(sender)
    }
    
    @objc internal func handleNotesClick(_ sender: NSMenuItem) {
        handleAppItemClick(sender)
    }
    
    @objc internal func handleMultiAppCycleClick(_ sender: NSMenuItem) {
        guard let repr = sender.representedObject as? String else { return }
        let bundleIDs = repr.split(separator: ",").map(String.init)
        guard let targetBundleID = AppGroupEngine.prioritizedBundleID(from: bundleIDs) ?? bundleIDs.first else { return }
        self.focusApp(bundleID: targetBundleID)
    }
    
    @objc internal func handleUnpinAppClick(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        AppGroupEngine.deselectApp(bundleID: bundleID)
        updateDynamicShortcuts()
        updateMenu()
    }
    
    @objc internal func handleTogglePinAppClick(_ sender: NSMenuItem) {
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
    
    @objc internal func handleSelectBrowserClick(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        ChromeProfileEngine.shared.selectBrowser(bundleID: bundleID)
        updateDynamicShortcuts()
        updateMenu()
    }
    
    @objc public func handleUpgradeToPro() {
        if let url = URL(string: LicenseEngine.polarCheckoutUrl) {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc internal func handleEnterLicenseKeyFromMenu() {
        promptEnterLicenseKey()
    }
    
    @objc public func handleOpenSettings() {
        MinimalHUDWindow.shared.hideImmediate()
        SettingsWindow.shared.show()
    }
    
    @objc public func handleOpenAppSearch() {
        MinimalHUDWindow.shared.hideImmediate()
        AppSearchPickerWindow.shared.show()
    }
    
    public func handleChooseOtherAppFromExternal() {
        handleChooseOtherApp()
    }
    
    @objc internal func handleChooseOtherApp() {
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
    
    @objc public func handleRefreshProfiles() {
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
    
    @objc internal func handleToggleCopyOnSelect() {
        CopyOnSelectEngine.shared.isEnabled.toggle()
        if CopyOnSelectEngine.shared.isEnabled {
            CopyOnSelectEngine.shared.start()
        } else {
            CopyOnSelectEngine.shared.stop()
        }
        updateMenu()
    }
    
    // MARK: - Finder Window Tidy Action Handlers
    @objc internal func handleFinderTidyNow() {
        let closed = FinderTidyEngine.shared.tidyNow(keepCount: 1)
        logger.info("Manual Finder tidy executed: closed \(closed) windows.")
        TelemetryBuffer.shared.append(category: "finder-tidy", level: "INFO", message: "Manual Finder tidy: closed \(closed) windows.")
        if closed > 0 {
            NSSound(named: "Hero")?.play()
        }
        updateMenu()
    }
    
    @objc internal func handleFinderTidyToMax() {
        let maxLimit = FinderTidyEngine.shared.maxWindows
        let closed = FinderTidyEngine.shared.enforceMaxWindows(limit: maxLimit)
        logger.info("Finder tidy to max (\(maxLimit)) executed: closed \(closed) windows.")
        TelemetryBuffer.shared.append(category: "finder-tidy", level: "INFO", message: "Finder tidy to max (\(maxLimit)): closed \(closed) windows.")
        if closed > 0 {
            NSSound(named: "Hero")?.play()
        }
        updateMenu()
    }
    
    @objc internal func handleFinderCloseDuplicates() {
        let closed = FinderTidyEngine.shared.closeDuplicateWindows()
        logger.info("Finder close duplicates executed: closed \(closed) windows.")
        TelemetryBuffer.shared.append(category: "finder-tidy", level: "INFO", message: "Finder close duplicates: closed \(closed) windows.")
        if closed > 0 {
            NSSound(named: "Hero")?.play()
        }
        updateMenu()
    }
    
    @objc internal func handleToggleFinderTidyEnabled() {
        FinderTidyEngine.shared.isEnabled.toggle()
        if FinderTidyEngine.shared.isEnabled {
            FinderTidyEngine.shared.start()
        } else {
            FinderTidyEngine.shared.stop()
        }
        updateMenu()
    }
    
    @objc internal func handleSetFinderMaxWindows(_ sender: NSMenuItem) {
        guard let limit = sender.representedObject as? Int else { return }
        FinderTidyEngine.shared.maxWindows = limit
        updateMenu()
    }
    
    @objc internal func handleToggleFinderAutoDuplicates() {
        FinderTidyEngine.shared.closeDuplicates.toggle()
        updateMenu()
    }
    
    @objc internal func handleToggleFinderInactivity() {
        if FinderTidyEngine.shared.inactivityMinutes > 0 {
            FinderTidyEngine.shared.inactivityMinutes = 0
        } else {
            FinderTidyEngine.shared.inactivityMinutes = 60
        }
        updateMenu()
    }
    
    @objc internal func handleOpenAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    @objc internal func handleOpenFullDiskAccessSettings() {
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
    
    @objc internal func handleQuit() {
        NSApplication.shared.terminate(nil)
    }
}
