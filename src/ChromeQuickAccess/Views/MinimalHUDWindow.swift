import Cocoa
import AppKit
import SwiftUI

// MARK: - Chrome App Icon Helper
public enum ChromeAppIconHelper {
    public static func chromeIcon() -> NSImage {
        let chromeAppPath = "/Applications/Google Chrome.app"
        if FileManager.default.fileExists(atPath: chromeAppPath) {
            return NSWorkspace.shared.icon(forFile: chromeAppPath)
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        if let icon = NSImage(named: NSImage.applicationIconName) {
            return icon
        }
        return NSWorkspace.shared.icon(for: .application)
    }
}

// MARK: - Switcher Mode
public enum SwitcherMode: Equatable, Sendable {
    case chrome
    case antigravity
    case terminal
    case notes
    case ide
}

// MARK: - Switcher HUD State
@MainActor
public final class ChromeSwitcherState: ObservableObject {
    public static let shared = ChromeSwitcherState()
    
    @Published public var mode: SwitcherMode = .chrome
    @Published public var profiles: [ChromeProfile] = []
    @Published public var antigravityItems: [AntigravityItem] = []
    @Published public var selectedIndex: Int = 0 {
        didSet {
            if mode == .chrome {
                selectedProfileIndex = selectedIndex
            }
        }
    }
    @Published public var selectedProfileIndex: Int = 0
    @Published public var isVisible: Bool = false
    
    public var selectedProfile: ChromeProfile? {
        guard !profiles.isEmpty else { return nil }
        if mode == .chrome {
            let idx = max(0, min(selectedIndex, profiles.count - 1))
            return profiles[idx]
        }
        let idx = max(0, min(selectedProfileIndex, profiles.count - 1))
        return profiles[idx]
    }
    
    public var selectedAppItem: AntigravityItem? {
        guard !antigravityItems.isEmpty, selectedIndex >= 0, selectedIndex < antigravityItems.count else {
            return antigravityItems.first
        }
        return antigravityItems[selectedIndex]
    }
    
    public var selectedAntigravityItem: AntigravityItem? {
        selectedAppItem
    }
    
    public var hasBrothers: Bool {
        if mode == .chrome {
            return profiles.count > 1
        } else {
            return antigravityItems.count > 1
        }
    }
    
    public func selectNext() {
        if mode == .chrome {
            guard !profiles.isEmpty else { return }
            withAnimation(XomskyMotion.magneticGlide) {
                selectedIndex = (selectedIndex + 1) % profiles.count
                selectedProfileIndex = selectedIndex
            }
            return
        }
        
        guard !antigravityItems.isEmpty else { return }
        withAnimation(XomskyMotion.magneticGlide) {
            selectedIndex = (selectedIndex + 1) % antigravityItems.count
        }
    }
    
    public func selectPrevious() {
        if mode == .chrome {
            guard !profiles.isEmpty else { return }
            withAnimation(XomskyMotion.magneticGlide) {
                selectedIndex = (selectedIndex - 1 + profiles.count) % profiles.count
                selectedProfileIndex = selectedIndex
            }
            return
        }
        
        guard !antigravityItems.isEmpty else { return }
        withAnimation(XomskyMotion.magneticGlide) {
            selectedIndex = (selectedIndex - 1 + antigravityItems.count) % antigravityItems.count
        }
    }
    
    public func selectNextCard() {
        selectNext()
    }
    
    public func selectPreviousCard() {
        selectPrevious()
    }
    
    public func selectIndex(_ index: Int) {
        if mode == .chrome {
            guard !profiles.isEmpty else { return }
            let clamped = max(0, min(index, profiles.count - 1))
            withAnimation(XomskyMotion.magneticGlide) {
                selectedIndex = clamped
                selectedProfileIndex = clamped
            }
        } else {
            guard !antigravityItems.isEmpty else { return }
            let clamped = max(0, min(index, antigravityItems.count - 1))
            withAnimation(XomskyMotion.magneticGlide) {
                selectedIndex = clamped
            }
        }
    }
    
