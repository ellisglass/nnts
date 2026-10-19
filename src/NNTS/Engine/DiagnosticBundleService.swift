import Foundation
import AppKit

/// Service responsible for gathering system diagnostic data, bundling logs,
/// and creating a compressed .zip archive using macOS native `/usr/bin/ditto`.
@MainActor
public enum DiagnosticBundleService {

    public struct SystemSummary: Codable {
        public let appVersion: String
        public let buildNumber: String
        public let macosVersion: String
        public let architecture: String
        public let isAccessibilityTrusted: Bool
        public let isProLicensed: Bool
        public let timestamp: String
    }

    /// Prepares a .zip diagnostic archive in `NSTemporaryDirectory()` and returns its URL.
    public static func createDiagnosticArchive() throws -> URL {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("nnts_diag_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])

        defer {
            // Clean up raw staging directory after zipping
            try? fileManager.removeItem(at: tempDir)
        }

        // 1. Gather System Summary
        let summary = SystemSummary(
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0",
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "11",
            macosVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            architecture: getArchitecture(),
            isAccessibilityTrusted: AXIsProcessTrusted(),
            isProLicensed: LicenseEngine.shared.isPro,
            timestamp: ISO8601DateFormatter().string(from: Date())
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let summaryData = try encoder.encode(summary)
        let summaryFile = tempDir.appendingPathComponent("system-summary.json")
        try summaryData.write(to: summaryFile)

        // 2. Gather Timeline Log from TelemetryBuffer and Full Report
        let reportText = makeFullDiagnosticReport()
        let reportFile = tempDir.appendingPathComponent("diagnostic-report.txt")
        try reportText.write(to: reportFile, atomically: true, encoding: .utf8)

        let timelineText = TelemetryBuffer.shared.exportTimelineText()
        let timelineFile = tempDir.appendingPathComponent("event-timeline.log")
        try timelineText.write(to: timelineFile, atomically: true, encoding: .utf8)

        // 3. Compress using /usr/bin/ditto into final .zip file in ~/Downloads
        let downloadsDir = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let outputZipURL = downloadsDir.appendingPathComponent("nnts-diagnostic.zip")
        if fileManager.fileExists(atPath: outputZipURL.path) {
            try? fileManager.removeItem(at: outputZipURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            tempDir.path,
            outputZipURL.path
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 && fileManager.fileExists(atPath: outputZipURL.path) else {
            throw NSError(
                domain: "com.almosteleven.nnts.diagnostic",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Failed to create diagnostic archive via ditto."]
            )
        }
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: outputZipURL.path)

        return outputZipURL
    }

    /// Formats a complete human-readable diagnostic report containing the system summary
    /// and the full chronological breadcrumb timeline from TelemetryBuffer.
    public static func makeFullDiagnosticReport() -> String {
        let appVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
        let buildNum = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "11"
        let osVer = ProcessInfo.processInfo.operatingSystemVersionString
        let arch = getArchitecture()
        let axStatus = AXIsProcessTrusted() ? "Granted ✅" : "Missing ❌"
        let isPro = LicenseEngine.shared.isPro ? "Pro Active" : "Free Tier"
        let copyEngine = CopyOnSelectEngine.shared
        let copyStatus = copyEngine.isEnabled ? "Enabled (threshold: \(copyEngine.dragThreshold)pt, delay: \(copyEngine.copyDelayMs)ms)" : "Disabled"
        let timestamp = ISO8601DateFormatter().string(from: Date())

        let summaryHeader = """
        === NNTS System Diagnostic Summary ===
        App Version: v\(appVer) (Build \(buildNum))
        macOS Version: \(osVer) (\(arch))
        Accessibility Permissions: \(axStatus)
        License Status: \(isPro)
        Copy-on-Select: \(copyStatus)
        Generated At: \(timestamp)

        === Event Timeline ===
        """

        let timelineText = TelemetryBuffer.shared.exportTimelineText()
        let rawReport = "\(summaryHeader)\n\(timelineText)"
        return TelemetryBuffer.sanitizePII(rawReport)
    }

    /// Formats a concise markdown summary for GitHub Issue body.
    public static func makeGitHubIssueURL(description: String = "") -> URL? {
        let osVer = ProcessInfo.processInfo.operatingSystemVersionString
        let arch = getArchitecture()
        let appVer = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0.0"
        let isPro = LicenseEngine.shared.isPro ? "Pro Active" : "Free Tier"
        let axStatus = AXIsProcessTrusted() ? "Granted ✅" : "Missing ❌"

        let body = """
        ### 💻 System Information
        - **NNTS:** v\(appVer) (\(isPro))
        - **macOS:** \(osVer) (\(arch))
        - **Accessibility:** \(axStatus)

        ### 📝 Issue Description
        \(description.isEmpty ? "<!-- Please describe what happened or what didn't work -->" : description)

        ### 📎 Diagnostics
        *(Please attach `nnts-diagnostic.zip` by dragging it into this issue box)*
        """

        var components = URLComponents(string: "https://github.com/ellisglass/nnts/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: "[Bug Report] "),
            URLQueryItem(name: "body", value: body)
        ]
        return components?.url
    }

    private static func getArchitecture() -> String {
        #if arch(arm64)
        return "Apple Silicon (arm64)"
        #else
        return "Intel (x86_64)"
        #endif
    }
}
