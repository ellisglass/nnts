import Foundation
import Cocoa
import AppKit
import ApplicationServices
import CoreServices
import UniformTypeIdentifiers
import os

// MARK: - App Candidate
public struct AppCandidate: Sendable, Equatable {
    public let name: String
    public let bundleID: String
    public let defaultPaths: [String]
    
    public var firstLetter: Character {
        Character((name.first(where: { $0.isLetter }) ?? "A").uppercased())
    }
    
    public init(name: String, bundleID: String, defaultPaths: [String]) {
        self.name = name
        self.bundleID = bundleID
        self.defaultPaths = defaultPaths
    }
}

// MARK: - Installed Application Info
public struct InstalledAppInfo: Identifiable, Sendable, Equatable {
    public var id: String { bundleID }
    public let name: String
    public let bundleID: String
    public let path: String
    public let icon: NSImage
    
    public var firstLetter: Character {
        Character((name.first(where: { $0.isLetter }) ?? "A").uppercased())
    }
    
    public init(name: String, bundleID: String, path: String, icon: NSImage) {
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.icon = icon
    }
    
    public static func == (lhs: InstalledAppInfo, rhs: InstalledAppInfo) -> Bool {
        lhs.bundleID == rhs.bundleID && lhs.path == rhs.path && lhs.name == rhs.name
    }
}

// MARK: - App Group Engine
@MainActor
public final class AppGroupEngine: ObservableObject, @unchecked Sendable {
    public let category: String
    public var candidates: [AppCandidate]
    
    /// Test hooks
    public var customItemsOverride: [AntigravityItem]? = nil
    public var mockFrontmostBundleID: String? = nil
    
    @Published public var items: [AntigravityItem] = []
    public var lastActiveIndex: Int = 0
    
    public var activeShortcutChar: Character {
        if let selected = selectedItem {
            return Character((selected.name.first(where: { $0.isLetter }) ?? "A").uppercased())
        }
        return Character((category.first(where: { $0.isLetter }) ?? "A").uppercased())
    }
    
    public var activeShortcutKeyCode: UInt32 {
        KeyCodes.keyCode(for: activeShortcutChar) ?? KeyCodes.kVK_ANSI_A
    }
    
    /// When running in test environments, bypasses actual external process launches
    public static var bypassLaunchInTests: Bool = {
        ProcessInfo.processInfo.environment["SWIFT_DETERMINISTIC_TESTING"] != nil ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.processName.contains("Tests") ||
        ProcessInfo.processInfo.arguments.first?.contains("PackageTests") == true ||
        NSClassFromString("XCTest") != nil
    }()
    
    public func candidate(for bundleID: String) -> AppCandidate? {
        candidates.first(where: { $0.bundleID == bundleID })
    }
    
    @Published public var selectedBundleID: String? {
        didSet {
            if let id = selectedBundleID {
                UserDefaults.standard.set(id, forKey: "SelectedApp_\(category)")
            }
        }
    }
    
    public var selectedItem: AntigravityItem? {
        if let id = selectedBundleID, let found = items.first(where: { $0.bundleID == id }) {
            return found
        }
        return items.first
    }
    
    public func select(bundleID: String) {
        if items.contains(where: { $0.bundleID == bundleID }) {
            selectedBundleID = bundleID
        }
    }
    
    public func isSelected(bundleID: String) -> Bool {
        selectedItem?.bundleID == bundleID
    }
    
    private let logger: Logger
    private static let staticLogger = Logger(subsystem: "com.almosteleven.xomsky", category: "appgroup")
    
    public init(category: String, candidates: [AppCandidate]) {
        self.category = category
        self.candidates = candidates
        self.logger = Logger(subsystem: "com.almosteleven.xomsky", category: category.lowercased())
        refreshItems()
        setupAppSwitchObserver()
    }
    
    // MARK: - Pre-configured Shared Engines
    
    /// Communication Engine: Telegram, Slack, Discord, WhatsApp, Messages, Mail
    public static let communication = AppGroupEngine(
        category: "Communication",
        candidates: [
            AppCandidate(
                name: "Telegram",
                bundleID: "com.tdesktop.Telegram",
                defaultPaths: [
                    "/Applications/Telegram.app",
                    "\(NSHomeDirectory())/Applications/Telegram.app"
                ]
            ),
            AppCandidate(
                name: "Slack",
                bundleID: "com.tinyspeck.slackmacgap",
                defaultPaths: [
                    "/Applications/Slack.app",
                    "\(NSHomeDirectory())/Applications/Slack.app"
                ]
            ),
            AppCandidate(
                name: "Discord",
                bundleID: "com.hnc.Discord",
                defaultPaths: [
                    "/Applications/Discord.app",
                    "\(NSHomeDirectory())/Applications/Discord.app"
                ]
            ),
            AppCandidate(
                name: "WhatsApp",
                bundleID: "net.whatsapp.WhatsApp",
                defaultPaths: [
                    "/Applications/WhatsApp.app",
                    "\(NSHomeDirectory())/Applications/WhatsApp.app"
                ]
            ),
            AppCandidate(
                name: "Messages",
                bundleID: "com.apple.MobileSMS",
                defaultPaths: [
                    "/System/Applications/Messages.app",
                    "/Applications/Messages.app"
                ]
            ),
            AppCandidate(
                name: "Mail",
                bundleID: "com.apple.mail",
                defaultPaths: [
                    "/System/Applications/Mail.app",
                    "/Applications/Mail.app"
                ]
            )
        ]
    )
    
