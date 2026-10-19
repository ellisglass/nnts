import Cocoa
import AppKit
import SwiftUI

// MARK: - CRT Color Theme (ArtistManagement Neon Violet-Pink Reference)
public enum CRTTheme {
    /// Authentic neon violet-pink contour / accent color from _ArtistManagement artwork
    public static let neonVioletPink = Color(red: 0.96, green: 0.20, blue: 0.78)
    public static let electricMagenta = Color(red: 0.98, green: 0.24, blue: 0.85)
    public static let deepViolet = Color(red: 0.82, green: 0.16, blue: 0.92)
    
    /// CRT phosphor green trace line on the outer left edge
    public static let phosphorGreen = Color(red: 0.22, green: 0.98, blue: 0.35)
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
            // 0. Dark Smoke Base Tint (anchors deep obsidian tone, stops background text bleed-through)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(red: 0.11, green: 0.12, blue: 0.15).opacity(0.88))
            
            // 1. Native macOS Behind-Window Visual Effect (dynamic desktop/window sampling blur)
            VisualEffectBlur(material: material, blendingMode: .behindWindow, state: .active, cornerRadius: cornerRadius)
                .opacity(0.65)
            
            // 2. Liquid Glass Translucent Luminous Sheen (subtle top specular highlight)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.12), location: 0.0),
                            .init(color: Color.white.opacity(0.04), location: 0.28),
                            .init(color: Color.clear, location: 0.60),
                            .init(color: Color.white.opacity(0.05), location: 1.0)
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
                            .init(color: Color.white.opacity(0.14), location: 0.0),
                            .init(color: Color.white.opacity(0.04), location: 0.20),
                            .init(color: Color.clear, location: 0.45)
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
                                Color.white.opacity(0.10),
                                Color.white.opacity(0.02),
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
                            .init(color: Color.white.opacity(0.40), location: 0.0),
                            .init(color: Color.white.opacity(0.18), location: 0.25),
                            .init(color: Color.white.opacity(0.06), location: 0.60),
                            .init(color: Color.white.opacity(0.20), location: 1.0)
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
                            .init(color: Color(red: 0.70, green: 0.88, blue: 1.0).opacity(0.45), location: 0.0),
                            .init(color: Color.white.opacity(0.35), location: 0.18),
                            .init(color: Color.white.opacity(0.12), location: 0.50),
                            .init(color: Color(red: 0.88, green: 0.72, blue: 1.0).opacity(0.30), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        // 7. Multi-layered Floating Glass Elevation Shadow
        .shadow(color: Color.black.opacity(0.35), radius: 32, x: 0, y: 16)
        .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 3)
    }
}

extension View {
    public func macNativeLiquidGlass(cornerRadius: CGFloat = 28, material: NSVisualEffectView.Material = .popover) -> some View {
        self.background(
            MacNativeLiquidGlassBackground(cornerRadius: cornerRadius, material: material)
        )
    }
}
