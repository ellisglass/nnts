//
//  ProfileStripView.swift
//  NNTS (macOS Productivity Suite)
//
//  Compact Visual Matrix Cheat Sheet for the macOS status bar menu.
//  Displays Chromium Profiles (caps lock + 1..8) and Quick Apps (caps lock + [a–z])
//  simultaneously in a clean, non-cluttered two-tier layout without tabs.
//

import Cocoa
import AppKit

// MARK: - Quick App Matrix Tile Model
public struct QuickAppTile: Equatable, Sendable {
    public let item: AntigravityItem
    public let letter: Character
    public let slotIndex: Int
    public let totalInGroup: Int
    
    public init(item: AntigravityItem, letter: Character, slotIndex: Int, totalInGroup: Int) {
        self.item = item
        self.letter = letter
        self.slotIndex = slotIndex
        self.totalInGroup = totalInGroup
    }
}

public final class ProfileStripView: NSView, NSViewToolTipOwner {
    public let profiles: [ChromeProfile]
    public let browserName: String
    public let browserIcon: NSImage
    public let totalBrowserSharing: Int
    public let browserChar: Character
    public let letterGroups: [(letter: Character, items: [AntigravityItem])]
    
    public private(set) var activeDir: String? {
        didSet {
            if activeDir != oldValue {
                needsDisplay = true
            }
        }
    }
    
    public func updateActiveDir(_ dir: String?) {
        self.activeDir = dir
    }
    
    // Backward compatibility properties for legacy tab-aware assertions
    public var hasTabs: Bool { false }
    public var totalTabs: Int { 1 }
    public var selectedTabIndex: Int { 0 }
    
    private var hoveredProfileIndex: Int? = nil
    private var hoveredAppIndex: Int? = nil
    private var trackingArea: NSTrackingArea?
    private var toolTipTags: [NSView.ToolTipTag] = []
    
    // Quick app tiles derived adaptively from letterGroups — always preserve all apps
    public var quickAppTiles: [QuickAppTile] {
        guard !letterGroups.isEmpty else { return [] }
        var tiles: [QuickAppTile] = []
        for group in letterGroups {
            for item in group.items {
                tiles.append(QuickAppTile(
                    item: item,
                    letter: group.letter,
                    slotIndex: item.index,
                    totalInGroup: group.items.count
                ))
            }
        }
        return tiles
    }
    
    public var hasProfiles: Bool { !profiles.isEmpty }
    public var hasQuickApps: Bool { !quickAppTiles.isEmpty }
    
    public static func appColumns(for count: Int) -> Int {
        if count <= 0 { return 5 }
        if count <= 4 { return count }
        if count == 6 { return 6 }
        return 5
    }
    
    public func appColumns(for count: Int) -> Int {
        Self.appColumns(for: count)
    }
    
    private func displayNSFont(size: CGFloat) -> NSFont {
        NNTSFont.registerFonts()
        if let custom = NSFont(name: NNTSFont.spaceGroteskBoldName, size: size) {
            return custom
        }
        return NSFont.boldSystemFont(ofSize: size)
    }
    
