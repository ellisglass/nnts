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
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Picker("Browser:", selection: $viewModel.currentBrowserBundleID) {
                            ForEach(viewModel.availableBrowsers) { b in
                                Text(b.name).tag(b.bundleID)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                        .onChange(of: viewModel.currentBrowserBundleID) { _, newID in
                            viewModel.chooseBrowser(bundleID: newID)
                        }
                        
                        Spacer()
                        
                        // Sync Real Profile Photos Button / Status Pill
                        Button {
                            viewModel.linkChromeFolder()
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: viewModel.isChromeFolderLinked ? "checkmark.circle.fill" : "photo.badge.arrow.forward")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(viewModel.isChromeFolderLinked ? NNTSColors.appleEmerald : Color.white)
                                Text(viewModel.isChromeFolderLinked ? "Real Photos Linked" : "Sync Real Photos")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundColor(viewModel.isChromeFolderLinked ? Color(nsColor: .labelColor) : Color.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(viewModel.isChromeFolderLinked ? Color.white.opacity(0.08) : NNTSColors.cobaltBlue)
                                    .overlay(
                                        Capsule()
                                            .stroke(viewModel.isChromeFolderLinked ? Color.white.opacity(0.14) : Color.clear, lineWidth: 0.75)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .help(viewModel.isChromeFolderLinked ? "Chrome folder connected. Click to re-sync or change folder." : "Click to connect your Google Chrome folder and display real Google account photos.")
                        
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
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .help("Rescan browser profiles without altering your custom slots")
                        
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
                                .font(.system(size: 11))
                                .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                .padding(5)
                        }
                        .menuStyle(.borderlessButton)
                        .frame(width: 24, height: 24)
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
                                Text("Quick Slots (caps lock + 1..\(viewModel.profiles.count))")
                                    .font(NNTSFont.display(size: 11.5))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                Spacer()
                                Text("Click avatar or drop photo to customize")
                                    .font(.system(size: 10.5))
                                    .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                            }
                            .padding(.bottom, 2)
                            
                            ActiveProfilesListView(viewModel: viewModel)
                            
                            if !viewModel.unassignedProfiles.isEmpty {
                                Divider()
                                    .padding(.vertical, 8)
                                
                                Text("Available Profiles (\(viewModel.unassignedProfiles.count))")
                                    .font(NNTSFont.display(size: 12))
                                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                
                                VStack(spacing: 6) {
                                    ForEach(viewModel.unassignedProfiles) { p in
                                        HStack(spacing: 10) {
                                            ZStack {
                                                if let img = p.avatarImage {
                                                    Image(nsImage: img)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 26, height: 26)
                                                        .clipShape(Circle())
                                                } else {
                                                    Circle()
                                                        .fill(Color.gray.opacity(0.20))
                                                        .frame(width: 26, height: 26)
                                                    let char = p.effectiveName.first(where: { $0.isLetter || $0.isNumber }) ?? "P"
                                                    Text(String(char).uppercased())
                                                        .font(NNTSFont.display(size: 11))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            .frame(width: 26, height: 26)
                                            
                                            HStack(spacing: 6) {
                                                Text(p.effectiveName)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(Color(nsColor: .labelColor))
                                                    .lineLimit(1)
                                                
                                                if let given = p.gaiaGivenName, !given.isEmpty, given.lowercased() != p.effectiveName.lowercased() {
                                                    Text("(\(given))")
                                                        .font(.system(size: 11))
                                                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                                                        .lineLimit(1)
                                                }
                                            }
                                            
                                            Spacer()
                                            
                                            Button {
                                                viewModel.addProfileToActiveSlots(dir: p.dir)
                                            } label: {
                                                Text("+ Add to Slots")
                                                    .font(.system(size: 11, weight: .medium))
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
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.35))
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

// MARK: - Zero-Lag Active Profiles State

@MainActor
internal final class ProfilesReorderState: ObservableObject {
    @Published var localProfiles: [ChromeProfile] = []
    @Published var targetedDir: String? = nil
    
    init(profiles: [ChromeProfile] = []) {
        self.localProfiles = profiles
    }
    
    func sync(with profiles: [ChromeProfile]) {
        if targetedDir == nil && localProfiles != profiles {
            self.localProfiles = profiles
        }
    }
}

// MARK: - Smooth Ergonomic Active Profiles List View

internal struct ActiveProfilesListView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var reorderState = ProfilesReorderState()
    
    var body: some View {
        VStack(spacing: 6) {
            ForEach(reorderState.localProfiles) { p in
                ModernProfileRow(
                    profile: p,
                    totalCount: reorderState.localProfiles.count,
                    isTargeted: reorderState.targetedDir == p.dir,
                    viewModel: viewModel
                )
                .dropDestination(for: String.self) { items, _ in
                    let targetDir = p.dir
                    reorderState.targetedDir = nil
                    guard let droppedDir = items.first, droppedDir != targetDir else { return false }
                    reorderLocal(draggedDir: droppedDir, targetDir: targetDir)
                    return true
                } isTargeted: { targeted in
                    reorderState.targetedDir = targeted ? p.dir : nil
                }
            }
        }
        .onAppear {
            reorderState.localProfiles = viewModel.profiles
        }
        .onChange(of: viewModel.profiles) { _, newProfiles in
            reorderState.sync(with: newProfiles)
        }
    }
    
    private func reorderLocal(draggedDir: String, targetDir: String) {
        guard let sourceIdx = reorderState.localProfiles.firstIndex(where: { $0.dir == draggedDir }),
              let targetIdx = reorderState.localProfiles.firstIndex(where: { $0.dir == targetDir }),
              sourceIdx != targetIdx else { return }
        
        withAnimation(NNTSMotion.interactiveSnap) {
            let item = reorderState.localProfiles.remove(at: sourceIdx)
            reorderState.localProfiles.insert(item, at: targetIdx)
            for i in 0..<reorderState.localProfiles.count {
                reorderState.localProfiles[i].index = i + 1
            }
        }
        
        viewModel.reorderProfile(draggedDir: draggedDir, targetDir: targetDir)
    }
}

// MARK: - Row Local Hover State

@MainActor
internal final class ProfileRowState: ObservableObject {
    @Published var isHoveringAvatar: Bool = false
    @Published var isHoveringRow: Bool = false
    @Published var justPastedAvatar: Bool = false
    @Published var isDropTargeted: Bool = false
}

// MARK: - Modern 2026 Profile Row with Interactive Avatar & Decluttered Controls

internal struct ModernProfileRow: View {
    let profile: ChromeProfile
    let totalCount: Int
    let isTargeted: Bool
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject private var rowState = ProfileRowState()
    
    var body: some View {
        HStack(spacing: 10) {
            // 1. Native 6-dot drag grip handle
            Image(systemName: "circle.grid.2x3.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(rowState.isHoveringRow ? Color(nsColor: .secondaryLabelColor) : Color(nsColor: .tertiaryLabelColor).opacity(0.45))
                .frame(width: 14, height: 28)
                .contentShape(Rectangle())
                .draggable(profile.dir)
                .help("Drag grip to reorder slot")
            
            // 2. Slot badge in Cobalt Blue
            Text("\(profile.index)")
                .font(NNTSFont.slotDigit(size: 11.5))
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
                .shadow(color: Color.black.opacity(0.20), radius: 2, y: 1)
            
            // 3. Interactive Direct-Manipulation Avatar
            Menu {
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
                Divider()
                Button {
                    viewModel.resetProfileAvatar(dir: profile.dir)
                } label: {
                    Label("Reset to Monogram", systemImage: "arrow.counterclockwise")
                }
            } label: {
                ZStack {
                    if let img = profile.avatarImage {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.75))
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
                    if rowState.isHoveringAvatar || rowState.justPastedAvatar || rowState.isDropTargeted {
                        Circle()
                            .fill(Color.black.opacity(0.60))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: rowState.justPastedAvatar ? "checkmark" : (rowState.isDropTargeted ? "plus" : "camera.fill"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(rowState.justPastedAvatar ? NNTSColors.appleEmerald : .white)
                    }
                }
                .frame(width: 32, height: 32)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 32, height: 32)
            .contentShape(Circle())
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
            .help("Click to change avatar photo, or drop image file here")
            
            // 4. Name & Secondary Account Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(profile.effectiveName)
                        .font(NNTSFont.display(size: 13))
                        .foregroundColor(Color(nsColor: .labelColor))
                        .lineLimit(1)
                    
                    if let given = profile.gaiaGivenName, !given.isEmpty, given.lowercased() != profile.effectiveName.lowercased() {
                        Text("(\(given))")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundColor(Color(nsColor: .secondaryLabelColor))
                            .lineLimit(1)
                    }
                }
                
                Text("caps lock + \(profile.index)")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
            }
            
            Spacer()
            
            // 5. 1-Click Ergonomic Up / Down Reorder Arrows
            HStack(spacing: 2) {
                Button {
                    viewModel.moveProfileUp(dir: profile.dir)
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(profile.index > 1 && rowState.isHoveringRow ? Color(nsColor: .labelColor) : Color(nsColor: .tertiaryLabelColor).opacity(0.35))
                        .frame(width: 18, height: 18)
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
                        .foregroundColor(profile.index < totalCount && rowState.isHoveringRow ? Color(nsColor: .labelColor) : Color(nsColor: .tertiaryLabelColor).opacity(0.35))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(profile.index >= totalCount)
                .help("Move slot down")
            }
            .padding(.trailing, 4)
            
            // 6. Options Menu
            Menu {
                Button {
                    viewModel.chooseAvatarFile(dir: profile.dir)
                } label: {
                    Label("Choose Photo from Disk...", systemImage: "photo")
                }
                Button {
                    viewModel.pasteProfileAvatar(dir: profile.dir)
                } label: {
                    Label("Paste Avatar from Clipboard (⌘⌃⇧4)", systemImage: "doc.on.clipboard")
                }
                Button {
                    viewModel.resetProfileAvatar(dir: profile.dir)
                } label: {
                    Label("Reset to Monogram", systemImage: "arrow.counterclockwise")
                }
                if totalCount > 1 {
                    Divider()
                    Button(role: .destructive) {
                        viewModel.removeProfileFromActiveSlots(dir: profile.dir)
                    } label: {
                        Label("Remove Slot", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    .frame(width: 24, height: 24)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(rowState.isHoveringRow ? 0.08 : 0.02))
                    )
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24, height: 24)
            .help("Slot options")
            
            // 7. Delete Slot button (visible on hover)
            if totalCount > 1 {
                Button {
                    viewModel.removeProfileFromActiveSlots(dir: profile.dir)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(rowState.isHoveringRow ? Color(nsColor: .tertiaryLabelColor) : Color.clear)
                        .frame(width: 18, height: 18)
                }
                .buttonStyle(.plain)
                .disabled(!rowState.isHoveringRow)
                .help("Remove slot")
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
                    isTargeted ? NNTSColors.cobaltBlue : NNTSColors.cardBorder,
                    lineWidth: 1.0
                )
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                rowState.isHoveringRow = hovering
            }
        }
        .contextMenu {
            Button {
                viewModel.chooseAvatarFile(dir: profile.dir)
            } label: {
                Label("Choose Photo from Disk...", systemImage: "photo")
            }
            Button {
                viewModel.pasteProfileAvatar(dir: profile.dir)
            } label: {
                Label("Paste Avatar from Clipboard (⌘⌃⇧4)", systemImage: "doc.on.clipboard")
            }
            Button {
                viewModel.resetProfileAvatar(dir: profile.dir)
            } label: {
                Label("Reset to Monogram", systemImage: "arrow.counterclockwise")
            }
            if totalCount > 1 {
                Divider()
                Button(role: .destructive) {
                    viewModel.removeProfileFromActiveSlots(dir: profile.dir)
                } label: {
                    Label("Remove Slot", systemImage: "trash")
                }
            }
        }
    }
}

// Backwards compatibility alias
internal typealias DraggableProfileRow = ModernProfileRow

