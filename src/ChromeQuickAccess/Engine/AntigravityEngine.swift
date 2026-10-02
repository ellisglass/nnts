import Foundation
import Cocoa
import AppKit
import ApplicationServices
import os

// MARK: - Antigravity App Item
public struct AntigravityItem: Identifiable, Sendable, Equatable {
    public let id: String // bundleID
    public let name: String
    public let bundleID: String
    public let path: String
    public let icon: NSImage
    public let index: Int
    
    public init(name: String, bundleID: String, path: String, icon: NSImage, index: Int) {
        self.id = bundleID
        self.name = name
        self.bundleID = bundleID
        self.path = path
        self.icon = icon
        self.index = index
    }
    
    public static func == (lhs: AntigravityItem, rhs: AntigravityItem) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name && lhs.index == rhs.index
    }
}

// MARK: - Antigravity Engine
@MainActor
public final class AntigravityEngine: ObservableObject, @unchecked Sendable {
    public static let shared = AntigravityEngine()
    
    public static let antigravityBundleID = "com.google.antigravity"
    public static let antigravityIdeBundleID = "com.google.antigravity-ide"
    
    /// Test hook for simulating installed applications
    public static var customItemsOverride: [AntigravityItem]? = nil
    /// Test hook for mocking frontmost app bundle identifier
    public static var mockFrontmostBundleID: String? = nil
    
    @Published public var items: [AntigravityItem] = []
    public var lastActiveIndex: Int = 0
    
    private let logger = Logger(subsystem: "com.almosteleven.nnts", category: "antigravity")
    
    public init() {
        refreshItems()
        setupAppSwitchObserver()
    }
    
    public func refreshItems() {
        if let override = Self.customItemsOverride {
            self.items = override
            return
        }
        
        var discovered: [AntigravityItem] = []
        
        let candidates: [(name: String, bundleID: String, defaultPaths: [String])] = [
            (
                name: "Antigravity",
                bundleID: Self.antigravityBundleID,
                defaultPaths: [
                    "/Applications/Antigravity.app",
                    "\(NSHomeDirectory())/Applications/Antigravity.app"
                ]
            ),
            (
                name: "Antigravity IDE",
                bundleID: Self.antigravityIdeBundleID,
                defaultPaths: [
                    "/Applications/Antigravity IDE.app",
                    "\(NSHomeDirectory())/Applications/Antigravity IDE.app"
                ]
            )
        ]
        
        for (idx, candidate) in candidates.enumerated() {
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
                    index: idx + 1
                )
            )
        }
        
        self.items = discovered
        logger.info("Discovered \(discovered.count) Antigravity applications.")
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
    
    /// Returns the index of the currently active/frontmost Antigravity application, if any.
    public func getActiveAppIndex() -> Int? {
        let frontBundleID = Self.mockFrontmostBundleID ?? NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard let bundleID = frontBundleID else { return nil }
        return items.firstIndex(where: { $0.bundleID == bundleID })
    }
    
    /// Focus the item with given bundle identifier
    public func focusItem(bundleID: String) {
        guard let item = items.first(where: { $0.bundleID == bundleID }) else {
            logger.warning("Antigravity app with bundle ID \(bundleID) not found.")
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
            
            // Raise and unminimize windows if needed
            let appElement = AXUIElementCreateApplication(running.processIdentifier)
            var windowsRef: CFTypeRef?
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
                }
            }
        } else {
            // Cold start
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
}
