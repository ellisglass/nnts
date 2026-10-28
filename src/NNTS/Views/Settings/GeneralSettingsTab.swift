import SwiftUI
import AppKit

// MARK: - Shared Settings Section Box

internal struct SettingsSectionBox<Content: View>: View {
    let title: String
    let icon: String
    let content: () -> Content
    
    init(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.accentColor)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(nsColor: .labelColor))
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.40), lineWidth: 0.5)
        )
    }
}

// MARK: - Tab 1: General Settings

internal struct GeneralTabContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Hardware & System
            SettingsSectionBox(title: "System Integration", icon: "keyboard") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Circle()
                            .fill(viewModel.isCapsLockRemapped ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(viewModel.isCapsLockRemapped ? "caps lock mapped to virtual F18" : "caps lock not remapped")
                            .font(.system(size: 12))
                            .foregroundColor(Color(nsColor: .labelColor))
                        
                        Spacer()
                        
                        if viewModel.isCapsLockRemapped {
                            Button("Restore System Default") {
                                viewModel.restoreDefaultCapsLock()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button("Apply Remapping") {
                                viewModel.reapplyCapsLockRemapping()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Image(systemName: viewModel.isAccessibilityTrusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(viewModel.isAccessibilityTrusted ? .green : .orange)
                            .font(.system(size: 12))
                        Text(viewModel.isAccessibilityTrusted ? "Accessibility permissions granted" : "Accessibility permissions required")
                            .font(.system(size: 12))
                            .foregroundColor(Color(nsColor: .labelColor))
                        
                        Spacer()
                        
                        if !viewModel.isAccessibilityTrusted {
                            Button("Open System Settings...") {
                                viewModel.openAccessibilitySettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        } else {
                            Button("Check Again") {
                                viewModel.refreshGeneral()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            
            // Features
            SettingsSectionBox(title: "Productivity Features", icon: "sparkles") {
                VStack(alignment: .leading, spacing: 12) {
                    // Copy on Select
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { viewModel.isCopyOnSelectEnabled },
                            set: { viewModel.setCopyOnSelectEnabled($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Copy on Select")
                                    .font(.system(size: 12.5, weight: .medium))
                                Text("Automatically copies text to clipboard whenever you highlight it")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            }
                        }
                        .toggleStyle(.switch)
                        
                        if viewModel.isCopyOnSelectEnabled {
                            VStack(alignment: .leading, spacing: 6) {
                                Toggle(isOn: Binding(
                                    get: { viewModel.isCopyToastEnabled },
                                    set: { viewModel.setCopyToastEnabled($0) }
                                )) {
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Show Copied Toast")
                                            .font(.system(size: 11.5))
                                        Text("Displays an ephemeral badge near your cursor upon copying")
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
                                        Text("Allow Everywhere")
                                            .font(.system(size: 11.5))
                                        Text("Enables copying across all applications, including Terminal emulators")
                                            .font(.system(size: 10.5))
                                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                    }
                                }
                                .toggleStyle(.checkbox)
                            }
                            .padding(.leading, 24)
                        }
                    }
                    
                    Divider()
                    
                    // Finder Window Tidy
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: Binding(
                            get: { viewModel.isFinderTidyEnabled },
                            set: { viewModel.setFinderTidyEnabled($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Finder Window Tidy")
                                    .font(.system(size: 12.5, weight: .medium))
                                Text("Automatically closes extra background Finder windows")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            }
                        }
                        .toggleStyle(.switch)
                        
                        if viewModel.isFinderTidyEnabled {
                            HStack {
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
                                .frame(width: 200)
                            }
                            .padding(.leading, 24)
                        }
                    }
                }
            }
        }
    }
}
