import Cocoa
import AppKit
import SwiftUI
import os

// MARK: - Avatar Capture Assistant View Model
@MainActor
public final class AvatarCaptureAssistantViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.almosteleven.nnts", category: "avatar-assistant")
    
    @Published public var profiles: [ChromeProfile] = []
    @Published public var selectedProfileDir: String = ""
    @Published public var isSuccess: Bool = false
    @Published public var capturedAvatar: NSImage? = nil
    @Published public var statusMessage: String? = nil
    
    private var pasteboardWatcherTimer: Timer?
    private var lastPasteboardChangeCount: Int = 0
    
    public init() {
        refreshProfiles()
    }
    
    public var selectedProfile: ChromeProfile? {
        profiles.first(where: { $0.dir == selectedProfileDir }) ?? profiles.first
    }
    
    public func refreshProfiles() {
        let engine = ChromeProfileEngine.shared
        self.profiles = engine.profiles
        if selectedProfileDir.isEmpty || !profiles.contains(where: { $0.dir == selectedProfileDir }) {
            self.selectedProfileDir = engine.getActiveProfileDir() ?? profiles.first?.dir ?? "Default"
        }
        updatePreview()
    }
    
    public func selectProfile(dir: String) {
        self.selectedProfileDir = dir
        self.isSuccess = false
        self.statusMessage = nil
        updatePreview()
        ChromeProfileEngine.shared.focusProfile(dir: dir)
    }
    
    public var previewAvatarImage: NSImage? {
        if let custom = capturedAvatar { return custom }
        return selectedProfile?.avatarImage
    }
    
    public var selectedProfileMonogram: String {
        let first = selectedProfile?.effectiveName.first(where: { $0.isLetter || $0.isNumber }) ?? "P"
        return String(first).uppercased()
    }
    
    public func updatePreview() {
        guard let p = selectedProfile else { return }
        self.capturedAvatar = ChromeProfileEngine.loadStoredAvatar(dirKey: p.dir, name: p.name)
    }
    
    public func startPasteboardWatcher() {
        stopPasteboardWatcher()
        lastPasteboardChangeCount = NSPasteboard.general.changeCount
        pasteboardWatcherTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let currentCount = NSPasteboard.general.changeCount
                if currentCount != self.lastPasteboardChangeCount {
                    self.lastPasteboardChangeCount = currentCount
                    if let img = ChromeProfileEngine.getImageFromPasteboard(), let profile = self.selectedProfile {
                        let saved = ChromeProfileEngine.shared.saveCapturedAvatar(image: img, forProfileDir: profile.dir, name: profile.name)
                        if saved {
                            if NSSound(named: "Hero")?.play() != true {
                                NSSound.beep()
                            }
                            self.isSuccess = true
                            self.statusMessage = "Auto-saved avatar from clipboard for '\(profile.effectiveName)'!"
                            self.capturedAvatar = ChromeProfileEngine.loadStoredAvatar(dirKey: profile.dir, name: profile.name)
                            AppDelegate.shared?.updateDynamicShortcuts()
                            AppDelegate.shared?.updateMenu()
                        }
                    }
                }
            }
        }
    }
    
    public func stopPasteboardWatcher() {
        pasteboardWatcherTimer?.invalidate()
        pasteboardWatcherTimer = nil
    }

    public func nextProfile() {
        guard !profiles.isEmpty, let currentIndex = profiles.firstIndex(where: { $0.dir == selectedProfileDir }) else { return }
        let nextIndex = (currentIndex + 1) % profiles.count
        selectProfile(dir: profiles[nextIndex].dir)
    }
    
    public func pasteFromClipboard() {
        guard let profile = selectedProfile else { return }
        let success = ChromeProfileEngine.shared.saveCapturedAvatarFromPasteboard(forProfileDir: profile.dir, name: profile.name)
        if success {
            if NSSound(named: "Hero")?.play() != true {
                NSSound.beep()
            }
            self.isSuccess = true
            self.statusMessage = "Avatar saved for '\(profile.effectiveName)'!"
            self.capturedAvatar = ChromeProfileEngine.loadStoredAvatar(dirKey: profile.dir, name: profile.name)
            AppDelegate.shared?.updateDynamicShortcuts()
            AppDelegate.shared?.updateMenu()
        } else {
            if NSSound(named: "Basso")?.play() != true {
                NSSound.beep()
            }
            self.statusMessage = "No image found in clipboard. Copy an image first."
        }
    }
}

