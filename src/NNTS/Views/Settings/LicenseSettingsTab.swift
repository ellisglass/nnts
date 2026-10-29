import SwiftUI
import AppKit

// MARK: - Tab 3: License Settings

internal struct LicenseTabContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Main License Status Box
            SettingsSectionBox(
                title: "License & Edition",
                subtitle: "Manage your NNTS Pro license, feature entitlements, and activations",
                icon: "checkmark.seal",
                iconColor: NNTSColors.cadmiumYellow
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    // Hero Card: Pro vs Free
                    if viewModel.isPro {
                        // Pro Activated Hero Card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.yellow.opacity(0.3), Color.orange.opacity(0.2)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 40, height: 40)
                                    
                                    Image(systemName: "crown.fill")
                                        .foregroundColor(NNTSColors.cadmiumYellow)
                                        .font(.system(size: 18))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("NNTS Pro Edition")
                                            .font(NNTSFont.display(size: 15))
                                            .foregroundColor(Color(nsColor: .labelColor))
                                        
                                        Text("ACTIVE")
                                            .font(.system(size: 9.5, weight: .bold))
                                            .foregroundColor(NNTSColors.appleEmerald)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule().fill(NNTSColors.appleEmerald.opacity(0.16))
                                            )
                                    }
                                    
                                    Text("All limits unlocked. Lifetime entitlements active on this Mac.")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                }
                                
                                Spacer()
                                
                                if !viewModel.showingDeactivateConfirm {
                                    Button("Deactivate...") {
                                        viewModel.showingDeactivateConfirm = true
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4.5)
                                    .background(
                                        Capsule()
                                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.3))
                                            .overlay(Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.75))
                                    )
                                } else {
                                    HStack(spacing: 6) {
                                        Button("Cancel") {
                                            viewModel.showingDeactivateConfirm = false
                                        }
                                        .buttonStyle(.plain)
                                        .font(.system(size: 11))
                                        
                                        Button("Confirm") {
                                            viewModel.showingDeactivateConfirm = false
                                            viewModel.deactivateLicense()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(NNTSColors.vermilion)
                                        .controlSize(.small)
                                    }
                                }
                            }
                            
                            Divider()
                                .opacity(0.4)
                            
                            // Unlocked perks checklist
                            VStack(alignment: .leading, spacing: 6) {
                                Text("UNLOCKED PRO FEATURES")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                
                                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                                    GridRow {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(NNTSColors.appleEmerald)
                                                .font(.system(size: 11))
                                            Text("Unlimited Quick App slots")
                                                .font(.system(size: 11))
                                        }
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(NNTSColors.appleEmerald)
                                                .font(.system(size: 11))
                                            Text("Rapid profile switching (up to 8)")
                                                .font(.system(size: 11))
                                        }
                                    }
                                    GridRow {
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(NNTSColors.appleEmerald)
                                                .font(.system(size: 11))
                                            Text("Copy-on-Select automation")
                                                .font(.system(size: 11))
                                        }
                                        HStack(spacing: 6) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(NNTSColors.appleEmerald)
                                                .font(.system(size: 11))
                                            Text("Intelligent Finder Window Tidy")
                                                .font(.system(size: 11))
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Free Edition Status & Feature Comparison
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: "person.fill")
                                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                        .font(.system(size: 16))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text("NNTS Free Edition")
                                            .font(NNTSFont.display(size: 14))
                                            .foregroundColor(Color(nsColor: .labelColor))
                                        
                                        Text("FREE")
                                            .font(.system(size: 9.5, weight: .bold))
                                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(
                                                Capsule().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
                                            )
                                    }
                                    
                                    Text("Quick Apps limited to 4 slots. Upgrade to Pro for unlimited apps.")
                                        .font(.system(size: 11.5))
                                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                }
                                
                                Spacer()
                                
                                Button {
                                    viewModel.openPolarCheckout()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 11))
                                        Text("Get NNTS Pro...")
                                            .font(.system(size: 12, weight: .semibold))
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                            }
                            
                            // Feature Matrix Pill
                            HStack(spacing: 0) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Free Edition")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                    Text("4 Pinned Quick Apps")
                                        .font(.system(size: 11))
                                    Text("8 Browser Profiles")
                                        .font(.system(size: 11))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Divider()
                                    .frame(height: 36)
                                    .padding(.horizontal, 12)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Pro Edition")
                                        .font(.system(size: 10.5, weight: .semibold))
                                        .foregroundColor(NNTSColors.cadmiumYellow)
                                    Text("Unlimited Quick Apps")
                                        .font(.system(size: 11, weight: .medium))
                                    Text("Priority Updates & Support")
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
                            )
                        }
                    }
                    
                    // Key Activation Card (always available if not Pro or to replace key)
                    if !viewModel.isPro {
                        Divider()
                            .opacity(0.4)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Activate License Key:")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(Color(nsColor: .labelColor))
                            
                            HStack(spacing: 8) {
                                TextField("XXXX-XXXX-XXXX-XXXX", text: $viewModel.licenseKeyInput)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .fill(Color(nsColor: .textBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                            .strokeBorder(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.75)
                                    )
                                    .onSubmit {
                                        if !viewModel.licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty {
                                            viewModel.activateLicenseKey()
                                        }
                                    }
                                
                                Button {
                                    viewModel.activateLicenseKey()
                                } label: {
                                    if viewModel.isActivating {
                                        ProgressView()
                                            .controlSize(.small)
                                            .frame(width: 50)
                                    } else {
                                        Text("Activate")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                                .disabled(viewModel.isActivating || viewModel.licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            
                            if let msg = viewModel.activationMessage {
                                HStack(spacing: 6) {
                                    Image(systemName: viewModel.isActivationError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                    Text(msg)
                                }
                                .font(.system(size: 11))
                                .foregroundColor(viewModel.isActivationError ? NNTSColors.vermilion : NNTSColors.appleEmerald)
                                .padding(.top, 2)
                                .transition(.opacity)
                            }
                        }
                    }
                }
            }
        }
    }
}
