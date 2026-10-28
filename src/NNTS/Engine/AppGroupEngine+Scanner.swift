import Foundation
import Cocoa
import AppKit
import CoreServices
import os

// MARK: - Installed Applications Scanning & Search
extension AppGroupEngine {
    
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
