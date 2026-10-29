import SwiftUI
import AppKit

// MARK: - Tab 2: Shortcuts (Quick Apps & Profiles)

internal struct ShortcutsTabContent: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Quick Apps Section
            SettingsSectionBox(
                title: "Quick Apps (caps lock + letter)",
                subtitle: "Apps are triggered with caps lock + letter. Apps sharing the same letter cycle on subsequent presses.",
                icon: "square.grid.2x2",
                iconColor: NNTSColors.cadmiumYellow
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        let count = viewModel.pinnedApps.count
                        let maxSlots = AppGroupEngine.maxPinnedQuickApps
                        
                        HStack(spacing: 6) {
                            Text(viewModel.isPro ? "\(count) apps pinned (Unlimited)" : "\(count) of \(maxSlots) slots pinned")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(Color(nsColor: .labelColor))
                            
                            if !viewModel.isPro && count >= maxSlots {
                                Text("MAX")
                                    .font(.system(size: 9.5, weight: .bold))
                                    .foregroundColor(NNTSColors.cadmiumYellow)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1.5)
                                    .background(
                                        Capsule().fill(NNTSColors.cadmiumYellow.opacity(0.18))
                                    )
                            }
                        }
                        
                        Spacer()
                    }
                    
                    // Pinned list grouped by letter
                    if viewModel.pinnedApps.isEmpty {
                        Text("No apps pinned. Search and select apps below.")
                            .font(.system(size: 11.5))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(viewModel.pinnedLetterGroups) { group in
                                PinnedAppLetterGroupCard(group: group, viewModel: viewModel)
                            }
                        }
                    }
                    
                    // Search bar to add apps
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .font(.system(size: 11.5, weight: .medium))
                        TextField("Search installed applications to pin...", text: $viewModel.appSearchQuery)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11.5))
                            .onChange(of: viewModel.appSearchQuery) { _, _ in
                                viewModel.refreshShortcuts()
                            }
                        
                        if !viewModel.appSearchQuery.isEmpty {
                            Button {
                                viewModel.appSearchQuery = ""
                                viewModel.refreshShortcuts()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                    .frame(width: 18, height: 18)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(nsColor: .textBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.75)
                    )
                    
                    // Search dropdown results if searching
                    if !viewModel.appSearchQuery.isEmpty && !viewModel.appSearchResults.isEmpty {
                        VStack(spacing: 4) {
                            ForEach(viewModel.appSearchResults.prefix(5)) { app in
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
                                            .foregroundColor(NNTSColors.appleEmerald)
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
                    } else if viewModel.appSearchQuery.isEmpty {
                        HStack {
                            Button {
                                viewModel.openAppPicker()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.grid.2x2")
                                        .font(.system(size: 11, weight: .medium))
                                    Text("Browse All Installed Applications...")
                                        .font(.system(size: 11.5, weight: .medium))
                                }
                                .foregroundColor(Color(nsColor: .labelColor))
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5.5)
                                .background(
                                    Capsule()
                                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                                        .overlay(
                                            Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.75)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                    
                    // Slot Limit / Pro Notice Banner
                    if viewModel.isSlotLimitReached {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(NNTSColors.cadmiumYellow)
                            Text("Free edition is limited to 4 quick apps. Upgrade to Pro for unlimited apps, or click an app's 'x' to swap.")
                                .font(.system(size: 10.5))
                                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            Spacer()
                            Button("Get Pro...") {
                                viewModel.selectedTab = .license
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(NNTSColors.cadmiumYellow)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(NNTSColors.cadmiumYellow.opacity(0.10))
                        )
                    }
                }
            }
            
            // Browser Profiles Section
            SettingsSectionBox(
                title: "Browser Profiles (caps lock + 1..8)",
                subtitle: "Direct window raising for individual Chrome, Brave, and Chromium profiles",
                icon: "person.2",
                iconColor: NNTSColors.cobaltBlue
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    // Header Controls Bar
                    HStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Text("Browser:")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            
                            Picker("", selection: $viewModel.currentBrowserBundleID) {
                                ForEach(viewModel.availableBrowsers) { b in
                                    Text(b.name).tag(b.bundleID)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: 180)
                            .onChange(of: viewModel.currentBrowserBundleID) { _, newID in
                                viewModel.chooseBrowser(bundleID: newID)
                            }
                        }
                        
                        Spacer()
                        
                        // Sync Real Profile Photos Button / Status Pill
                        Button {
                            viewModel.linkChromeFolder()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: viewModel.isChromeFolderLinked ? "checkmark.circle.fill" : "photo.badge.arrow.forward")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(viewModel.isChromeFolderLinked ? NNTSColors.appleEmerald : NNTSColors.cobaltBlue)
                                Text(viewModel.isChromeFolderLinked ? "Real Photos Linked" : "Sync Real Photos")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(Color(nsColor: .labelColor))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(viewModel.isChromeFolderLinked ? NNTSColors.appleEmerald.opacity(0.12) : Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                                    .overlay(
                                        Capsule()
                                            .stroke(viewModel.isChromeFolderLinked ? NNTSColors.appleEmerald.opacity(0.32) : Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.75)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .help(viewModel.isChromeFolderLinked ? "Browser directory connected. Click to re-sync or change folder." : "Click to connect your Google Chrome folder and display real account photos.")
                        
                        // Rescan Button
                        Button {
                            viewModel.refreshBrowserProfiles()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Rescan")
                                    .font(.system(size: 11.5, weight: .medium))
                            }
                            .foregroundColor(Color(nsColor: .labelColor))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 0.75)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Rescan browser profiles without altering your custom slots")
                        
                        // Options Gear Menu
                        Menu {
                            Button("Populate All Discovered Profiles") {
                                viewModel.resetSlotsToAllDiscovered()
                            }
                            Divider()
                            Button("Link Chrome Folder...") {
                                viewModel.linkChromeFolder()
                            }
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                .frame(width: 26, height: 26)
                                .background(
                                    Circle()
                                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                                )
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.hidden)
                        .frame(width: 26, height: 26)
                        .help("Advanced slot options")
                    }
                    
                    if viewModel.profiles.isEmpty {
                        Text("No browser profiles detected. Ensure your browser is installed.")
                            .font(.system(size: 11.5))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .padding(.vertical, 6)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Active Slots (\(viewModel.profiles.count) of \(ChromeProfileEngine.maxProfileSlots))")
                                    .font(NNTSFont.display(size: 11.5))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                Spacer()
                                Text("Click photo to change • Use arrows or drag to reorder")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            }
                            .padding(.bottom, 2)
                            
                            ActiveProfilesListView(viewModel: viewModel)
                            
                            if !viewModel.unassignedProfiles.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                                
                                HStack {
                                    Text("Available Profiles (\(viewModel.unassignedProfiles.count))")
                                        .font(NNTSFont.display(size: 12))
                                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                    Spacer()
                                    Text("Click + to add to quick access slots")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                                }
                                
                                VStack(spacing: 6) {
                                    ForEach(viewModel.unassignedProfiles) { p in
                                        HStack(spacing: 10) {
                                            ZStack {
                                                if let img = p.avatarImage {
                                                    Image(nsImage: img)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 28, height: 28)
                                                        .clipShape(Circle())
                                                        .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                                                } else {
                                                    Circle()
                                                        .fill(LinearGradient(
                                                            colors: [Color.gray.opacity(0.25), Color.gray.opacity(0.40)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ))
                                                        .frame(width: 28, height: 28)
                                                    let char = p.effectiveName.first(where: { $0.isLetter || $0.isNumber }) ?? "P"
                                                    Text(String(char).uppercased())
                                                        .font(NNTSFont.display(size: 11))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .frame(width: 28, height: 28)
                                            
                                            HStack(spacing: 6) {
                                                Text(p.effectiveName)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(Color(nsColor: .labelColor))
                                                    .lineLimit(1)
                                                
                                                if let given = p.gaiaGivenName, !given.isEmpty, given.lowercased() != p.effectiveName.lowercased() {
                                                    Text(given)
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 1.5)
                                                        .background(
                                                            Capsule()
                                                                .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.4))
                                                        )
                                                        .lineLimit(1)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Button {
                                                viewModel.addProfileToActiveSlots(dir: p.dir)
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: "plus")
                                                        .font(.system(size: 10, weight: .bold))
                                                    Text("Add to Slots")
                                                        .font(.system(size: 11, weight: .medium))
                                                }
                                                .foregroundColor(viewModel.profiles.count >= ChromeProfileEngine.maxProfileSlots ? Color.secondary : Color.white)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4.5)
                                                .background(
                                                    Capsule()
                                                        .fill(viewModel.profiles.count >= ChromeProfileEngine.maxProfileSlots ? Color.gray.opacity(0.15) : NNTSColors.cobaltBlue.opacity(0.85))
                                                )
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(viewModel.profiles.count >= ChromeProfileEngine.maxProfileSlots)
                                            .help(viewModel.profiles.count >= ChromeProfileEngine.maxProfileSlots ? "All 8 slots full" : "Add to quick access slots")
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.35))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                        .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
                                                )
                                        )
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

// MARK: - Grouped Pinned Apps Views

@MainActor
internal final class PinnedAppRowState: ObservableObject {
    @Published var isHoveringRow: Bool = false
    @Published var isHoveringUnpin: Bool = false
}

internal struct PinnedAppLetterGroupCard: View {
    let group: PinnedAppGroup
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Letter Group Header
            HStack(spacing: 6) {
                Text(String(group.letter))
                    .font(NNTSFont.slotDigit(size: 10.5))
                    .foregroundColor(Color(nsColor: .labelColor))
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.55))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color(nsColor: .separatorColor).opacity(0.35), lineWidth: 0.5)
                    )
                
                if group.items.count > 1 {
                    HStack(spacing: 4) {
                        Text("•")
                            .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                        Text("\(group.items.count) apps cycle")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(NNTSColors.cadmiumYellow)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 2)
            .padding(.top, 1)
            
            // App Rows in this group
            VStack(spacing: 4) {
                ForEach(Array(group.items.enumerated()), id: \.element.id) { indexInGroup, app in
                    PinnedAppRow(
                        app: app,
                        indexInGroup: indexInGroup,
                        totalInGroup: group.items.count,
                        viewModel: viewModel
                    )
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.35))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(group.items.count > 1 ? NNTSColors.cadmiumYellow.opacity(0.18) : Color(nsColor: .separatorColor).opacity(0.20), lineWidth: 0.75)
        )
    }
}

