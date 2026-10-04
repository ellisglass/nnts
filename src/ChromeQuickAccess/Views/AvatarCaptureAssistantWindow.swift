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

// MARK: - KeyCap View
private struct KeyCapView: View {
    let key: String
    
    var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 5.5)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4.5)
                    .fill(Color(red: 0.16, green: 0.18, blue: 0.22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4.5)
                            .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.75)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 1.5, y: 1)
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
                .frame(width: 48, height: 48)
            
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(0.40), lineWidth: 1.5)
                    )
            } else {
                Text(monogram)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1.5)
    }
}

// MARK: - Avatar Capture Assistant View
public struct AvatarCaptureAssistantView: View {
    @ObservedObject var viewModel: AvatarCaptureAssistantViewModel
    var onClose: () -> Void
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. Header Bar (Identical to Settings & Quick Apps)
            HStack(spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                    Text("Avatar Assistant")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.88))
                }
                
                // Zero Permissions Pill (Matches Pro Active badge style)
                HStack(spacing: 3) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 9, weight: .bold))
                    Text("0 Permissions")
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
                .help("Zero screen recording. Imports strictly via clipboard (⌘⌃⇧4).")
                
                Spacer()
                
                // Refresh Profiles Button
                Button(action: { viewModel.refreshProfiles() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(5)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Refresh Profiles (⌘R)")
                
                // Close Button
                Button(action: onClose) {
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
                // Target Profile Card (Identical to Settings row card)
                HStack(spacing: 12) {
                    AvatarPreviewCircle(
                        image: viewModel.previewAvatarImage,
                        monogram: viewModel.selectedProfileMonogram
                    )
                    
                    VStack(alignment: .leading, spacing: 3) {
                        if viewModel.profiles.count > 1 {
                            HStack(spacing: 6) {
                                Text("Profile:")
                                    .font(.system(size: 11.5, weight: .semibold))
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
                                .frame(maxWidth: 160)
                            }
                            
                            Text("Target profile for avatar snip")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.70))
                        } else {
                            Text(viewModel.selectedProfile?.effectiveName ?? "Chrome Profile")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            Text("Active Profile · \(viewModel.selectedProfile?.dir ?? "Default")")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.70))
                        }
                    }
                    
                    Spacer()
                    
                    // Profile hotkey badge (Capsule pill identical to Settings caps lock + A)
                    let slotIndex = viewModel.selectedProfile?.index ?? 1
                    Text("caps lock + c + \(slotIndex)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.14)))
                        .overlay(Capsule().stroke(Color.white.opacity(0.22), lineWidth: 0.5))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
                        )
                )
                
                // Instructions / Status Card
                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.isSuccess {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(red: 0.35, green: 0.88, blue: 0.52))
                            
                            Text(viewModel.statusMessage ?? "Avatar applied successfully!")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(red: 0.35, green: 0.88, blue: 0.52))
                        }
                    } else if let status = viewModel.statusMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                            
                            Text(status)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.yellow)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 6) {
                                Text("1")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(.cyan)
                                    .frame(width: 15, height: 15)
                                    .background(Circle().fill(Color.cyan.opacity(0.20)))
                                
                                Text("In Chrome, press")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                                
                                HStack(spacing: 2.5) {
                                    KeyCapView(key: "⌘")
                                    KeyCapView(key: "⌃")
                                    KeyCapView(key: "⇧")
                                    KeyCapView(key: "4")
                                }
                                
                                Text("and snip your avatar.")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            
                            HStack(spacing: 6) {
                                Text("2")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(.cyan)
                                    .frame(width: 15, height: 15)
                                    .background(Circle().fill(Color.cyan.opacity(0.20)))
                                
                                Text("NNTS catches it from the clipboard automatically.")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(11)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.75)
                        )
                )
                
                // Primary Action Button (Matching Settings +Pin style)
                Button(action: {
                    viewModel.pasteFromClipboard()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 12, weight: .semibold))
                        
                        Text("Paste Avatar from Clipboard")
                            .font(.system(size: 12, weight: .semibold))
                        
                        Spacer()
                        
                        Text("[ ↵ ]")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .foregroundColor(.white.opacity(0.70))
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.16, green: 0.48, blue: 0.96),
                                        Color(red: 0.08, green: 0.38, blue: 0.86)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.75)
                            )
                    )
                    .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .help("Paste image currently in clipboard (or press Enter)")
                
                if viewModel.isSuccess && viewModel.profiles.count > 1 {
                    Button(action: { viewModel.nextProfile() }) {
                        HStack(spacing: 5) {
                            Text("Configure Next Profile")
                                .font(.system(size: 11.5, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9.5, weight: .bold))
                        }
                        .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            
            Divider()
                .opacity(0.4)
            
            // 3. Footer Bar (Identical to Settings footer)
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.50).opacity(0.85))
                    Text("Zero screen recording · 100% private")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.70))
                }
                
                Spacer()
                
                Button(action: {
                    AvatarCaptureAssistantWindow.shared.hideImmediate()
                    AppSearchPickerWindow.shared.show()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 11))
                        Text("Settings... (⌘,)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.40, green: 0.70, blue: 1.0))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            // 4. Key Hints Bar (Identical to Settings)
            HStack(spacing: 12) {
                Text("[⌘⌃⇧4] Snip")
                Text("[↵] Paste")
                Text("[⌘R] Refresh")
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
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - (frame.width / 2)
            let y = screenRect.midY - (frame.height / 2) + 100
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
