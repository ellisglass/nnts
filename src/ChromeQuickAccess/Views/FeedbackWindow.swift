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

    private let telegramSupportURL = URL(string: "https://t.me/nnts_app")!

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Header Bar (Identical to Settings & Avatar Assistant)
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                    Text("Report an Issue")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.88))
                }
                
                // Zero Telemetry Pill
                HStack(spacing: 3) {
                    Image(systemName: "shield.checkerboard")
                        .font(.system(size: 9, weight: .bold))
                    Text("Zero Telemetry")
                        .font(.system(size: 9.5, weight: .bold))
                }
                .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.50))
                .padding(.horizontal, 6)
                .padding(.vertical, 2.5)
                .background(
                    Capsule().fill(Color(red: 0.35, green: 0.85, blue: 0.50).opacity(0.18))
                )
                .overlay(
                    Capsule().stroke(Color(red: 0.35, green: 0.85, blue: 0.50).opacity(0.35), lineWidth: 0.75)
                )
                
                Spacer()
                
                // Close button
                Button(action: {
                    NSApp.keyWindow?.close()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.40))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            Divider()
                .opacity(0.4)
            
            // 2. Body Content
            VStack(spacing: 12) {
                // Diagnostic File Card with Drag and Drop
                VStack(spacing: 10) {
                    if viewModel.isPreparingArchive {
                        ProgressView("Packaging diagnostics...")
                            .frame(height: 80)
                    } else if let zipURL = viewModel.zipURL {
                        VStack(spacing: 6) {
                            Image(systemName: "doc.zipper")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.orange)
                            
                            Text("nnts-diagnostic.zip")
                                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.90))
                            
                            Text("Drag & drop this file directly into Telegram, WhatsApp, or Finder")
                                .font(.system(size: 10.5))
                                .foregroundColor(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.25))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
                                )
                        )
                        .onDrag {
                            let provider = NSItemProvider(object: zipURL as NSURL)
                            provider.suggestedName = "nnts-diagnostic.zip"
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
                        .frame(height: 80)
                    }
                }
                
                // Action Buttons
                HStack(spacing: 10) {
                    Button(action: openTelegram) {
                        HStack(spacing: 6) {
                            Image(nsImage: Self.telegramIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            Text("Telegram Chat")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(red: 0.16, green: 0.52, blue: 0.90).opacity(0.25))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color(red: 0.16, green: 0.52, blue: 0.90).opacity(0.5), lineWidth: 0.75)
                                )
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: openGitHub) {
                        HStack(spacing: 6) {
                            Image(nsImage: Self.gitHubIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                            Text("GitHub Issue")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.75)
                                )
                        )
                        .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack(spacing: 10) {
                    Button(action: revealInFinder) {
                        HStack(spacing: 5) {
                            Image(nsImage: Self.finderIcon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                            Text("Show in Finder")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(Color(red: 0.40, green: 0.70, blue: 1.0))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.zipURL == nil)
                    
                    Spacer()
                    
                    Button(action: copyDiagnosticsToClipboard) {
                        HStack(spacing: 5) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 11))
                            Text(viewModel.copiedNotice ? "Copied! ✅" : "Copy Raw Log")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.70))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            
            Divider()
                .opacity(0.4)
            
            // 3. Footer Bar
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.50).opacity(0.85))
                    Text("100% offline & local diagnostic archive")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.70))
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            // 4. Key Hints Bar
            HStack(spacing: 12) {
                Text("[⌘C] Copy Log")
                Text("[⌘O] Finder")
                Text("[Esc] Close")
            }
            .font(.system(size: 9.5, weight: .medium, design: .monospaced))
            .foregroundColor(.white.opacity(0.60))
            .padding(.bottom, 8)
        }
        .frame(width: 440)
        .background(
            MacNativeLiquidGlassBackground(cornerRadius: 18, material: .popover)
        )
        .preferredColorScheme(.dark)
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
