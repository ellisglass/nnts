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
    @Published public var isCrosshairActive: Bool = false
    @Published public var countdownSeconds: Int? = nil
    @Published public var isSuccess: Bool = false
    @Published public var capturedAvatar: NSImage? = nil
    @Published public var statusMessage: String? = nil
    
    private var countdownTimer: Timer?
    
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
    
    public var isScreenRecordingAuthorized: Bool {
        ChromeProfileEngine.hasScreenRecordingPermission
    }
    
    public func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private var pasteboardWatcherTimer: Timer?
    private var lastPasteboardChangeCount: Int = 0
    
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
    
    public func syncAllProfiles() {
        guard isScreenRecordingAuthorized else {
            let alert = NSAlert()
            alert.messageText = "1-Click Auto-Sync: Permissions Guide"
            alert.informativeText = """
Why this exists:
Profile photos give you intuitive visual recognition in the HUD during quick switching.

What happens next (macOS Permissions):
1. Clicking 'Open Settings' takes you to macOS System Settings.
2. Toggle the switch for NNTS.
3. macOS will prompt: "NNTS will not be able to record the screen until it is quit." Click [Quit & Reopen].
4. After reopen, 1-Click Auto-Sync will scan open windows in 2 seconds and cache avatars locally.
5. Once cached, you can immediately turn off Screen Recording in System Settings!

Prefer 0 permissions?
Just press ⌘⌃⇧4 and snip your profile avatar in Chrome — NNTS catches it from the clipboard automatically!
"""
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Use Clipboard Snip (0 Permissions)")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)
            alert.window.level = .floating
            let resp = alert.runModal()
            if resp == .alertFirstButtonReturn {
                requestScreenRecordingPermission()
            }
            return
        }
        isSuccess = false
        statusMessage = "Scanning open browser windows..."
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let count = await ChromeProfileEngine.shared.snapActiveBrowserAvatars()
            self.refreshProfiles()
            self.updatePreview()
            if count > 0 {
                if NSSound(named: "Hero")?.play() != true {
                    NSSound.beep()
                }
                self.isSuccess = true
                self.statusMessage = "Synced \(count) profile avatars! Cached locally on your Mac."
                AppDelegate.shared?.updateDynamicShortcuts()
                AppDelegate.shared?.updateMenu()
            } else {
                self.statusMessage = "No open browser windows found to snap. Open Chrome and try again."
            }
        }
    }
    
    public func startCrosshair(delayed: Bool = false) {
        guard let profile = selectedProfile else { return }
        self.isSuccess = false
        self.statusMessage = nil
        
        if !ChromeProfileEngine.hasScreenRecordingPermission {
            CGRequestScreenCaptureAccess()
            self.statusMessage = "Screen Recording permission needed for crosshair. Enable in Settings or use ⌘⌃⇧4."
        }
        
        // Focus the browser window for this profile
        ChromeProfileEngine.shared.focusProfile(dir: profile.dir)
        
        if delayed {
            countdownSeconds = 3
            countdownTimer?.invalidate()
            countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                Task { @MainActor [weak self] in
                    guard let self = self else { timer.invalidate(); return }
                    if let sec = self.countdownSeconds, sec > 1 {
                        self.countdownSeconds = sec - 1
                        if NSSound(named: "Tink")?.play() != true {
                            NSSound.beep()
                        }
                    } else {
                        timer.invalidate()
                        self.countdownTimer = nil
                        self.countdownSeconds = nil
                        self.executeCrosshairCapture(for: profile)
                    }
                }
            }
        } else {
            // Small pause to let user release click before triggering crosshair
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 200_000_000)
                guard let self = self else { return }
                self.executeCrosshairCapture(for: profile)
            }
        }
    }
    
    private func executeCrosshairCapture(for profile: ChromeProfile) {
        self.isCrosshairActive = true
        AvatarCaptureAssistantWindow.shared.orderOut(nil)
        
        let profileEngine = ChromeProfileEngine.shared
        let tempPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nnts_avatar_\(UUID().uuidString).png").path
        
        profileEngine.launchInteractiveScreenCaptureToFile(targetPath: tempPath) { [weak self] success in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    try? FileManager.default.removeItem(atPath: tempPath)
                    return
                }
                self.isCrosshairActive = false
                
                if success, let img = NSImage(contentsOfFile: tempPath) {
                    let saved = profileEngine.saveCapturedAvatar(image: img, forProfileDir: profile.dir, name: profile.name)
                    try? FileManager.default.removeItem(atPath: tempPath)
                    
                    if saved {
                        if NSSound(named: "Hero")?.play() != true {
                            NSSound.beep()
                        }
                        self.isSuccess = true
                        self.statusMessage = "Avatar saved for '\(profile.effectiveName)'!"
                        self.capturedAvatar = ChromeProfileEngine.loadStoredAvatar(dirKey: profile.dir, name: profile.name)
                        AppDelegate.shared?.updateDynamicShortcuts()
                        AppDelegate.shared?.updateMenu()
                    } else {
                        self.isSuccess = false
                        self.statusMessage = "Failed to process image."
                    }
                } else {
                    try? FileManager.default.removeItem(atPath: tempPath)
                    self.isSuccess = false
                    if !ChromeProfileEngine.hasScreenRecordingPermission {
                        self.statusMessage = "Screen Recording permission required for crosshairs. Click Open Settings or press ⌘⌃⇧4."
                    } else {
                        self.statusMessage = "Capture cancelled. Click Start Crosshair to try again."
                    }
                }
                
                AvatarCaptureAssistantWindow.shared.show(profileDir: profile.dir, preservingState: true)
            }
        }
    }
    
    public func pasteFromClipboard() {
        guard let profile = selectedProfile else { return }
        let success = ChromeProfileEngine.shared.saveCapturedAvatarFromPasteboard(forProfileDir: profile.dir, name: profile.name)
        if success {
            if NSSound(named: "Hero")?.play() != true {
                NSSound.beep()
            }
            self.isSuccess = true
            self.statusMessage = "Avatar pasted for '\(profile.effectiveName)'!"
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
        VStack(spacing: 14) {
            // Header Bar
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color.cyan)
                
                Text("Smart Avatar Capture")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
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
            
            // Permission Warning Banner (if Screen Recording is not yet granted)
            if !viewModel.isScreenRecordingAuthorized {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 11))
                    Text("Screen Recording needed for Auto-Sync & Crosshairs")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    Spacer()
                    Button("Open Settings") {
                        viewModel.requestScreenRecordingPermission()
                    }
                    .font(.system(size: 10.5, weight: .bold))
                    .buttonStyle(.plain)
                    .foregroundColor(.cyan)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.orange.opacity(0.35), lineWidth: 0.75)
                )
            } else if viewModel.isSuccess {
                // Privacy offboarding reassurance: avatars are cached, user can revoke permission
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(Color(red: 0.35, green: 0.88, blue: 0.52))
                        .font(.system(size: 11))
                    Text("Avatars cached locally. Screen Recording can be turned off.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(1)
                    Spacer()
                    Button("Turn Off…") {
                        ChromeProfileEngine.openScreenRecordingSettings()
                    }
                    .font(.system(size: 10, weight: .bold))
                    .buttonStyle(.plain)
                    .foregroundColor(.cyan)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
                )
            }
            
            // Instructions / Status
            VStack(alignment: .leading, spacing: 5) {
                if let count = viewModel.countdownSeconds {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Opening crosshairs in \(count)s... (Open profile menu now!)")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                } else if let status = viewModel.statusMessage {
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
                            Text("Fastest: Zero Permissions Needed")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("1. In Chrome, press **⌘⌃⇧4** and snip your profile avatar.\n2. NNTS automatically catches it from the clipboard and saves it!")
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
                    Text("Paste Snip from Clipboard")
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
            
            // Secondary Options: 1-Click Auto-Sync or Native Crosshairs
            HStack(spacing: 8) {
                Button(action: {
                    viewModel.syncAllProfiles()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Auto-Sync (1-Click)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white.opacity(0.9))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
                .help("Scans all open Chrome windows in 2 seconds (requires Screen Recording permission)")
                
                Button(action: {
                    viewModel.startCrosshair(delayed: false)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 11))
                        Text("Crosshair")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white.opacity(0.9))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
                .help("Interactive crosshairs overlay")
            }
            
            if viewModel.isSuccess && viewModel.profiles.count > 1 {
                Button(action: {
                    viewModel.nextProfile()
                }) {
                    HStack(spacing: 4) {
                        Text("Next Profile")
                            .font(.system(size: 11, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
                .padding(.top, -4)
            }
        }
        .padding(16)
        .frame(width: 360)
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
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 250),
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
            viewModel.startCrosshair(delayed: false)
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
