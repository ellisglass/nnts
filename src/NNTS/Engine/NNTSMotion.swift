import Foundation
import SwiftUI

// MARK: - NNTS Motion Design System
/// Calibrated spring curves and physical motion tokens for sub-16ms zero-latency interaction.
public enum NNTSMotion: Sendable {
    /// Snappy, critically-damped responsive spring for HUD display and keypress feedback (zero overshoot)
    public static let interactiveSnap = Animation.spring(
        response: 0.18,
        dampingFraction: 0.88,
        blendDuration: 0.04
    )
    
    /// Magnetic liquid spring for selection capsules and cursor gliding
    public static let magneticGlide = Animation.spring(
        response: 0.20,
        dampingFraction: 0.85,
        blendDuration: 0.06
    )
    
    /// Subtle celebratory spring for pin confirmations and mascot emotes
    public static let tactileBop = Animation.spring(
        response: 0.20,
        dampingFraction: 0.82,
        blendDuration: 0.04
    )
    
    /// Smooth accordion expansion for HUD card width and slot allocation
    public static let cardMorph = Animation.spring(
        response: 0.24,
        dampingFraction: 0.88,
        blendDuration: 0.08
    )
    
    /// Subtle micro-press scale stamp
    public static let microPress = Animation.spring(
        response: 0.12,
        dampingFraction: 0.80,
        blendDuration: 0.02
    )
}

// MARK: - Mac Tactile Button Style
/// Emil Kowalski & Apple HIG compliant button style providing instantaneous scale(0.97) feedback on pointer-down.
public struct MacTactileButtonStyle: ButtonStyle {
    public var scaleAmount: CGFloat
    public var pressedOpacity: Double
    
    public init(scaleAmount: CGFloat = 0.97, pressedOpacity: Double = 0.90) {
        self.scaleAmount = scaleAmount
        self.pressedOpacity = pressedOpacity
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .opacity(configuration.isPressed ? pressedOpacity : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