internal struct PinnedAppRow: View {
    let app: AntigravityItem
    let indexInGroup: Int
    let totalInGroup: Int
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var rowState = PinnedAppRowState()
    
    var body: some View {
        HStack(spacing: 10) {
            // 1. App Icon
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 24, height: 24)
            
            // 2. App Name
            Text(app.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(nsColor: .labelColor))
                .lineLimit(1)
            
            Spacer()
            
            // 3. Compact Keycap Badge (Zero "caps lock +" repetition, disciplined color)
            HStack(spacing: 3.5) {
                Text(String(app.firstLetter).uppercased())
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(nsColor: .labelColor))
                
                if totalInGroup > 1 {
                    Text("·")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                    
                    Text("\(indexInGroup + 1)/\(totalInGroup) ↻")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(NNTSColors.cadmiumYellow)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: Color.black.opacity(0.10), radius: 1, y: 0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(
                        totalInGroup > 1 ? NNTSColors.cadmiumYellow.opacity(0.35) : Color(nsColor: .separatorColor).opacity(0.35),
                        lineWidth: 0.75
                    )
            )
            .help(totalInGroup > 1 ? "Shortcut: caps lock + \(String(app.firstLetter).lowercased()) (cycle \(indexInGroup + 1) of \(totalInGroup))" : "Shortcut: caps lock + \(String(app.firstLetter).lowercased())")
            
            // 4. Subtle Cycle Reorder Stepper (for cyclic apps)
            if totalInGroup > 1 {
                HStack(spacing: 2) {
                    Button {
                        viewModel.movePinnedAppUp(bundleID: app.bundleID)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(indexInGroup > 0 ? Color(nsColor: .labelColor) : Color(nsColor: .tertiaryLabelColor).opacity(0.30))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(indexInGroup <= 0)
                    .help(indexInGroup > 0 ? "Move up in cycle order" : "First in cycle order")
                    
                    Button {
                        viewModel.movePinnedAppDown(bundleID: app.bundleID)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(indexInGroup < totalInGroup - 1 ? Color(nsColor: .labelColor) : Color(nsColor: .tertiaryLabelColor).opacity(0.30))
                            .frame(width: 20, height: 20)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(indexInGroup >= totalInGroup - 1)
                    .help(indexInGroup < totalInGroup - 1 ? "Move down in cycle order" : "Last in cycle order")
                }
            }
            
            // 5. Accessible Unpin Button with generous hover target
            Button {
                viewModel.unpinApp(bundleID: app.bundleID)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundColor(rowState.isHoveringUnpin ? NNTSColors.vermilion : Color(nsColor: .secondaryLabelColor))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { h in
                rowState.isHoveringUnpin = h
            }
            .help("Unpin app")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(rowState.isHoveringRow ? 0.70 : 0.45))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(rowState.isHoveringRow ? 0.35 : 0.15), lineWidth: 0.5)
        )
        .onHover { h in
            rowState.isHoveringRow = h
        }
    }
}

