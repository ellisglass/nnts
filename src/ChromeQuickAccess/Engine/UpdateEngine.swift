import Foundation
import AppKit
import os

public enum InstallationSource: String, Sendable, Equatable {
    case homebrew
    case directDownload
}

public final class UpdateEngine: Sendable {
    private static let logger = Logger(subsystem: "com.almosteleven.nnts", category: "update-engine")
    
    public static let directDmgDownloadUrl = URL(string: "https://github.com/ellisglass/nnts/releases/latest/download/NNTS.dmg")!
    
    public static let homebrewUpgradeCommand = "brew update && brew upgrade --cask nnts"
    
    public static func detectInstallationSource(
        bundlePath: String = Bundle.main.bundlePath,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> InstallationSource {
        // 1. Running directly out of Caskroom
        if bundlePath.contains("Caskroom/nnts") {
            return .homebrew
        }
        
        // 2. Common Homebrew Cask metadata locations on Apple Silicon and Intel Macs
        let commonCaskPaths = [
            "/opt/homebrew/Caskroom/nnts",
            "/usr/local/Caskroom/nnts"
        ]
        if commonCaskPaths.contains(where: { fileExists($0) }) {
            return .homebrew
        }
        
        return .directDownload
    }
    
    @discardableResult
    public static func runHomebrewUpgradeInTerminal(
        workspaceOpen: (URL) -> Bool = { NSWorkspace.shared.open($0) }
    ) -> Bool {
        // 1. Primary approach: Launch an executable .command script.
        // Opening a .command file executes directly in Terminal without requiring TCC AppleEvents permissions.
        // Isolate the script inside a uniquely generated, restricted (0700) subdirectory to prevent symlink / race attacks.
        let isolatedDir = FileManager.default.temporaryDirectory.appendingPathComponent("nnts-upg-\(UUID().uuidString)", isDirectory: true)
        let tempScriptUrl = isolatedDir.appendingPathComponent("nnts-upgrade.command")
        let scriptContent = """
        #!/bin/bash
        echo "=========================================="
        echo "        Upgrading NNTS via Homebrew       "
        echo "=========================================="
        echo ""
        echo "==> Fetching latest tap recipes (brew update)..."
        brew update
        echo ""
        echo "==> Upgrading NNTS cask..."
        if brew upgrade --cask nnts; then
            echo ""
            echo "=========================================="
            echo "     NNTS successfully upgraded!          "
            echo "     Restart NNTS to apply changes.       "
            echo "=========================================="
        else
            echo ""
            echo "=========================================="
            echo "    Upgrade encountered an issue.         "
            echo "    Try running: brew reinstall --cask nnts"
            echo "=========================================="
        fi
        echo ""
        read -n 1 -s -r -p "Press any key to close this terminal window..."
        echo ""
        """
        
        do {
            try FileManager.default.createDirectory(at: isolatedDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            try scriptContent.write(to: tempScriptUrl, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: tempScriptUrl.path)
            if workspaceOpen(tempScriptUrl) {
                logger.info("Successfully launched upgrade .command script in Terminal via LaunchServices.")
                return true
            }
        } catch {
            logger.error("Failed to write temporary .command script: \(error.localizedDescription)")
        }
        
        // 2. Secondary fallback: AppleScript (if .command launch is unavailable)
        let scriptSource = """
        tell application "Terminal"
            activate
            do script "\(homebrewUpgradeCommand)"
        end tell
        """
        
        if let appleScript = NSAppleScript(source: scriptSource) {
            var errorInfo: NSDictionary?
            appleScript.executeAndReturnError(&errorInfo)
            if let error = errorInfo {
                logger.error("Failed to execute AppleScript for Terminal: \(String(describing: error))")
                return false
            }
            logger.info("Successfully launched upgrade command via AppleScript.")
            return true
        }
        
        logger.error("Could not instantiate NSAppleScript for Terminal launch.")
        return false
    }
    
    /// Extracts concise bullet points from a markdown release notes body.
    /// Filters out changelog compare links, trims markdown symbols, and enforces maximum bullet count.
    public static func parseReleaseHighlights(from body: String?, maxBullets: Int = 4) -> [String] {
        guard let body = body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        var highlights: [String] = []
        let lines = body.components(separatedBy: .newlines)
        
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("* ") || line.hasPrefix("- ") || line.hasPrefix("• ") else {
                continue
            }
            
            // Drop bullet prefix
            var content = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            
            // Filter out git log / compare links or empty lines
            if content.lowercased().hasPrefix("full changelog") || content.hasPrefix("http") {
                continue
            }
            
            // Remove markdown bold / code formatting for clean Cocoa text
            content = content.replacingOccurrences(of: "**", with: "")
            content = content.replacingOccurrences(of: "`", with: "")
            
            // Trim author PR suffixes like "by @author in https://..."
            if let prRange = content.range(of: " by @") {
                content = String(content[..<prRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
            
            if !content.isEmpty {
                highlights.append(content)
                if highlights.count >= maxBullets {
                    break
                }
            }
        }
        
        return highlights
    }
}