// MARK: - Avatar Preview Circle View
private struct AvatarPreviewCircle: View {
    let image: NSImage?
    let monogram: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 44, height: 44)
            
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1.5)
                    )
            } else {
                Text(monogram)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Avatar Capture Assistant View
public struct AvatarCaptureAssistantView: View {
    @ObservedObject var viewModel: AvatarCaptureAssistantViewModel
    var onClose: () -> Void
    
    public var body: some View {
        VStack(spacing: 13) {
            // Header Bar
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.cyan)
                
                Text("Clipboard Avatar Assistant")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
            
            // Profile Selector Card
            HStack(spacing: 12) {
                // Profile Avatar Preview
                AvatarPreviewCircle(
                    image: viewModel.previewAvatarImage,
                    monogram: viewModel.selectedProfileMonogram
                )
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.selectedProfile?.effectiveName ?? "Chrome Profile")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if viewModel.profiles.count > 1 {
                        Picker("", selection: Binding(
                            get: { viewModel.selectedProfileDir },
                            set: { viewModel.selectProfile(dir: $0) }
                        )) {
                            ForEach(viewModel.profiles, id: \.dir) { p in
                                Text(p.effectiveName).tag(p.dir)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 180)
                    } else {
                        Text("Active Profile")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if viewModel.isSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.35, green: 0.88, blue: 0.52))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
                    )
            )
            
            // Instructions / Status
            VStack(alignment: .leading, spacing: 5) {
                if let status = viewModel.statusMessage {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isSuccess ? "checkmark.circle.fill" : "info.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(viewModel.isSuccess ? Color(red: 0.35, green: 0.88, blue: 0.52) : .yellow)
                        Text(status)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(viewModel.isSuccess ? Color(red: 0.35, green: 0.88, blue: 0.52) : .yellow)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.cyan)
                            Text("Fast & Private: Zero Permissions")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("1. In Chrome, press **⌘⌃⇧4** and snip your profile avatar.\n2. NNTS catches it from the clipboard automatically, or click Paste below.")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            
            // Primary Hero Button: Paste from Clipboard
            Button(action: {
                viewModel.pasteFromClipboard()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("Paste Avatar from Clipboard")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .help("Applies image currently in clipboard (or auto-saved via ⌘⌃⇧4)")
            
            if viewModel.isSuccess && viewModel.profiles.count > 1 {
                Button(action: {
                    viewModel.nextProfile()
                }) {
                    HStack(spacing: 4) {
                        Text("Configure Next Profile")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
                .padding(.top, -2)
            }
            
            // Privacy Guarantee Badge
            HStack(spacing: 5) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                Text("Zero screen recording. Captured solely on your terms via clipboard.")
                    .font(.system(size: 9.5))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(15)
        .frame(width: 350)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow, state: .active, cornerRadius: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.12, green: 0.14, blue: 0.18).opacity(0.85))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.35), location: 0.0),
                            .init(color: Color.white.opacity(0.10), location: 0.5),
                            .init(color: Color.white.opacity(0.20), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
    }
}

// MARK: - Avatar Capture Assistant Window
public final class AvatarCaptureAssistantWindow: NSWindow {
    public static let shared = AvatarCaptureAssistantWindow()
    public let viewModel = AvatarCaptureAssistantViewModel()
    
    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 220),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let rootView = AvatarCaptureAssistantView(
            viewModel: viewModel,
            onClose: { [weak self] in
                self?.hideImmediate()
            }
        )
        
        let hosting = NSHostingView(rootView: rootView)
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        self.contentView = hosting
    }
    
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == KeyCodes.kVK_Escape {
            hideImmediate()
            return
        }
        if event.keyCode == KeyCodes.kVK_Return || event.keyCode == KeyCodes.kVK_Space {
            viewModel.pasteFromClipboard()
            return
        }
        super.keyDown(with: event)
    }
    
    public func show(profileDir: String? = nil, preservingState: Bool = false) {
        if !preservingState {
            viewModel.refreshProfiles()
            if let dir = profileDir {
                viewModel.selectProfile(dir: dir)
            }
        } else {
            viewModel.updatePreview()
        }
        viewModel.startPasteboardWatcher()
        centerOnScreen()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func hideImmediate() {
        viewModel.stopPasteboardWatcher()
        orderOut(nil)
    }
    
    private func centerOnScreen() {
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - (frame.width / 2)
            let y = screenRect.midY - (frame.height / 2) + 100
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
