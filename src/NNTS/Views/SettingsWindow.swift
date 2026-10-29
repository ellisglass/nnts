//
//  SettingsWindow.swift
//  NNTS (macOS Productivity Suite)
//
//  Clean, refined native macOS Settings Window hosting SettingsView.
//

import SwiftUI
import AppKit
import Cocoa
import os

// MARK: - Main Settings View

public struct SettingsView: View {
    @ObservedObject public var viewModel: SettingsViewModel
    @Namespace private var tabNamespace
    
    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Unified macOS Header Bar
            HStack(spacing: 12) {
                // Window drag margin for traffic lights
                Spacer()
                    .frame(width: 58)
                
                // Brand Title & Edition Badge
                HStack(spacing: 7) {
                    Text("NNTS")
                        .font(NNTSFont.display(size: 13.5))
                        .foregroundColor(Color(nsColor: .labelColor))
                    
                    Text("Settings")
                        .font(NNTSFont.display(size: 13.5))
                        .foregroundColor(Color(nsColor: .secondaryLabelColor))
                    
                    if viewModel.isPro {
                        HStack(spacing: 3) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 9))
                            Text("PRO")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundColor(NNTSColors.cadmiumYellow)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(NNTSColors.cadmiumYellow.opacity(0.18))
                        )
                    }
                }
                
                Spacer()
                
                // Streamlined Tab Switcher
                HStack(spacing: 4) {
                    ForEach(Array(SettingsTab.allCases.enumerated()), id: \.element) { index, tab in
                        Button(action: {
                            withAnimation(NNTSMotion.magneticGlide) {
                                viewModel.selectedTab = tab
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: tab.iconName)
                                    .font(.system(size: 11.5, weight: viewModel.selectedTab == tab ? .semibold : .medium))
                                Text(tab.rawValue)
                                    .font(.system(size: 12, weight: viewModel.selectedTab == tab ? .semibold : .medium))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .foregroundColor(viewModel.selectedTab == tab ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))
                            .background {
                                if viewModel.selectedTab == tab {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(Color(nsColor: .controlBackgroundColor))
                                        .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
                                        .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .help("⌘\(index + 1) — Switch to \(tab.rawValue)")
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            Divider()
                .opacity(0.4)
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch viewModel.selectedTab {
                    case .general:
                        GeneralTabContent(viewModel: viewModel)
                    case .shortcuts:
                        ShortcutsTabContent(viewModel: viewModel)
                    case .license:
                        LicenseTabContent(viewModel: viewModel)
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 600, minHeight: 480)
    }
}

// MARK: - Native Settings Window Panel

@MainActor
public final class SettingsWindow: NSWindow {
    public static let shared = SettingsWindow()
    public let viewModel = SettingsViewModel()
    private var windowKeyObserver: Any?
    private var appActiveObserver: Any?
    
    private init() {
        let contentRect = NSRect(x: 0, y: 0, width: 640, height: 530)
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.title = "NNTS Settings"
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.isMovableByWindowBackground = true
        self.isReleasedWhenClosed = false
        self.center()
        self.setFrameAutosaveName("NNTSSettingsWindowFrame")
        self.minSize = NSSize(width: 580, height: 460)
        
        let rootView = SettingsView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        self.contentView = hostingView
        
        // Auto-refresh when window or application receives focus (e.g. returning from System Settings)
        self.windowKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: self,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.viewModel.refreshAll()
            }
        }
        
        self.appActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                if self?.isVisible == true {
                    self?.viewModel.refreshAll()
                }
            }
        }
    }
    
    public func show(tab: SettingsTab? = nil) {
        if let tab = tab {
            viewModel.selectedTab = tab
        }
        viewModel.refreshAll()
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == KeyCodes.kVK_Escape {
            orderOut(nil)
            return
        }
        if event.modifierFlags.contains(.command) {
            let chars = event.charactersIgnoringModifiers?.lowercased()
            if chars == "w" || chars == "," {
                orderOut(nil)
                return
            }
            if chars == "r" {
                viewModel.refreshAll()
                return
            }
            if let firstChar = chars?.first, let digit = Int(String(firstChar)), digit >= 1 && digit <= SettingsTab.allCases.count {
                withAnimation(NNTSMotion.magneticGlide) {
                    viewModel.selectedTab = SettingsTab.allCases[digit - 1]
                }
                return
            }
        }
        super.keyDown(with: event)
    }
}