    public init(
        profiles: [ChromeProfile],
        activeDir: String? = nil,
        browserName: String = "Google Chrome",
        browserIcon: NSImage? = nil,
        totalBrowserSharing: Int = 1,
        browserChar: Character = "C",
        letterGroups: [(letter: Character, items: [AntigravityItem])] = []
    ) {
        self.profiles = profiles
        self.activeDir = activeDir
        self.browserName = browserName
        if let icon = browserIcon {
            self.browserIcon = icon
        } else if let candidate = ChromeProfileEngine.supportedBrowsers.first(where: { $0.bundleID == ChromeProfileEngine.shared.browserBundleID }),
                  let appIcon = NSWorkspace.shared.icon(forFile: candidate.appPath) as NSImage? {
            self.browserIcon = appIcon
        } else if let appIcon = NSWorkspace.shared.icon(forFile: "/Applications/Google Chrome.app") as NSImage? {
            self.browserIcon = appIcon
        } else {
            self.browserIcon = NSImage(systemSymbolName: "globe", accessibilityDescription: nil) ?? NSImage()
        }
        self.totalBrowserSharing = totalBrowserSharing
        self.browserChar = browserChar
        self.letterGroups = letterGroups
        
        let width: CGFloat = 286
        let hasP = !profiles.isEmpty
        let hasA = !letterGroups.isEmpty
        
        // Dynamically compute number of Quick App rows and overall view height
        let appCount = letterGroups.reduce(0) { $0 + $1.items.count }
        let cols = ProfileStripView.appColumns(for: appCount)
        let numAppRows = appCount > 0 ? Int(ceil(Double(appCount) / Double(cols))) : 0
        let appGridHeight: CGFloat = numAppRows > 0 ? (CGFloat(numAppRows) * 48.0 + CGFloat(max(0, numAppRows - 1)) * 6.0) : 0
        
        let height: CGFloat
        if hasP && hasA {
            // Profiles section: 88pt + gap (8pt) + Quick Apps header (16pt) + gap (4pt) + appGridHeight + bottom padding (10pt)
            height = 88.0 + 8.0 + 16.0 + 4.0 + appGridHeight + 10.0
        } else if hasP {
            height = 92.0
        } else if hasA {
            // Quick Apps only: top padding (9pt) + header (16pt) + gap (4pt) + appGridHeight + bottom padding (10pt)
            height = 9.0 + 16.0 + 4.0 + appGridHeight + 10.0
        } else {
            height = 36.0
        }
        
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var isFlipped: Bool { true }
    
    // MARK: - Geometry & Layout Metrics
    
    public var profilesHeaderRect: NSRect {
        guard hasProfiles else { return .zero }
        return NSRect(x: 12, y: 9, width: bounds.width - 24, height: 16)
    }
    
    public var profilesRowY: CGFloat { 29.0 }
    
    public var dividerY: CGFloat {
        hasProfiles && hasQuickApps ? 88.0 : 0.0
    }
    
    public var quickAppsHeaderY: CGFloat {
        hasProfiles ? 96.0 : 9.0
    }
    
    public var quickAppsHeaderRect: NSRect {
        guard hasQuickApps else { return .zero }
        return NSRect(x: 12, y: quickAppsHeaderY, width: bounds.width - 24, height: 16)
    }
    
    public var quickAppsRowY: CGFloat {
        quickAppsHeaderY + 20.0
    }
    
    public var currentItemCount: Int { profiles.count }
    
    public func segBarRect() -> NSRect { .zero }
    public func tabRect(for index: Int) -> NSRect { .zero }
    public func headerRect() -> NSRect { profilesHeaderRect }
    public var nameY: CGFloat { profilesRowY + 36.0 }
    
    public func tileRect(for index: Int) -> NSRect {
        guard !profiles.isEmpty, index >= 0, index < profiles.count else { return .zero }
        let count = profiles.count
        let contentWidth = bounds.width - 24.0
        let tileWidth: CGFloat
        if count <= 4 {
            tileWidth = 46.0
        } else if count <= 6 {
            tileWidth = 40.0
        } else {
            tileWidth = max(28.0, floor((contentWidth - CGFloat(count - 1) * 3.0) / CGFloat(count)))
        }
        let maxSpacing: CGFloat = count <= 4 ? 14.0 : 8.0
        let naturalSpacing = count > 1 ? (contentWidth - CGFloat(count) * tileWidth) / CGFloat(count - 1) : 0
        let spacing = max(2.0, min(maxSpacing, naturalSpacing))
        let totalWidth = CGFloat(count) * tileWidth + CGFloat(count - 1) * spacing
        let startX = 12.0 + max(0, (contentWidth - totalWidth) / 2.0)
        return NSRect(
            x: round(startX + CGFloat(index) * (tileWidth + spacing)),
            y: profilesRowY,
            width: tileWidth,
            height: 50.0
        )
    }
    
    public func appTileRect(for index: Int) -> NSRect {
        let tiles = quickAppTiles
        guard !tiles.isEmpty, index >= 0, index < tiles.count else { return .zero }
        let count = tiles.count
        let cols = appColumns(for: count)
        let row = index / cols
        let col = index % cols
        
        let contentWidth = bounds.width - 24.0
        let tileWidth: CGFloat
        let tileHeight: CGFloat = 48.0
        let rowSpacing: CGFloat = 6.0
        let colSpacing: CGFloat
        let startX: CGFloat
        
        if cols <= 4 {
            tileWidth = 46.0
            let maxSpacing: CGFloat = 14.0
            let naturalSpacing = count > 1 ? (contentWidth - CGFloat(count) * tileWidth) / CGFloat(count - 1) : 0
            colSpacing = max(4.0, min(maxSpacing, naturalSpacing))
            let totalWidth = CGFloat(count) * tileWidth + CGFloat(count - 1) * colSpacing
            startX = 12.0 + max(0, (contentWidth - totalWidth) / 2.0)
        } else if cols == 6 {
            tileWidth = 38.0
            colSpacing = (contentWidth - 6.0 * tileWidth) / 5.0
            startX = 12.0
        } else {
            tileWidth = 46.0
            colSpacing = (contentWidth - 5.0 * tileWidth) / 4.0
            startX = 12.0
        }
        
        let x = round(startX + CGFloat(col) * (tileWidth + colSpacing))
        let y = round(quickAppsRowY + CGFloat(row) * (tileHeight + rowSpacing))
        
        return NSRect(x: x, y: y, width: tileWidth, height: tileHeight)
    }
    
    // MARK: - Tracking Areas & Mouse Handling
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        self.trackingArea = area
        
        for tag in toolTipTags {
            removeToolTip(tag)
        }
        toolTipTags.removeAll()
        
        if hasProfiles {
            for i in 0..<profiles.count {
                toolTipTags.append(addToolTip(tileRect(for: i), owner: self, userData: nil))
            }
        }
        if hasQuickApps {
            for j in 0..<quickAppTiles.count {
                toolTipTags.append(addToolTip(appTileRect(for: j), owner: self, userData: nil))
            }
        }
    }
    
