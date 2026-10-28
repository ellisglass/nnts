//
//  SettingsWindow.swift
//  NNTS (macOS Productivity Suite)
//
//  Clean, simplified native macOS Settings Window hosting SettingsView.
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
            // Streamlined Tab Header
            HStack(spacing: 6) {
                ForEach(SettingsTab.allCases) { tab in
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .foregroundColor(viewModel.selectedTab == tab ? Color(nsColor: .labelColor) : Color(nsColor: .secondaryLabelColor))
                        .background {
                            if viewModel.selectedTab == tab {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                                    .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)
                                    .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(0.35))
            )
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            
            Divider()
            
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
        .frame(minWidth: 580, minHeight: 460)
    }
}

// MARK: - Native Settings Window Panel

@MainActor
public final class SettingsWindow: NSWindow {
    public static let shared = SettingsWindow()
    public let viewModel = SettingsViewModel()
    
    private init() {
        let contentRect = NSRect(x: 0, y: 0, width: 600, height: 480)
        super.init(
            contentRect: contentRect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "NNTS Settings"
        self.titleVisibility = .visible
        self.isReleasedWhenClosed = false
        self.center()
        self.setFrameAutosaveName("NNTSSettingsWindowFrame")
        self.minSize = NSSize(width: 560, height: 440)
        
        let rootView = SettingsView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        self.contentView = hostingView
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