    /// Design & Media Engine: Figma, Spotify, Canva
    public static let design = AppGroupEngine(
        category: "Design & Media",
        candidates: [
            AppCandidate(
                name: "Figma",
                bundleID: "com.figma.Desktop",
                defaultPaths: [
                    "/Applications/Figma.app",
                    "\(NSHomeDirectory())/Applications/Figma.app"
                ]
            ),
            AppCandidate(
                name: "Spotify",
                bundleID: "com.spotify.client",
                defaultPaths: [
                    "/Applications/Spotify.app",
                    "\(NSHomeDirectory())/Applications/Spotify.app"
                ]
            ),
            AppCandidate(
                name: "Canva",
                bundleID: "com.canva.canvadesktop",
                defaultPaths: [
                    "/Applications/Canva.app",
                    "\(NSHomeDirectory())/Applications/Canva.app"
                ]
            )
        ]
    )
    
    /// Terminal Engine: iTerm2 (I), Ghostty (G), Warp (W), macOS Terminal (T)
    public static let terminal = AppGroupEngine(
        category: "Terminal",
        candidates: [
            AppCandidate(
                name: "iTerm2",
                bundleID: "com.googlecode.iterm2",
                defaultPaths: [
                    "/Applications/iTerm.app",
                    "\(NSHomeDirectory())/Applications/iTerm.app"
                ]
            ),
            AppCandidate(
                name: "Ghostty",
                bundleID: "com.mitchellh.ghostty",
                defaultPaths: [
                    "/Applications/Ghostty.app",
                    "\(NSHomeDirectory())/Applications/Ghostty.app"
                ]
            ),
            AppCandidate(
                name: "Warp",
                bundleID: "dev.warp.Warp-Stable",
                defaultPaths: [
                    "/Applications/Warp.app",
                    "\(NSHomeDirectory())/Applications/Warp.app"
                ]
            ),
            AppCandidate(
                name: "Terminal",
                bundleID: "com.apple.Terminal",
                defaultPaths: [
                    "/System/Applications/Utilities/Terminal.app",
                    "/Applications/Utilities/Terminal.app"
                ]
            )
        ]
    )
    
    /// Notes & Productivity Engine: Apple Notes (N), Notion (N), Obsidian (O), Linear (L), Keynote (K), Bear (B)
    public static let notes = AppGroupEngine(
        category: "Notes",
        candidates: [
            AppCandidate(
                name: "Notes",
                bundleID: "com.apple.Notes",
                defaultPaths: [
                    "/System/Applications/Notes.app",
                    "/Applications/Notes.app"
                ]
            ),
            AppCandidate(
                name: "Notion",
                bundleID: "notion.id",
                defaultPaths: [
                    "/Applications/Notion.app",
                    "\(NSHomeDirectory())/Applications/Notion.app"
                ]
            ),
            AppCandidate(
                name: "Obsidian",
                bundleID: "md.obsidian",
                defaultPaths: [
                    "/Applications/Obsidian.app",
                    "\(NSHomeDirectory())/Applications/Obsidian.app"
                ]
            ),
            AppCandidate(
                name: "Linear",
                bundleID: "com.linear",
                defaultPaths: [
                    "/Applications/Linear.app",
                    "\(NSHomeDirectory())/Applications/Linear.app"
                ]
            ),
            AppCandidate(
                name: "Keynote",
                bundleID: "com.apple.iWork.Keynote",
                defaultPaths: [
                    "/Applications/Keynote.app",
                    "\(NSHomeDirectory())/Applications/Keynote.app"
                ]
            ),
            AppCandidate(
                name: "Bear",
                bundleID: "net.shinyfrog.bear",
                defaultPaths: [
                    "/Applications/Bear.app",
                    "\(NSHomeDirectory())/Applications/Bear.app"
                ]
            )
        ]
    )
    
    /// IDE Engine: Antigravity IDE (A), Cursor (C), VS Code (V), Zed (Z), Xcode (X), IntelliJ IDEA (I)
    public static let ide = AppGroupEngine(
        category: "IDE",
        candidates: [
            AppCandidate(
                name: "IntelliJ IDEA",
                bundleID: "com.jetbrains.intellij",
                defaultPaths: [
                    "/Applications/IntelliJ IDEA.app",
                    "/Applications/IntelliJ IDEA Ultimate.app",
                    "/Applications/IntelliJ IDEA CE.app",
                    "\(NSHomeDirectory())/Applications/IntelliJ IDEA.app",
                    "\(NSHomeDirectory())/Applications/IntelliJ IDEA Ultimate.app",
                    "\(NSHomeDirectory())/Applications/IntelliJ IDEA CE.app"
                ]
            ),
            AppCandidate(
                name: "IntelliJ IDEA CE",
                bundleID: "com.jetbrains.intellij.ce",
                defaultPaths: [
                    "/Applications/IntelliJ IDEA CE.app",
                    "\(NSHomeDirectory())/Applications/IntelliJ IDEA CE.app"
                ]
            ),
            AppCandidate(
                name: "Antigravity IDE",
                bundleID: "com.google.antigravity-ide",
                defaultPaths: [
                    "/Applications/Antigravity IDE.app",
                    "\(NSHomeDirectory())/Applications/Antigravity IDE.app"
                ]
            ),
            AppCandidate(
                name: "Cursor",
                bundleID: "com.todesktop.230313mzl4w4u92",
                defaultPaths: [
                    "/Applications/Cursor.app",
                    "\(NSHomeDirectory())/Applications/Cursor.app"
                ]
            ),
            AppCandidate(
                name: "Visual Studio Code",
                bundleID: "com.microsoft.VSCode",
                defaultPaths: [
                    "/Applications/Visual Studio Code.app",
                    "\(NSHomeDirectory())/Applications/Visual Studio Code.app"
                ]
            ),
            AppCandidate(
                name: "Zed",
                bundleID: "dev.zed.Zed",
                defaultPaths: [
                    "/Applications/Zed.app",
                    "\(NSHomeDirectory())/Applications/Zed.app"
                ]
            ),
            AppCandidate(
                name: "Xcode",
                bundleID: "com.apple.dt.Xcode",
                defaultPaths: [
                    "/Applications/Xcode.app"
                ]
            )
        ]
    )
    
