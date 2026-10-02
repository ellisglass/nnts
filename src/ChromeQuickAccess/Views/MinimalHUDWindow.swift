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
    @Published public var isMascotPeeking: Bool = false
    
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
    public var namespace: Namespace.ID?
    
    public init(
        profile: ChromeProfile,
        isSelected: Bool,
        slotIndex: Int = 0,
        isLarge: Bool = false,
        namespace: Namespace.ID? = nil
    ) {
        self.profile = profile
        self.isSelected = isSelected
        self.slotIndex = slotIndex > 0 ? slotIndex : profile.index
        self.isLarge = isLarge
        self.namespace = namespace
    }
    
    public var body: some View {
        let avatarSize: CGFloat = isLarge ? 42 : 34
        let ringSize: CGFloat = isLarge ? 48 : 40
        let colWidth: CGFloat = isLarge ? 48 : 40
        
        VStack(spacing: 3) {
            ZStack {
                // Frosted light circular plate
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.38),
                                Color.white.opacity(0.24)
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
                                .font(.system(size: isLarge ? 15 : 12, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                // Active glassmorphic selection ring
                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 1.75)
                        .frame(width: ringSize, height: ringSize)
                        .shadow(color: Color.white.opacity(0.60), radius: 4, x: 0, y: 0)
                        .shadow(color: Color.black.opacity(0.35), radius: 2.5, x: 0, y: 1.5)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.24), lineWidth: 0.75)
                        .frame(width: ringSize - 2, height: ringSize - 2)
                }
            }
            .frame(width: ringSize, height: ringSize)
            
            Text("\(slotIndex)")
                .font(.system(size: isLarge ? 12 : 10, weight: isSelected ? .bold : .medium, design: .monospaced))
                .foregroundColor(isSelected ? .white : .white.opacity(0.65))
                .shadow(color: Color.black.opacity(0.45), radius: 1.5, y: 1)
        }
        .frame(width: colWidth)
        .padding(.vertical, 2.5)
        .background {
            if isSelected {
                if let ns = namespace {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.38), lineWidth: 0.75)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
                        .matchedGeometryEffect(id: "activeSlotCapsule", in: ns)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.38), lineWidth: 0.75)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
                }
            }
        }
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
                if let ns = namespace {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.white.opacity(0.38), lineWidth: 0.75)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
                        .matchedGeometryEffect(id: "activeAppChannelCapsule", in: ns)
                } else {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .stroke(Color.white.opacity(0.38), lineWidth: 0.75)
                        )
                        .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
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
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 6, x: 0, y: 3)
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


// MARK: - CRT Chromatic Aberration App Icon
public struct CRTChromaticAberrationIcon: View {
    public let icon: NSImage
    public let size: CGFloat
    
    public init(icon: NSImage, size: CGFloat = 78) {
        self.icon = icon
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Magenta / Red CRT convergence error offset
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .colorMultiply(Color(red: 1.0, green: 0.16, blue: 0.42))
                .opacity(0.42)
                .offset(x: -1.6, y: -0.6)
                .blendMode(.screen)
            
            // Cyan / Green CRT convergence error offset
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .colorMultiply(Color(red: 0.16, green: 0.95, blue: 0.85))
                .opacity(0.42)
                .offset(x: 1.6, y: 0.6)
                .blendMode(.screen)
            
            // Primary sharp icon layer with ambient shadow
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.50), radius: 6, x: 0, y: 3)
        }
        .frame(width: size + 6, height: size + 6)
    }
}

// MARK: - Visual Effect Blur (Native macOS Behind-Window Frosted Glass)
public struct VisualEffectBlur: NSViewRepresentable {
    public var material: NSVisualEffectView.Material
    public var blendingMode: NSVisualEffectView.BlendingMode
    public var state: NSVisualEffectView.State