    public func selectChromeProfile(index: Int) {
        guard !profiles.isEmpty else { return }
        let clamped = max(0, min(index, profiles.count - 1))
        if let browserIdx = antigravityItems.firstIndex(where: { item in
            item.bundleID == ChromeProfileEngine.shared.browserBundleID ||
            ChromeProfileEngine.supportedBrowsers.contains(where: { b in b.bundleID == item.bundleID })
        }) {
            withAnimation(XomskyMotion.magneticGlide) {
                selectedIndex = browserIdx
                selectedProfileIndex = clamped
            }
        } else {
            withAnimation(XomskyMotion.magneticGlide) {
                mode = .chrome
                selectedIndex = clamped
                selectedProfileIndex = clamped
            }
        }
    }
}

// MARK: - CRT Color Theme (ArtistManagement Neon Violet-Pink Reference)
public enum CRTTheme {
    /// Authentic neon violet-pink contour / accent color from _ArtistManagement artwork
    public static let neonVioletPink = Color(red: 0.96, green: 0.20, blue: 0.78)
    public static let electricMagenta = Color(red: 0.98, green: 0.24, blue: 0.85)
    public static let deepViolet = Color(red: 0.82, green: 0.16, blue: 0.92)
    
    /// CRT phosphor green trace line on the outer left edge
    public static let phosphorGreen = Color(red: 0.22, green: 0.98, blue: 0.35)
}

// MARK: - Profile Avatar View
public struct ProfileAvatarView: View {
    public let profile: ChromeProfile
    public let isSelected: Bool
    public let slotIndex: Int
    public let isLarge: Bool
    public let isCompact: Bool
    public var namespace: Namespace.ID?
    
    public init(
        profile: ChromeProfile,
        isSelected: Bool,
        slotIndex: Int = 0,
        isLarge: Bool = false,
        isCompact: Bool = false,
        namespace: Namespace.ID? = nil
    ) {
        self.profile = profile
        self.isSelected = isSelected
        self.slotIndex = slotIndex > 0 ? slotIndex : profile.index
        self.isLarge = isLarge
        self.isCompact = isCompact
        self.namespace = namespace
    }
    
    public var body: some View {
        let avatarSize: CGFloat = isLarge ? 42 : (isCompact ? 24 : 34)
        let ringSize: CGFloat = isLarge ? 48 : (isCompact ? 29 : 40)
        let colWidth: CGFloat = isLarge ? 48 : (isCompact ? 30 : 40)
        
        VStack(spacing: isCompact ? 2 : 3) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: avatarSize, height: avatarSize)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.18)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: avatarSize, height: avatarSize)
                
                if let avatar = profile.avatarImage {
                    Image(nsImage: avatar)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color(red: 0.35, green: 0.55, blue: 0.95), Color(red: 0.55, green: 0.35, blue: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: avatarSize, height: avatarSize)
                        .overlay(
                            Text(String(profile.effectiveName.prefix(1)).uppercased())
                                .font(.system(size: isLarge ? 15 : (isCompact ? 10 : 12), weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                // Active liquid glass selection ring
                if isSelected {
                    Circle()
                        .strokeBorder(Color.white, lineWidth: 2.0)
                        .frame(width: ringSize, height: ringSize)
                        .shadow(color: Color.white.opacity(0.95), radius: 5, x: 0, y: 0)
                        .shadow(color: Color(red: 0.40, green: 0.80, blue: 1.0).opacity(0.60), radius: 8, x: 0, y: 0)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.32), lineWidth: 0.75)
                        .frame(width: ringSize - 2, height: ringSize - 2)
                }
            }
            .frame(width: ringSize, height: ringSize)
            
            Text("\(slotIndex)")
                .font(.system(size: isLarge ? 12 : (isCompact ? 9 : 10), weight: isSelected ? .bold : .medium, design: .monospaced))
                .foregroundColor(isSelected ? .white : .white.opacity(0.75))
                .shadow(color: Color.black.opacity(0.40), radius: 1.5, y: 1)
        }
        .frame(width: colWidth)
        .padding(.vertical, isCompact ? 1.5 : 2.5)
        .scaleEffect(isSelected ? 1.05 : 0.96)
        .animation(XomskyMotion.magneticGlide, value: isSelected)
    }
}

// MARK: - App Channel Item View (Bottom row for apps on same letter)
public struct AppChannelItemView: View {
    public let item: AntigravityItem
    public let isSelected: Bool
    public let channelIndex: Int
    public var namespace: Namespace.ID?
    
    public init(item: AntigravityItem, isSelected: Bool, channelIndex: Int = 0, namespace: Namespace.ID? = nil) {
        self.item = item
        self.isSelected = isSelected
        self.channelIndex = channelIndex > 0 ? channelIndex : item.index
        self.namespace = namespace
    }
    