    /// AI Agent Engine: Antigravity (A), Gemini (G), Claude (C), ChatGPT (C)
    public static let aiAgent = AppGroupEngine(
        category: "AI Agent",
        candidates: [
            AppCandidate(
                name: "Antigravity",
                bundleID: "com.google.antigravity",
                defaultPaths: [
                    "/Applications/Antigravity.app",
                    "\(NSHomeDirectory())/Applications/Antigravity.app"
                ]
            ),
            AppCandidate(
                name: "Gemini",
                bundleID: "com.google.GeminiMacOS",
                defaultPaths: [
                    "/Applications/Gemini.app",
                    "\(NSHomeDirectory())/Applications/Gemini.app"
                ]
            ),
            AppCandidate(
                name: "Claude",
                bundleID: "com.anthropic.claudefordesktop",
                defaultPaths: [
                    "/Applications/Claude.app",
                    "\(NSHomeDirectory())/Applications/Claude.app"
                ]
            ),
            AppCandidate(
                name: "ChatGPT",
                bundleID: "com.openai.chat",
                defaultPaths: [
                    "/Applications/ChatGPT.app",
                    "\(NSHomeDirectory())/Applications/ChatGPT.app"
                ]
            )
        ]
    )
    
    private static func loadCustomAppCandidates() -> [AppCandidate] {
        let paths = UserDefaults.standard.stringArray(forKey: "CustomAppPaths") ?? []
        return paths.compactMap { path in
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
            let bundleID = Bundle(path: path)?.bundleIdentifier ?? "custom.\(name.lowercased())"
            return AppCandidate(name: name, bundleID: bundleID, defaultPaths: [path])
        }
    }
    
    /// Custom / User-Added Apps Engine
    public static let custom = AppGroupEngine(
        category: "Custom",
        candidates: loadCustomAppCandidates()
    )
    
    // MARK: - Discovery & Refresh
    
