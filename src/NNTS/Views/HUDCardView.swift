import Cocoa
import AppKit
import SwiftUI

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
        .animation(NNTSMotion.magneticGlide, value: isSelected)
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