    public func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        let loc = convert(point, from: nil)
        if hasProfiles {
            for (i, p) in profiles.enumerated() {
                if tileRect(for: i).contains(loc) {
                    let status = (p.dir == activeDir) ? "Active Now" : "Inactive"
                    return "\(p.effectiveName) (Profile \(p.index))\nShortcut: caps lock + \(p.index)\nStatus: \(status)"
                }
            }
        }
        if hasQuickApps {
            let tiles = quickAppTiles
            for (j, tile) in tiles.enumerated() {
                if appTileRect(for: j).contains(loc) {
                    let isRunning = NSRunningApplication.runningApplications(withBundleIdentifier: tile.item.bundleID).first != nil
                    let runStatus = isRunning ? "Running" : "Available"
                    let charLower = String(tile.letter).lowercased()
                    let cycleText = tile.totalInGroup > 1 ? " (\(tile.slotIndex)/\(tile.totalInGroup))" : ""
                    return "\(tile.item.name)\nShortcut: caps lock + \(charLower)\(cycleText)\nStatus: \(runStatus)"
                }
            }
        }
        return ""
    }
    
    public override func mouseMoved(with event: NSEvent) {
        let loc = (window != nil) ? convert(event.locationInWindow, from: nil) : event.locationInWindow
        
        var newProfileHover: Int? = nil
        if hasProfiles {
            for i in 0..<profiles.count {
                if tileRect(for: i).contains(loc) {
                    newProfileHover = i
                    break
                }
            }
        }
        
        var newAppHover: Int? = nil
        if hasQuickApps {
            for j in 0..<quickAppTiles.count {
                if appTileRect(for: j).contains(loc) {
                    newAppHover = j
                    break
                }
            }
        }
        
        if newProfileHover != hoveredProfileIndex || newAppHover != hoveredAppIndex {
            hoveredProfileIndex = newProfileHover
            hoveredAppIndex = newAppHover
            needsDisplay = true
        }
        
        if newProfileHover != nil {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        if hoveredProfileIndex != nil || hoveredAppIndex != nil {
            hoveredProfileIndex = nil
            hoveredAppIndex = nil
            needsDisplay = true
        }
        NSCursor.arrow.set()
    }
    
    public override func mouseDown(with event: NSEvent) {
        let loc = (window != nil) ? convert(event.locationInWindow, from: nil) : event.locationInWindow
        
        // 1. Profile Tile Click
        if hasProfiles {
            for (i, p) in profiles.enumerated() {
                if tileRect(for: i).contains(loc) {
                    MinimalHUDWindow.shared.hideImmediate()
                    if let menu = enclosingMenuItem?.menu {
                        menu.cancelTracking()
                    }
                    if event.modifierFlags.contains(.option) {
                        ChromeProfileEngine.shared.toggleProfileSelection(dir: p.dir)
                    } else {
                        ChromeProfileEngine.shared.selectProfile(dir: p.dir)
                        ChromeProfileEngine.shared.focusProfile(dir: p.dir)
                    }
                    return
                }
            }
        }
        
        // 2. Quick App Tile (Read-only reference cheat sheet - strictly no launcher action)
        if hasQuickApps {
            let tiles = quickAppTiles
            for (j, _) in tiles.enumerated() {
                if appTileRect(for: j).contains(loc) {
                    // Strictly read-only cheat sheet according to Option 1: do not launch
                    return
                }
            }
        }
        
        super.mouseDown(with: event)
    }
    
    // MARK: - Drawing & Layout
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let cadmiumYellow = NSColor(red: 251/255, green: 191/255, blue: 36/255, alpha: 1.0)
        let primaryLabel = isDark ? NSColor.white : NSColor.labelColor
        let secondaryLabel = isDark ? NSColor.white.withAlphaComponent(0.60) : NSColor.secondaryLabelColor
        let subtleBorder = isDark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.06)
        let keycapBg = isDark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.05)
        let keycapBorder = isDark ? NSColor.white.withAlphaComponent(0.14) : NSColor.black.withAlphaComponent(0.08)
        
        // 1. Draw Profiles Section
        if hasProfiles {
            drawSectionHeader(
                title: "PROFILES",
                shortcutText: "caps lock + 1..\(min(8, profiles.count))",
                rect: profilesHeaderRect,
                isDark: isDark,
                secondaryLabel: secondaryLabel,
                keycapBg: keycapBg,
                keycapBorder: keycapBorder
            )
            drawProfilesRow(isDark: isDark, cadmiumYellow: cadmiumYellow, primaryLabel: primaryLabel, secondaryLabel: secondaryLabel, subtleBorder: subtleBorder)
        }
        
        // 2. Draw Soft Subtle Section Divider
        if hasProfiles && hasQuickApps {
            let divPath = NSBezierPath()
            divPath.move(to: NSPoint(x: 12, y: dividerY))
            divPath.line(to: NSPoint(x: bounds.width - 12, y: dividerY))
            divPath.lineWidth = 0.5
            subtleBorder.setStroke()
            divPath.stroke()
        }
        
        // 3. Draw Quick Apps Section
        if hasQuickApps {
            drawSectionHeader(
                title: "QUICK APPS",
                shortcutText: "caps lock + [a–z]",
                rect: quickAppsHeaderRect,
                isDark: isDark,
                secondaryLabel: secondaryLabel,
                keycapBg: keycapBg,
                keycapBorder: keycapBorder
            )
            drawQuickAppsRow(isDark: isDark, cadmiumYellow: cadmiumYellow, primaryLabel: primaryLabel, secondaryLabel: secondaryLabel, subtleBorder: subtleBorder)
        }
    }
    
    // MARK: - Section Headers
    
    private func drawSectionHeader(
        title: String,
        shortcutText: String,
        rect: NSRect,
        isDark: Bool,
        secondaryLabel: NSColor,
        keycapBg: NSColor,
        keycapBorder: NSColor
    ) {
        let titleAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10.0, weight: .bold),
            .foregroundColor: secondaryLabel,
            .kern: 0.6
        ]
        let titleStr = NSAttributedString(string: title, attributes: titleAttr)
        let titleSize = titleStr.size()
        let titleRect = NSRect(x: rect.minX, y: round(rect.midY - titleSize.height / 2.0), width: titleSize.width, height: titleSize.height)
        titleStr.draw(in: titleRect)
        
        let shortcutAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .medium),
            .foregroundColor: secondaryLabel
        ]
        let shortcutStr = NSAttributedString(string: shortcutText, attributes: shortcutAttr)
        let shortcutSize = shortcutStr.size()
        let capsulePaddingH: CGFloat = 5.0
        let capsuleHeight: CGFloat = 15.0
        let capsuleWidth = shortcutSize.width + capsulePaddingH * 2.0
        let capsuleRect = NSRect(x: rect.maxX - capsuleWidth, y: round(rect.midY - capsuleHeight / 2.0), width: capsuleWidth, height: capsuleHeight)
        
        let capsule = NSBezierPath(roundedRect: capsuleRect, xRadius: 3.5, yRadius: 3.5)
        keycapBg.setFill()
        capsule.fill()
        keycapBorder.setStroke()
        capsule.lineWidth = 0.5
        capsule.stroke()
        
        let shortcutTextRect = NSRect(
            x: round(capsuleRect.midX - shortcutSize.width / 2.0),
            y: round(capsuleRect.midY - shortcutSize.height / 2.0 - 0.5),
            width: shortcutSize.width,
            height: shortcutSize.height
        )
        shortcutStr.draw(in: shortcutTextRect)
    }
    
    // MARK: - Profiles Row Rendering
    
    private func drawProfilesRow(isDark: Bool, cadmiumYellow: NSColor, primaryLabel: NSColor, secondaryLabel: NSColor, subtleBorder: NSColor) {
        let count = profiles.count
        let avatarDiameter: CGFloat = count <= 6 ? 32.0 : 28.0
        let cutoutBg = isDark ? NSColor(calibratedWhite: 0.14, alpha: 1.0) : NSColor(calibratedWhite: 0.98, alpha: 1.0)
        let keycapInactiveBg = isDark ? NSColor(calibratedWhite: 0.22, alpha: 0.95) : NSColor(calibratedWhite: 0.92, alpha: 0.95)
        let keycapInactiveBorder = isDark ? NSColor.white.withAlphaComponent(0.20) : NSColor.black.withAlphaComponent(0.12)
        
        for (i, p) in profiles.enumerated() {
            let rect = tileRect(for: i)
            let isActive = (p.dir == activeDir)
            let isHovered = (i == hoveredProfileIndex)
            
            // 1. Subtle Plate on Hover (active state is indicated cleanly by the avatar ring and keycap)
            if isHovered {
                let plateRect = rect.insetBy(dx: 1.0, dy: 1.0)
                let plate = NSBezierPath(roundedRect: plateRect, xRadius: 8.0, yRadius: 8.0)
                (isDark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.05)).setFill()
                plate.fill()
                (isDark ? NSColor.white.withAlphaComponent(0.12) : NSColor.black.withAlphaComponent(0.08)).setStroke()
                plate.lineWidth = 0.5
                plate.stroke()
            }
            
            // 2. Avatar Image or Monogram
            let avatarRect = NSRect(
                x: round(rect.midX - avatarDiameter / 2.0),
                y: rect.minY + 2.0,
                width: avatarDiameter,
                height: avatarDiameter
            )
            
            let circlePath = NSBezierPath(ovalIn: avatarRect)
            NSGraphicsContext.saveGraphicsState()
            circlePath.addClip()
            if let avatar = p.avatarImage {
                avatar.draw(in: avatarRect)
            } else {
                let defaultAvatar = ChromeProfileEngine.shared.makeMonogramImage(name: p.name, colorSeed: p.index)
                defaultAvatar.draw(in: avatarRect)
            }
            NSGraphicsContext.restoreGraphicsState()
            
            // 3. Avatar Border / Focus Ring
            if isActive {
                let ringPath = NSBezierPath(ovalIn: avatarRect.insetBy(dx: -1.5, dy: -1.5))
                cadmiumYellow.setStroke()
                ringPath.lineWidth = 1.5
                ringPath.stroke()
            } else if isHovered {
                let hoverPath = NSBezierPath(ovalIn: avatarRect.insetBy(dx: -0.75, dy: -0.75))
                NSColor.white.withAlphaComponent(isDark ? 0.40 : 0.25).setStroke()
                hoverPath.lineWidth = 1.0
                hoverPath.stroke()
            } else {
                let borderPath = NSBezierPath(ovalIn: avatarRect)
                subtleBorder.setStroke()
                borderPath.lineWidth = 0.5
                borderPath.stroke()
            }
            
            // 4. Integrated Corner Keycap Badge (caps lock 1..8)
            let badgeSize: CGFloat = 14.5
            let badgeRect = NSRect(
                x: round(avatarRect.maxX - badgeSize + 2.0),
                y: round(avatarRect.maxY - badgeSize + 2.0),
                width: badgeSize,
                height: badgeSize
            )
            
            // Cutout border for high-contrast separation
            let cutoutPath = NSBezierPath(ovalIn: badgeRect.insetBy(dx: -1.5, dy: -1.5))
            cutoutBg.setFill()
            cutoutPath.fill()
            
            // Keycap body
            let badgePath = NSBezierPath(ovalIn: badgeRect)
            if isActive {
                cadmiumYellow.setFill()
                badgePath.fill()
            } else {
                keycapInactiveBg.setFill()
                badgePath.fill()
                keycapInactiveBorder.setStroke()
                badgePath.lineWidth = 0.5
                badgePath.stroke()
            }
            
            // Keycap number text
            let slotAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .bold),
                .foregroundColor: isActive ? NSColor(calibratedWhite: 0.10, alpha: 1.0) : (isDark ? NSColor.white : NSColor(calibratedWhite: 0.15, alpha: 1.0))
            ]
            let slotStr = NSAttributedString(string: "\(p.index)", attributes: slotAttr)
            let slotSize = slotStr.size()
            let textDrawRect = NSRect(
                x: round(badgeRect.midX - slotSize.width / 2.0),
                y: round(badgeRect.midY - slotSize.height / 2.0 - 0.5),
                width: slotSize.width,
                height: slotSize.height
            )
            slotStr.draw(in: textDrawRect)
            
            // 5. Profile Name (directly below avatar, clean typography)
            let pStyle = NSMutableParagraphStyle()
            pStyle.alignment = .center
            pStyle.lineBreakMode = .byTruncatingTail
            let pFontSize: CGFloat = count > 6 ? 8.0 : 8.5
            let nameAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: pFontSize, weight: isActive ? .semibold : .medium),
                .foregroundColor: isActive ? primaryLabel : (isHovered ? primaryLabel : secondaryLabel),
                .paragraphStyle: pStyle
            ]
            let nameStr = NSAttributedString(string: p.effectiveName, attributes: nameAttr)
            let nameRect = NSRect(
                x: rect.minX,
                y: avatarRect.maxY + 4.0,
                width: rect.width,
                height: 13.0
            )
            nameStr.draw(in: nameRect)
        }
    }
    
    // MARK: - Quick Apps Row Rendering
    
    private func drawQuickAppsRow(isDark: Bool, cadmiumYellow: NSColor, primaryLabel: NSColor, secondaryLabel: NSColor, subtleBorder: NSColor) {
        let tiles = quickAppTiles
        let iconSize: CGFloat = 28.0
        let frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let cutoutBg = isDark ? NSColor(calibratedWhite: 0.14, alpha: 1.0) : NSColor(calibratedWhite: 0.98, alpha: 1.0)
        let keycapInactiveBg = isDark ? NSColor(calibratedWhite: 0.22, alpha: 0.95) : NSColor(calibratedWhite: 0.92, alpha: 0.95)
        let keycapInactiveBorder = isDark ? NSColor.white.withAlphaComponent(0.20) : NSColor.black.withAlphaComponent(0.12)
        
        for (j, tile) in tiles.enumerated() {
            let rect = appTileRect(for: j)
            let isFrontmost = (tile.item.bundleID == frontBundleID)
            let isHovered = (j == hoveredAppIndex)
            
            // 1. Interactive Plate for active/hovered app
            let plateRect = rect.insetBy(dx: 1.0, dy: 1.0)
            if isFrontmost {
                let plate = NSBezierPath(roundedRect: plateRect, xRadius: 8.0, yRadius: 8.0)
                cadmiumYellow.withAlphaComponent(isDark ? 0.14 : 0.10).setFill()
                plate.fill()
                cadmiumYellow.withAlphaComponent(isDark ? 0.60 : 0.45).setStroke()
                plate.lineWidth = 1.0
                plate.stroke()
            } else if isHovered {
                let plate = NSBezierPath(roundedRect: plateRect, xRadius: 8.0, yRadius: 8.0)
                (isDark ? NSColor.white.withAlphaComponent(0.08) : NSColor.black.withAlphaComponent(0.05)).setFill()
                plate.fill()
                (isDark ? NSColor.white.withAlphaComponent(0.12) : NSColor.black.withAlphaComponent(0.08)).setStroke()
                plate.lineWidth = 0.5
                plate.stroke()
            }
            
            // 2. Squircle Native App Icon
            let iconRect = NSRect(
                x: round(rect.midX - iconSize / 2.0),
                y: rect.minY + 2.0,
                width: iconSize,
                height: iconSize
            )
            
            let iconPath = NSBezierPath(roundedRect: iconRect, xRadius: 6.0, yRadius: 6.0)
            NSGraphicsContext.saveGraphicsState()
            iconPath.addClip()
            tile.item.icon.draw(in: iconRect)
            NSGraphicsContext.restoreGraphicsState()
            
            // Squircle subtle outline
            subtleBorder.setStroke()
            iconPath.lineWidth = 0.5
            iconPath.stroke()
            
            // 3. Integrated Corner Keycap Badge (letter or letter¹/letter²)
            let letterChar = String(tile.letter).lowercased()
            let badgeText: String
            if tile.totalInGroup > 1 {
                badgeText = "\(letterChar)\(superscript(for: tile.slotIndex))"
            } else {
                badgeText = letterChar
            }
            
            let isMultiChar = badgeText.count > 1
            let badgeWidth: CGFloat = isMultiChar ? 18.0 : 14.5
            let badgeHeight: CGFloat = 14.5
            let badgeRadius: CGFloat = isMultiChar ? 4.5 : 7.25
            let badgeRect = NSRect(
                x: round(iconRect.maxX - badgeWidth + 2.0),
                y: round(iconRect.maxY - badgeHeight + 2.0),
                width: badgeWidth,
                height: badgeHeight
            )
            
            // Cutout border for high-contrast separation
            let cutoutPath = NSBezierPath(
                roundedRect: badgeRect.insetBy(dx: -1.5, dy: -1.5),
                xRadius: badgeRadius + 1.5,
                yRadius: badgeRadius + 1.5
            )
            cutoutBg.setFill()
            cutoutPath.fill()
            
            // Keycap body
            let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: badgeRadius, yRadius: badgeRadius)
            if isFrontmost {
                cadmiumYellow.setFill()
                badgePath.fill()
            } else {
                keycapInactiveBg.setFill()
                badgePath.fill()
                keycapInactiveBorder.setStroke()
                badgePath.lineWidth = 0.5
                badgePath.stroke()
            }
            
            // Keycap text
            let keyAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 8.5, weight: .bold),
                .foregroundColor: isFrontmost ? NSColor(calibratedWhite: 0.10, alpha: 1.0) : (isDark ? NSColor.white : NSColor(calibratedWhite: 0.15, alpha: 1.0))
            ]
            let keyStr = NSAttributedString(string: badgeText, attributes: keyAttr)
            let keySize = keyStr.size()
            let keyDrawRect = NSRect(
                x: round(badgeRect.midX - keySize.width / 2.0),
                y: round(badgeRect.midY - keySize.height / 2.0 - 0.5),
                width: keySize.width,
                height: keySize.height
            )
            keyStr.draw(in: keyDrawRect)
            
            // 4. App Name (directly below icon, clean typography)
            let pStyle = NSMutableParagraphStyle()
            pStyle.alignment = .center
            pStyle.lineBreakMode = .byTruncatingTail
            
            let displayName: String
            if tile.item.bundleID.contains("antigravity-ide") || tile.item.name == "Antigravity IDE" {
                displayName = "AGY IDE"
            } else if tile.item.name == "Activity Monitor" {
                displayName = "Activity"
            } else if tile.item.name == "System Settings" || tile.item.name == "System Preferences" {
                displayName = "Settings"
            } else {
                displayName = tile.item.name
            }
            
            let nameAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8.5, weight: isFrontmost ? .semibold : .medium),
                .foregroundColor: isFrontmost ? primaryLabel : (isHovered ? primaryLabel : secondaryLabel),
                .paragraphStyle: pStyle
            ]
            let nameStr = NSAttributedString(string: displayName, attributes: nameAttr)
            let nameRect = NSRect(
                x: rect.minX,
                y: iconRect.maxY + 4.0,
                width: rect.width,
                height: 13.0
            )
            nameStr.draw(in: nameRect)
        }
    }
    
    private func superscript(for number: Int) -> String {
        let superscripts: [Character: Character] = [
            "0": "⁰", "1": "¹", "2": "²", "3": "³", "4": "⁴",
            "5": "⁵", "6": "⁶", "7": "⁷", "8": "⁸", "9": "⁹"
        ]
        return String(String(number).map { superscripts[$0] ?? $0 })
    }
    
    // MARK: - Accessibility
    
    public override func isAccessibilityElement() -> Bool { false }
    
    public override func accessibilityChildren() -> [Any]? {
        var elements: [Any] = []
        
        if hasProfiles {
            for (i, p) in profiles.enumerated() {
                let el = NSAccessibilityElement()
                el.setAccessibilityParent(self)
                el.setAccessibilityRole(.button)
                el.setAccessibilityLabel("\(p.effectiveName), Profile \(p.index)")
                el.setAccessibilityHelp("Hold caps lock and press \(p.index) to switch to \(p.effectiveName)")
                let screenRect = window?.convertToScreen(convert(tileRect(for: i), to: nil)) ?? .zero
                el.setAccessibilityFrame(screenRect)
                elements.append(el)
            }
        }
        
        if hasQuickApps {
            let tiles = quickAppTiles
            for (j, tile) in tiles.enumerated() {
                let el = NSAccessibilityElement()
                el.setAccessibilityParent(self)
                el.setAccessibilityRole(.button)
                let charLower = String(tile.letter).lowercased()
                let cycleInfo = tile.totalInGroup > 1 ? ", item \(tile.slotIndex) of \(tile.totalInGroup)" : ""
                el.setAccessibilityLabel("\(tile.item.name), Shortcut caps lock + \(charLower)\(cycleInfo)")
                el.setAccessibilityHelp("Hold caps lock and press \(charLower) to switch to \(tile.item.name)")
                let screenRect = window?.convertToScreen(convert(appTileRect(for: j), to: nil)) ?? .zero
                el.setAccessibilityFrame(screenRect)
                elements.append(el)
            }
        }
        
        return elements
    }
    
    // MARK: - Context Menu (Avatar Editing)
    
    public override func menu(for event: NSEvent) -> NSMenu? {
        guard hasProfiles else { return nil }
        let loc = (window != nil) ? convert(event.locationInWindow, from: nil) : event.locationInWindow
        for (i, p) in profiles.enumerated() {
            let rect = tileRect(for: i)
            if rect.contains(loc) || rect.contains(event.locationInWindow) {
                let contextMenu = NSMenu(title: p.effectiveName)
                let pasteItem = NSMenuItem(
                    title: "Paste Avatar for \(p.effectiveName)...",
                    action: #selector(handlePasteAvatarFromContext(_:)),
                    keyEquivalent: ""
                )
                pasteItem.target = self
                pasteItem.representedObject = p.dir
                contextMenu.addItem(pasteItem)
                
                let assistantItem = NSMenuItem(
                    title: "Open Avatar Assistant...",
                    action: #selector(handleOpenAssistantFromContext),
                    keyEquivalent: ""
                )
                assistantItem.target = self
                contextMenu.addItem(assistantItem)
                return contextMenu
            }
        }
        return nil
    }
    
    @objc private func handlePasteAvatarFromContext(_ sender: NSMenuItem) {
        guard let dir = sender.representedObject as? String else { return }
        if let appDelegate = NSApp.delegate as? AppDelegate {
            let fakeItem = NSMenuItem()
            fakeItem.representedObject = dir
            appDelegate.handlePasteAvatarFromClipboard(fakeItem)
        }
    }
    
    @objc private func handleOpenAssistantFromContext() {
        AvatarCaptureAssistantWindow.shared.show()
    }
}
