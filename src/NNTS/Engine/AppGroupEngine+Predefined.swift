import Foundation
import Cocoa
import AppKit
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

// MARK: - Pre-configured Shared Engines
extension AppGroupEngine {
    
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
    
    internal static func loadCustomAppCandidates() -> [AppCandidate] {
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
}
