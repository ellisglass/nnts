import Cocoa
import AppKit
import SwiftUI

// MARK: - Mascot Animation Engine & Status Bar Icon
extension AppDelegate {
    public func startMascotBlinkTimer() {
        scheduleNextBlink()
    }
    
    public func stopMascotBlinkTimer() {
        mascotBlinkTimer?.invalidate()
        mascotBlinkTimer = nil
        mascotGazeResetTask?.cancel()
        mascotGazeResetTask = nil
    }
    
    internal func scheduleNextBlink() {
        mascotBlinkTimer?.invalidate()
        let interval = Double.random(in: 7.0...12.0)
        mascotBlinkTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.performMascotBlink()
            }
        }
    }
    
    public func performMascotBlink() {
        guard let button = self.statusItem?.button else { return }
        button.image = AppDelegate.makeStatusIcon(pressed: true)
        
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard let self = self else { return }
            self.statusItem?.button?.image = AppDelegate.makeStatusIcon(pressed: false)
            self.scheduleNextBlink()
        }
    }
    
    public func triggerMascotGaze(offset: CGFloat) {
        mascotGazeResetTask?.cancel()
        guard let button = self.statusItem?.button else { return }
        button.image = AppDelegate.makeStatusIcon(pressed: true)
        
        mascotGazeResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled, let self = self else { return }
            self.statusItem?.button?.image = AppDelegate.makeStatusIcon(pressed: false)
        }
    }
    
    public func updateStatusIcon() {
        guard let button = self.statusItem?.button else { return }
        button.image = AppDelegate.makeStatusIcon()
    }
    
    // MARK: - NNTS Status Bar Icon
    public static func makeStatusIcon(pressed: Bool = false) -> NSImage {
        let size = NSSize(width: 29, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            
            let dy: CGFloat = pressed ? -0.8 : 0.0
            let keyRect = CGRect(x: 1.25, y: 1.25 + dy, width: 26.5, height: 15.5)
            let path = CGPath(roundedRect: keyRect, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil)
            cg.addPath(path)
            cg.setLineWidth(1.25)
            cg.setStrokeColor(NSColor.black.cgColor)
            cg.strokePath()
            
            let text = "NNTS" as NSString
            let font = NSFont.systemFont(ofSize: 7.2, weight: .black)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            let strSize = text.size(withAttributes: attrs)
            let textRect = CGRect(
                x: (29 - strSize.width) / 2.0,
                y: (18 - strSize.height) / 2.0 + dy - 0.5,
                width: strSize.width,
                height: strSize.height
            )
            text.draw(in: textRect, withAttributes: attrs)
            return true
        }
        image.isTemplate = true
        return image
    }
    
    public static func makeStatusIcon(
        eyeGazeX: CGFloat = 0.0,
        eyeGazeY: CGFloat = 0.0,
        blinkProgress: CGFloat = 0.0
    ) -> NSImage {
        return makeStatusIcon(pressed: blinkProgress >= 0.5 || abs(eyeGazeX) > 0.1)
    }
    
    public static func makeNNTSKeycapIcon(pressed: Bool = false) -> NSImage {
        return makeStatusIcon(pressed: pressed)
    }
    
    public static func makeMascotStatusIcon(
        eyeGazeX: CGFloat = 0.0,
        eyeGazeY: CGFloat = 0.0,
        blinkProgress: CGFloat = 0.0
    ) -> NSImage {
        return makeStatusIcon(pressed: blinkProgress >= 0.5 || abs(eyeGazeX) > 0.1)
    }
    
    // MARK: - Mascot Separator View
    @MainActor
    public final class MascotSeparatorView: NSView {
        private let icon: NSImage
        private var bounceOffset: CGFloat = 0.0
        
        public init(icon: NSImage) {
            self.icon = icon
            super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 20))
            self.autoresizingMask = [.width]
            self.setAccessibilityElement(false)
        }
        
        public required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public override var intrinsicContentSize: NSSize {
            return NSSize(width: NSView.noIntrinsicMetric, height: 20)
        }
        
        public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            return false
        }
        
        public override var acceptsFirstResponder: Bool {
            return false
        }
        
        public override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window != nil else { return }
            self.bounceOffset = -3.5
            self.needsDisplay = true
            
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 25_000_000)
                guard let self = self else { return }
                self.bounceOffset = 1.0
                self.needsDisplay = true
                
                try? await Task.sleep(nanoseconds: 50_000_000)
                self.bounceOffset = 0.0
                self.needsDisplay = true
            }
        }
        
        public override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            
            let bounds = self.bounds
            let midY = bounds.midY
            let midX = bounds.midX
            let iconSize: CGFloat = 16
            let iconRect = NSRect(x: midX - iconSize / 2.0, y: midY - iconSize / 2.0 + bounceOffset, width: iconSize, height: iconSize)
            
            let margin: CGFloat = 14
            let spacing: CGFloat = 8
            
            // Accessible system-adaptive separator lines flanking the mascot icon (WCAG 1.4.11 compliant)
            let leftLineRect = NSRect(x: margin, y: midY - 0.5, width: max(0, iconRect.minX - spacing - margin), height: 1.0)
            if leftLineRect.width > 0 {
                NSColor.separatorColor.set()
                NSBezierPath.fill(leftLineRect)
            }
            
            let rightLineStart = iconRect.maxX + spacing
            let rightLineWidth = max(0, bounds.maxX - margin - rightLineStart)
            let rightLineRect = NSRect(x: rightLineStart, y: midY - 0.5, width: rightLineWidth, height: 1.0)
            if rightLineRect.width > 0 {
                NSColor.separatorColor.set()
                NSBezierPath.fill(rightLineRect)
            }
            
            // Center: Draw NNTS Mascot
            icon.draw(in: iconRect)
        }
    }
    
    public typealias HamsterSeparatorView = MascotSeparatorView
    
    internal func makeMascotSeparatorItem() -> NSMenuItem {
        let item = NSMenuItem()
        item.title = ""
        item.isEnabled = false
        item.view = MascotSeparatorView(icon: AppDelegate.makeMascotStatusIcon())
        return item
    }
    
    internal func makeHamsterSeparatorItem() -> NSMenuItem {
        return makeMascotSeparatorItem()
    }
}
