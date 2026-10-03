import Cocoa
import AppKit

// MARK: - 1. Drawing Engine: 2D Bauhaus Hamster Mascot
// Based directly on AppDelegate.makeKhomyakStatusIcon() with adaptive LOD (level of detail)

func drawBauhausHamster(in rect: CGRect, cg: CGContext, isMiniLOD: Bool = false) {
    let s = rect.width / 32.0
    cg.saveGState()
    cg.translateBy(x: rect.origin.x, y: rect.origin.y)
    cg.scaleBy(x: s, y: s)

    let cYellow = NSColor(red: 0.965, green: 0.737, blue: 0.078, alpha: 1.0).cgColor // #F6BC14 (Cadmium Yellow)
    let cCream = NSColor(red: 1.0, green: 0.98, blue: 0.92, alpha: 1.0).cgColor       // Warm Cream
    let cDark = NSColor(red: 0.086, green: 0.106, blue: 0.149, alpha: 1.0).cgColor   // #161B26 (Obsidian Dark)
    let cRed = NSColor(red: 0.902, green: 0.224, blue: 0.275, alpha: 1.0).cgColor    // #E63946 (Vermilion Red)
    let cWhite = NSColor.white.cgColor

    cg.setLineCap(.round)
    cg.setLineJoin(.round)

    func Y(_ y: CGFloat) -> CGFloat { 32.0 - y }

    if isMiniLOD {
        let cPeach = NSColor(red: 0.996, green: 0.843, blue: 0.667, alpha: 1.0).cgColor  // #FED7AA
        
        // 1. Ears (clean circles, no heavy strokes)
        func drawMiniEar(cx: CGFloat, svgY: CGFloat) {
            let cy = Y(svgY)
            cg.setFillColor(cYellow)
            cg.addEllipse(in: CGRect(x: cx - 4.5, y: cy - 4.5, width: 9.0, height: 9.0))
            cg.fillPath()

            cg.setFillColor(cPeach)
            cg.addEllipse(in: CGRect(x: cx - 2.3, y: cy - 2.3, width: 4.6, height: 4.6))
            cg.fillPath()
        }
        drawMiniEar(cx: 7.5, svgY: 7.5)
        drawMiniEar(cx: 24.5, svgY: 7.5)

        // 2. Head & Cheek Lobes (solid clean yellow geons)
        cg.setFillColor(cYellow)
        cg.addEllipse(in: CGRect(x: 9.5 - 7.0, y: Y(17.0) - 7.0, width: 14.0, height: 14.0))
        cg.fillPath()
        cg.addEllipse(in: CGRect(x: 22.5 - 7.0, y: Y(17.0) - 7.0, width: 14.0, height: 14.0))
        cg.fillPath()

        let headBox = CGRect(x: 6.0, y: Y(23.5), width: 20.0, height: 15.0)
        let headPath = CGPath(roundedRect: headBox, cornerWidth: 6.5, cornerHeight: 6.5, transform: nil)
        cg.addPath(headPath)
        cg.fillPath()

        // 3. White Snout / Cheeks
        cg.setFillColor(cWhite)
        cg.addEllipse(in: CGRect(x: 16.0 - 6.8, y: Y(19.5) - 4.8, width: 13.6, height: 9.6))
        cg.fillPath()

        // 4. Two Focal Dot Eyes (Obsidian + clean glint)
        func drawMiniEye(cx: CGFloat, svgY: CGFloat, gx: CGFloat, svgGY: CGFloat) {
            let cy = Y(svgY)
            let gy = Y(svgGY)

            cg.setFillColor(cDark)
            cg.addEllipse(in: CGRect(x: cx - 2.4, y: cy - 2.4, width: 4.8, height: 4.8))
            cg.fillPath()

            cg.setFillColor(cWhite)
            cg.addEllipse(in: CGRect(x: gx - 0.8, y: gy - 0.8, width: 1.6, height: 1.6))
            cg.fillPath()
        }
        drawMiniEye(cx: 10.8, svgY: 14.0, gx: 11.5, svgGY: 13.3)
        drawMiniEye(cx: 21.2, svgY: 14.0, gx: 21.9, svgGY: 13.3)

        // 5. Red Nose Apex
        let nose = CGMutablePath()
        nose.move(to: CGPoint(x: 14.2, y: Y(17.2)))
        nose.addLine(to: CGPoint(x: 17.8, y: Y(17.2)))
        nose.addLine(to: CGPoint(x: 16.0, y: Y(19.4)))
        nose.closeSubpath()
        cg.addPath(nose)
        cg.setFillColor(cRed)
        cg.fillPath()

        cg.restoreGState()
        return
    }

    // 1. Ears
    func drawEar(cx: CGFloat, svgY: CGFloat) {
        let cy = Y(svgY)
        cg.setFillColor(cYellow)
        cg.setStrokeColor(cDark)
        cg.setLineWidth(1.4)
        cg.addEllipse(in: CGRect(x: cx - 4.2, y: cy - 4.2, width: 8.4, height: 8.4))
        cg.drawPath(using: .fillStroke)

        cg.setFillColor(cCream)
        cg.setStrokeColor(cDark)
        cg.setLineWidth(0.8)
        cg.addEllipse(in: CGRect(x: cx - 2.2, y: cy - 2.2, width: 4.4, height: 4.4))
        cg.drawPath(using: .fillStroke)
    }
    drawEar(cx: 7.5, svgY: 7.5)
    drawEar(cx: 24.5, svgY: 7.5)

    // 2. Cheek Lobes (Backing)
    cg.setFillColor(cYellow)
    cg.setStrokeColor(cDark)
    cg.setLineWidth(1.4)
    cg.addEllipse(in: CGRect(x: 9.0 - 6.2, y: Y(16.5) - 6.2, width: 12.4, height: 12.4))
    cg.drawPath(using: .fillStroke)
    cg.addEllipse(in: CGRect(x: 23.0 - 6.2, y: Y(16.5) - 6.2, width: 12.4, height: 12.4))
    cg.drawPath(using: .fillStroke)

    // 3. Head Center Fill
    let head = CGMutablePath()
    head.move(to: CGPoint(x: 9, y: Y(10)))
    head.addCurve(to: CGPoint(x: 23, y: Y(10)), control1: CGPoint(x: 13, y: Y(8.5)), control2: CGPoint(x: 19, y: Y(8.5)))
    head.addCurve(to: CGPoint(x: 26.5, y: Y(18)), control1: CGPoint(x: 25.5, y: Y(12)), control2: CGPoint(x: 26.5, y: Y(15)))
    head.addCurve(to: CGPoint(x: 16, y: Y(22.5)), control1: CGPoint(x: 26.5, y: Y(21)), control2: CGPoint(x: 21.5, y: Y(22.5)))
    head.addCurve(to: CGPoint(x: 5.5, y: Y(18)), control1: CGPoint(x: 10.5, y: Y(22.5)), control2: CGPoint(x: 5.5, y: Y(21)))
    head.addCurve(to: CGPoint(x: 9, y: Y(10)), control1: CGPoint(x: 5.5, y: Y(15)), control2: CGPoint(x: 6.5, y: Y(12)))
    head.closeSubpath()
    cg.addPath(head)
    cg.setFillColor(cYellow)
    cg.fillPath()

    // 4. White Muzzle
    let muzzle = CGMutablePath()
    muzzle.move(to: CGPoint(x: 12.5, y: Y(9.5)))
    muzzle.addCurve(to: CGPoint(x: 10.5, y: Y(18)), control1: CGPoint(x: 12.5, y: Y(9.5)), control2: CGPoint(x: 10.5, y: Y(14)))
    muzzle.addCurve(to: CGPoint(x: 16, y: Y(22.5)), control1: CGPoint(x: 10.5, y: Y(21.5)), control2: CGPoint(x: 13, y: Y(22.5)))
    muzzle.addCurve(to: CGPoint(x: 21.5, y: Y(18)), control1: CGPoint(x: 19, y: Y(22.5)), control2: CGPoint(x: 21.5, y: Y(21.5)))
    muzzle.addCurve(to: CGPoint(x: 19.5, y: Y(9.5)), control1: CGPoint(x: 21.5, y: Y(14)), control2: CGPoint(x: 19.5, y: Y(9.5)))
    muzzle.closeSubpath()
    cg.addPath(muzzle)
    cg.setFillColor(cWhite)
    cg.fillPath()

    // 5. Concentric Eyes (Full Scale)
    func drawEye(cx: CGFloat, svgY: CGFloat, gx: CGFloat, svgGY: CGFloat) {
        let cy = Y(svgY)
        let gy = Y(svgGY)

        // Full 3-layer Bauhaus concentric eye
        cg.setFillColor(cWhite)
        cg.setStrokeColor(cDark)
        cg.setLineWidth(1.3)
        cg.addEllipse(in: CGRect(x: cx - 4.2, y: cy - 4.2, width: 8.4, height: 8.4))
        cg.drawPath(using: .fillStroke)

        cg.setFillColor(cWhite)
        cg.setStrokeColor(cDark)
        cg.setLineWidth(0.9)
        cg.addEllipse(in: CGRect(x: cx - 3.0, y: cy - 3.0, width: 6.0, height: 6.0))
        cg.drawPath(using: .fillStroke)

        cg.setFillColor(cDark)
        cg.addEllipse(in: CGRect(x: cx - 1.9, y: cy - 1.9, width: 3.8, height: 3.8))
        cg.fillPath()

        cg.setFillColor(cWhite)
        cg.addEllipse(in: CGRect(x: gx - 0.7, y: gy - 0.7, width: 1.4, height: 1.4))
        cg.fillPath()
    }
    drawEye(cx: 11.2, svgY: 13.8, gx: 12.0, svgGY: 13.0)
    drawEye(cx: 20.8, svgY: 13.8, gx: 21.6, svgGY: 13.0)

    // 6. Red Inverted Triangle Nose
    let nose = CGMutablePath()
    nose.move(to: CGPoint(x: 14.1, y: Y(16.8)))
    nose.addLine(to: CGPoint(x: 17.9, y: Y(16.8)))
    nose.addLine(to: CGPoint(x: 16.0, y: Y(19.2)))
    nose.closeSubpath()
    cg.addPath(nose)
    cg.setFillColor(cRed)
    cg.setStrokeColor(cDark)
    cg.setLineWidth(0.6)
    cg.drawPath(using: .fillStroke)

    // 7. Mouth W
    let mouth = CGMutablePath()
    mouth.move(to: CGPoint(x: 13.8, y: Y(20.0)))
    mouth.addCurve(to: CGPoint(x: 16.0, y: Y(20.0)), control1: CGPoint(x: 14.6, y: Y(20.8)), control2: CGPoint(x: 15.4, y: Y(20.8)))
    mouth.addCurve(to: CGPoint(x: 18.2, y: Y(20.0)), control1: CGPoint(x: 16.6, y: Y(20.8)), control2: CGPoint(x: 17.4, y: Y(20.8)))
    cg.addPath(mouth)
    cg.setStrokeColor(cDark)
    cg.setLineWidth(1.0)
    cg.strokePath()

    // 8. Paws
    func drawPaw(cx: CGFloat, svgY: CGFloat) {
        let cy = Y(svgY)
        cg.setFillColor(cWhite)
        cg.setStrokeColor(cDark)
        cg.setLineWidth(1.1)
        cg.addEllipse(in: CGRect(x: cx - 2.5, y: cy - 2.5, width: 5.0, height: 5.0))
        cg.drawPath(using: .fillStroke)

        cg.setFillColor(cRed)
        cg.addEllipse(in: CGRect(x: cx - 0.8 - 0.35, y: cy - 1.0 - 0.35, width: 0.7, height: 0.7))
        cg.addEllipse(in: CGRect(x: cx - 0.35, y: cy - 1.3 - 0.35, width: 0.7, height: 0.7))
        cg.addEllipse(in: CGRect(x: cx + 0.8 - 0.35, y: cy - 1.0 - 0.35, width: 0.7, height: 0.7))
        cg.fillPath()
    }
    drawPaw(cx: 12.8, svgY: 22.8)
    drawPaw(cx: 19.2, svgY: 22.8)

    cg.restoreGState()
}

