import Foundation
import SwiftUI

// MARK: - NNTS Motion Design System
/// Calibrated spring curves and physical motion tokens for sub-16ms zero-latency interaction.
public enum NNTSMotion: Sendable {
    /// Snappy, sub-16ms responsive spring for HUD display and keypress feedback
    public static let interactiveSnap = Animation.spring(
        response: 0.18,
        dampingFraction: 0.72,
        blendDuration: 0.05
    )
    
    /// Magnetic liquid spring for selection capsules and cursor gliding
    public static let magneticGlide = Animation.spring(
        response: 0.22,
        dampingFraction: 0.82,
        blendDuration: 0.08
    )
    
    /// Bouncy celebratory spring for pin confirmations and mascot emotes
    public static let tactileBop = Animation.spring(
        response: 0.28,
        dampingFraction: 0.58,
        blendDuration: 0.0
    )
    
    /// Smooth accordion expansion for HUD card width and slot allocation
    public static let cardMorph = Animation.spring(
        response: 0.24,
        dampingFraction: 0.85,
        blendDuration: 0.10
    )
    
    /// Subtle micro-press scale stamp
    public static let microPress = Animation.spring(
        response: 0.12,
        dampingFraction: 0.65,
        blendDuration: 0.02
    )
}

public typealias XomskyMotion = NNTSMotion

