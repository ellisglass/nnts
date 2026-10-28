import SwiftUI
import AppKit

// MARK: - Tab 2: Shortcuts (Quick Apps & Profiles)

internal struct ShortcutsTabContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Quick Apps Section
            SettingsSectionBox(title: "Quick Apps (caps lock + letter)", icon: "square.grid.2x2") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        let count = viewModel.pinnedApps.count
                        let maxSlots = AppGroupEngine.maxPinnedQuickApps
                        Text(viewModel.isPro ? "\(count) apps pinned (Unlimited)" : "\(count) of \(maxSlots) slots pinned")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                        
                        Spacer()
                    }
                    
                    // Pinned list
                    if viewModel.pinnedApps.isEmpty {
                        Text("No apps pinned. Search and select apps below.")
                            .font(.system(size: 11.5))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(viewModel.pinnedApps) { app in
                                HStack(spacing: 10) {
                                    Image(nsImage: app.icon)
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                    
                                    Text(app.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Color(nsColor: .labelColor))
                                    
                                    Spacer()
                                    
                                    Text("caps lock + \(String(app.firstLetter).lowercased())")
                                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule().fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
                                        )
                                    
                                    Button(action: {
                                        viewModel.unpinApp(bundleID: app.bundleID)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Unpin app")
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
                                )
                            }
                        }
                    }
                    
                    // Search bar to add apps
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .font(.system(size: 11))
                        TextField("Search apps to pin...", text: $viewModel.appSearchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5))
                            .onChange(of: viewModel.appSearchQuery) { _, _ in
                                viewModel.refreshShortcuts()
                            }
                    }
                    .padding(7)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    
                    // Search dropdown results if searching
                    if !viewModel.appSearchQuery.isEmpty && !viewModel.appSearchResults.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(viewModel.appSearchResults.prefix(4)) { app in
                                HStack {
                                    Image(nsImage: app.icon)
                                        .resizable()
                                        .frame(width: 20, height: 20)
                                    Text(app.name)
                                        .font(.system(size: 11.5))
                                    Spacer()
                                    let isPinned = viewModel.pinnedBundleIDs.contains(app.bundleID)
                                    if isPinned {
                                        Text("Pinned")
                                            .font(.system(size: 10.5, weight: .medium))
                                            .foregroundColor(.green)
                                    } else {
                                        Button("Pin") {
                                            viewModel.pinApp(app: app)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.mini)
                                    }
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
                        )
                    }
                }
            }
            
            // Browser Profiles Section
            SettingsSectionBox(title: "Browser Profiles (caps lock + 1..8)", icon: "person.2") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Picker("Browser:", selection: $viewModel.currentBrowserBundleID) {
                            ForEach(viewModel.availableBrowsers) { b in
                                Text(b.name).tag(b.bundleID)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 220)
                        .onChange(of: viewModel.currentBrowserBundleID) { _, newID in
                            viewModel.chooseBrowser(bundleID: newID)
                        }
                        
                        Spacer()
                        
                        Button("Refresh Profiles") {
                            viewModel.refreshBrowserProfiles()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    if viewModel.profiles.isEmpty {
                        Text("No browser profiles detected. Ensure your browser is installed.")
                            .font(.system(size: 11.5))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .padding(.vertical, 4)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Drag to reorder slots 1–8. Up to 8 quick profiles active.")
                                .font(.system(size: 11))
                                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                .padding(.bottom, 2)
                            
                            ForEach(viewModel.profiles) { p in
                                DraggableProfileRow(
                                    profile: p,
                                    totalCount: viewModel.profiles.count,
                                    viewModel: viewModel
                                )
                            }
                            
                            if !viewModel.unassignedProfiles.isEmpty {
                                Divider()
                                    .padding(.vertical, 6)
                                
                                Text("Available Profiles (\(viewModel.unassignedProfiles.count))")
                                    .font(.system(size: 11.5, weight: .semibold))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                
                                VStack(spacing: 5) {
                                    ForEach(viewModel.unassignedProfiles) { p in
                                        HStack(spacing: 8) {
                                            ZStack {
                                                if let img = p.avatarImage {
                                                    Image(nsImage: img)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 22, height: 22)
                                                        .clipShape(Circle())
                                                } else {
                                                    Circle()
                                                        .fill(Color.gray.opacity(0.20))
                                                        .frame(width: 22, height: 22)
                                                    let char = p.effectiveName.first(where: { $0.isLetter || $0.isNumber }) ?? "P"
                                                    Text(String(char).uppercased())
                                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .frame(width: 22, height: 22)
                                            
                                            Text(p.effectiveName)
                                                .font(.system(size: 11.5))
                                                .foregroundColor(Color(nsColor: .labelColor))
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            Button("+ Add to Slots") {
                                                viewModel.addProfileToActiveSlots(dir: p.dir)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            .disabled(viewModel.profiles.count >= ChromeProfileEngine.maxProfileSlots)
                                            .help(viewModel.profiles.count >= ChromeProfileEngine.maxProfileSlots ? "All 8 slots full" : "Add to quick access slots")
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Draggable Profile Row

internal struct DraggableProfileRow: View {
    let profile: ChromeProfile
    let totalCount: Int
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        let isTargeted = viewModel.targetedProfileDir == profile.dir
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                .help("Drag to reorder slot")
            
            Text("\(profile.index)")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.accentColor.opacity(0.85)))
            
            // Avatar
            ZStack {
                if let img = profile.avatarImage {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 26, height: 26)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.accentColor.opacity(0.20))
                        .frame(width: 26, height: 26)
                    let char = profile.effectiveName.first(where: { $0.isLetter || $0.isNumber }) ?? "P"
                    Text(String(char).uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Color.accentColor)
                }
            }
            .frame(width: 26, height: 26)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(profile.effectiveName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .lineLimit(1)
                Text("caps lock + \(profile.index)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
            }
            
            Spacer()
            
            // Reorder buttons
            HStack(spacing: 3) {
                Button(action: { viewModel.moveProfileUp(dir: profile.dir) }) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .disabled(profile.index <= 1)
                .help("Move slot up")
                
                Button(action: { viewModel.moveProfileDown(dir: profile.dir) }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }
                .buttonStyle(.plain)
                .frame(width: 16, height: 16)
                .disabled(profile.index >= totalCount)
                .help("Move slot down")
            }
            
            Button("Paste Avatar") {
                viewModel.pasteProfileAvatar(dir: profile.dir)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Paste image from clipboard as avatar")
            
            Button("Reset") {
                viewModel.resetProfileAvatar(dir: profile.dir)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundColor(Color(nsColor: .secondaryLabelColor))
            .help("Reset to monogram avatar")
            
            if totalCount > 1 {
                Button(action: { viewModel.removeProfileFromActiveSlots(dir: profile.dir) }) {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }
                .buttonStyle(.plain)
                .help("Remove from quick access slots")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isTargeted ? Color.accentColor.opacity(0.18) : Color(nsColor: .controlBackgroundColor).opacity(0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .draggable(profile.dir)
        .dropDestination(for: String.self) { items, _ in
            viewModel.targetedProfileDir = nil
            guard let droppedDir = items.first, droppedDir != profile.dir else { return false }
            viewModel.reorderProfile(draggedDir: droppedDir, targetDir: profile.dir)
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.targetedProfileDir = targeted ? profile.dir : nil
            }
        }
    }
}