// MARK: - 2. macOS AppIcon Canvas Generator (Standard Apple HIG Squircle)
func renderMacAppIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
        guard let cg = NSGraphicsContext.current?.cgContext else { return false }

        let margin = s * (100.0 / 1024.0)
        let squircleRect = rect.insetBy(dx: margin, dy: margin)
        let cornerRadius = squircleRect.width * (185.0 / 824.0)

        // Drop shadow under the squircle
        cg.saveGState()
        let shadowBlur = s * (32.0 / 1024.0)
        let shadowOffset = CGSize(width: 0, height: -s * (16.0 / 1024.0))
        cg.setShadow(offset: shadowOffset, blur: shadowBlur, color: NSColor(white: 0, alpha: 0.28).cgColor)

        let path = NSBezierPath(roundedRect: squircleRect, xRadius: cornerRadius, yRadius: cornerRadius)
        NSColor(red: 0.985, green: 0.985, blue: 0.992, alpha: 1.0).setFill()
        path.fill()
        cg.restoreGState()

        // Subtle inner rim
        cg.saveGState()
        let rimPath = NSBezierPath(roundedRect: squircleRect.insetBy(dx: 1, dy: 1), xRadius: cornerRadius - 1, yRadius: cornerRadius - 1)
        NSColor(white: 1.0, alpha: 0.8).setStroke()
        rimPath.lineWidth = s * (2.0 / 1024.0)
        rimPath.stroke()

        NSColor(white: 0.82, alpha: 0.8).setStroke()
        path.lineWidth = s * (1.5 / 1024.0)
        path.stroke()
        cg.restoreGState()

        let mascotInset = s * (195.0 / 1024.0)
        let mascotYOffset = s * (10.0 / 1024.0)
        let mascotRect = CGRect(x: mascotInset, y: mascotInset + mascotYOffset, width: s - mascotInset * 2, height: s - mascotInset * 2)

        cg.saveGState()
        let contactShadowRect = CGRect(x: mascotRect.midX - mascotRect.width * 0.35,
                                       y: mascotRect.minY + mascotRect.height * 0.05,
                                       width: mascotRect.width * 0.70,
                                       height: mascotRect.height * 0.12)
        let contactShadow = CGPath(ellipseIn: contactShadowRect, transform: nil)
        cg.addPath(contactShadow)
        cg.setFillColor(NSColor(red: 0.82, green: 0.80, blue: 0.75, alpha: 0.35).cgColor)
        cg.fillPath()
        cg.restoreGState()

        drawBauhausHamster(in: mascotRect, cg: cg, isMiniLOD: size <= 32)
        return true
    }
    return img
}

