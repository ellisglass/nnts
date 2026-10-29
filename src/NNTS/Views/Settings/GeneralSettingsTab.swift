import SwiftUI
import AppKit

// MARK: - Shared Settings Section Box

internal struct SettingsSectionBox<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    let content: () -> Content
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        iconColor: Color = NNTSColors.cadmiumYellow,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 1.5) {
                    Text(title)
                        .font(NNTSFont.display(size: 13))
                        .foregroundColor(Color(nsColor: .labelColor))
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    }
                }
                
                Spacer()
            }
            
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: NNTSGeometry.settingsCardRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.60))
        )
        .overlay(
            RoundedRectangle(cornerRadius: NNTSGeometry.settingsCardRadius, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.75)
        )
    }
}

// MARK: - Tab 1: General Settings

internal struct GeneralTabContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Animated Status Message Banner
            if let msg = viewModel.statusMessage {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isStatusError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(viewModel.isStatusError ? NNTSColors.vermilion : NNTSColors.appleEmerald)
                        .font(.system(size: 13, weight: .semibold))
                    
                    Text(msg)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(nsColor: .labelColor))
                    
                    Spacer()
                    
                    Button {
                        withAnimation(NNTSMotion.interactiveSnap) {
                            viewModel.clearStatusMessage()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss notification")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(viewModel.isStatusError ? NNTSColors.vermilion.opacity(0.12) : NNTSColors.appleEmerald.opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(viewModel.isStatusError ? NNTSColors.vermilion.opacity(0.30) : NNTSColors.appleEmerald.opacity(0.30), lineWidth: 0.75)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // 1. Hardware & System Integration
            SettingsSectionBox(
                title: "System Integration",
                subtitle: "Driverless hardware remapping and macOS accessibility event tap",
                icon: "keyboard",
                iconColor: NNTSColors.cobaltBlue
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    // Row 1: Caps Lock
                    HStack {
                        ZStack {
                            Circle()
                                .fill(viewModel.isCapsLockRemapped ? NNTSColors.appleEmerald.opacity(0.25) : Color.orange.opacity(0.20))
                                .frame(width: 16, height: 16)
                            Circle()
                                .fill(viewModel.isCapsLockRemapped ? NNTSColors.appleEmerald : Color.orange)
                                .frame(width: 8, height: 8)
                        }
                        
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text(viewModel.isCapsLockRemapped ? "caps lock mapped to virtual F18" : "caps lock not remapped")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(nsColor: .labelColor))
                            Text("Driverless hardware remapping prevents green LED blinking and native delay")
                                .font(.system(size: 10.5))
                                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        }
                        
                        Spacer()
                        
                        if viewModel.isCapsLockRemapped {
                            Button("Restore System Default") {
                                withAnimation(NNTSMotion.interactiveSnap) {
                                    viewModel.restoreDefaultCapsLock()
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(Color(nsColor: .labelColor))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4.5)
                            .background(
                                Capsule()
                                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.75)
                                    )
                            )
                        } else {
                            Button("Apply Remapping") {
                                withAnimation(NNTSMotion.interactiveSnap) {
                                    viewModel.reapplyCapsLockRemapping()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    
                    Divider()
                        .opacity(0.4)
                    
                    // Row 2: Accessibility
                    HStack {
                        Image(systemName: viewModel.isAccessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(viewModel.isAccessibilityTrusted ? NNTSColors.appleEmerald : Color.orange)
                            .font(.system(size: 14))
                        
                        VStack(alignment: .leading, spacing: 1.5) {
                            Text(viewModel.isAccessibilityTrusted ? "Accessibility permissions granted" : "Accessibility permissions required")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(nsColor: .labelColor))
                            Text("Allows event tap listening for caps lock combinations and window raising")
                                .font(.system(size: 10.5))
                                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        }
                        
                        Spacer()
                        
                        if !viewModel.isAccessibilityTrusted {
                            Button("Open System Settings...") {
                                viewModel.openAccessibilitySettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Active")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(NNTSColors.appleEmerald)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(NNTSColors.appleEmerald.opacity(0.12))
                                    .overlay(
                                        Capsule().stroke(NNTSColors.appleEmerald.opacity(0.3), lineWidth: 0.75)
                                    )
                            )
                        }
                    }
                }
            }
            
            // 2. Productivity Features
            SettingsSectionBox(
                title: "Productivity Features",
                subtitle: "Copy-on-Select automation and intelligent Finder window management",
                icon: "sparkles",
                iconColor: NNTSColors.appleEmerald
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    // Feature 1: Copy on Select
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: Binding(
                            get: { viewModel.isCopyOnSelectEnabled },
                            set: { viewModel.setCopyOnSelectEnabled($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Copy on Select")
                                    .font(.system(size: 12.5, weight: .medium))
                                Text("Automatically copies text to clipboard whenever you highlight with mouse or double-click")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            }
                        }
                        .toggleStyle(.switch)
                        
                        if viewModel.isCopyOnSelectEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Toggle(isOn: Binding(
                                    get: { viewModel.isCopyToastEnabled },
                                    set: { viewModel.setCopyToastEnabled($0) }
                                )) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Show Copied Toast")
                                            .font(.system(size: 11.5))
                                        Text("Displays an ephemeral badge near your cursor confirming clipboard capture")
                                            .font(.system(size: 10.5))
                                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                    }
                                }
                                .toggleStyle(.checkbox)
                                
                                Toggle(isOn: Binding(
                                    get: { viewModel.isCopyAllowEverywhere },
                                    set: { viewModel.setCopyAllowEverywhere($0) }
                                )) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Allow in Terminal Emulators")
                                            .font(.system(size: 11.5))
                                        Text("Enables copying inside Terminal, iTerm2, Warp, Ghostty, Alacritty, Kitty")
                                            .font(.system(size: 10.5))
                                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                    }
                                }
                                .toggleStyle(.checkbox)
                                
                                // Security reassurance callout
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.shield.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(NNTSColors.appleEmerald)
                                    Text("Immutable Vault Protection: 1Password, Bitwarden, Apple Passwords & KeePass are strictly protected and never intercepted.")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.25))
                                )
                                
                                // Interactive Copy Test Zone
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Interactive Test Sandbox:")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                    
                                    HStack {
                                        Text(viewModel.testHighlightText)
                                            .font(.system(size: 11.5))
                                            .foregroundColor(Color(nsColor: .labelColor))
                                            .textSelection(.enabled)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(Color(nsColor: .textBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.75)
                                    )
                                }
                            }
                            .padding(.leading, 24)
                        }
                    }
                    
                    Divider()
                        .opacity(0.4)
                    
                    // Feature 2: Finder Window Tidy
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle(isOn: Binding(
                            get: { viewModel.isFinderTidyEnabled },
                            set: { viewModel.setFinderTidyEnabled($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Finder Window Tidy")
                                    .font(.system(size: 12.5, weight: .medium))
                                Text("Automatically closes background Finder windows to prevent desktop clutter")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            }
                        }
                        .toggleStyle(.switch)
                        
                        if viewModel.isFinderTidyEnabled {
                            HStack(spacing: 12) {
                                Text("Window Ceiling Limit:")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                
                                Picker("", selection: Binding(
                                    get: { viewModel.finderMaxWindows },
                                    set: { viewModel.setFinderMaxWindows($0) }
                                )) {
                                    Text("1 Window").tag(1)
                                    Text("3 Windows").tag(3)
                                    Text("5 Windows (Recommended)").tag(5)
                                    Text("10 Windows").tag(10)
                                    Text("Unlimited").tag(0)
                                }
                                .pickerStyle(.menu)
                                .frame(width: 190)
                                
                                Spacer()
                                
                                Button {
                                    withAnimation(NNTSMotion.interactiveSnap) {
                                        viewModel.tidyFinderWindowsNow()
                                    }
                                } label: {
                                    HStack(spacing: 5) {
                                        Image(systemName: "wand.and.stars")
                                            .font(.system(size: 10.5))
                                        Text("Tidy Now")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4.5)
                                .background(
                                    Capsule()
                                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                                        .overlay(
                                            Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.75)
                                        )
                                )
                                .help("Immediately closes excess background Finder windows")
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
            }
            
            // 3. Application Info & Updates
            SettingsSectionBox(
                title: "Application & Updates",
                subtitle: "Version details and update channel management",
                icon: "arrow.triangle.2.circlepath.circle",
                iconColor: NNTSColors.cadmiumYellow
            ) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NNTS v\(viewModel.appVersion)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(nsColor: .labelColor))
                        Text(viewModel.installationSource == .homebrew ? "Installed via Homebrew Cask" : "Installed via Standalone Application")
                            .font(.system(size: 10.5))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    }
                    
                    Spacer()
                    
                    Button("Check for Updates...") {
                        viewModel.checkForUpdates()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4.5)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                            .overlay(
                                Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.75)
                            )
                    )
                }
            }
        }
    }
}