    public var body: some View {
        let avatarSize: CGFloat = 34
        let ringSize: CGFloat = 40
        let colWidth: CGFloat = 40
        let iconCornerRadius: CGFloat = 8.0
        let ringCornerRadius: CGFloat = 9.5
        
        VStack(spacing: 3) {
            ZStack {
                RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.14))
                    .frame(width: avatarSize, height: avatarSize)
                
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: avatarSize, height: avatarSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous))
                
                // Active glassmorphic selection ring along the app icon perimeter
                if isSelected {
                    RoundedRectangle(cornerRadius: ringCornerRadius, style: .continuous)
                        .stroke(Color.white, lineWidth: 1.75)
                        .frame(width: ringSize, height: ringSize)
                        .shadow(color: Color.white.opacity(0.60), radius: 4, x: 0, y: 0)
                        .shadow(color: Color.black.opacity(0.35), radius: 2.0, x: 0, y: 1.0)
                } else {
                    RoundedRectangle(cornerRadius: ringCornerRadius - 0.5, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 0.75)
                        .frame(width: ringSize - 2, height: ringSize - 2)
                }
            }
            .frame(width: ringSize, height: ringSize)
            
            Text("\(channelIndex)")
                .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .monospaced))
                .foregroundColor(isSelected ? .white : .white.opacity(0.65))
                .shadow(color: Color.black.opacity(0.45), radius: 1.5, y: 1)
        }
        .frame(width: colWidth)
        .padding(.vertical, 2.5)
        .background {
            if isSelected {
                let capsuleShape = RoundedRectangle(cornerRadius: 11, style: .continuous)
                let capsuleContent = ZStack {
                    capsuleShape
                        .fill(.ultraThinMaterial)
                    capsuleShape
                        .fill(Color.white.opacity(0.18))
                }
                .overlay(
                    capsuleShape
                        .stroke(Color.white.opacity(0.38), lineWidth: 0.75)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)

                if let ns = namespace {
                    capsuleContent
                        .matchedGeometryEffect(id: "activeAppChannelCapsule", in: ns)
                } else {
                    capsuleContent
                }
            }
        }
        .scaleEffect(isSelected ? 1.05 : 0.96)
        .animation(XomskyMotion.magneticGlide, value: isSelected)
    }
}

// Retain AntigravityAvatarView for backwards compatibility
public struct AntigravityAvatarView: View {
    public let item: AntigravityItem
    public let isSelected: Bool
    public let slotIndex: Int
    public var namespace: Namespace.ID?
    
    public init(item: AntigravityItem, isSelected: Bool, slotIndex: Int = 0, namespace: Namespace.ID? = nil) {
        self.item = item
        self.isSelected = isSelected
        self.slotIndex = slotIndex > 0 ? slotIndex : item.index
        self.namespace = namespace
    }
    
    public var body: some View {
        AppChannelItemView(item: item, isSelected: isSelected, channelIndex: slotIndex, namespace: namespace)
    }
}

// MARK: - Native macOS HUD Card View
public struct HUDCardView: View {
    /// Deterministic standard width matching native macOS application switcher cards.
    public static let standardCardWidth: CGFloat = 132
    
    public let name: String
    public let icon: NSImage
    public let isSelected: Bool
    public let isBrowser: Bool
    public let profiles: [ChromeProfile]
    public let selectedProfileIndex: Int
    public let hasRowProfiles: Bool
    public let isSingleCard: Bool
    public var namespace: Namespace.ID?
    
    public init(
        name: String,
        icon: NSImage,
        isSelected: Bool,
        isBrowser: Bool,
        profiles: [ChromeProfile],
        selectedProfileIndex: Int,
        hasRowProfiles: Bool = true,
        isSingleCard: Bool = false,
        namespace: Namespace.ID? = nil
    ) {
        self.name = name
        self.icon = icon
        self.isSelected = isSelected
        self.isBrowser = isBrowser
        self.profiles = profiles
        self.selectedProfileIndex = selectedProfileIndex
        self.hasRowProfiles = hasRowProfiles
        self.isSingleCard = isSingleCard
        self.namespace = namespace
    }
    
    public var cardWidth: CGFloat {
        if isSingleCard {
            return (isBrowser && !profiles.isEmpty) ? 240 : 190
        }
        return Self.standardCardWidth
    }
    
    public var cardHeight: CGFloat {
        if isSingleCard {
            return (isBrowser && !profiles.isEmpty) ? 304 : 204
        }
        return hasRowProfiles ? 190 : 174
    }
    
