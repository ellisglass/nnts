//
//  ProfileStripView.swift
//  NNTS (macOS Productivity Suite)
//
//  Fluid horizontal profile switcher strip for the status bar menu.
//  Replaces vertical row sprawl with a compact, tactile card (Concept 2 + 3).
//

import Cocoa
import AppKit

public final class ProfileStripView: NSView, NSViewToolTipOwner {
    public let profiles: [ChromeProfile]
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
    
    private var hoveredIndex: Int? = nil
    private var trackingArea: NSTrackingArea?
    
    public init(profiles: [ChromeProfile], activeDir: String? = nil) {
        self.profiles = profiles
        self.activeDir = activeDir
        
        let width: CGFloat = 290
        let height: CGFloat = 56
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override var isFlipped: Bool { true }
    
    public func tileRect(for index: Int) -> NSRect {
        let count = profiles.count
        guard count > 0, index >= 0, index < count else { return .zero }
        
        let totalWidth = bounds.width
        let isCompact = count > 4
        let tileHeight: CGFloat = isCompact ? 46 : 50
        let spacing: CGFloat = isCompact ? 4 : 6
        let maxTileWidth: CGFloat
        if count == 1 {
            maxTileWidth = min(220, totalWidth - 24)
        } else if isCompact {
            maxTileWidth = min(32, (totalWidth - 16 - CGFloat(count - 1) * spacing) / CGFloat(count))
        } else {
            maxTileWidth = min(66, (totalWidth - 16 - CGFloat(count - 1) * spacing) / CGFloat(count))
        }
        let contentWidth = CGFloat(count) * maxTileWidth + CGFloat(count - 1) * spacing
        let startX = max(8, (totalWidth - contentWidth) / 2.0)
        let startY: CGFloat = isCompact ? 5 : 3
        
        return NSRect(
            x: startX + CGFloat(index) * (maxTileWidth + spacing),
            y: startY,
            width: maxTileWidth,
            height: tileHeight
        )
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
        
        removeAllToolTips()
        for (i, _) in profiles.enumerated() {
            let rect = tileRect(for: i)
            if rect.width > 0 {
                addToolTip(rect, owner: self, userData: nil)
            }
        }
    }
    
    public func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String {
        for (i, p) in profiles.enumerated() {
            if tileRect(for: i).contains(point) {
                return "caps lock + \(p.index): switch to \(p.effectiveName)"
            }
        }
        return ""
    }
    
    public override func mouseMoved(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        var newHover: Int? = nil
        for (i, _) in profiles.enumerated() {
            if tileRect(for: i).contains(loc) {
                newHover = i
                break
            }
        }
        if newHover != hoveredIndex {
            hoveredIndex = newHover
            needsDisplay = true
        }
        NSCursor.arrow.set() // Native macOS menu cursor invariant
    }
    
    public override func mouseExited(with event: NSEvent) {
        if hoveredIndex != nil {
            hoveredIndex = nil
            needsDisplay = true
        }
        NSCursor.arrow.set()
    }
    
    public override func mouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        for (i, p) in profiles.enumerated() {
            let rect = tileRect(for: i)
            if rect.contains(loc) {
                // Dismiss menu cleanly before external action (Mac HIG invariant)
                if let menu = enclosingMenuItem?.menu {
                    menu.cancelTracking()
                }
                if event.modifierFlags.contains(.option) {
                    ChromeProfileEngine.shared.toggleProfileSelection(dir: p.dir)
                } else {
                    self.updateActiveDir(p.dir)
                    ChromeProfileEngine.shared.focusProfile(dir: p.dir)
                }
                return
            }
        }
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        let loc = convert(event.locationInWindow, from: nil)
        for (i, p) in profiles.enumerated() {
            let rect = tileRect(for: i)
            if rect.contains(loc) {
                if let menu = enclosingMenuItem?.menu {
                    menu.cancelTracking()
                }
                self.updateActiveDir(p.dir)
                ChromeProfileEngine.shared.focusProfile(dir: p.dir)
                return
            }
        }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard !profiles.isEmpty else { return }
        
        // Dynamic active profile synchronization
        let currentActive = activeDir ?? ChromeProfileEngine.shared.getActiveProfileDir()
        
        // 0. Sleek unified Card Dock container
        let cardRect = NSRect(x: 8, y: 1, width: bounds.width - 16, height: bounds.height - 2)
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 10, yRadius: 10)
        NSColor.white.withAlphaComponent(0.06).setFill()
        cardPath.fill()
        NSColor.white.withAlphaComponent(0.12).setStroke()
        cardPath.lineWidth = 0.75
        cardPath.stroke()
        
