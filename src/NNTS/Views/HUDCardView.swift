import Cocoa
import AppKit
import SwiftUI

// MARK: - Profile Color Palette
public enum ProfileColorPalette {
    public static func gradient(for key: String) -> LinearGradient {
        let palettes: [[Color]] = [
            [NNTSColors.cobaltBlue, Color(red: 0.40, green: 0.25, blue: 0.75)], // Cobalt / Violet
            [Color(red: 0.08, green: 0.45, blue: 0.42), Color(red: 0.15, green: 0.65, blue: 0.55)], // Deep Teal / Emerald
            [Color(red: 0.82, green: 0.35, blue: 0.15), Color(red: 0.95, green: 0.55, blue: 0.20)], // Vermilion / Amber
            [Color(red: 0.18, green: 0.28, blue: 0.58), Color(red: 0.22, green: 0.52, blue: 0.85)], // Indigo / Sky
            [Color(red: 0.58, green: 0.15, blue: 0.45), Color(red: 0.82, green: 0.25, blue: 0.55)], // Plum / Rose
            [Color(red: 0.25, green: 0.45, blue: 0.20), Color(red: 0.42, green: 0.68, blue: 0.32)]  // Forest / Lime
        ]
        let hash = abs(key.unicodeScalars.reduce(0) { ($0 << 5) &+ $0 &+ Int($1.value) })
        let palette = palettes[hash % palettes.count]
        return LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: - Profile Avatar View
public struct ProfileAvatarView: View {
    public let profile: ChromeProfile
    public let isSelected: Bool
    public let slotIndex: Int
    public let isLarge: Bool
    public let isCompact: Bool
    public let showBadge: Bool
    public let isCurrentActive: Bool
    public var namespace: Namespace.ID?
    
    public init(
        profile: ChromeProfile,
        isSelected: Bool,
        slotIndex: Int = 0,
        isLarge: Bool = false,
        isCompact: Bool = false,
        showBadge: Bool = false,
        isCurrentActive: Bool = false,
        namespace: Namespace.ID? = nil
    ) {
        self.profile = profile
        self.isSelected = isSelected
        self.slotIndex = slotIndex > 0 ? slotIndex : profile.index
        self.isLarge = isLarge
        self.isCompact = isCompact
        self.showBadge = showBadge
        self.isCurrentActive = isCurrentActive
        self.namespace = namespace
    }
    
    public var body: some View {
        let avatarSize: CGFloat = isLarge ? 62 : (isCompact ? 36 : 48)
        let ringSize: CGFloat = isLarge ? 70 : (isCompact ? 42 : 54)
        let colWidth: CGFloat = isLarge ? 70 : (isCompact ? 42 : 54)
        
        let badgeSize: CGFloat = isLarge ? 20 : (isCompact ? 16 : 18)
        let pipSize: CGFloat = isLarge ? 8 : (isCompact ? 6 : 7)
        
        VStack(spacing: 0) {
            ZStack {
                // 1. Soft depth backing
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
                
                // 2. Avatar Image or Deterministic Monogram
                if let avatar = profile.avatarImage {
                    Image(nsImage: avatar)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(ProfileColorPalette.gradient(for: profile.dir + profile.effectiveName))
                        .frame(width: avatarSize, height: avatarSize)
                        .overlay(
                            Text(String(profile.effectiveName.prefix(profile.effectiveName.count > 2 ? 2 : 1)).uppercased())
                                .font(NNTSFont.display(size: isLarge ? 20 : (isCompact ? 12 : 15)))
                                .foregroundColor(.white)
                                .shadow(color: Color.black.opacity(0.4), radius: 2, y: 1)
                        )
                }
                
                // 3. Selection Ring (Matched Geometry or Static Fallback)
                if isSelected {
                    if let ns = namespace {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white, NNTSColors.cadmiumYellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isLarge ? 2.8 : 2.2
                            )
                            .frame(width: ringSize, height: ringSize)
                            .shadow(color: NNTSColors.cadmiumYellow.opacity(0.85), radius: 8, x: 0, y: 0)
                            .shadow(color: NNTSColors.cobaltBlue.opacity(0.40), radius: 10, x: 0, y: 0)
                            .matchedGeometryEffect(id: "active_profile_cursor", in: ns)
                    } else {
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [Color.white, NNTSColors.cadmiumYellow],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: isLarge ? 2.8 : 2.2
                            )
                            .frame(width: ringSize, height: ringSize)
                            .shadow(color: NNTSColors.cadmiumYellow.opacity(0.85), radius: 8, x: 0, y: 0)
                            .shadow(color: NNTSColors.cobaltBlue.opacity(0.40), radius: 10, x: 0, y: 0)
                    }
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.20), lineWidth: 1.0)
                        .frame(width: ringSize - 2, height: ringSize - 2)
                }
                
                // 4. Current Window Status Pip (Apple Emerald LED at Top-Right)
                if isCurrentActive {
                    Circle()
                        .fill(NNTSColors.appleEmerald)
                        .frame(width: pipSize, height: pipSize)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.black.opacity(0.7), lineWidth: 1.0)
                        )
                        .shadow(color: NNTSColors.appleEmerald.opacity(0.9), radius: 3, x: 0, y: 0)
                        .offset(x: (ringSize / 2) - (pipSize * 0.6), y: -((ringSize / 2) - (pipSize * 0.6)))
                }
                
                // 5. Hotkey Slot Keycap Badge (at Bottom-Right)
                if showBadge {
                    ZStack {
                        RoundedRectangle(cornerRadius: badgeSize * 0.35, style: .continuous)
                            .fill(isSelected ? NNTSColors.cadmiumYellow : Color(red: 0.12, green: 0.13, blue: 0.17).opacity(0.92))
                        
                        RoundedRectangle(cornerRadius: badgeSize * 0.35, style: .continuous)
                            .strokeBorder(
                                isSelected ? Color.white.opacity(0.8) : Color.white.opacity(0.35),
                                lineWidth: 0.8
                            )
                        
                        Text("\(slotIndex)")
                            .font(NNTSFont.slotDigit(size: isLarge ? 11.5 : (isCompact ? 9.5 : 10.5)))
                            .foregroundColor(isSelected ? NNTSColors.obsidianBase : NNTSColors.warmCream)
                    }
                    .frame(width: badgeSize, height: badgeSize)
                    .shadow(color: Color.black.opacity(0.45), radius: 2, y: 1)
                    .offset(x: (ringSize / 2) - (badgeSize * 0.45), y: (ringSize / 2) - (badgeSize * 0.45))
                }
            }
            .frame(width: ringSize, height: ringSize)
        }
        .frame(width: colWidth)
        .padding(.vertical, isCompact ? 2 : 3)
        .scaleEffect(isSelected ? 1.06 : 0.95)
        .opacity(isSelected ? 1.0 : 0.82)
        .animation(NNTSMotion.interactiveSnap, value: isSelected)
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
        .animation(NNTSMotion.magneticGlide, value: isSelected)
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
            return (isBrowser && !profiles.isEmpty) ? (profiles.count > 4 ? 280 : 240) : 190
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
                let useCompact = profiles.count > 4
                HStack(spacing: isSingleCard ? (useCompact ? 5 : 8) : 4) {
                    ForEach(Array(profiles.enumerated()), id: \.element.id) { idx, profile in
                        ProfileAvatarView(
                            profile: profile,
                            isSelected: isSelected && (idx == selectedProfileIndex),
                            slotIndex: idx + 1,
                            isLarge: isSingleCard && !useCompact,
                            isCompact: useCompact || !isSingleCard,
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
        .animation(NNTSMotion.magneticGlide, value: isSelected)
    }
}