    /// App icon size scaled 1.7x (92pt standard, 116pt single-card)
    public var iconSize: CGFloat {
        round((isSingleCard ? 68.0 : 54.0) * 1.7)
    }
    
    public var body: some View {
        VStack(spacing: isSingleCard ? 8 : 6) {
            // 1. App Icon with subtle shadow and border (1.7x scaled: 92pt / 116pt)
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
                .padding(.top, isSingleCard ? ((isBrowser && !profiles.isEmpty) ? 6 : 2) : 2)
            
            // 2. Primary Title Label (only shown when focused/selected!)
            Text(name)
                .font(.system(size: isSingleCard ? 15 : 13, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                .shadow(color: Color.black.opacity(0.28), radius: 2, y: 1)
                .lineLimit(1)
                .opacity(isSelected ? 1.0 : 0.0)
            
            // 3. Profiles Avatar Row or Balanced Spacer (when row has profiles)
            if isBrowser && !profiles.isEmpty {
                HStack(spacing: isSingleCard ? 8 : 4) {
                    ForEach(Array(profiles.enumerated()), id: \.element.id) { idx, profile in
                        ProfileAvatarView(
                            profile: profile,
                            isSelected: isSelected && (idx == selectedProfileIndex),
                            slotIndex: idx + 1,
                            isLarge: isSingleCard,
                            namespace: namespace
                        )
                    }
                }
                .padding(.top, 2)
                
                // In single card mode, show active profile pill badge under the profiles icons
                if isSingleCard, selectedProfileIndex >= 0, selectedProfileIndex < profiles.count {
                    let activeProf = profiles[selectedProfileIndex]
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(red: 0.20, green: 0.80, blue: 0.60))
                            .frame(width: 6, height: 6)
                        Text(activeProf.effectiveName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.92))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.24), lineWidth: 0.75)
                            )
                    )
                    .padding(.top, 4)
                }
            } else if !isSingleCard && hasRowProfiles {
                Spacer().frame(height: 38)
            }
        }
        .padding(.vertical, isSingleCard ? ((isBrowser && !profiles.isEmpty) ? 16 : 14) : 12)
        .padding(.horizontal, isSingleCard ? ((isBrowser && !profiles.isEmpty) ? 16 : 14) : 10)
        .frame(width: cardWidth, height: cardHeight)
        .background {
            if isSelected && !isSingleCard {
                let cardShape = RoundedRectangle(cornerRadius: 16, style: .continuous)
                ZStack {
                    cardShape
                        .fill(.ultraThinMaterial)
                    cardShape
                        .fill(Color.white.opacity(0.16))
                }
                .overlay(
                    cardShape
                        .stroke(Color.white.opacity(0.32), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 3)
            }
        }
        .scaleEffect(isSelected ? 1.02 : 0.98)
        .animation(XomskyMotion.magneticGlide, value: isSelected)
    }
}

// MARK: - Kinescope (CRT) Convex Bezel Shape
public struct KinescopeShape: InsettableShape, Sendable {
    public var cornerRadius: CGFloat
    public var bulge: CGFloat
    public var insetAmount: CGFloat
    
    public init(cornerRadius: CGFloat = 32, bulge: CGFloat = 7, insetAmount: CGFloat = 0) {
        self.cornerRadius = cornerRadius
        self.bulge = bulge
        self.insetAmount = insetAmount
    }
    
    public func inset(by amount: CGFloat) -> KinescopeShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
    
    public func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard insetRect.width > 20, insetRect.height > 20 else { return Path() }
        
        let w = insetRect.width
        let h = insetRect.height
        let a = w / 2.0
        let b = h / 2.0
        let cx = insetRect.midX
        let cy = insetRect.midY
        
        // Superellipse exponents providing infinite curvature continuity (C^∞):
        // Silk-smooth top & bottom transitions without any corner kinks or creases.
        let aspectRatio = w / h
        let expX: Double = aspectRatio > 1.4 ? 4.8 : 4.4
        let expY: Double = aspectRatio > 1.4 ? 4.2 : 4.4
        
        var path = Path()
        let steps = 180
        var isFirst = true
        