        for (i, p) in profiles.enumerated() {
            let rect = tileRect(for: i)
            guard rect.width > 0 else { continue }
            
            let isHovered = (hoveredIndex == i)
            
            // 1. Hover state background
            if isHovered {
                let hoverBg = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
                NSColor.white.withAlphaComponent(0.12).setFill()
                hoverBg.fill()
            }
            
            let isActive = (p.dir == currentActive)
            
            // 2. Avatar circular image with fallback monogram & active ring
            let isCompact = profiles.count > 4
            let avatarDiameter: CGFloat = isCompact ? 28 : 30
            let avatarY: CGFloat = isCompact ? round(rect.midY - avatarDiameter / 2.0) : rect.minY + 3.5
            let avatarRect = NSRect(
                x: round(rect.midX - avatarDiameter / 2.0),
                y: avatarY,
                width: avatarDiameter,
                height: avatarDiameter
            )
            
            if let img = p.avatarImage {
                NSGraphicsContext.saveGraphicsState()
                let clip = NSBezierPath(ovalIn: avatarRect)
                clip.addClip()
                img.draw(in: avatarRect)
                NSGraphicsContext.restoreGraphicsState()
            } else {
                let bg = NSBezierPath(ovalIn: avatarRect)
                NSColor.controlAccentColor.withAlphaComponent(0.20).setFill()
                bg.fill()
                let char = p.effectiveName.first(where: { $0.isLetter || $0.isNumber }) ?? "P"
                let monoAttr: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: isCompact ? 11.0 : 12.5, weight: .bold),
                    .foregroundColor: NSColor.controlAccentColor
                ]
                let monoStr = NSAttributedString(string: String(char).uppercased(), attributes: monoAttr)
                let sSize = monoStr.size()
                let sRect = NSRect(
                    x: round(avatarRect.midX - sSize.width / 2.0),
                    y: round(avatarRect.midY - sSize.height / 2.0 - 0.5),
                    width: sSize.width,
                    height: sSize.height
                )
                monoStr.draw(in: sRect)
            }
            
            if isActive {
                let ring = NSBezierPath(ovalIn: avatarRect.insetBy(dx: -1.75, dy: -1.75))
                NSColor.controlAccentColor.setStroke()
                ring.lineWidth = 1.75
                ring.stroke()
            }
            
            // 3. Hotkey slot badge (caps lock + 1...8)
            let badgeDiameter: CGFloat = isCompact ? 12.0 : 13.5
            let badgeRect = NSRect(
                x: avatarRect.maxX - (isCompact ? 4.5 : 6),
                y: avatarRect.maxY - (isCompact ? 5.5 : 7),
                width: badgeDiameter,
                height: badgeDiameter
            )
            let badgeBg = NSBezierPath(ovalIn: badgeRect)
            NSColor(white: 0.12, alpha: 0.95).setFill()
            badgeBg.fill()
            NSColor.white.withAlphaComponent(0.35).setStroke()
            badgeBg.lineWidth = 0.75
            badgeBg.stroke()
            
            let slotStr = "\(p.index)"
            let slotAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: isCompact ? 8.0 : 9.0, weight: .bold),
                .foregroundColor: NSColor.white
            ]
            let slotAttrStr = NSAttributedString(string: slotStr, attributes: slotAttr)
            let slotSize = slotAttrStr.size()
            let slotDrawRect = NSRect(
                x: badgeRect.midX - slotSize.width / 2.0,
                y: badgeRect.midY - slotSize.height / 2.0 - 0.5,
                width: slotSize.width,
                height: slotSize.height
            )
            slotAttrStr.draw(in: slotDrawRect)
            
            // 4. Profile Name label below avatar (shown in standard mode; in compact mode names are shown in hover tooltip)
            if !isCompact {
                let nameRect = NSRect(
                    x: rect.minX + 2,
                    y: avatarRect.maxY + 2.5,
                    width: rect.width - 4,
                    height: 13
                )
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                paragraphStyle.lineBreakMode = .byTruncatingTail
                
                let nameAttr: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10, weight: isActive ? .semibold : .medium),
                    .foregroundColor: isActive ? NSColor.labelColor : NSColor.secondaryLabelColor.withAlphaComponent(0.85),
                    .paragraphStyle: paragraphStyle
                ]
                let nameStr = NSAttributedString(string: p.effectiveName, attributes: nameAttr)
                nameStr.draw(in: nameRect)
            }
        }
    }
    
    public override func isAccessibilityElement() -> Bool {
        return false
    }
    
    public override func accessibilityChildren() -> [Any]? {
        return profiles.enumerated().map { (i, p) in
            let element = NSAccessibilityElement()
            element.setAccessibilityParent(self)
            element.setAccessibilityRole(.button)
            element.setAccessibilityLabel("\(p.effectiveName), Profile \(p.index)")
            element.setAccessibilityHelp("Hold caps lock and press \(p.index) to switch to \(p.effectiveName)")
            let screenRect = window?.convertToScreen(convert(tileRect(for: i), to: nil)) ?? .zero
            element.setAccessibilityFrame(screenRect)
            return element
        }
    }
    
    public override func menu(for event: NSEvent) -> NSMenu? {
        let loc = convert(event.locationInWindow, from: nil)
        for (i, p) in profiles.enumerated() {
            if tileRect(for: i).contains(loc) {
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