    public func refreshItems() {
        if category == "Custom" {
            self.candidates = Self.loadCustomAppCandidates()
        }
        
        if let override = self.customItemsOverride {
            self.items = override
            if let saved = UserDefaults.standard.string(forKey: "SelectedApp_\(category)"),
               override.contains(where: { $0.bundleID == saved }) {
                self.selectedBundleID = saved
            } else {
                self.selectedBundleID = override.first?.bundleID
            }
            return
        }
        
        var discovered: [AntigravityItem] = []
        let runningBundles = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        
        for candidate in candidates {
            var appPath: String?
            for path in candidate.defaultPaths {
                if FileManager.default.fileExists(atPath: path) {
                    appPath = path
                    break
                }
            }
            
            if appPath == nil {
                if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: candidate.bundleID) {
                    appPath = url.path
                }
            }
            
            let isRunning = runningBundles.contains(candidate.bundleID)
            let isInstalled = appPath != nil && FileManager.default.fileExists(atPath: appPath!)
            
            // Only add candidate if installed or currently running
            guard isInstalled || isRunning else { continue }
            
            let finalPath = appPath ?? candidate.defaultPaths.first ?? ""
            let icon: NSImage
            if !finalPath.isEmpty && FileManager.default.fileExists(atPath: finalPath) {
                icon = NSWorkspace.shared.icon(forFile: finalPath)
            } else if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == candidate.bundleID }),
                      let runningIcon = running.icon {
                icon = runningIcon
            } else {
                icon = makeMonogramImage(name: candidate.name)
            }
            icon.size = NSSize(width: 64, height: 64)
            
            discovered.append(
                AntigravityItem(
                    name: candidate.name,
                    bundleID: candidate.bundleID,
                    path: finalPath,
                    icon: icon,
                    index: discovered.count + 1
                )
            )
        }
        
        // Fallback if none discovered: add the last candidate (system default) only in test environments
        if discovered.isEmpty, Self.bypassLaunchInTests, let fallback = candidates.last {
            let finalPath = fallback.defaultPaths.first ?? ""
            let icon: NSImage
            if !finalPath.isEmpty && FileManager.default.fileExists(atPath: finalPath) {
                icon = NSWorkspace.shared.icon(forFile: finalPath)
            } else {
                icon = makeMonogramImage(name: fallback.name)
            }
            icon.size = NSSize(width: 64, height: 64)
            
            discovered.append(
                AntigravityItem(
                    name: fallback.name,
                    bundleID: fallback.bundleID,
                    path: finalPath,
                    icon: icon,
                    index: 1
                )
            )
        }
        
        self.items = discovered
        
        // Restore selectedBundleID from UserDefaults or default to first
        let saved = UserDefaults.standard.string(forKey: "SelectedApp_\(category)")
        if let saved = saved, discovered.contains(where: { $0.bundleID == saved }) {
            self.selectedBundleID = saved
        } else {
            self.selectedBundleID = discovered.first?.bundleID
        }
        
        logger.info("Discovered \(discovered.count) \(self.category) applications. Selected: \(self.selectedItem?.name ?? "none")")
    }
    
    private func setupAppSwitchObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  let bundleID = app.bundleIdentifier else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if let idx = self.items.firstIndex(where: { $0.bundleID == bundleID }) {
                    self.lastActiveIndex = idx
                }
            }
        }
    }
    
    /// Returns the index of the currently active/frontmost application in this group, if any.
    public func getActiveAppIndex() -> Int? {
        let frontBundleID = self.mockFrontmostBundleID ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard let bundleID = frontBundleID else { return nil }
        return items.firstIndex(where: { $0.bundleID == bundleID })
    }
    
    /// Focus the item with given bundle identifier
    public func focusItem(bundleID: String) {
        guard let item = items.first(where: { $0.bundleID == bundleID }) else {
            logger.warning("\(self.category) app with bundle ID \(bundleID) not found.")
            return
        }
        
        if let idx = items.firstIndex(where: { $0.bundleID == bundleID }) {
            lastActiveIndex = idx
        }
        
        let runningApps = NSWorkspace.shared.runningApplications
        if let running = runningApps.first(where: { $0.bundleIdentifier == bundleID }) {
            logger.info("Activating running application: \(item.name) (PID: \(running.processIdentifier))")
            if #available(macOS 14.0, *) {
                running.activate()
            } else {
                running.activate(options: .activateIgnoringOtherApps)
            }
            
            // Raise and unminimize windows
            let appElement = AXUIElementCreateApplication(running.processIdentifier)
            var windowsRef: CFTypeRef?
            var windowRaised = false
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let windows = windowsRef as? [AXUIElement], !windows.isEmpty {
                for window in windows {
                    var isMinRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &isMinRef) == .success,
                       let isMin = isMinRef as? Bool, isMin {
                        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, false as CFTypeRef)
                    }
                }
                if let first = windows.first {
                    AXUIElementPerformAction(first, kAXRaiseAction as CFString)
                    AXUIElementSetAttributeValue(first, kAXMainAttribute as CFString, true as CFTypeRef)
                    windowRaised = true
                }
            }
            
            // Special handling for Finder: if Finder is running but has no open windows, activating it leaves the user
            // on the current screen with only the menu bar changed. Open a new Finder window if none was raised!
            if bundleID == "com.apple.finder" && !windowRaised {
                Task.detached(priority: .userInitiated) {
                    let script = "tell application \"Finder\" to make new Finder window"
                    if let appleScript = NSAppleScript(source: script) {
                        var errorDict: NSDictionary?
                        appleScript.executeAndReturnError(&errorDict)
                    }
                }
            }
        } else {
            // Cold start
            if Self.bypassLaunchInTests {
                logger.info("[Test] Cold starting bypassed for: \(item.name)")
                return
            }
            logger.info("Cold starting application: \(item.name) at path \(item.path)")
            if !item.path.isEmpty && FileManager.default.fileExists(atPath: item.path) {
                let url = URL(fileURLWithPath: item.path)
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            } else {
                let task = Process()
                task.launchPath = "/usr/bin/open"
                task.arguments = ["-b", bundleID]
                try? task.run()
                task.waitUntilExit()
            }
        }
    }
    
    public func makeMonogramImage(name: String) -> NSImage {
        let size = NSSize(width: 64, height: 64)
        let img = NSImage(size: size)
        img.lockFocus()
        
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect)
        NSColor(red: 70/255, green: 130/255, blue: 230/255, alpha: 1.0).setFill()
        path.fill()
        
        let letter = String(name.prefix(1)).uppercased()
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 28),
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: letter, attributes: attrs)
        let strSize = str.size()
        let strRect = NSRect(
            x: (size.width - strSize.width) / 2,
            y: (size.height - strSize.height) / 2,
            width: strSize.width,
            height: strSize.height
        )
        str.draw(in: strRect)
        
        img.unlockFocus()
        return img
    }
    
    // MARK: - Unified Letter-Based Discovery & Selection
    
    public static var allEngines: [AppGroupEngine] {
        [communication, notes, design, aiAgent, ide, terminal, custom]
    }
    
    public static var catalogCategories: [(category: String, items: [AntigravityItem])] {
        allEngines.compactMap { engine in
            let discovered = engine.items
            guard !discovered.isEmpty else { return nil }
            return (category: engine.category, items: discovered)
        }
    }
    
    /// Maximum number of non-browser pinned quick apps (4 pinned + 1 Chrome/browser = 5 quick apps total in Free tier; unlimited in Pro)
    public static var maxPinnedQuickApps: Int {
        LicenseEngine.shared.isPro ? 26 : LicenseEngine.freePinnedAppsLimit
    }
    
    public static let freePinnedAppsLimit = 4
    
    /// Default pinned quick apps fallback (4 core apps + 1 Chrome/browser = 5 quick apps total)
    public static let defaultPinnedBundleIDs: [String] = [
        "com.google.antigravity",
        "com.google.antigravity-ide",
        "com.googlecode.iterm2",
        "com.apple.Notes"
    ]
    
    /// Discovers smart default pinned application bundle IDs on fresh installations.
    /// Prioritizes verified installed developer/workstation applications and user Dock favorites,
    /// ensuring zero dashed placeholder ('app.dashed') icons on clean macOS machines.
    public static func discoverSmartDefaultPinnedBundleIDs() -> [String] {
        var chosen: [String] = []
        let activeBrowserBundleID = ChromeProfileEngine.shared.browserBundleID
        
        // Helper to check if an app is installed on this Mac
        func isInstalled(_ bundleID: String) -> Bool {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
        }
        
        // Helper to query launch count from Spotlight metadata
        func usageCount(for bundleID: String) -> Int {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
                  let item = MDItemCreate(kCFAllocatorDefault, url.path as CFString),
                  let count = MDItemCopyAttribute(item, "kMDItemUseCount" as CFString) as? Int else {
                return 0
            }
            return count
        }
        
        // 1. Core workstation category preferences: select the best installed app per slot
        let workstationCategories: [[String]] = [
            // Terminal slot: Ghostty -> iTerm2 -> Warp -> Terminal.app (Terminal.app always present on macOS)
            ["com.mitchellh.ghostty", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.apple.Terminal"],
            // IDE / Code editor slot: Antigravity IDE -> VSCode -> Cursor -> Xcode -> Zed -> TextEdit
            ["com.google.antigravity-ide", "com.microsoft.VSCode", "com.todesktop.230313mzl4w4u92", "com.apple.dt.Xcode", "dev.zed.Zed", "com.sublimetext.4", "com.apple.TextEdit"],
            // AI Assistant / Communication slot: Antigravity -> Telegram -> Slack -> Discord -> Messages
            ["com.google.antigravity", "com.tdesktop.Telegram", "com.tinyspeck.slackmacgap", "com.hnc.Discord", "com.apple.MobileSMS"],
            // Notes & Knowledge slot: Notes.app -> Obsidian -> Notion -> Bear
            ["com.apple.Notes", "md.obsidian", "notion.id", "net.shinyfrog.bear-mac"]
        ]
        
        for category in workstationCategories {
            for bundle in category {
                if bundle != activeBrowserBundleID && isInstalled(bundle) {
                    if !chosen.contains(bundle) {
                        chosen.append(bundle)
                        break
                    }
                }
            }
        }
        
        // 2. If slots remain (< 4), inspect user's Dock persistent-apps (user-curated favorites)
        if chosen.count < freePinnedAppsLimit {
            let dockPlistPath = ("~/Library/Preferences/com.apple.dock.plist" as NSString).expandingTildeInPath
            if let dict = NSDictionary(contentsOfFile: dockPlistPath),
               let persistentApps = dict["persistent-apps"] as? [[String: Any]] {
                var dockCandidates: [(bundle: String, count: Int)] = []
                for item in persistentApps {
                    if let tileData = item["tile-data"] as? [String: Any],
                       let bundle = tileData["bundle-identifier"] as? String {
                        if bundle != activeBrowserBundleID &&
                           !bundle.lowercased().contains("chrome") &&
                           !bundle.lowercased().contains("safari") &&
                           !chosen.contains(bundle) &&
                           isInstalled(bundle) {
                            dockCandidates.append((bundle: bundle, count: usageCount(for: bundle)))
                        }
                    }
                }
                dockCandidates.sort(by: { $0.count > $1.count })
                for candidate in dockCandidates {
                    chosen.append(candidate.bundle)
                    if chosen.count >= freePinnedAppsLimit { break }
                }
            }
        }
        
        // 3. Fallback: if still fewer than 4, check defaultPinnedBundleIDs that are actually installed
        if chosen.count < freePinnedAppsLimit {
            for bundle in defaultPinnedBundleIDs {
                if !chosen.contains(bundle) && isInstalled(bundle) {
                    chosen.append(bundle)
                    if chosen.count >= freePinnedAppsLimit { break }
                }
            }
        }
        
        // 4. Guaranteed macOS native fallbacks
        let nativeFallbacks = ["com.apple.Terminal", "com.apple.Notes", "com.apple.TextEdit", "com.apple.calculator"]
        if chosen.count < freePinnedAppsLimit {
            for bundle in nativeFallbacks {
                if !chosen.contains(bundle) && isInstalled(bundle) {
                    chosen.append(bundle)
                    if chosen.count >= freePinnedAppsLimit { break }
                }
            }
        }
        
        // 5. Ultimate fallback for headless test runners with mocked candidates
        if chosen.isEmpty {
            return defaultPinnedBundleIDs
        }
        
        return Array(chosen.prefix(freePinnedAppsLimit))
    }
    
    /// Known phantom/fallback bundle IDs produced by legacy Xomsky versions when categories were empty.
    public static let legacyPhantomBundleIDs: Set<String> = [
        "com.openai.chat",
        "com.apple.dt.Xcode",
        "com.google.antigravity",
        "com.google.antigravity-ide",
        "com.googlecode.iterm2"
    ]
    
    public static let migrationV116Key = "DidMigrateLegacyPinnedAppsV116"

    /// Migrates saved pinned apps by stripping legacy phantom fallback apps that are not installed on this machine,
    /// seamlessly backfilling empty slots with genuine workstation apps from discoverSmartDefaultPinnedBundleIDs().
    public static func migrateLegacyPinnedAppsIfNeeded(force: Bool = false) {
        if !force {
            guard !bypassLaunchInTests else { return }
            guard !UserDefaults.standard.bool(forKey: migrationV116Key) else { return }
        }
        
        defer {
            UserDefaults.standard.set(true, forKey: migrationV116Key)
        }
        
        guard let saved = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs"), !saved.isEmpty else {
            return
        }
        
        func isInstalled(_ bundleID: String) -> Bool {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
        }
        
        // Check if any saved bundle ID is an uninstalled legacy phantom
        let hasUninstalledLegacyPhantom = saved.contains { bundleID in
            legacyPhantomBundleIDs.contains(bundleID) && !isInstalled(bundleID)
        }
        
        guard hasUninstalledLegacyPhantom else { return }
        
        // Keep all installed saved apps
        var validApps = saved.filter { isInstalled($0) }
        
        // If slots are below limit, backfill with smart defaults that are actually installed
        if validApps.count < freePinnedAppsLimit {
            let smartDefaults = discoverSmartDefaultPinnedBundleIDs()
            for candidate in smartDefaults {
                if !validApps.contains(candidate) && isInstalled(candidate) {
                    validApps.append(candidate)
                    if validApps.count >= freePinnedAppsLimit { break }
                }
            }
        }
        
        if validApps.isEmpty {
            validApps = defaultPinnedBundleIDs
        }
        
        let cleaned = Array(validApps.prefix(maxPinnedQuickApps))
        UserDefaults.standard.set(cleaned, forKey: "SelectedAppBundleIDs")
        staticLogger.info("Migrated legacy pinned apps. Cleaned list: \(cleaned)")
    }
    
    public static var selectedBundleIDs: Set<String> {
        get {
            if let saved = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs"), !saved.isEmpty {
                return Set(saved.prefix(maxPinnedQuickApps))
            }
            var initial: [String] = []
            let legacyKeys = [
                "SelectedApp_AI Agent",
                "SelectedApp_IDE",
                "SelectedApp_Terminal",
                "SelectedApp_Notes"
            ]
            for key in legacyKeys {
                if let val = UserDefaults.standard.string(forKey: key), !initial.contains(val) {
                    if Self.bypassLaunchInTests || NSWorkspace.shared.urlForApplication(withBundleIdentifier: val) != nil {
                        initial.append(val)
                    }
                }
            }
            if initial.isEmpty {
                initial = discoverSmartDefaultPinnedBundleIDs()
            }
            let list = Array(initial.prefix(maxPinnedQuickApps))
            UserDefaults.standard.set(list, forKey: "SelectedAppBundleIDs")
            return Set(list)
        }
        set {
            let list = Array(newValue.prefix(maxPinnedQuickApps))
            UserDefaults.standard.set(list, forKey: "SelectedAppBundleIDs")
        }
    }
    
    /// Whether more quick apps can be pinned (max 4 pinned apps + 1 Chrome/browser = 5 quick apps total)
    public static var canPinMoreApps: Bool {
        pinnedAppItems().count < maxPinnedQuickApps
    }
    
    /// Explicitly replace an existing pinned app with a new app
    public static func replaceApp(oldBundleID: String, newBundleID: String) {
        var list = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs") ?? Array(selectedBundleIDs)
        if let idx = list.firstIndex(of: oldBundleID) {
            list[idx] = newBundleID
        } else {
            list.removeAll(where: { $0 == oldBundleID })
            list.append(newBundleID)
        }
        let capped = Array(list.prefix(maxPinnedQuickApps))
        UserDefaults.standard.set(capped, forKey: "SelectedAppBundleIDs")
        selectedBundleIDs = Set(capped)
    }
    
    public static func isAppSelected(bundleID: String) -> Bool {
        selectedBundleIDs.contains(bundleID)
    }
    
    public static func selectApp(bundleID: String) {
        var list = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs") ?? Array(selectedBundleIDs)
        if !list.contains(bundleID) {
            if list.count >= maxPinnedQuickApps {
                list.removeLast()
            }
            list.append(bundleID)
            selectedBundleIDs = Set(list)
        }
    }
    
    public static func deselectApp(bundleID: String) {
        var set = selectedBundleIDs
        if set.count > 1 {
            set.remove(bundleID)
            selectedBundleIDs = set
            var list = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs") ?? []
            list.removeAll(where: { $0 == bundleID })
            UserDefaults.standard.set(list, forKey: "SelectedAppBundleIDs")
        }
    }
    
    public static func toggleApp(bundleID: String) {
        if isAppSelected(bundleID: bundleID) {
            deselectApp(bundleID: bundleID)
        } else {
            selectApp(bundleID: bundleID)
        }
    }
    
    public static func allDiscoveredItems() -> [AntigravityItem] {
        var seen = Set<String>()
        var result: [AntigravityItem] = []
        for engine in allEngines {
            for item in engine.items {
                guard !seen.contains(item.bundleID) else { continue }
                seen.insert(item.bundleID)
                result.append(item)
            }
        }
        return result
    }
    
    public static func pinnedAppItems() -> [AntigravityItem] {
        let savedList = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs") ?? Array(selectedBundleIDs)
        let all = allDiscoveredItems()
        var allMap = Dictionary(all.map { ($0.bundleID, $0) }, uniquingKeysWith: { first, _ in first })
        
        var result: [AntigravityItem] = []
        for bundleID in savedList {
            if let item = allMap[bundleID] {
                if !result.contains(where: { $0.bundleID == bundleID }) {
                    result.append(item)
                }
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                // Resilient on-the-fly resolution for system/custom apps (Finder, Settings, etc.)
                let path = url.path
                let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
                let icon = NSWorkspace.shared.icon(forFile: path)
                icon.size = NSSize(width: 64, height: 64)
                let item = AntigravityItem(
                    name: name,
                    bundleID: bundleID,
                    path: path,
                    icon: icon,
                    index: result.count + 1
                )
                result.append(item)
                allMap[bundleID] = item
                if !custom.items.contains(where: { $0.bundleID == bundleID }) {
                    custom.items.append(item)
                }
            } else if Self.bypassLaunchInTests, let candidate = allEngines.flatMap({ $0.candidates }).first(where: { $0.bundleID == bundleID }) {
                // Resilient fallback for catalog candidates (e.g. headless/CI environments or uninstalled defaults)
                let icon = NSImage(systemSymbolName: "app.dashed", accessibilityDescription: nil) ?? NSImage()
                icon.size = NSSize(width: 64, height: 64)
                let item = AntigravityItem(
                    name: candidate.name,
                    bundleID: candidate.bundleID,
                    path: candidate.defaultPaths.first ?? "",
                    icon: icon,
                    index: result.count + 1
                )
                result.append(item)
                allMap[bundleID] = item
            }
        }
        return Array(result.prefix(maxPinnedQuickApps))
    }
    
    /// Returns pinned apps grouped by their first letter, sorted alphabetically.
    public static func pinnedAppsGroupedByLetter() -> [(letter: Character, items: [AntigravityItem])] {
        let pinned = pinnedAppItems()
        var letterMap: [Character: [AntigravityItem]] = [:]
        for item in pinned {
            let char = Character((item.name.first(where: { $0.isLetter }) ?? "A").uppercased())
            if letterMap[char] == nil {
                letterMap[char] = []
            }
            letterMap[char]!.append(item)
        }
        
        return letterMap.keys.sorted().map { char in
            (letter: char, items: letterMap[char]!)
        }
    }
    
    
    /// Discovers and groups all available application items strictly by their first letter.
    public static func discoveredItemsByLetter() -> [Character: [AntigravityItem]] {
        var seen = Set<String>()
        var result: [Character: [AntigravityItem]] = [:]
        
        for engine in allEngines {
            for item in engine.items {
                guard !seen.contains(item.bundleID) else { continue }
                seen.insert(item.bundleID)
                
                let char = Character((item.name.first(where: { $0.isLetter }) ?? "A").uppercased())
                if result[char] == nil {
                    result[char] = []
                }
                result[char]?.append(item)
            }
        }
        
        return result
    }
    
    /// Register an external custom app by URL and pin it immediately.
    @discardableResult
    public static func registerCustomApp(url: URL) -> AntigravityItem? {
        let path = url.path
        guard url.isFileURL,
              url.pathExtension.lowercased() == "app",
              FileManager.default.fileExists(atPath: path) else {
            return nil
        }
        var paths = UserDefaults.standard.stringArray(forKey: "CustomAppPaths") ?? []
        if !paths.contains(path) {
            paths.append(path)
            UserDefaults.standard.set(paths, forKey: "CustomAppPaths")
        }
        
        let name = (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")
        let bundleID = Bundle(path: path)?.bundleIdentifier ?? "custom.\(name.lowercased())"
        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 64, height: 64)
        
        let item = AntigravityItem(
            name: name,
            bundleID: bundleID,
            path: path,
            icon: icon,
            index: custom.items.count + 1
        )
        
        // Sync candidates and refresh custom engine
        custom.candidates = loadCustomAppCandidates()
        custom.refreshItems()
        
        if !custom.items.contains(where: { $0.bundleID == bundleID }) {
            custom.items.append(item)
        }
        
        if canPinMoreApps {
            selectApp(bundleID: bundleID)
        }
        return item
    }
    
    /// Returns an AntigravityItem representation of the active browser from ChromeProfileEngine.
    public static func browserAsAntigravityItem() -> AntigravityItem {
        let profileEngine = ChromeProfileEngine.shared
        return AntigravityItem(
            name: profileEngine.activeBrowserName,
            bundleID: profileEngine.browserBundleID,
            path: profileEngine.activeBrowserAppPath,
            icon: profileEngine.activeBrowserIcon,
            index: 1
        )
    }
    
    /// Focus an application item across all engines, browsers, and installed macOS applications.
    public static func focusItem(bundleID: String) {
        if Self.bypassLaunchInTests {
            return
        }
        
        // 1. Browser focus
        if bundleID == ChromeProfileEngine.shared.browserBundleID ||
           ChromeProfileEngine.supportedBrowsers.contains(where: { $0.bundleID == bundleID }) {
            ChromeProfileEngine.shared.focusChrome()
            return
        }
        
        // 2. Pre-configured group engines
        if let engine = allEngines.first(where: { $0.items.contains(where: { $0.bundleID == bundleID }) }) {
            engine.focusItem(bundleID: bundleID)
            return
        }
        
        // 3. Running application (activate directly)
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            if #available(macOS 14.0, *) {
                running.activate()
            } else {
                running.activate(options: .activateIgnoringOtherApps)
            }
            return
        }
        
        // 4. Installed application on disk
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            NSWorkspace.shared.openApplication(at: appUrl, configuration: NSWorkspace.OpenConfiguration())
            return
        }
        
        // 5. Antigravity fallback
        AntigravityEngine.shared.focusItem(bundleID: bundleID)
    }
    
    // MARK: - Installed Applications Scanning & Search
    
    public static var cachedInstalledApplications: [InstalledAppInfo] = []
    
    @discardableResult
    public static func scanInstalledApplications(forceRefresh: Bool = false) -> [InstalledAppInfo] {
        if !cachedInstalledApplications.isEmpty && !forceRefresh {
            return cachedInstalledApplications
        }
        
        let fileManager = FileManager.default
        var dirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        
        let coreServicesAppsDir = URL(fileURLWithPath: "/System/Library/CoreServices/Applications")
        if fileManager.fileExists(atPath: coreServicesAppsDir.path) {
            dirs.append(coreServicesAppsDir)
        }
        
        var apps: [InstalledAppInfo] = []
        var seenBundleIDs = Set<String>()
        
        // 1. Explicitly include macOS Finder
        let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        if fileManager.fileExists(atPath: finderURL.path) {
            let bundleID = Bundle(url: finderURL)?.bundleIdentifier ?? "com.apple.finder"
            let icon = NSWorkspace.shared.icon(forFile: finderURL.path)
            icon.size = NSSize(width: 64, height: 64)
            apps.append(
                InstalledAppInfo(
                    name: "Finder",
                    bundleID: bundleID,
                    path: finderURL.path,
                    icon: icon
                )
            )
            seenBundleIDs.insert(bundleID)
        }
        
        // 2. Scan standard and additional system application directories
        for dir in dirs {
            guard let contents = try? fileManager.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsHiddenFiles]
            ) else { continue }
            
            for url in contents where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                
                // Skip uninstallers, helpers, and hidden packages
                let lowerName = name.lowercased()
                if lowerName.contains("uninstaller") || lowerName.hasPrefix(".") || lowerName.contains("crash reporter") {
                    continue
                }
                
                let bundleID = Bundle(url: url)?.bundleIdentifier ?? "app.\(lowerName.replacingOccurrences(of: " ", with: "."))"
                guard !seenBundleIDs.contains(bundleID) else { continue }
                seenBundleIDs.insert(bundleID)
                
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 64, height: 64)
                
                apps.append(
                    InstalledAppInfo(
                        name: name,
                        bundleID: bundleID,
                        path: url.path,
                        icon: icon
                    )
                )
            }
        }
        
        // 3. Include any user-registered custom app paths
        let customPaths = UserDefaults.standard.stringArray(forKey: "CustomAppPaths") ?? []
        for customPath in customPaths {
            guard fileManager.fileExists(atPath: customPath) else { continue }
            let customURL = URL(fileURLWithPath: customPath)
            let name = customURL.deletingPathExtension().lastPathComponent
            let bundleID = Bundle(url: customURL)?.bundleIdentifier ?? "custom.\(name.lowercased())"
            guard !seenBundleIDs.contains(bundleID) else { continue }
            seenBundleIDs.insert(bundleID)
            let icon = NSWorkspace.shared.icon(forFile: customPath)
            icon.size = NSSize(width: 64, height: 64)
            apps.append(
                InstalledAppInfo(
                    name: name,
                    bundleID: bundleID,
                    path: customPath,
                    icon: icon
                )
            )
        }
        
        apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        cachedInstalledApplications = apps
        return apps
    }
    
    public static func searchInstalledApplications(query: String) -> [InstalledAppInfo] {
        let all = scanInstalledApplications()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        
        let q = trimmed.lowercased()
        return all.filter { app in
            let nameMatch = app.name.lowercased().contains(q)
            let bundleMatch = app.bundleID.lowercased().contains(q)
            var aliasMatch = false
            if app.bundleID == "com.apple.systempreferences" {
                aliasMatch = "settings".contains(q) || "системные настройки".contains(q) || "настройки".contains(q)
            } else if app.bundleID == "com.apple.finder" {
                aliasMatch = "файндер".contains(q)
            }
            return nameMatch || bundleMatch || aliasMatch
        }.sorted { a, b in
            let aName = a.name.lowercased()
            let bName = b.name.lowercased()
            let aStarts = aName.hasPrefix(q)
            let bStarts = bName.hasPrefix(q)
            if aStarts && !bStarts { return true }
            if !aStarts && bStarts { return false }
            return aName.localizedStandardCompare(bName) == .orderedAscending
        }
    }
    
    /// Pins or unpins an installed application from search results.
    /// Returns true if pinned/unpinned successfully, or false if slot replacement is needed.
    @discardableResult
    public static func toggleInstalledAppPin(app: InstalledAppInfo) -> Bool {
        if isAppSelected(bundleID: app.bundleID) {
            deselectApp(bundleID: app.bundleID)
            return true
        } else {
            let url = URL(fileURLWithPath: app.path)
            registerCustomApp(url: url)
            
            if isAppSelected(bundleID: app.bundleID) {
                return true
            }
            
            if canPinMoreApps {
                selectApp(bundleID: app.bundleID)
                return true
            } else {
                return false
            }
        }
    }
}