        for i in 0..<steps {
            let theta = (Double(i) / Double(steps)) * 2.0 * .pi
            let cosT = cos(theta)
            let sinT = sin(theta)
            let signX = cosT >= 0 ? 1.0 : -1.0
            let signY = sinT >= 0 ? 1.0 : -1.0
            
            let x = signX * pow(abs(cosT), 2.0 / expX) * a + cx
            let y = signY * pow(abs(sinT), 2.0 / expY) * b + cy
            let pt = CGPoint(x: x, y: y)
            
            if isFirst {
                path.move(to: pt)
                isFirst = false
            } else {
                path.addLine(to: pt)
            }
        }
        
        path.closeSubpath()
        return path
    }
}

// MARK: - CRT Aperture Grille Scanlines
public struct CRTScanlinesView: View {
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let step: CGFloat = 3.2
                let count = Int(size.height / step)
                for i in 0..<count {
                    let y = CGFloat(i) * step
                    let lineRect = CGRect(x: 0, y: y, width: size.width, height: 1.0)
                    context.fill(Path(lineRect), with: .color(Color.black.opacity(0.10)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - CRT Left Edge Arc Shape
public struct CRTLeftEdgeArcShape: Shape {
    public var insetAmount: CGFloat = 1.0
    
    public init(insetAmount: CGFloat = 1.0) {
        self.insetAmount = insetAmount
    }
    
    public func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        guard insetRect.width > 20, insetRect.height > 20 else { return Path() }
        
        let w = insetRect.width
        let h = insetRect.height
        let a = w / 2.0
        let b = h / 2.0
        let cx = insetRect.midX
        let cy = insetRect.midY
        
        let aspectRatio = w / h
        let expX: Double = aspectRatio > 1.4 ? 4.8 : 4.4
        let expY: Double = aspectRatio > 1.4 ? 4.2 : 4.4
        
        var path = Path()
        let steps = 90
        let startTheta = 1.36 * Double.pi
        let endTheta = 0.64 * Double.pi
        
        var isFirst = true
        for i in 0...steps {
            // Sweep from top-left (1.36 * pi) down to bottom-left (0.64 * pi)
            let t = Double(i) / Double(steps)
            let theta = startTheta - t * (startTheta - endTheta)
            
            let cosT = cos(theta)
            let sinT = sin(theta)
            let signX = cosT >= 0 ? 1.0 : -1.0
            let signY = sinT >= 0 ? 1.0 : -1.0
            
            let x = signX * pow(abs(cosT), 2.0 / expX) * a + cx
            let y = signY * pow(abs(sinT), 2.0 / expY) * b + cy
            let pt = CGPoint(x: x, y: y)
            
            if isFirst {
                path.move(to: pt)
                isFirst = false
            } else {
                path.addLine(to: pt)
            }
        }
        
        return path
    }
}

// MARK: - CRT Vector Arc View (Phosphor green oscilloscope/kinescope trace line on the very outer left edge)
public struct CRTVectorArcView: View {
    public init() {}
    
    public var body: some View {
        CRTLeftEdgeArcShape(insetAmount: 1.0)
            .stroke(
                LinearGradient(
                    colors: [
                        CRTTheme.phosphorGreen.opacity(0.12),
                        CRTTheme.phosphorGreen.opacity(0.95),
                        CRTTheme.phosphorGreen,
                        CRTTheme.phosphorGreen.opacity(0.95),
                        CRTTheme.phosphorGreen.opacity(0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                style: StrokeStyle(lineWidth: 0.75, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: CRTTheme.phosphorGreen.opacity(0.85), radius: 1.5, x: 0.5, y: 0)
            .shadow(color: CRTTheme.phosphorGreen.opacity(0.35), radius: 3, x: 1, y: 0)
            .allowsHitTesting(false)
    }
}




// MARK: - Visual Effect Blur (Native macOS Behind-Window Frosted Glass)
public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State
    public var cornerRadius: CGFloat

    public init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active,
        cornerRadius: CGFloat = 30
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
        self.cornerRadius = cornerRadius
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.masksToBounds = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.layer?.cornerRadius = cornerRadius
        nsView.layer?.masksToBounds = true
    }
}

// MARK: - Mac Native Liquid Glass (Tahoe / Sequoia Native Liquid Glass System)
public struct MacNativeLiquidGlassBackground: View {
    public var cornerRadius: CGFloat
    public var material: NSVisualEffectView.Material
    
    public init(cornerRadius: CGFloat = 28, material: NSVisualEffectView.Material = .popover) {
        self.cornerRadius = cornerRadius
        self.material = material
    }
    
    public var body: some View {
        ZStack {
            // 1. Native macOS Behind-Window Visual Effect (dynamic desktop/window sampling blur)
            VisualEffectBlur(material: material, blendingMode: .behindWindow, state: .active, cornerRadius: cornerRadius)
            
            // 2. Liquid Glass Translucent Luminous Sheen (crystal clarity, light passing through, NEVER black!)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.36), location: 0.0),
                            .init(color: Color.white.opacity(0.14), location: 0.28),
                            .init(color: Color.white.opacity(0.04), location: 0.60),
                            .init(color: Color.white.opacity(0.20), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 3. Diagonal Liquid Specular Glaze (wet glossy reflection across surface)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.48), location: 0.0),
                            .init(color: Color.white.opacity(0.18), location: 0.22),
                            .init(color: Color.clear, location: 0.52)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // 4. Upper Bulb/Dome Lens Reflection (convex liquid glare)
            GeometryReader { geo in
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.36),
                                Color.white.opacity(0.10),
                                Color.clear
                            ],
                            center: .top,
                            startRadius: 0,
                            endRadius: geo.size.width * 0.65
                        )
                    )
                    .frame(width: geo.size.width * 1.3, height: geo.size.height * 0.45)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.08)
            }
            
            // 5. Specular Inner Refraction Rim Highlight
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: 1.0)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.92), location: 0.0),
                            .init(color: Color.white.opacity(0.45), location: 0.25),
                            .init(color: Color.white.opacity(0.15), location: 0.60),
                            .init(color: Color.white.opacity(0.50), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        }
        .overlay(
            // 6. Hairline Outer Specular Border with subtle cyan-to-violet dispersion
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.70, green: 0.88, blue: 1.0).opacity(0.80), location: 0.0),
                            .init(color: Color.white.opacity(0.80), location: 0.18),
                            .init(color: Color.white.opacity(0.25), location: 0.50),
                            .init(color: Color(red: 0.88, green: 0.72, blue: 1.0).opacity(0.55), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        // 7. Multi-layered Floating Glass Elevation Shadow
        .shadow(color: Color.black.opacity(0.22), radius: 32, x: 0, y: 16)
        .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 3)
        .shadow(color: Color.white.opacity(0.30), radius: 1, x: 0, y: -0.5)
    }
}

