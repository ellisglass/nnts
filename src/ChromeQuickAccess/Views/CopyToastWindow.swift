import Cocoa
import AppKit
import SwiftUI

// MARK: - Copy Toast View
public struct CopyToastView: View {
    public let isVisible: Bool
    
    public init(isVisible: Bool) {
        self.isVisible = isVisible
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundColor(Color(red: 0.35, green: 0.88, blue: 0.52))
            
            Text("Copied")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            ZStack {
                VisualEffectBlur(material: .popover, blendingMode: .behindWindow, state: .active, cornerRadius: 18)
                    .clipShape(Capsule())
                Capsule()
                    .fill(.ultraThinMaterial)
                Capsule()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.18), location: 0.0),
                                .init(color: Color.white.opacity(0.06), location: 0.40),
                                .init(color: Color(red: 0.15, green: 0.18, blue: 0.26).opacity(0.15), location: 0.80),
                                .init(color: Color.white.opacity(0.04), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.50), location: 0.0),
                            .init(color: Color.white.opacity(0.15), location: 0.50),
                            .init(color: Color.white.opacity(0.25), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
        .shadow(color: Color.white.opacity(0.15), radius: 1, x: 0, y: -0.5)
        .scaleEffect(isVisible ? 1.0 : 0.95)
        .opacity(isVisible ? 1.0 : 0.0)
        .offset(y: isVisible ? 0 : 3)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Copy Toast State
@MainActor
public final class CopyToastState: ObservableObject {
    public static let shared = CopyToastState()
    @Published public var isVisible: Bool = false
}

// MARK: - Copy Toast Window
@MainActor
public final class CopyToastWindow: NSPanel {
    public static let shared = CopyToastWindow()
    
    private var dismissTask: Task<Void, Never>?
    
    public init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 84, height: 28),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = false
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        
        let hosting = NSHostingView(rootView: CopyToastHostingRoot())
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        self.contentView = hosting
    }
    
    /// Positions and presents the ephemeral toast near the cursor point
    public func show(at mouseLocation: CGPoint) {
        dismissTask?.cancel()
        
        // Offset snuggly beside the cursor
        let toastWidth: CGFloat = 84
        let toastHeight: CGFloat = 28
        var originX = mouseLocation.x + 8
        var originY = mouseLocation.y + 4
        
        // Clamp to screen bounds if available
        if let screen = NSScreen.screens.first(where: { NSPointInRect(mouseLocation, $0.frame) }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            if originX + toastWidth > visible.maxX {
                originX = mouseLocation.x - toastWidth - 6
            }
            if originY + toastHeight > visible.maxY {
                originY = mouseLocation.y - toastHeight - 6
            }
            originX = max(visible.minX, min(originX, visible.maxX - toastWidth))
            originY = max(visible.minY, min(originY, visible.maxY - toastHeight))
        }
        
        self.setFrame(NSRect(x: originX, y: originY, width: toastWidth, height: toastHeight), display: true)
        
        withAnimation(NNTSMotion.tactileBop) {
            CopyToastState.shared.isVisible = true
        }
        self.alphaValue = 1.0
        self.orderFrontRegardless()
        
        // Auto-dismiss after 450ms with smooth fade out
        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled, let self = self else { return }
            
            withAnimation(.easeOut(duration: 0.15)) {
                CopyToastState.shared.isVisible = false
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            self.orderOut(nil)
        }
    }
    
    public func hideImmediate() {
        dismissTask?.cancel()
        dismissTask = nil
        CopyToastState.shared.isVisible = false
        self.orderOut(nil)
    }
}

// MARK: - Hosting Root View
private struct CopyToastHostingRoot: View {
    @ObservedObject var state = CopyToastState.shared
    
    var body: some View {
        CopyToastView(isVisible: state.isVisible)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
