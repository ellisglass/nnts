//
//  NNTSDesignTokens.swift
//  NNTS (macOS Productivity Suite)
//
//  Design Tokens: Bauhaus Modernism x macOS 2026 Liquid Glass System
//

import SwiftUI
import AppKit
import CoreText

// MARK: - Color Tokens
public enum NNTSColors {
    /// Bauhaus Cadmium Yellow - Primary active highlight & focus ring
    public static let cadmiumYellow = Color(red: 0.961, green: 0.729, blue: 0.075)
    
    /// Bauhaus Cobalt Blue - Secondary focus, structural elements, tabs
    public static let cobaltBlue = Color(red: 0.118, green: 0.337, blue: 0.627)
    
    /// Apple Emerald LED - Live status indicators & copy toast
    public static let appleEmerald = Color(red: 0.000, green: 0.902, blue: 0.463)
    
    /// Bauhaus Vermilion - Destructive actions, unpinning, reset
    public static let vermilion = Color(red: 0.851, green: 0.220, blue: 0.118)
    
    /// Obsidian Slate - Deep background tint preventing bleed-through
    public static let obsidianBase = Color(red: 0.118, green: 0.137, blue: 0.176)
    
    /// Warm Cream - High contrast typography & specular reflections
    public static let warmCream = Color(red: 0.973, green: 0.961, blue: 0.933)
    
    /// Card background surface for Settings
    public static let cardSurface = Color(nsColor: .controlBackgroundColor).opacity(0.48)
    public static let cardBorder = Color.white.opacity(0.09)
}

// MARK: - Geometry & Layout Tokens
public enum NNTSGeometry {
    // Dessau 8pt Modular Grid
    public static let spaceXXS: CGFloat = 4
    public static let spaceXS: CGFloat  = 8
    public static let spaceS: CGFloat   = 12
    public static let spaceM: CGFloat   = 16
    public static let spaceL: CGFloat   = 24
    public static let spaceXL: CGFloat  = 32
    public static let space2XL: CGFloat = 48
    public static let space3XL: CGFloat = 64
    
    // HUD Dimensions
    public static let hudWidth: CGFloat  = 400
    public static let hudHeight: CGFloat = 280
    public static let hudCornerRadius: CGFloat = 30
    
    // Settings Dimensions
    public static let settingsRowHeight: CGFloat = 54
    public static let settingsCardRadius: CGFloat = 12
}

// MARK: - Typography & Font Loading
public enum NNTSFont {
    private static var isRegistered: Bool = false
    public static let spaceGroteskBoldName = "SpaceGrotesk-Bold"
    
    public static func registerFonts() {
        guard !isRegistered else { return }
        
        // 1. Search in main bundle resources
        if let bundleURL = Bundle.main.url(forResource: "SpaceGrotesk-Bold", withExtension: "ttf") {
            registerFontURL(bundleURL)
            return
        }
        
        // 2. Search relative development / assets paths
        let fileManager = FileManager.default
        let possiblePaths = [
            Bundle.main.bundlePath + "/Contents/Resources/SpaceGrotesk-Bold.ttf",
            "assets/fonts/SpaceGrotesk-Bold.ttf",
            "../assets/fonts/SpaceGrotesk-Bold.ttf",
            "/Applications/NNTS.app/Contents/Resources/SpaceGrotesk-Bold.ttf"
        ]
        
        for path in possiblePaths where fileManager.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            registerFontURL(url)
            return
        }
    }
    
    private static func registerFontURL(_ url: URL) {
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
            isRegistered = true
        }
    }
    
    public static func display(size: CGFloat) -> Font {
        registerFonts()
        if NSFont(name: spaceGroteskBoldName, size: size) != nil {
            return .custom(spaceGroteskBoldName, size: size)
        }
        return .system(size: size, weight: .bold, design: .rounded)
    }
    
    public static func slotDigit(size: CGFloat) -> Font {
        registerFonts()
        if NSFont(name: spaceGroteskBoldName, size: size) != nil {
            return .custom(spaceGroteskBoldName, size: size)
        }
        return .system(size: size, weight: .bold, design: .monospaced)
    }
}