// MARK: - Fluid, Zero-Jump Active Profiles List View

internal struct ActiveProfilesListView: View {
    @ObservedObject var viewModel: SettingsViewModel
    
    var body: some View {
        VStack(spacing: 6) {
            ForEach(viewModel.profiles) { p in
                ModernProfileRow(
                    profile: p,
                    totalCount: viewModel.profiles.count,
                    isTargeted: viewModel.targetedProfileDir == p.dir,
                    viewModel: viewModel
                )
                .dropDestination(for: String.self) { items, _ in
                    viewModel.targetedProfileDir = nil
                    guard let droppedDir = items.first, droppedDir != p.dir else { return false }
                    viewModel.reorderProfile(draggedDir: droppedDir, targetDir: p.dir)
                    return true
                } isTargeted: { targeted in
                    viewModel.targetedProfileDir = targeted ? p.dir : nil
                }
            }
        }
    }
}

// MARK: - Row Local Hover State

@MainActor
internal final class ProfileRowState: ObservableObject {
    @Published var isHoveringRow: Bool = false
    @Published var isHoveringAvatar: Bool = false
    @Published var isDropTargeted: Bool = false
}

// MARK: - Modern Streamlined Profile Row (Reorder + Avatar + Remove)

internal struct ModernProfileRow: View {
    let profile: ChromeProfile
    let totalCount: Int
    let isTargeted: Bool
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var rowState = ProfileRowState()
    
