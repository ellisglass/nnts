import SwiftUI
import AppKit
import UniformTypeIdentifiers

public final class FeedbackViewModel: ObservableObject {
    @Published public var zipURL: URL? = nil
    @Published public var isPreparingArchive: Bool = true
    @Published public var errorMessage: String? = nil
    @Published public var copiedNotice: Bool = false
    public init() {}
}

public struct FeedbackWindowView: View {
    @ObservedObject private var viewModel = FeedbackViewModel()

    private let telegramSupportURL = URL(string: "https://t.me/xomsky_app")!

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "ladybug.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Report an Issue")
                        .font(.headline)
                        .fontWeight(.semibold)
                    Text("Zero-telemetry diagnostics. Inspect or share on your terms.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            // Diagnostic File Card with Drag and Drop
            VStack(spacing: 12) {
                if viewModel.isPreparingArchive {
                    ProgressView("Packaging diagnostics...")
                        .frame(height: 90)
                } else if let zipURL = viewModel.zipURL {
                    VStack(spacing: 8) {
                        Image(systemName: "doc.zipper")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 44, height: 44)
                            .foregroundColor(.orange)

                        Text("xomsky-diagnostic.zip")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))

                        Text("Drag & drop this file directly into Telegram, WhatsApp, or Finder")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color(NSColor.controlBackgroundColor)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .onDrag {
                        let provider = NSItemProvider(object: zipURL as NSURL)
                        provider.suggestedName = "xomsky-diagnostic.zip"
                        return provider
                    }
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 90)
                }
            }

            // Action Buttons
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Button(action: openTelegram) {
                        HStack(spacing: 8) {
                            Image(nsImage: Self.telegramIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("Telegram Chat")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: openGitHub) {
                        HStack(spacing: 8) {
                            Image(nsImage: Self.gitHubIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                            Text("GitHub Issue")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }

                HStack(spacing: 12) {
                    Button(action: revealInFinder) {
                        HStack(spacing: 6) {
                            Image(nsImage: Self.finderIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            Text("Show in Finder")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .disabled(viewModel.zipURL == nil)

                    Button(action: copyDiagnosticsToClipboard) {
                        Label(viewModel.copiedNotice ? "Copied! ✅" : "Copy Raw Log", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(22)
        .frame(width: 460)
        .onAppear {
            generateArchive()
        }
    }

    private func generateArchive() {
        Task { @MainActor in
            do {
                let url = try DiagnosticBundleService.createDiagnosticArchive()
                viewModel.zipURL = url
                viewModel.isPreparingArchive = false
            } catch {
                viewModel.errorMessage = "Failed to bundle diagnostics: \(error.localizedDescription)"
                viewModel.isPreparingArchive = false
            }
        }
    }

    private func openTelegram() {
        NSWorkspace.shared.open(telegramSupportURL)
    }

    private func openGitHub() {
        if let ghURL = DiagnosticBundleService.makeGitHubIssueURL() {
            NSWorkspace.shared.open(ghURL)
        }
    }

    private func revealInFinder() {
        guard let zipURL = viewModel.zipURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([zipURL])
    }

    private func copyDiagnosticsToClipboard() {
        let text = DiagnosticBundleService.makeFullDiagnosticReport()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        withAnimation {
            viewModel.copiedNotice = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                viewModel.copiedNotice = false
            }
        }
    }

    // MARK: - Native Application Icon Resolvers
    public static var finderIcon: NSImage {
        let path = "/System/Library/CoreServices/Finder.app"
        if FileManager.default.fileExists(atPath: path) {
            let icon = NSWorkspace.shared.icon(forFile: path)
            icon.size = NSSize(width: 32, height: 32)
            return icon
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 32, height: 32)
            return icon
        }
        return NSWorkspace.shared.icon(for: .folder)
    }

    public static var telegramIcon: NSImage {
        let bundleIDs = ["ru.keepcoder.Telegram", "org.telegram.desktop"]
        for bid in bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                icon.size = NSSize(width: 32, height: 32)
                return icon
            }
        }
        let standardAppPath = "/Applications/Telegram.app"
        if FileManager.default.fileExists(atPath: standardAppPath) {
            let icon = NSWorkspace.shared.icon(forFile: standardAppPath)
            icon.size = NSSize(width: 32, height: 32)
            return icon
        }
        return makeTelegramVectorIcon()
    }

    private static func makeTelegramVectorIcon() -> NSImage {
        let svg = """
        <svg width="32" height="32" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <circle cx="12" cy="12" r="12" fill="#2AABEE"/>
            <path d="M5.4 11.9l11.4-4.8c.5-.2 1 .1.8.7l-1.9 9.1c-.1.6-.5.7-1 .4l-2.8-2.1-1.3 1.3c-.2.2-.3.3-.6.3l.2-2.8 5.1-4.6c.2-.2 0-.3-.3-.1l-6.3 4-2.7-.9c-.6-.2-.6-.6.1-.9z" fill="#ffffff"/>
        </svg>
        """
        if let data = svg.data(using: .utf8), let img = NSImage(data: data) {
            img.size = NSSize(width: 32, height: 32)
            return img
        }
        return NSImage(systemSymbolName: "paperplane.fill", accessibilityDescription: nil) ?? NSImage()
    }

    public static var gitHubIcon: NSImage {
        let bundleID = "com.github.GitHubClient"
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: url.path)
            icon.size = NSSize(width: 32, height: 32)
            return icon
        }
        let standardAppPath = "/Applications/GitHub Desktop.app"
        if FileManager.default.fileExists(atPath: standardAppPath) {
            let icon = NSWorkspace.shared.icon(forFile: standardAppPath)
            icon.size = NSSize(width: 32, height: 32)
            return icon
        }
        return makeGitHubVectorIcon()
    }

    private static func makeGitHubVectorIcon() -> NSImage {
        let svg = """
        <svg width="32" height="32" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
            <circle cx="12" cy="12" r="12" fill="#24292f"/>
            <path d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.53 1.032 1.53 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" fill="#ffffff"/>
        </svg>
        """
        if let data = svg.data(using: .utf8), let img = NSImage(data: data) {
            img.size = NSSize(width: 32, height: 32)
            return img
        }
        return NSImage(systemSymbolName: "arrow.up.forward.app", accessibilityDescription: nil) ?? NSImage()
    }
}