// MARK: - 3. Favicon Generator (Standalone Vector Mask without outer squircle for maximum pixel punch)
func renderFavicon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s), flipped: false) { rect in
        guard let cg = NSGraphicsContext.current?.cgContext else { return false }
        let pad = s <= 16 ? 0.5 : (s <= 32 ? 1.0 : 4.0)
        let mascotRect = rect.insetBy(dx: pad, dy: pad)
        drawBauhausHamster(in: mascotRect, cg: cg, isMiniLOD: true)
        return true
    }
    return img
}

// MARK: - 4. File Exporter Helper
func savePNG(image: NSImage, path: String, pixelSize: Int) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    rep.size = NSSize(width: pixelSize, height: pixelSize)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
               from: .zero, operation: .sourceOver, fraction: 1.0)
    NSGraphicsContext.restoreGraphicsState()

    if let data = rep.representation(using: .png, properties: [:]) {
        try? data.write(to: URL(fileURLWithPath: path))
        print("Generated: \(path) (\(pixelSize)×\(pixelSize))")
    }
}

// MARK: - 5. Execute Pipeline
let appRoot = "/Users/igorekishev/.gemini/antigravity/worktrees/mac-productivity-suite/update_branding_and_icons"
let iconsetDir = "/tmp/NNTSAppIcon.iconset"
let fileManager = FileManager.default

