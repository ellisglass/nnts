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
    
    public func nextProfile() {
        guard !profiles.isEmpty, let currentIndex = profiles.firstIndex(where: { $0.dir == selectedProfileDir }) else { return }
        let nextIndex = (currentIndex + 1) % profiles.count
        selectProfile(dir: profiles[nextIndex].dir)
    }
    
    public func startCrosshair(delayed: Bool = false) {
        guard let profile = selectedProfile else { return }
        self.isSuccess = false
        self.statusMessage = nil
        
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
        
        profileEngine.startPasteboardAvatarWatcher(forProfileDir: profile.dir, name: profile.name, timeoutSeconds: 30.0) { [weak self] success in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isCrosshairActive = false
                if success {
                    if NSSound(named: "Hero")?.play() != true {
                        NSSound.beep()
                    }
                    self.isSuccess = true
                    self.statusMessage = "Avatar saved for '\(profile.effectiveName)'!"
                    self.capturedAvatar = ChromeProfileEngine.loadStoredAvatar(dirKey: profile.dir, name: profile.name)
                    AppDelegate.shared?.updateDynamicShortcuts()
                    AppDelegate.shared?.updateMenu()
                }
                AvatarCaptureAssistantWindow.shared.show(profileDir: profile.dir)
            }
        }
        
        profileEngine.launchInteractiveScreenCapture { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // If user pressed Escape in screencapture, restore window if still hidden
                try? await Task.sleep(nanoseconds: 300_000_000)
                if self.isCrosshairActive && !AvatarCaptureAssistantWindow.shared.isVisible {
                    self.isCrosshairActive = false
                    profileEngine.cancelPasteboardAvatarWatcher()
                    AvatarCaptureAssistantWindow.shared.show(profileDir: profile.dir)
                }
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
            
            // Instructions / Status
            VStack(alignment: .leading, spacing: 4) {
                if let count = viewModel.countdownSeconds {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Opening crosshairs in \(count)s... (Open profile menu now!)")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(.orange)
                    }
                } else if let status = viewModel.statusMessage {
                    Text(status)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(viewModel.isSuccess ? Color(red: 0.35, green: 0.88, blue: 0.52) : .yellow)
                } else {
                    HStack(alignment: .top, spacing: 6) {
                        Text("1.")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("Click the profile avatar in Chrome (or open profile panel).")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Text("2.")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)
                        Text("Click **Start Crosshair**, then drag a box over the avatar.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            
            // Action Buttons
            HStack(spacing: 8) {
                // Primary Crosshair Button
                Button(action: {
                    viewModel.startCrosshair(delayed: false)
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "crosshair")
                            .font(.system(size: 11, weight: .bold))
                        Text("Start Crosshair")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                
                // 3-Second Timer Button (to allow opening popups/menus)
                Button(action: {
                    viewModel.startCrosshair(delayed: true)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.system(size: 11))
                        Text("3s Timer")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.10))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.75)
                    )
                }
                .buttonStyle(.plain)
                .help("Gives you 3 seconds to click inside Chrome and open the profile dropdown before crosshairs appear")
                
                // Paste from Clipboard Button
                Button(action: {
                    viewModel.pasteFromClipboard()
                }) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 12))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(Color.white.opacity(0.10))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.75)
                        )
                }
                .buttonStyle(.plain)
                .help("Paste image currently in your clipboard (or Cmd+Ctrl+Shift+4)")
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
    
    public func show(profileDir: String? = nil) {
        viewModel.refreshProfiles()
        if let dir = profileDir {
            viewModel.selectProfile(dir: dir)
        }
        centerOnScreen()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func hideImmediate() {
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