extension View {
    public func macNativeLiquidGlass(cornerRadius: CGFloat = 28, material: NSVisualEffectView.Material = .popover) -> some View {
        self.background(
            MacNativeLiquidGlassBackground(cornerRadius: cornerRadius, material: material)
        )
    }
}

// MARK: - Modern Switcher HUD View (Retro TV Channel Switcher)
public struct MinimalHUDView: View {
    @ObservedObject var state = ChromeSwitcherState.shared
    @Namespace private var selectionNamespace
    
    /// Deterministic size-invariant CRT screen frame
    public static let hudWidth: CGFloat = 300
    public static let hudHeight: CGFloat = 270
    
    public init() {}
    
    private func isBrowser(_ item: AntigravityItem) -> Bool {
        let browserBundleID = ChromeProfileEngine.shared.browserBundleID
        if item.bundleID == browserBundleID { return true }
        return ChromeProfileEngine.supportedBrowsers.contains(where: { b in b.bundleID == item.bundleID })
    }
    
    private var activeIcon: NSImage {
        if state.mode == .chrome {
            return ChromeProfileEngine.shared.activeBrowserIcon
        }
        if let item = state.selectedAppItem {
            return item.icon
        }
        return NSWorkspace.shared.icon(for: .application)
    }
    
    private var activeName: String {
        if state.mode == .chrome {
            return ChromeProfileEngine.shared.activeBrowserName
        }
        if let item = state.selectedAppItem {
            return item.name
        }
        return "Application"
    }
    
    private var activeProfile: ChromeProfile? {
        if state.mode == .chrome {
            return state.selectedProfile
        }
        if let item = state.selectedAppItem, isBrowser(item) {
            return state.selectedProfile
        }
        return nil
    }
    
    private var isCurrentBrowser: Bool {
        if state.mode == .chrome { return true }
        guard let item = state.selectedAppItem else { return false }
        return isBrowser(item)
    }
    
    private var hasMultipleApps: Bool {
        state.antigravityItems.count > 1
    }
    
    private var showProfilesRow: Bool {
        (state.mode == .chrome || isCurrentBrowser) && !state.profiles.isEmpty
    }
    