try? fileManager.removeItem(atPath: iconsetDir)
try? fileManager.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)

// 1. Generate full iconset for macOS AppIcon.icns
let iconSizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, px) in iconSizes {
    let icon = renderMacAppIcon(size: px)
    savePNG(image: icon, path: "\(iconsetDir)/\(name)", pixelSize: px)
}

// 2. Compile iconset into AppIcon.icns using iconutil
let icnsTarget = "\(appRoot)/src/ChromeQuickAccess/Resources/AppIcon.icns"
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
proc.arguments = ["-c", "icns", iconsetDir, "-o", icnsTarget]
try? proc.run()
proc.waitUntilExit()
print("Compiled ICNS: \(icnsTarget)")

// 3. Update master AppIcon.png (1024x1024) for app resources
let masterIcon = renderMacAppIcon(size: 1024)
savePNG(image: masterIcon, path: "\(appRoot)/src/ChromeQuickAccess/Resources/AppIcon.png", pixelSize: 1024)
savePNG(image: masterIcon, path: "\(appRoot)/docs/site/assets/images/AppIcon.png", pixelSize: 1024)

// 4. Generate Web Favicons
let fav16 = renderFavicon(size: 16)
let fav32 = renderFavicon(size: 32)
let touch180 = renderMacAppIcon(size: 180)

