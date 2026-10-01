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
        let avatarSize: CGFloat = isLarge ? 28 : 20
        let ringSize: CGFloat = isLarge ? 32 : 24
        let colWidth: CGFloat = isLarge ? 32 : 24
        
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
                                .font(.system(size: isLarge ? 12 : 9, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                
                // Active white glowing selection ring (matching CRT bezel aesthetic)
                if isSelected {
                    Circle()
                        .stroke(Color.white, lineWidth: 2.2)
                        .frame(width: ringSize, height: ringSize)
                        .shadow(color: Color.white.opacity(0.65), radius: 3)
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.75)
                        .frame(width: ringSize - 2, height: ringSize - 2)
                }
            }
            .frame(width: ringSize, height: ringSize)
            
            Text("\(slotIndex)")
                .font(.system(size: isLarge ? 11 : 9, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : .white.opacity(0.68))
                .shadow(color: Color.black.opacity(0.25), radius: 1, y: 1)
        }
        .frame(width: colWidth)
        .padding(.vertical, 2)
        .background {
            if isSelected {
                if let ns = namespace {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.24), lineWidth: 0.75)
                        )
                        .matchedGeometryEffect(id: "activeSlotCapsule", in: ns)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.24), lineWidth: 0.75)
                        )
                }
            }
        }
        .scaleEffect(isSelected ? 1.05 : 0.96)
        .animation(XomskyMotion.magneticGlide, value: isSelected)
    }
}

// MARK: - Antigravity App Avatar View
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
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.22),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 32, height: 32)
                
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
                
                Circle()
                    .stroke(
                        Color.white.opacity(isSelected ? 0.35 : 0.12),
                        lineWidth: 1
                    )
                    .frame(width: 34, height: 34)
            }
            .frame(width: 36, height: 36)
            
            Text("\(slotIndex)")
                .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                .foregroundColor(isSelected ? .white : .white.opacity(0.68))
                .shadow(color: Color.black.opacity(0.25), radius: 1, y: 1)
        }
        .frame(width: 44)
        .padding(.vertical, 4)
        .background {
            if isSelected {
                if let ns = namespace {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.24), lineWidth: 0.75)
                        )
                        .matchedGeometryEffect(id: "activeSlotCapsule", in: ns)
                } else {
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.24), lineWidth: 0.75)
                        )
                }
            }
        }
        .scaleEffect(isSelected ? 1.05 : 0.96)
        .animation(XomskyMotion.magneticGlide, value: isSelected)
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
                // In single card mode, show active profile pill badge
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
                }
                
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
                let step: CGFloat = 3.5
                let count = Int(size.height / step)
                for i in 0..<count {
                    let y = CGFloat(i) * step
                    let lineRect = CGRect(x: 0, y: y, width: size.width, height: 1.0)
                    context.fill(Path(lineRect), with: .color(Color.black.opacity(0.045)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Retro VHS Tape Recording OSD Badge
public struct VHSRecordingBadgeView: View {
    @State private var isBlinking = false
    
    public init() {}
    
    public var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(red: 0.95, green: 0.22, blue: 0.22))
                .frame(width: 6, height: 6)
                .shadow(color: Color(red: 0.95, green: 0.22, blue: 0.22).opacity(isBlinking ? 0.9 : 0.2), radius: 3)
                .opacity(isBlinking ? 1.0 : 0.25)
            
            Text("REC")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.88))
                .shadow(color: Color.black.opacity(0.35), radius: 1, y: 1)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isBlinking = true
            }
        }
    }
}

// MARK: - Modern Switcher HUD View
public struct MinimalHUDView: View {
    @ObservedObject var state = ChromeSwitcherState.shared
    @Namespace private var selectionNamespace
    
    public init() {}
    
    private func isBrowser(_ item: AntigravityItem) -> Bool {
        let browserBundleID = ChromeProfileEngine.shared.browserBundleID
        if item.bundleID == browserBundleID { return true }
        return ChromeProfileEngine.supportedBrowsers.contains(where: { b in b.bundleID == item.bundleID })
    }
    
    private var hasRowProfiles: Bool {
        if state.mode == .chrome {
            return !state.profiles.isEmpty
        }
        return state.antigravityItems.contains(where: { isBrowser($0) }) && !state.profiles.isEmpty
    }
    
    private var isSingleCard: Bool {
        state.mode == .chrome || state.antigravityItems.count <= 1
    }
    