    var body: some View {
        HStack(spacing: 10) {
            // 1. Reorder Grip Handle
            Image(systemName: "circle.grid.2x3.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Color(nsColor: .secondaryLabelColor).opacity(rowState.isHoveringRow ? 0.90 : 0.40))
                .frame(width: 14, height: 32)
                .contentShape(Rectangle())
                .draggable(profile.dir)
                .help("Drag to reorder slot")
            
            // 2. Slot badge in Cobalt Blue
            Text("\(profile.index)")
                .font(NNTSFont.slotDigit(size: 11))
                .foregroundColor(.white)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [NNTSColors.cobaltBlue, NNTSColors.cobaltBlue.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
            
            // 3. Avatar (1-Click Photo Picker, Drop Image, or Right-Click Context Menu)
            Button {
                viewModel.chooseAvatarFile(dir: profile.dir)
            } label: {
                ZStack {
                    if let img = profile.avatarImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 0.75))
                    } else {
                        Circle()
                            .fill(LinearGradient(
                                colors: [NNTSColors.cobaltBlue, Color(red: 0.55, green: 0.35, blue: 0.85)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 32, height: 32)
                        let char = profile.effectiveName.first(where: { $0.isLetter || $0.isNumber }) ?? "P"
                        Text(String(char).uppercased())
                            .font(NNTSFont.display(size: 12))
                            .foregroundColor(.white)
                    }
                    
                    // Hover Camera / Edit Action Overlay
                    if rowState.isHoveringAvatar || rowState.isDropTargeted {
                        Circle()
                            .fill(Color.black.opacity(0.55))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: rowState.isDropTargeted ? "plus" : "camera.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 32, height: 32)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { h in
                rowState.isHoveringAvatar = h
            }
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                viewModel.setAvatarFromImageURL(url: url, dir: profile.dir)
                return true
            } isTargeted: { targeted in
                rowState.isDropTargeted = targeted
            }
            .help("Click to change photo, or drop image file here")
            .contextMenu {
                Button {
                    viewModel.chooseAvatarFile(dir: profile.dir)
                } label: {
                    Label("Choose Photo from Disk...", systemImage: "photo")
                }
                Button {
                    viewModel.pasteProfileAvatar(dir: profile.dir)
                } label: {
                    Label("Paste from Clipboard (⌘⌃⇧4)", systemImage: "doc.on.clipboard")
                }
                Button {
                    viewModel.resetProfileAvatar(dir: profile.dir)
                } label: {
                    Label("Reset to Monogram", systemImage: "arrow.counterclockwise")
                }
            }
            
            // 4. Name & Secondary Account Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.effectiveName)
                        .font(NNTSFont.display(size: 13))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .lineLimit(1)
                    
                    if let given = profile.gaiaGivenName, !given.isEmpty, given.lowercased() != profile.effectiveName.lowercased() {
                        Text(given)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(
                                Capsule()
                                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.45))
                            )
                            .lineLimit(1)
                    }
                }
                
                Text("caps lock + \(profile.index)")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
            }
            