    private var cycleIndicator: String? {
        guard state.antigravityItems.count > 1 else { return nil }
        let current = state.selectedIndex + 1
        let total = state.antigravityItems.count
        return "\(current)/\(total) ↻"
    }
    
    private var shortcutChar: Character {
        if let item = state.selectedAppItem {
            return item.name.first(where: { $0.isLetter }) ?? "C"
        }
        return "C"
    }
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 1. Top Apps Row (Clear indicator of what's on this hotkey)
                if hasMultipleApps {
                    HStack(spacing: 12) {
                        ForEach(Array(state.antigravityItems.enumerated()), id: \.element.id) { idx, item in
                            let isCurrent = idx == state.selectedIndex
                            Image(nsImage: item.icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: isCurrent ? 28 : 22, height: isCurrent ? 28 : 22)
                                .opacity(isCurrent ? 1.0 : 0.40)
                                .shadow(color: Color.black.opacity(isCurrent ? 0.25 : 0), radius: 2, y: 1)
                                .background(
                                    isCurrent ?
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color.white.opacity(0.28))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .strokeBorder(Color.white.opacity(0.55), lineWidth: 0.75)
                                            )
                                            .frame(width: 38, height: 38)
                                        : nil
                                )
                        }
                    }
                    .padding(.top, 16)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Color.clear.frame(height: 16)
                }
                
                Spacer()
                
                // 2. Center Hero Display (Large App Icon + Title)
                VStack(spacing: 6) {
                    Image(nsImage: activeIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: showProfilesRow ? 62 : 76, height: showProfilesRow ? 62 : 76)
                        .shadow(color: Color.black.opacity(0.30), radius: 12, y: 6)
                    
                    Text(activeName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.40), radius: 3, y: 1.5)
                        .lineLimit(1)
                    
                    // Chrome active profile pill (if applicable)
                    if showProfilesRow, let prof = activeProfile {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(red: 0.25, green: 0.90, blue: 0.55))
                                .frame(width: 5, height: 5)
                                .shadow(color: Color(red: 0.25, green: 0.90, blue: 0.55).opacity(0.85), radius: 3)
                            Text(prof.effectiveName)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3.5)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.24))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(
                                            LinearGradient(
                                                colors: [Color.white.opacity(0.75), Color.white.opacity(0.25)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            lineWidth: 0.75
                                        )
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                
                Spacer()
                
                // 3. Bottom Presets Row (Chrome Profiles)
                if showProfilesRow {
                    HStack(spacing: 8) {
                        ForEach(Array(state.profiles.enumerated()), id: \.element.id) { idx, profile in
                            ProfileAvatarView(
                                profile: profile,
                                isSelected: idx == state.selectedProfileIndex,
                                slotIndex: idx + 1,
                                isLarge: false,
                                isCompact: false,
                                namespace: selectionNamespace
                            )
                        }
                    }
                    .padding(.bottom, 18)
                } else {
                    Color.clear
                        .frame(height: 18)
                }
            }
            .frame(width: Self.hudWidth, height: Self.hudHeight)
            .background(
                MacNativeLiquidGlassBackground(cornerRadius: 28, material: .popover)
            )
            .scaleEffect(state.isVisible ? 1.0 : 0.94)
            .opacity(state.isVisible ? 1.0 : 0.0)
            .animation(XomskyMotion.interactiveSnap, value: state.isVisible)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Minimal HUD Window
@MainActor
public final class MinimalHUDWindow: NSPanel {

    public static let shared = MinimalHUDWindow()
    
    private let hostingView: NSHostingView<MinimalHUDView>
    
    public init() {
        let hosting = NSHostingView(rootView: MinimalHUDView())
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        self.hostingView = hosting
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 380),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.becomesKeyOnlyIfNeeded = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        self.contentView = hosting
    }
    
    public func show(profiles: [ChromeProfile], selectedIndex: Int) {
        withAnimation(XomskyMotion.interactiveSnap) {
            ChromeSwitcherState.shared.mode = .chrome
            ChromeSwitcherState.shared.profiles = profiles
            ChromeSwitcherState.shared.antigravityItems = []
            let validIndex = profiles.isEmpty ? 0 : max(0, min(selectedIndex, profiles.count - 1))
            ChromeSwitcherState.shared.selectedIndex = validIndex
            ChromeSwitcherState.shared.selectedProfileIndex = validIndex
            ChromeSwitcherState.shared.isVisible = true
        }
        
        reposition()
        self.alphaValue = 1.0
        self.orderFrontRegardless()
        triggerSensoryFeedback()
    }
    
    public func showAntigravity(items: [AntigravityItem], selectedIndex: Int) {
        showAppGroup(mode: .antigravity, items: items, selectedIndex: selectedIndex)
    }
    
    public func showAppGroup(mode: SwitcherMode, items: [AntigravityItem], selectedIndex: Int, profileIndex: Int = 0) {
        withAnimation(XomskyMotion.interactiveSnap) {
            ChromeSwitcherState.shared.mode = mode
            ChromeSwitcherState.shared.antigravityItems = items
            
            let profileEngine = ChromeProfileEngine.shared
            let containsBrowser = items.contains(where: { item in
                item.bundleID == profileEngine.browserBundleID ||
                ChromeProfileEngine.supportedBrowsers.contains(where: { b in b.bundleID == item.bundleID })
            })
            if containsBrowser {
                ChromeSwitcherState.shared.profiles = profileEngine.selectedProfiles
            } else {
                ChromeSwitcherState.shared.profiles = []
            }
            
            let validIndex = items.isEmpty ? 0 : max(0, min(selectedIndex, items.count - 1))
            let profCount = ChromeSwitcherState.shared.profiles.count
            let validProfIndex = profCount > 0 ? max(0, min(profileIndex, profCount - 1)) : 0
            
            ChromeSwitcherState.shared.selectedIndex = validIndex
            ChromeSwitcherState.shared.selectedProfileIndex = validProfIndex
            ChromeSwitcherState.shared.isVisible = true
        }
        
        reposition()
        self.alphaValue = 1.0
        self.orderFrontRegardless()
        triggerSensoryFeedback()
    }
    
    private func currentScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
            ?? NSScreen()
    }
    
    private func reposition() {
        let screen = currentScreen()
        let screenRect = screen.frame
        let windowWidth: CGFloat = 880
        let windowHeight: CGFloat = 380
        let x = screenRect.midX - (windowWidth / 2)
        let y = screenRect.midY - (windowHeight / 2)
        let targetFrame = NSRect(x: x, y: y, width: windowWidth, height: windowHeight)
        if self.frame != targetFrame {
            self.setFrame(targetFrame, display: true)
            self.invalidateShadow()
        }
    }
    
    private func triggerSensoryFeedback() {
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .default
        )
        
        let announcementText: String
        if ChromeSwitcherState.shared.mode == .chrome {
            let prof = ChromeSwitcherState.shared.selectedProfile?.effectiveName ?? "Profile"
            announcementText = "\(ChromeProfileEngine.shared.activeBrowserName), \(prof)"
        } else if let app = ChromeSwitcherState.shared.selectedAppItem {
            let profileEngine = ChromeProfileEngine.shared
            let isBrowser = app.bundleID == profileEngine.browserBundleID ||
                            ChromeProfileEngine.supportedBrowsers.contains(where: { $0.bundleID == app.bundleID })
            if isBrowser, let prof = ChromeSwitcherState.shared.selectedProfile {
                announcementText = "\(app.name), \(prof.effectiveName)"
            } else {
                announcementText = app.name
            }
        } else {
            announcementText = "Quick Switcher"
        }
        
        NSAccessibility.post(
            element: NSApp as Any,
            notification: .announcementRequested,
            userInfo: [.announcement: announcementText]
        )
    }
    
    public func updateSelection(to index: Int) {
        ChromeSwitcherState.shared.selectIndex(index)
        triggerSensoryFeedback()
    }
    
    public func selectChromeProfile(index: Int) {
        ChromeSwitcherState.shared.selectChromeProfile(index: index)
        triggerSensoryFeedback()
    }
    
    public func selectNext() {
        ChromeSwitcherState.shared.selectNext()
        triggerSensoryFeedback()
    }
    
    public func selectPrevious() {
        ChromeSwitcherState.shared.selectPrevious()
        triggerSensoryFeedback()
    }
    
    public func selectNextCard() {
        ChromeSwitcherState.shared.selectNextCard()
        triggerSensoryFeedback()
    }
    
    public func selectPreviousCard() {
        ChromeSwitcherState.shared.selectPreviousCard()
        triggerSensoryFeedback()
    }
    
    public func hideImmediate() {
        ChromeSwitcherState.shared.isVisible = false
        self.orderOut(nil)
        self.alphaValue = 1.0
    }

}