    public init(
        material: NSVisualEffectView.Material = .popover,
        blendingMode: NSVisualEffectView.BlendingMode = .behindWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.wantsLayer = true
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
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
    
    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                
                // 1. Center Hero Display (Large App Icon with Chromatic Aberration + Title)
                VStack(spacing: 7) {
                    CRTChromaticAberrationIcon(icon: activeIcon, size: 84)
                    
                    Text(activeName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color.black.opacity(0.50), radius: 3, y: 1.5)
                        .lineLimit(1)
                }
                
                Spacer().frame(height: 16)
                
                // 2. Bottom Channel Presets Row (Apps on same letter or Chrome profiles)
                VStack(spacing: 6) {
                    HStack(spacing: 9) {
                        let isCurrentBrowser = isBrowser(state.selectedAppItem ?? AntigravityItem(name: "", bundleID: "", path: "", icon: NSImage(), index: 0))
                        if state.mode == .chrome || (!state.profiles.isEmpty && isCurrentBrowser) {
                            ForEach(Array(state.profiles.enumerated()), id: \.element.id) { idx, profile in
                                ProfileAvatarView(
                                    profile: profile,
                                    isSelected: idx == state.selectedProfileIndex,
                                    slotIndex: idx + 1,
                                    isLarge: false,
                                    namespace: selectionNamespace
                                )
                            }
                        } else if state.antigravityItems.count > 1 {
                            ForEach(Array(state.antigravityItems.enumerated()), id: \.element.id) { idx, item in
                                AppChannelItemView(
                                    item: item,
                                    isSelected: idx == state.selectedIndex,
                                    channelIndex: idx + 1,
                                    namespace: selectionNamespace
                                )
                            }
                        } else if let single = state.antigravityItems.first {
                            AppChannelItemView(
                                item: single,
                                isSelected: true,
                                channelIndex: 1,
                                namespace: selectionNamespace
                            )
                        }
                    }
                    .frame(height: 60)
                    
                    // Profile name placed directly under the profiles icons, or clear spacer to lock baseline
                    if let prof = activeProfile {
                        HStack(spacing: 4.5) {
                            Circle()
                                .fill(Color(red: 0.30, green: 0.85, blue: 0.60))
                                .frame(width: 5, height: 5)
                                .shadow(color: Color(red: 0.30, green: 0.85, blue: 0.60).opacity(0.65), radius: 2)
                            Text(prof.effectiveName)
                                .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.95))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.20))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.36), lineWidth: 0.75)
                                )
                                .shadow(color: Color.black.opacity(0.12), radius: 3, y: 1)
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        Color.clear
                            .frame(height: 20.5)
                    }
                }
                .padding(.bottom, 16)
            }
            .frame(width: Self.hudWidth, height: Self.hudHeight)
            .background(
                ZStack {
                    // 1. Native macOS Behind-Window Frosted Glass Blur
                    VisualEffectBlur(material: .popover, blendingMode: .behindWindow, state: .active)
                    
                    // 2. Frosted ultra-thin material for native macOS glass blur & vibrancy
                    KinescopeShape(cornerRadius: 34, bulge: 8)
                        .fill(.ultraThinMaterial)
                    
                    // 3. Translucent luminous liquid glass tint (lighter & brighter with true optical depth)
                    KinescopeShape(cornerRadius: 34, bulge: 8)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.18),
                                    Color(red: 0.22, green: 0.25, blue: 0.35).opacity(0.30)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // 4. Subtle phosphor aperture grille scanlines for optical texture
                    CRTScanlinesView()
                        .opacity(0.10)
                        .clipShape(KinescopeShape(cornerRadius: 34, bulge: 8))
                    
                    // 5. Diagonal Ambient Glass Gloss across face
                    KinescopeShape(cornerRadius: 34, bulge: 8)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.32), location: 0.0),
                                    .init(color: Color.white.opacity(0.12), location: 0.28),
                                    .init(color: Color.white.opacity(0.04), location: 0.52),
                                    .init(color: Color.clear, location: 0.72)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // 6. Upper bulb glass dome reflection (convex lens glare)
                    GeometryReader { geo in
                        Ellipse()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(0.28),
                                        Color.white.opacity(0.08),
                                        Color.clear
                                    ]),
                                    center: UnitPoint(x: 0.5, y: 0.0),
                                    startRadius: 0,
                                    endRadius: geo.size.width * 0.55
                                )
                            )
                            .frame(width: geo.size.width * 1.2, height: geo.size.height * 0.65)
                            .position(x: geo.size.width / 2, y: geo.size.height * 0.12)
                    }
                    
                    // 7. Top inner glass refraction rim highlight
                    KinescopeShape(cornerRadius: 34, bulge: 8)
                        .inset(by: 1.0)
                        .stroke(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(0.75), location: 0.0),
                                    .init(color: Color.white.opacity(0.30), location: 0.28),
                                    .init(color: Color.clear, location: 0.60)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1.0
                        )
                }
                .clipShape(KinescopeShape(cornerRadius: 34, bulge: 8))
            )
            .overlay(
                // Curved Outer Glass Refraction Rim (Multi-stop specular highlight and subtle shadow)
                KinescopeShape(cornerRadius: 34, bulge: 8)
                    .strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.80), location: 0.0),
                                .init(color: Color.white.opacity(0.40), location: 0.35),
                                .init(color: Color.white.opacity(0.18), location: 0.70),
                                .init(color: Color.white.opacity(0.35), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.25
                    )
            )
            .overlay(
                // CRT phosphor green vector arc trace strictly along the outer left edge
                CRTVectorArcView()
                    .opacity(0.55)
            )
            .overlay(alignment: .top) {
                if state.isMascotPeeking {
                    Image(nsImage: AppDelegate.makeMascotStatusIcon())
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .offset(y: -14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // Multi-layered floating glass drop shadow
            .shadow(color: Color.black.opacity(0.25), radius: 28, x: 0, y: 14)
            .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 3)
            .shadow(color: Color.white.opacity(0.15), radius: 1, x: 0, y: -0.5)
            .scaleEffect(state.isVisible ? 1.0 : 0.93)
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
    private var peekTask: Task<Void, Never>?
    
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
    
    private func resetAndSchedulePeek() {
        peekTask?.cancel()
        ChromeSwitcherState.shared.isMascotPeeking = false
        peekTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled, let _ = self, ChromeSwitcherState.shared.isVisible else { return }
            withAnimation(XomskyMotion.tactileBop) {
                ChromeSwitcherState.shared.isMascotPeeking = true
            }
        }
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
        resetAndSchedulePeek()
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
        resetAndSchedulePeek()
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
        // Deterministic window sizing: 880pt width x 380pt height accommodates up to 5 cards
        // plus margins to cleanly contain the drop shadow without clipping.
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
        // 1. Tactile haptic feedback on Force Touch trackpads
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .default
        )
        
        // 2. VoiceOver announcement
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
        peekTask?.cancel()
        if ChromeSwitcherState.shared.isMascotPeeking {
            withAnimation(XomskyMotion.interactiveSnap) {
                ChromeSwitcherState.shared.isMascotPeeking = false
            }
        }
        ChromeSwitcherState.shared.selectIndex(index)
        triggerSensoryFeedback()
    }
    
    public func selectChromeProfile(index: Int) {
        peekTask?.cancel()
        if ChromeSwitcherState.shared.isMascotPeeking {
            withAnimation(XomskyMotion.interactiveSnap) {
                ChromeSwitcherState.shared.isMascotPeeking = false
            }
        }
        ChromeSwitcherState.shared.selectChromeProfile(index: index)
        triggerSensoryFeedback()
    }
    
    public func selectNext() {
        peekTask?.cancel()
        if ChromeSwitcherState.shared.isMascotPeeking {
            withAnimation(XomskyMotion.interactiveSnap) {
                ChromeSwitcherState.shared.isMascotPeeking = false
            }
        }
        ChromeSwitcherState.shared.selectNext()
        triggerSensoryFeedback()
    }
    
    public func selectPrevious() {
        peekTask?.cancel()
        if ChromeSwitcherState.shared.isMascotPeeking {
            withAnimation(XomskyMotion.interactiveSnap) {
                ChromeSwitcherState.shared.isMascotPeeking = false
            }
        }
        ChromeSwitcherState.shared.selectPrevious()
        triggerSensoryFeedback()
    }
    
    public func selectNextCard() {
        peekTask?.cancel()
        if ChromeSwitcherState.shared.isMascotPeeking {
            withAnimation(XomskyMotion.interactiveSnap) {
                ChromeSwitcherState.shared.isMascotPeeking = false
            }
        }
        ChromeSwitcherState.shared.selectNextCard()
        triggerSensoryFeedback()
    }
    
    public func selectPreviousCard() {
        peekTask?.cancel()
        if ChromeSwitcherState.shared.isMascotPeeking {
            withAnimation(XomskyMotion.interactiveSnap) {
                ChromeSwitcherState.shared.isMascotPeeking = false
            }
        }
        ChromeSwitcherState.shared.selectPreviousCard()
        triggerSensoryFeedback()
    }
    
    public func hideImmediate() {
        peekTask?.cancel()
        peekTask = nil
        ChromeSwitcherState.shared.isMascotPeeking = false
        ChromeSwitcherState.shared.isVisible = false
        self.orderOut(nil)
        self.alphaValue = 1.0
    }
}

