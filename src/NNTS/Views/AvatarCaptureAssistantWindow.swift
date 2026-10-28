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
        guard let profile = selectedProfile else {
            self.statusMessage = "No Chrome profile found to update."
            NSSound.beep()
            return
        }
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

// MARK: - KeyCap View
private struct KeyCapView: View {
    let key: String
    
    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.95))
            .frame(minWidth: 20, minHeight: 19)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(white: 0.24),
                                Color(white: 0.16)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.30),
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.75
                            )
                    )
            )
            .shadow(color: Color.black.opacity(0.40), radius: 1.5, x: 0, y: 1)
    }
}

// MARK: - Avatar Preview Circle View
private struct AvatarPreviewCircle: View {
    let image: NSImage?
    let monogram: String
    
    var body: some View {
        ZStack {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.40), Color.white.opacity(0.12)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
            } else {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.24, blue: 0.32),
                                Color(red: 0.12, green: 0.14, blue: 0.18)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.60), Color.accentColor.opacity(0.20)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1.5
                            )
                    )
                    .overlay(
                        Text(monogram)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    )
            }
        }
        .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Avatar Capture Assistant View
public struct AvatarCaptureAssistantView: View {
    @ObservedObject var viewModel: AvatarCaptureAssistantViewModel
    var onClose: () -> Void
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Header Bar
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.accentColor)
                    Text("Avatar Assistant")
                        .font(.system(size: 13, weight: .semibold))
                        .tracking(-0.3)
                        .foregroundColor(.white.opacity(0.92))
                }
                
                // Zero Permissions Pill
                HStack(spacing: 4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.50))
                    Text("0 Permissions")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule().fill(Color.white.opacity(0.08))
                )
                .overlay(
                    Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.5)
                )
                .help("Zero screen recording. Imports strictly via clipboard (⌘⌃⇧4).")
                
                Spacer()
                
                // Refresh Profiles Button
                Button(action: { viewModel.refreshProfiles() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.75))
                        .padding(5.5)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(MacTactileButtonStyle(scaleAmount: 0.94))
                .help("Refresh Profiles (⌘R)")
                
                // Close Button
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.45))
                }
                .buttonStyle(MacTactileButtonStyle(scaleAmount: 0.94))
                .help("Close (Esc)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            Divider()
                .opacity(0.25)
            
            // 2. Body Content
            VStack(spacing: 12) {
                // Target Profile Hero Card (Elevated Frosted Glass)
                HStack(spacing: 14) {
                    AvatarPreviewCircle(
                        image: viewModel.previewAvatarImage,
                        monogram: viewModel.selectedProfileMonogram
                    )
                    .fixedSize()
                    
                    VStack(alignment: .leading, spacing: 3.5) {
                        if viewModel.profiles.count > 1 {
                            HStack(spacing: 6) {
                                Text("Profile:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                
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
                                .frame(maxWidth: 170)
                            }
                            
                            Text("Target profile to update")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            Text(viewModel.selectedProfile?.effectiveName ?? "Chrome Profile")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            
                            Text("Active Profile · \(viewModel.selectedProfile?.dir ?? "Default")")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.white.opacity(0.65))
                                .lineLimit(1)
                        }
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    
                    Spacer(minLength: 8)
                    
                    // Profile hotkey badge
                    let slotIndex = viewModel.selectedProfile?.index ?? 1
                    HStack(spacing: 3) {
                        Text("caps lock")
                            .font(.system(size: 9.5, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.70))
                        Text("+")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.40))
                        Text("c")
                            .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.90))
                        Text("+")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.40))
                        Text("\(slotIndex)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 7.5)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.12))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.20), lineWidth: 0.5)
                    )
                    .fixedSize()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.18), Color.white.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ),
                                    lineWidth: 0.75
                                )
                        )
                )
                .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 2)
                
                // Instructions / Status Card
                VStack(alignment: .leading, spacing: 9) {
                    if viewModel.isSuccess {
                        HStack(spacing: 9) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Color(red: 0.35, green: 0.88, blue: 0.52))
                            
                            Text(viewModel.statusMessage ?? "Avatar applied successfully!")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(Color(red: 0.35, green: 0.88, blue: 0.52))
                        }
                        .padding(.vertical, 2)
                    } else if let status = viewModel.statusMessage {
                        HStack(spacing: 9) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 15))
                                .foregroundColor(.yellow)
                            
                            Text(status)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.yellow)
                        }
                        .padding(.vertical, 2)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                HStack(spacing: 3) {
                                    KeyCapView(key: "⌘")
                                    KeyCapView(key: "⌃")
                                    KeyCapView(key: "⇧")
                                    KeyCapView(key: "4")
                                }
                                Text("Snip avatar area in Chrome")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.88))
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.accentColor)
                                    .frame(width: 20)
                                Text("NNTS detects clipboard & saves automatically")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.70))
                            }
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.75)
                        )
                )
                
                // Primary Action Button (Tactile Apple Prominent Button)
                Button(action: {
                    viewModel.pasteFromClipboard()
                }) {
                    HStack(spacing: 9) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 13, weight: .semibold))
                        
                        Text("Paste Avatar from Clipboard")
                            .font(.system(size: 13, weight: .semibold))
                        
                        Spacer()
                        
                        // Return Keycap Badge
                        HStack(spacing: 2) {
                            Text("↩")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(.white.opacity(0.90))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.black.opacity(0.28))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                                        .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                )
                        )
                    }
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.08, green: 0.52, blue: 0.98),
                                        Color(red: 0.02, green: 0.40, blue: 0.88)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        ),
                                        lineWidth: 0.75
                                    )
                            )
                    )
                    .foregroundColor(.white)
                    .shadow(color: Color(red: 0.05, green: 0.42, blue: 0.95).opacity(0.35), radius: 6, x: 0, y: 2.5)
                }
                .buttonStyle(MacTactileButtonStyle(scaleAmount: 0.97, pressedOpacity: 0.92))
                .help("Paste image currently in clipboard (or press Enter)")
                
                if viewModel.isSuccess && viewModel.profiles.count > 1 {
                    Button(action: { viewModel.nextProfile() }) {
                        HStack(spacing: 5) {
                            Text("Configure Next Profile")
                                .font(.system(size: 11.5, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundColor(Color.accentColor)
                    }
                    .buttonStyle(MacTactileButtonStyle(scaleAmount: 0.97))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            
            Divider()
                .opacity(0.25)
            
            // 3. Footer Bar
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 10.5))
                        .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.50))
                    Text("Zero screen recording · 100% private")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.65))
                }
                
                Spacer()
                
                Button(action: {
                    AvatarCaptureAssistantWindow.shared.hideImmediate()
                    SettingsWindow.shared.show(tab: .profiles)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10.5))
                        Text("Settings... (⌘,)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.40, green: 0.72, blue: 1.0))
                }
                .buttonStyle(MacTactileButtonStyle(scaleAmount: 0.97))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 440)
        .background(
            MacNativeLiquidGlassBackground(cornerRadius: 18, material: .popover)
        )
        .preferredColorScheme(.dark)
    }
}

// MARK: - Avatar Capture Assistant Window
@MainActor
public final class AvatarCaptureAssistantWindow: NSPanel {
    public static let shared = AvatarCaptureAssistantWindow()
    public let viewModel = AvatarCaptureAssistantViewModel()
    
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 380),
            styleMask: [.titled, .fullSizeContentView, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
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
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        if let screen = screen {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - (frame.width / 2)
            let y = screenRect.midY - (frame.height / 2) + 100
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