    @ViewBuilder
    private var cardsContent: some View {
        let rowHasProfiles = hasRowProfiles
        let single = isSingleCard
        if state.mode == .chrome {
            HUDCardView(
                name: ChromeProfileEngine.shared.activeBrowserName,
                icon: ChromeProfileEngine.shared.activeBrowserIcon,
                isSelected: true,
                isBrowser: true,
                profiles: state.profiles,
                selectedProfileIndex: state.selectedProfileIndex,
                hasRowProfiles: rowHasProfiles,
                isSingleCard: single,
                namespace: selectionNamespace
            )
        } else if !state.antigravityItems.isEmpty {
            ForEach(Array(state.antigravityItems.enumerated()), id: \.element.id) { cardIdx, item in
                let browser = isBrowser(item)
                HUDCardView(
                    name: item.name,
                    icon: item.icon,
                    isSelected: cardIdx == state.selectedIndex,
                    isBrowser: browser,
                    profiles: browser ? state.profiles : [],
                    selectedProfileIndex: state.selectedProfileIndex,
                    hasRowProfiles: rowHasProfiles,
                    isSingleCard: single,
                    namespace: selectionNamespace
                )
            }
        } else {
            HUDCardView(
                name: "Application",
                icon: NSWorkspace.shared.icon(for: .application),
                isSelected: true,
                isBrowser: false,
                profiles: [],
                selectedProfileIndex: 0,
                hasRowProfiles: false,
                isSingleCard: true,
                namespace: selectionNamespace
            )
        }
    }
    
    public var body: some View {
        ZStack {
            HStack(spacing: isSingleCard ? 0 : 14) {
                cardsContent
            }
            .padding(.horizontal, isSingleCard ? 20 : 22)
            .padding(.vertical, isSingleCard ? 20 : 18)
            .background(
                ZStack {
                    // 1. Frosted ultra-thin material for native macOS glass blur
                    KinescopeShape(cornerRadius: 32, bulge: 7)
                        .fill(.ultraThinMaterial)
                    
                    // 2. Tactile CRT Gray Translucent Base (matching screenshot aesthetic)
                    KinescopeShape(cornerRadius: 32, bulge: 7)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.82, green: 0.82, blue: 0.84).opacity(0.88),
                                    Color(red: 0.76, green: 0.76, blue: 0.78).opacity(0.92)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // 3. Phosphor Aperture Grille Scanlines
                    CRTScanlinesView()
                        .clipShape(KinescopeShape(cornerRadius: 32, bulge: 7))
                    
                    // 4. Convex Kinescope Face Lighting (Radial specular highlight across upper curved glass)
                    KinescopeShape(cornerRadius: 32, bulge: 7)
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.30),
                                    Color.white.opacity(0.08),
                                    Color.clear
                                ]),
                                center: UnitPoint(x: 0.5, y: 0.12),
                                startRadius: 0,
                                endRadius: 220
                            )
                        )
                    
                    // 5. Subtle CRT phosphor tube vignette & bottom depth
                    KinescopeShape(cornerRadius: 32, bulge: 7)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.black.opacity(0.14)
                                ],
                                startPoint: .center,
                                endPoint: .bottom
                            )
                        )
                }
                .clipShape(KinescopeShape(cornerRadius: 32, bulge: 7))
            )
            .overlay(
                // Curved Outer Kinescope Bezel Rim (Dual-tone lighting: specular on top, dark at bottom)
                KinescopeShape(cornerRadius: 32, bulge: 7)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.75),
                                Color.white.opacity(0.35),
                                Color.black.opacity(0.15),
                                Color.black.opacity(0.40)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.25
                    )
            )
            // VHS Cassette Recording OSD (Top Left: ● REC)
            .overlay(alignment: .topLeading) {
                VHSRecordingBadgeView()
                    .padding(.top, isSingleCard ? 16 : 14)
                    .padding(.leading, isSingleCard ? 24 : 20)
            }
            // VHS Tape Play Speed OSD (Top Right: SP)
            .overlay(alignment: .topTrailing) {
                Text("SP")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.68))
                    .shadow(color: Color.black.opacity(0.35), radius: 1, y: 1)
                    .padding(.top, isSingleCard ? 16 : 14)
                    .padding(.trailing, isSingleCard ? 24 : 20)
            }
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
            // Convex 3D drop shadow (ambient + deep directional)
            .shadow(color: Color.black.opacity(0.32), radius: 26, x: 0, y: 14)
            .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 3)
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

