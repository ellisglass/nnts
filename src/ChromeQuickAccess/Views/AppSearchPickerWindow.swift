import Cocoa
import AppKit
import SwiftUI
import os

// MARK: - App Search Picker View Model
@MainActor
public final class AppSearchPickerViewModel: ObservableObject {
    @Published public var searchQuery: String = "" {
        didSet {
            performSearch()
        }
    }
    
    @Published public var results: [InstalledAppInfo] = []
    @Published public var selectedIndex: Int = 0
    @Published public var pinnedBundleIDs: Set<String> = []
    
    public init() {
        refresh()
    }
    
    public func refresh() {
        self.pinnedBundleIDs = AppGroupEngine.selectedBundleIDs
        self.results = AppGroupEngine.searchInstalledApplications(query: searchQuery)
        if selectedIndex >= results.count {
            selectedIndex = max(0, results.count - 1)
        }
    }
    
    private func performSearch() {
        self.results = AppGroupEngine.searchInstalledApplications(query: searchQuery)
        self.selectedIndex = 0
    }
    
    public func selectNext() {
        guard !results.isEmpty else { return }
        withAnimation(XomskyMotion.magneticGlide) {
            selectedIndex = min(results.count - 1, selectedIndex + 1)
        }
    }
    
    public func selectPrevious() {
        guard !results.isEmpty else { return }
        withAnimation(XomskyMotion.magneticGlide) {
            selectedIndex = max(0, selectedIndex - 1)
        }
    }
    
    public func toggleApp(app: InstalledAppInfo, onSlotLimitReached: ((String) -> Void)? = nil) {
        withAnimation(XomskyMotion.tactileBop) {
            let isAlreadyPinned = AppGroupEngine.isAppSelected(bundleID: app.bundleID)
            if isAlreadyPinned {
                AppGroupEngine.deselectApp(bundleID: app.bundleID)
                self.pinnedBundleIDs = AppGroupEngine.selectedBundleIDs
                AppDelegate.shared?.updateDynamicShortcuts()
                AppDelegate.shared?.updateMenu()
            } else {
                let success = AppGroupEngine.toggleInstalledAppPin(app: app)
                if success {
                    self.pinnedBundleIDs = AppGroupEngine.selectedBundleIDs
                    AppDelegate.shared?.updateDynamicShortcuts()
                    AppDelegate.shared?.updateMenu()
                } else {
                    onSlotLimitReached?(app.bundleID)
                }
            }
        }
    }
    
    public func confirmSelection(onSlotLimitReached: ((String) -> Void)? = nil) {
        guard !results.isEmpty, selectedIndex >= 0, selectedIndex < results.count else { return }
        let selectedApp = results[selectedIndex]
        toggleApp(app: selectedApp, onSlotLimitReached: onSlotLimitReached)
    }
}

// MARK: - App Search Picker Row View
public struct AppSearchPickerRowView: View {
    public let app: InstalledAppInfo
    public let isSelected: Bool
    public let isPinned: Bool
    public let canPinMore: Bool
    public var namespace: Namespace.ID?
    public let onToggle: () -> Void
    
    public init(
        app: InstalledAppInfo,
        isSelected: Bool,
        isPinned: Bool,
        canPinMore: Bool,
        namespace: Namespace.ID? = nil,
        onToggle: @escaping () -> Void
    ) {
        self.app = app
        self.isSelected = isSelected
        self.isPinned = isPinned
        self.canPinMore = canPinMore
        self.namespace = namespace
        self.onToggle = onToggle
    }
    
