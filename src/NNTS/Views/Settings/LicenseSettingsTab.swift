import SwiftUI
import AppKit

// MARK: - Tab 3: License Settings

internal struct LicenseTabContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSectionBox(title: "License Status", icon: "checkmark.seal") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.isPro ? "crown.fill" : "person.fill")
                            .foregroundColor(viewModel.isPro ? .yellow : Color(nsColor: .secondaryLabelColor))
                            .font(.system(size: 15))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(viewModel.isPro ? "NNTS Pro Edition" : "NNTS Free Edition")
                                .font(.system(size: 13, weight: .semibold))
                            Text(viewModel.isPro ? "Unlimited Quick Apps & priority updates unlocked" : "Limited to 4 pinned quick app slots")
                                .font(.system(size: 11))
                                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        }
                        
                        Spacer()
                        
                        if viewModel.isPro {
                            Button("Deactivate") {
                                viewModel.deactivateLicense()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        } else {
                            Button("Get Pro...") {
                                viewModel.openPolarCheckout()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    
                    if !viewModel.isPro {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Activate License Key:")
                                .font(.system(size: 11.5, weight: .medium))
                            
                            HStack {
                                TextField("XXXX-XXXX-XXXX-XXXX", text: $viewModel.licenseKeyInput)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 11.5, design: .monospaced))
                                
                                Button("Activate") {
                                    viewModel.activateLicenseKey()
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .disabled(viewModel.isActivating || viewModel.licenseKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                            
                            if let msg = viewModel.activationMessage {
                                Text(msg)
                                    .font(.system(size: 11))
                                    .foregroundColor(viewModel.isActivationError ? .red : .green)
                            }
                        }
                    }
                }
            }
        }
    }
}