let siteImgDir = "\(appRoot)/docs/site/assets/images"
savePNG(image: fav16, path: "\(siteImgDir)/favicon-16x16.png", pixelSize: 16)
savePNG(image: fav32, path: "\(siteImgDir)/favicon-32x32.png", pixelSize: 32)
savePNG(image: touch180, path: "\(siteImgDir)/apple-touch-icon.png", pixelSize: 180)

// 5. Generate high-precision vector favicon.svg (LOD 0 Neotenic Kindchenschema)
let svgContent = """
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="100%" height="100%">
  <!-- Ears -->
  <circle cx="7.5" cy="7.5" r="4.6" fill="#F6BC14"/>
  <circle cx="7.5" cy="7.5" r="2.4" fill="#FED7AA"/>
  <circle cx="24.5" cy="7.5" r="4.6" fill="#F6BC14"/>
  <circle cx="24.5" cy="7.5" r="2.4" fill="#FED7AA"/>

  <!-- Head & Cheeks -->
  <circle cx="9.5" cy="17.0" r="7.0" fill="#F6BC14"/>
  <circle cx="22.5" cy="17.0" r="7.0" fill="#F6BC14"/>
  <rect x="6.0" y="8.5" width="20.0" height="15.0" rx="6.5" fill="#F6BC14"/>

  <!-- White Snout / Cheeks (Neotenic Kindchenschema) -->
  <ellipse cx="16.0" cy="19.5" rx="6.8" ry="4.8" fill="#FFFFFF"/>

  <!-- Eyes: Clean Obsidian Dots + Subtle Glint -->
  <circle cx="10.8" cy="14.0" r="2.4" fill="#161B26"/>
  <circle cx="11.5" cy="13.3" r="0.8" fill="#FFFFFF"/>

  <circle cx="21.2" cy="14.0" r="2.4" fill="#161B26"/>
  <circle cx="21.9" cy="13.3" r="0.8" fill="#FFFFFF"/>

  <!-- Red Nose Apex -->
  <polygon points="14.2,17.2 17.8,17.2 16.0,19.4" fill="#E63946"/>
</svg>
"""
try? svgContent.write(to: URL(fileURLWithPath: "\(siteImgDir)/favicon.svg"), atomically: true, encoding: .utf8)
print("Generated SVG Favicon: \(siteImgDir)/favicon.svg")
print("Generated SVG Favicon: \(siteImgDir)/favicon.svg")

// 6. Sync to projects/khomyak/website if it exists
let websiteDir = "/Users/igorekishev/.gemini/antigravity/worktrees/website/update_branding_and_icons/projects/khomyak/website/assets/images"
if fileManager.fileExists(atPath: websiteDir) {
    try? fileManager.copyItem(atPath: "\(siteImgDir)/favicon.svg", toPath: "\(websiteDir)/favicon.svg")
    try? fileManager.removeItem(atPath: "\(websiteDir)/favicon-16x16.png")
    try? fileManager.copyItem(atPath: "\(siteImgDir)/favicon-16x16.png", toPath: "\(websiteDir)/favicon-16x16.png")
    try? fileManager.removeItem(atPath: "\(websiteDir)/favicon-32x32.png")
    try? fileManager.copyItem(atPath: "\(siteImgDir)/favicon-32x32.png", toPath: "\(websiteDir)/favicon-32x32.png")
    try? fileManager.removeItem(atPath: "\(websiteDir)/apple-touch-icon.png")
    try? fileManager.copyItem(atPath: "\(siteImgDir)/apple-touch-icon.png", toPath: "\(websiteDir)/apple-touch-icon.png")
    try? fileManager.removeItem(atPath: "\(websiteDir)/AppIcon.png")
    try? fileManager.copyItem(atPath: "\(siteImgDir)/AppIcon.png", toPath: "\(websiteDir)/AppIcon.png")
    print("Synced assets to website repo directory.")
}

print("✅ All assets generated successfully!")