    public var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Application Icon
                Image(nsImage: app.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                
                // Name & Bundle Identifier
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(app.bundleID)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Shortcut Badge
                let char = app.firstLetter
                Text("Caps + \(String(char))")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.70))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                    )
                
                // Pin Status Badge with tactile bounce
                Group {
                    if isPinned {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 9, weight: .bold))
                            Text("Pinned")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.35, green: 0.85, blue: 0.50))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.35, green: 0.85, blue: 0.50).opacity(0.18))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color(red: 0.35, green: 0.85, blue: 0.50).opacity(0.30), lineWidth: 0.75)
                        )
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    } else if canPinMore {
                        HStack(spacing: 3) {
                            Image(systemName: "plus")
                                .font(.system(size: 9, weight: .bold))
                            Text("Pin")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(Color.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.14))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.22), lineWidth: 0.75)
                        )
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                    } else {
                        Text("Replace")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color.orange.opacity(0.90))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.18))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color.orange.opacity(0.30), lineWidth: 0.75)
                            )
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .animation(XomskyMotion.tactileBop, value: isPinned)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    if let ns = namespace {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.24), lineWidth: 0.75)
                            )
                            .matchedGeometryEffect(id: "pickerRowCapsule", in: ns)
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.24), lineWidth: 0.75)
                            )
                    }
                }
            }
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(XomskyMotion.interactiveSnap, value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Search Picker View
public struct AppSearchPickerView: View {
    @ObservedObject var viewModel: AppSearchPickerViewModel
    @Namespace private var pickerNamespace
    public let onClose: () -> Void
    public let onChooseOther: () -> Void
    public let onSlotLimitReached: (String) -> Void
    
    public init(
        viewModel: AppSearchPickerViewModel,
        onClose: @escaping () -> Void,
        onChooseOther: @escaping () -> Void,
        onSlotLimitReached: @escaping (String) -> Void
    ) {
        self.viewModel = viewModel
        self.onClose = onClose
        self.onChooseOther = onChooseOther
        self.onSlotLimitReached = onSlotLimitReached
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Bar
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "plus.app.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.70))
                    Text("Add Quick Application")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                // Close button
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.40))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            // Search Input Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.50))
                
                TextField("Search installed applications to pin...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                
                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.75)
            )
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Results List
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if viewModel.results.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "questionmark.app.dashed")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.30))
                                Text("No applications found")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.60))
                                Text("Try another search query or browse manually below.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.40))
                            }
                            .padding(.vertical, 40)
                        } else {
                            ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { idx, app in
                                AppSearchPickerRowView(
                                    app: app,
                                    isSelected: idx == viewModel.selectedIndex,
                                    isPinned: viewModel.pinnedBundleIDs.contains(app.bundleID),
                                    canPinMore: AppGroupEngine.canPinMoreApps,
                                    namespace: pickerNamespace,
                                    onToggle: {
                                        viewModel.toggleApp(app: app, onSlotLimitReached: onSlotLimitReached)
                                    }
                                )
                                .id(app.bundleID)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                }
                .frame(maxHeight: 280)
                .onChange(of: viewModel.selectedIndex) { _, newIdx in
                    guard newIdx >= 0, newIdx < viewModel.results.count else { return }
                    withAnimation(XomskyMotion.magneticGlide) {
                        proxy.scrollTo(viewModel.results[newIdx].bundleID, anchor: .center)
                    }
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.12))
            
            // Footer Bar
            HStack {
                // Slot counter
                let pinnedCount = viewModel.pinnedBundleIDs.count
                let maxCount = AppGroupEngine.maxPinnedQuickApps
                Text("\(pinnedCount) of \(maxCount) slots used")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.55))
                    .contentTransition(.numericText())
                    .animation(XomskyMotion.tactileBop, value: pinnedCount)
                
                Spacer()
                
                // Browse in Finder button
                Button(action: onChooseOther) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder")
                            .font(.system(size: 11))
                        Text("Browse in Finder... (⌘O)")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.40, green: 0.70, blue: 1.0))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            
            // Key hints bar
            HStack(spacing: 12) {
                Text("[↑/↓] Navigate")
                Text("[↵] Pin / Unpin")
                Text("[Esc] Close")
            }
            .font(.system(size: 9.5, weight: .regular, design: .monospaced))
            .foregroundColor(.white.opacity(0.35))
            .padding(.bottom, 8)
        }
        .frame(width: 440)
        .background(
            MacNativeLiquidGlassBackground(cornerRadius: 18, material: .popover)
        )
        .preferredColorScheme(.dark)
    }
}

// MARK: - App Search Picker Window Panel
@MainActor
public final class AppSearchPickerWindow: NSPanel {
    public static let shared = AppSearchPickerWindow()
    
    public let viewModel = AppSearchPickerViewModel()
    
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 420),
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
        
        let rootView = AppSearchPickerView(
            viewModel: viewModel,
            onClose: { [weak self] in
                self?.hideImmediate()
            },
            onChooseOther: { [weak self] in
                self?.hideImmediate()
                AppDelegate.shared?.handleChooseOtherAppFromExternal()
            },
            onSlotLimitReached: { [weak self] bundleID in
                self?.hideImmediate()
                AppDelegate.shared?.promptAppReplacement(newBundleID: bundleID)
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
        if event.keyCode == KeyCodes.kVK_DownArrow {
            viewModel.selectNext()
            return
        }
        if event.keyCode == KeyCodes.kVK_UpArrow {
            viewModel.selectPrevious()
            return
        }
        if event.keyCode == KeyCodes.kVK_Return {
            viewModel.confirmSelection { [weak self] bundleID in
                self?.hideImmediate()
                AppDelegate.shared?.promptAppReplacement(newBundleID: bundleID)
            }
            return
        }
        super.keyDown(with: event)
    }
    
    public func show() {
        viewModel.refresh()
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
            let y = screenRect.midY - (frame.height / 2) + 60
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}
