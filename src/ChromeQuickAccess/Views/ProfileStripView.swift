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
    public let activeDir: String?
    
    private var hoveredIndex: Int? = nil
    private var trackingArea: NSTrackingArea?
    
    public init(profiles: [ChromeProfile], activeDir: String?) {
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
        let tileHeight: CGFloat = 50
        let spacing: CGFloat = 6
        let maxTileWidth: CGFloat = min(66, (totalWidth - 16 - CGFloat(count - 1) * spacing) / CGFloat(count))
        let contentWidth = CGFloat(count) * maxTileWidth + CGFloat(count - 1) * spacing
        let startX = max(8, (totalWidth - contentWidth) / 2.0)
        let startY: CGFloat = 3
        
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
                return "caps lock + \(p.index): switch to \(p.effectiveName)\nClick to focus · Right-click for Avatar Assistant"
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
        if newHover != nil {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
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
                if event.modifierFlags.contains(.control) {
                    AvatarCaptureAssistantWindow.shared.show(profileDir: p.dir)
                } else if event.modifierFlags.contains(.option) {
                    ChromeProfileEngine.shared.toggleProfileSelection(dir: p.dir)
                } else {
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
                AvatarCaptureAssistantWindow.shared.show(profileDir: p.dir)
                return
            }
        }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard !profiles.isEmpty else { return }
        
        // 0. Sleek unified Card Dock container
        let cardRect = NSRect(x: 8, y: 1, width: bounds.width - 16, height: bounds.height - 2)
        let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 10, yRadius: 10)
        NSColor.quaternaryLabelColor.withAlphaComponent(0.28).setFill()
        cardPath.fill()
        NSColor.separatorColor.withAlphaComponent(0.2).setStroke()
        cardPath.lineWidth = 0.5
        cardPath.stroke()
        
        for (i, p) in profiles.enumerated() {
            let rect = tileRect(for: i)
            guard rect.width > 0 else { continue }
            
            let isActive = (p.dir == activeDir)
            let isHovered = (hoveredIndex == i)
            
            // 1. Hover state background
            if isHovered {
                let hoverBg = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
                NSColor.quaternaryLabelColor.withAlphaComponent(0.6).setFill()
                hoverBg.fill()
            }
            
            // 2. Avatar circular image
            let avatarDiameter: CGFloat = 28
            let avatarRect = NSRect(
                x: round(rect.midX - avatarDiameter / 2.0),
                y: rect.minY + 4,
                width: avatarDiameter,
                height: avatarDiameter
            )
            
            NSGraphicsContext.saveGraphicsState()
            let clip = NSBezierPath(ovalIn: avatarRect)
            clip.addClip()
            p.avatarImage?.draw(in: avatarRect)
            NSGraphicsContext.restoreGraphicsState()
            
            // 3. Active ring & checkmark indicator
            if isActive {
                let ring = NSBezierPath(ovalIn: avatarRect.insetBy(dx: -1.5, dy: -1.5))
                ring.lineWidth = 2.0
                NSColor.controlAccentColor.setStroke()
                ring.stroke()
                
                // Vector Checkmark badge at top-right
                let checkBadgeRect = NSRect(
                    x: avatarRect.maxX - 7,
                    y: avatarRect.minY - 2,
                    width: 11,
                    height: 11
                )
                let checkBg = NSBezierPath(ovalIn: checkBadgeRect)
                NSColor.controlAccentColor.setFill()
                checkBg.fill()
                NSColor.windowBackgroundColor.setStroke()
                checkBg.lineWidth = 0.75
                checkBg.stroke()
                
                let checkPath = NSBezierPath()
                checkPath.move(to: NSPoint(x: checkBadgeRect.minX + 2.8, y: checkBadgeRect.midY + 0.2))
                checkPath.line(to: NSPoint(x: checkBadgeRect.minX + 4.5, y: checkBadgeRect.maxY - 3.2))
                checkPath.line(to: NSPoint(x: checkBadgeRect.maxX - 2.8, y: checkBadgeRect.minY + 3.0))
                checkPath.lineWidth = 1.25
                checkPath.lineCapStyle = .round
                checkPath.lineJoinStyle = .round
                NSColor.white.setStroke()
                checkPath.stroke()
            }
            
            // 4. Hotkey slot badge (caps lock + 1...4)
            let badgeDiameter: CGFloat = 13
            let badgeRect = NSRect(
                x: avatarRect.maxX - 6,
                y: avatarRect.maxY - 7,
                width: badgeDiameter,
                height: badgeDiameter
            )
            let badgeBg = NSBezierPath(ovalIn: badgeRect)
            NSColor.black.withAlphaComponent(0.85).setFill()
            badgeBg.fill()
            NSColor.white.withAlphaComponent(0.4).setStroke()
            badgeBg.lineWidth = 0.5
            badgeBg.stroke()
            
            let slotStr = "\(p.index)"
            let slotAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .bold),
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
            
            // 5. Profile Name label below avatar
            let nameRect = NSRect(
                x: rect.minX + 2,
                y: avatarRect.maxY + 3,
                width: rect.width - 4,
                height: 13
            )
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byTruncatingTail
            
            let nameAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: isActive ? .semibold : .medium),
                .foregroundColor: isActive ? NSColor.labelColor : NSColor.secondaryLabelColor,
                .paragraphStyle: paragraphStyle
            ]
            let nameStr = NSAttributedString(string: p.effectiveName, attributes: nameAttr)
            nameStr.draw(in: nameRect)
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