            Spacer()
            
            // 5. Minimal Reorder Stepper [ ^ ] [ v ] (Zero Jump, 1-Click Swap)
            HStack(spacing: 2) {
                Button {
                    viewModel.moveProfileUp(dir: profile.dir)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(profile.index > 1 ? Color(nsColor: .labelColor) : Color(nsColor: .tertiaryLabelColor).opacity(0.35))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(profile.index <= 1)
                .help("Move slot up")
                
                Button {
                    viewModel.moveProfileDown(dir: profile.dir)
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(profile.index < totalCount ? Color(nsColor: .labelColor) : Color(nsColor: .tertiaryLabelColor).opacity(0.35))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(profile.index >= totalCount)
                .help("Move slot down")
            }
            .padding(.trailing, 2)
            
            // 6. Delete / Unpin Slot button (matches Quick Apps design)
            if totalCount > 1 {
                Button {
                    viewModel.removeProfileFromActiveSlots(dir: profile.dir)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                }
                .buttonStyle(.plain)
                .help("Remove from active slots")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: NNTSGeometry.settingsRowHeight)
        .background(
            RoundedRectangle(cornerRadius: NNTSGeometry.settingsCardRadius, style: .continuous)
                .fill(isTargeted ? NNTSColors.cobaltBlue.opacity(0.12) : NNTSColors.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: NNTSGeometry.settingsCardRadius, style: .continuous)
                .strokeBorder(
                    isTargeted ? NNTSColors.cobaltBlue : Color(nsColor: .separatorColor).opacity(0.25),
                    lineWidth: 1.0
                )
        )
        .onHover { hovering in
            rowState.isHoveringRow = hovering
        }
    }
}

// Backwards compatibility alias
internal typealias DraggableProfileRow = ModernProfileRow



