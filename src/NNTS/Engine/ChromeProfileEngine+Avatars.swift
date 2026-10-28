import Foundation
import Cocoa
import AppKit
import os

// MARK: - Avatar Storage, Capture & Image Processing
extension ChromeProfileEngine {
    
    public func saveCachedProfiles(_ profiles: [ChromeProfile], bundleID: String) {
        guard !profiles.isEmpty else { return }
        let records: [[String: Any]] = profiles.map { p in
            [
                "index": p.index,
                "dir": p.dir,
                "name": p.name
            ]
        }
        UserDefaults.standard.set(records, forKey: "CachedProfiles_\(bundleID)")
    }
    
    public func loadCachedProfiles(bundleID: String) -> [ChromeProfile] {
        guard let records = UserDefaults.standard.array(forKey: "CachedProfiles_\(bundleID)") as? [[String: Any]],
              !records.isEmpty else {
            return []
        }
        return records.compactMap { dict in
            guard let index = dict["index"] as? Int,
                  let dir = dict["dir"] as? String,
                  let name = dict["name"] as? String else {
                return nil
            }
            let avatar: NSImage
            if let customImg = Self.loadStoredAvatar(dirKey: dir, name: name) {
                avatar = makeCircularImage(image: customImg)
            } else {
                avatar = makeMonogramImage(name: name, colorSeed: index)
            }
            return ChromeProfile(
                index: index,
                dir: dir,
                name: name,
                email: nil,
                gaiaName: nil,
                gaiaGivenName: nil,
                avatarImage: avatar
            )
        }
    }
    
    public func clearAvatarCache() {
        self.cachedAvatars.removeAll()
    }
    
    // MARK: - Local Custom & Imported Avatar Storage
    public static var localAvatarStorageURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let nntsDir = appSupport.appendingPathComponent("NNTS/Avatars", isDirectory: true)
        try? FileManager.default.createDirectory(at: nntsDir, withIntermediateDirectories: true)
        return nntsDir
    }
    
    public static func loadStoredAvatar(dirKey: String, name: String) -> NSImage? {
        let storage = localAvatarStorageURL
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        var candidatePaths: [String] = []
        let extensions = ["png", "jpg", "jpeg", "heic", "webp"]
        for ext in extensions {
            candidatePaths.append(storage.appendingPathComponent("\(dirKey).\(ext)").path)
            candidatePaths.append(storage.appendingPathComponent("\(name).\(ext)").path)
            if safeName != name {
                candidatePaths.append(storage.appendingPathComponent("\(safeName).\(ext)").path)
            }
        }
        for path in candidatePaths {
            if FileManager.default.fileExists(atPath: path),
               let img = NSImage(contentsOfFile: path) {
                return img
            }
        }
        return nil
    }
    
    @MainActor
    public func importAvatarsFromFolder(url: URL) -> Int {
        let isAccessGranted = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessGranted { url.stopAccessingSecurityScopedResource() }
        }
        
        let fileManager = FileManager.default
        let storage = Self.localAvatarStorageURL
        var importedCount = 0
        
        var targetURL = url
        if fileManager.fileExists(atPath: url.appendingPathComponent("Chrome/Local State").path) {
            targetURL = url.appendingPathComponent("Chrome")
        } else if url.lastPathComponent.hasPrefix("Profile") || url.lastPathComponent == "Default" {
            targetURL = url.deletingLastPathComponent()
        }
        
        // Save bookmark for persistence across app restarts
        if let bookmarkData = try? targetURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(bookmarkData, forKey: "ChromeFolderSecurityScopedBookmark")
        }
        
        func saveCroppedImage(_ image: NSImage, primaryKey: String, secondaryKey: String? = nil) {
            let circular = makeCircularImage(image: image)
            cachedAvatars[primaryKey] = circular
            if let tiff = circular.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let pngData = bitmap.representation(using: .png, properties: [:]) {
                let destURL = storage.appendingPathComponent("\(primaryKey).png")
                try? pngData.write(to: destURL)
                if let sec = secondaryKey {
                    let safeSec = sec.replacingOccurrences(of: "/", with: "-")
                    if safeSec != primaryKey {
                        try? pngData.write(to: storage.appendingPathComponent("\(safeSec).png"))
                    }
                }
                importedCount += 1
            }
        }
        
        // 1. Try reading Local State now that we have permission
        let localStateURL = targetURL.appendingPathComponent("Local State")
        if fileManager.fileExists(atPath: localStateURL.path),
           let data = try? Data(contentsOf: localStateURL),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let profileObj = json["profile"] as? [String: Any],
           let infoCache = profileObj["info_cache"] as? [String: [String: Any]] {
            for (dirKey, info) in infoCache {
                let name = (info["name"] as? String) ?? (info["gaia_name"] as? String) ?? dirKey
                let profileDir = targetURL.appendingPathComponent(dirKey)
                var picCandidates = [
                    profileDir.appendingPathComponent("Google Profile Picture.png"),
                    profileDir.appendingPathComponent("Google Profile Picture.jpg"),
                    profileDir.appendingPathComponent("Edge Profile Picture.png"),
                    profileDir.appendingPathComponent("Custom Profile Picture.png")
                ]
                if let gaiaName = info["gaia_picture_file_name"] as? String, !gaiaName.isEmpty {
                    let sanitized = (gaiaName as NSString).lastPathComponent
                    if !sanitized.isEmpty && !sanitized.contains("/") && !sanitized.contains("\\") && !sanitized.contains("..") {
                        picCandidates.insert(profileDir.appendingPathComponent(sanitized), at: 0)
                    }
                }
                if let subfiles = try? fileManager.contentsOfDirectory(atPath: profileDir.path) {
                    for f in subfiles {
                        let lower = f.lowercased()
                        if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") {
                            if lower.contains("profile") || lower.contains("avatar") || lower.contains("picture") {
                                picCandidates.append(profileDir.appendingPathComponent(f))
                            }
                        }
                    }
                }
                for pic in picCandidates {
                    if fileManager.fileExists(atPath: pic.path),
                       let imgData = try? Data(contentsOf: pic),
                       let image = NSImage(data: imgData) {
                        saveCroppedImage(image, primaryKey: dirKey, secondaryKey: name)
                        break
                    }
                }
            }
        } else {
            let candidateDirs = ["Default"] + (1...20).map { "Profile \($0)" }
            for dir in candidateDirs {
                let profileDir = url.appendingPathComponent(dir)
                var picCandidates = [
                    profileDir.appendingPathComponent("Google Profile Picture.png"),
                    profileDir.appendingPathComponent("Google Profile Picture.jpg")
                ]
                if let subfiles = try? fileManager.contentsOfDirectory(atPath: profileDir.path) {
                    for f in subfiles {
                        let lower = f.lowercased()
                        if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") {
                            if lower.contains("profile") || lower.contains("avatar") || lower.contains("picture") {
                                picCandidates.append(profileDir.appendingPathComponent(f))
                            }
                        }
                    }
                }
                for pic in picCandidates {
                    if fileManager.fileExists(atPath: pic.path),
                       let imgData = try? Data(contentsOf: pic),
                       let image = NSImage(data: imgData) {
                        saveCroppedImage(image, primaryKey: dir)
                        break
                    }
                }
            }
        }
        
        // Also check if user selected a folder containing loose image files
        if let directFiles = try? fileManager.contentsOfDirectory(atPath: url.path) {
            for f in directFiles {
                let lower = f.lowercased()
                if lower.hasSuffix(".png") || lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg") || lower.hasSuffix(".heic") {
                    let fileURL = url.appendingPathComponent(f)
                    let baseName = (f as NSString).deletingPathExtension
                    if let image = NSImage(contentsOf: fileURL) {
                        saveCroppedImage(image, primaryKey: baseName)
                    }
                }
            }
        }
        
        self.cachedAvatars.removeAll()
        if !isRestoringBookmark {
            refreshProfiles()
        }
        return importedCount
    }
    
    public func restoreSecurityScopedFolderAccessIfNeeded() {
        guard !isRestoringBookmark else { return }
        guard let bookmarkData = UserDefaults.standard.data(forKey: "ChromeFolderSecurityScopedBookmark") else { return }
        isRestoringBookmark = true
        defer { isRestoringBookmark = false }
        var isStale = false
        if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
            let _ = importAvatarsFromFolder(url: url)
        }
    }
    
    // MARK: - User-Assisted & Clipboard Avatar Capture
    
    @discardableResult
    @MainActor
    public func saveCapturedAvatar(image: NSImage, forProfileDir dirKey: String, name: String) -> Bool {
        let circular = makeCircularImage(image: image)
        guard let tiff = circular.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return false
        }
        let dest1 = Self.localAvatarStorageURL.appendingPathComponent("\(dirKey).png")
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        let dest2 = Self.localAvatarStorageURL.appendingPathComponent("\(safeName).png")
        do {
            try pngData.write(to: dest1)
            if safeName != dirKey {
                try pngData.write(to: dest2)
            }
            cachedAvatars[dirKey] = circular
            cachedAvatars[name] = circular
            if safeName != name {
                cachedAvatars[safeName] = circular
            }
            refreshProfiles()
            logger.info("Saved user-captured avatar for profile '\(name)' (\(dirKey)).")
            return true
        } catch {
            logger.error("Failed to save captured avatar: \(error.localizedDescription)")
            return false
        }
    }
    
    public static func getImageFromPasteboard(_ pboard: NSPasteboard = .general) -> NSImage? {
        if let img = NSImage(pasteboard: pboard) {
            return img
        }
        if let objects = pboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage], let first = objects.first {
            return first
        }
        if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let first = urls.first {
            if let img = NSImage(contentsOf: first) {
                return img
            }
        }
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pboard.data(forType: type), let img = NSImage(data: data) {
                return img
            }
        }
        return nil
    }
    
    @discardableResult
    @MainActor
    public func saveCapturedAvatarFromPasteboard(forProfileDir dirKey: String, name: String) -> Bool {
        guard let img = Self.getImageFromPasteboard() else { return false }
        return saveCapturedAvatar(image: img, forProfileDir: dirKey, name: name)
    }
    
    @MainActor
    public func deleteCustomAvatar(profileDir: String) {
        let dest = Self.localAvatarStorageURL.appendingPathComponent("\(profileDir).png")
        try? FileManager.default.removeItem(at: dest)
        cachedAvatars.removeValue(forKey: profileDir)
        refreshProfiles()
    }
    
    @MainActor
    public func startPasteboardAvatarWatcher(
        forProfileDir dirKey: String,
        name: String,
        timeoutSeconds: TimeInterval = 45.0,
        onCapture: @escaping @Sendable (Bool) -> Void
    ) {
        cancelPasteboardAvatarWatcher()
        let startChangeCount = NSPasteboard.general.changeCount
        let startTime = Date()
        
        pasteboardWatcherTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if NSPasteboard.general.changeCount != startChangeCount {
                    if let img = NSImage(pasteboard: NSPasteboard.general) {
                        self.cancelPasteboardAvatarWatcher()
                        let success = self.saveCapturedAvatar(image: img, forProfileDir: dirKey, name: name)
                        onCapture(success)
                        return
                    }
                }
                
                if Date().timeIntervalSince(startTime) >= timeoutSeconds {
                    self.cancelPasteboardAvatarWatcher()
                    onCapture(false)
                }
            }
        }
    }
    
    @MainActor
    public func cancelPasteboardAvatarWatcher() {
        pasteboardWatcherTimer?.invalidate()
        pasteboardWatcherTimer = nil
    }
    
    // MARK: - Avatar & Monogram Helpers
    
    internal func resolveAvatar(baseDir: String, dirKey: String, info: [String: Any]) -> NSImage {
        if let cached = cachedAvatars[dirKey] { return cached }
        
        let name = (info["name"] as? String) ?? (info["gaia_name"] as? String) ?? dirKey
        
        // 0. Priority: Use locally stored or Smart-Snapped avatar if available
        if let stored = Self.loadStoredAvatar(dirKey: dirKey, name: name) {
            let circular = makeCircularImage(image: stored)
            cachedAvatars[dirKey] = circular
            return circular
        }
        
        let profileDir = (baseDir as NSString).appendingPathComponent(dirKey)
        
        var candidatePics = [
            (profileDir as NSString).appendingPathComponent("Google Profile Picture.png"),
            (profileDir as NSString).appendingPathComponent("Google Profile Picture.jpg"),
            (profileDir as NSString).appendingPathComponent("Edge Profile Picture.png"),
            (profileDir as NSString).appendingPathComponent("Custom Profile Picture.png")
        ]
        // Validate gaia_picture_file_name: must be a pure basename without directory traversal components
        if let gaiaName = info["gaia_picture_file_name"] as? String, !gaiaName.isEmpty {
            let sanitized = (gaiaName as NSString).lastPathComponent
            if !sanitized.isEmpty && !sanitized.contains("/") && !sanitized.contains("\\") && !sanitized.contains("..") {
                candidatePics.insert((profileDir as NSString).appendingPathComponent(sanitized), at: 0)
            }
        }
        
        let hasAuthorizedFolder = UserDefaults.standard.data(forKey: "ChromeFolderSecurityScopedBookmark") != nil
        if hasAuthorizedFolder || Self.bypassLaunchInTests {
            let canonicalBase = URL(fileURLWithPath: profileDir).resolvingSymlinksInPath().path
            for picPath in candidatePics {
                let canonicalPic = URL(fileURLWithPath: picPath).resolvingSymlinksInPath().path
                guard canonicalPic.hasPrefix(canonicalBase) else { continue }
                if FileManager.default.fileExists(atPath: canonicalPic),
                   let image = NSImage(contentsOfFile: canonicalPic) {
                    let circular = makeCircularImage(image: image)
                    cachedAvatars[dirKey] = circular
                    if let tiff = circular.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiff),
                       let pngData = bitmap.representation(using: .png, properties: [:]) {
                        let dest = Self.localAvatarStorageURL.appendingPathComponent("\(dirKey).png")
                        try? pngData.write(to: dest)
                        let safeName = name.replacingOccurrences(of: "/", with: "-")
                        if safeName != dirKey {
                            try? pngData.write(to: Self.localAvatarStorageURL.appendingPathComponent("\(safeName).png"))
                        }
                    }
                    return circular
                }
            }
        }
        
        let colorSeed = info["profile_color_seed"] as? Int
        let monogram = makeMonogramImage(name: name, colorSeed: colorSeed)
        cachedAvatars[dirKey] = monogram
        return monogram
    }
    
    public func makeCircularImage(image: NSImage) -> NSImage {
        let size = NSSize(width: 96, height: 96)
        let output = NSImage(size: size)
        output.lockFocus()
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(ovalIn: rect)
        path.addClip()
        
        let srcSize = image.size
        let minSide = min(srcSize.width, srcSize.height)
        let srcRect = NSRect(
            x: (srcSize.width - minSide) / 2,
            y: (srcSize.height - minSide) / 2,
            width: minSide,
            height: minSide
        )
        image.draw(in: rect, from: srcRect, operation: .sourceOver, fraction: 1.0)
        
        let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
        NSColor.white.withAlphaComponent(0.3).setStroke()
        ring.lineWidth = 2
        ring.stroke()
        output.unlockFocus()
        return output
    }
    
    public func makeMonogramImage(name: String, colorSeed: Int? = nil) -> NSImage {
        let size = NSSize(width: 96, height: 96)
        let output = NSImage(size: size)
        output.lockFocus()
        
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = cleanName.lowercased()
        
        // 1. Check for parenthesized tag e.g. "Igor (Al11)" -> "Al11", "Igor (GCP Free 2)" -> "GCP Free 2"
        var tag: String? = nil
        if let openParen = cleanName.firstIndex(of: "("),
           let closeParen = cleanName.lastIndex(of: ")"),
           openParen < closeParen {
            let inner = String(cleanName[cleanName.index(after: openParen)..<closeParen]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !inner.isEmpty {
                tag = inner
            }
        }
        
        let tagLower = tag?.lowercased() ?? ""
        
        // 2. Determine contextual gradient colors and distinct token badge
        let bgGradient: (top: NSColor, bottom: NSColor)
        var badgeText: String = ""
        
        if lower.contains("al11") || tagLower.contains("al11") {
            // Almost Eleven / Work: Deep Indigo to Violet
            bgGradient = (
                top: NSColor(red: 0.40, green: 0.35, blue: 0.95, alpha: 1.0),
                bottom: NSColor(red: 0.28, green: 0.20, blue: 0.78, alpha: 1.0)
            )
            badgeText = "11"
        } else if lower.contains("gcp") || tagLower.contains("gcp") || lower.contains("cloud") || tagLower.contains("cloud") {
            if lower.contains("2") || tagLower.contains("2") {
                // GCP Project 2: Radiant Amber to Warm Tangerine
                bgGradient = (
                    top: NSColor(red: 0.98, green: 0.65, blue: 0.15, alpha: 1.0),
                    bottom: NSColor(red: 0.88, green: 0.45, blue: 0.05, alpha: 1.0)
                )
                badgeText = "GC2"
            } else {
                // GCP Free / Primary Cloud: Electric Cyan to Azure
                bgGradient = (
                    top: NSColor(red: 0.12, green: 0.70, blue: 0.92, alpha: 1.0),
                    bottom: NSColor(red: 0.02, green: 0.48, blue: 0.78, alpha: 1.0)
                )
                badgeText = "GCP"
            }
        } else if lower.contains("nastya") || lower.contains("anastasia") || lower.contains("kate") || lower.contains("anna") {
            // Partner / Warm Coral Rose
            bgGradient = (
                top: NSColor(red: 0.95, green: 0.35, blue: 0.52, alpha: 1.0),
                bottom: NSColor(red: 0.82, green: 0.18, blue: 0.38, alpha: 1.0)
            )
            badgeText = "NA"
        } else if lower.contains("work") || tagLower.contains("work") || lower.contains("corp") || tagLower.contains("corp") || lower.contains("office") {
            // Corporate / Work: Slate Purple to Deep Indigo
            bgGradient = (
                top: NSColor(red: 0.48, green: 0.38, blue: 0.92, alpha: 1.0),
                bottom: NSColor(red: 0.32, green: 0.22, blue: 0.72, alpha: 1.0)
            )
            badgeText = "WK"
        } else if lower.contains("dev") || tagLower.contains("dev") || lower.contains("code") || tagLower.contains("code") {
            // Developer: Vivid Emerald to Forest Teal
            bgGradient = (
                top: NSColor(red: 0.15, green: 0.75, blue: 0.50, alpha: 1.0),
                bottom: NSColor(red: 0.05, green: 0.55, blue: 0.35, alpha: 1.0)
            )
            badgeText = "DEV"
        } else if lower.contains("test") || tagLower.contains("test") || lower.contains("qa") || tagLower.contains("qa") {
            // QA / Testing: Burnt Orange to Rust
            bgGradient = (
                top: NSColor(red: 0.95, green: 0.50, blue: 0.20, alpha: 1.0),
                bottom: NSColor(red: 0.80, green: 0.35, blue: 0.10, alpha: 1.0)
            )
            badgeText = "QA"
        } else if lower.contains("igor") || lower == "personal" || lower == "default" || lower == "default profile" {
            // Igor / Primary Personal: Vibrant Royal Blue
            bgGradient = (
                top: NSColor(red: 0.25, green: 0.55, blue: 0.98, alpha: 1.0),
                bottom: NSColor(red: 0.12, green: 0.38, blue: 0.85, alpha: 1.0)
            )
            badgeText = "IG"
        } else {
            // Fallback: Harmonious macOS palette based on hash or colorSeed
            let palette: [(top: NSColor, bottom: NSColor)] = [
                (NSColor(red: 0.25, green: 0.55, blue: 0.98, alpha: 1.0), NSColor(red: 0.12, green: 0.38, blue: 0.85, alpha: 1.0)),
                (NSColor(red: 0.58, green: 0.35, blue: 0.92, alpha: 1.0), NSColor(red: 0.42, green: 0.20, blue: 0.75, alpha: 1.0)),
                (NSColor(red: 0.95, green: 0.45, blue: 0.25, alpha: 1.0), NSColor(red: 0.82, green: 0.30, blue: 0.12, alpha: 1.0)),
                (NSColor(red: 0.18, green: 0.72, blue: 0.48, alpha: 1.0), NSColor(red: 0.08, green: 0.55, blue: 0.35, alpha: 1.0)),
                (NSColor(red: 0.92, green: 0.65, blue: 0.15, alpha: 1.0), NSColor(red: 0.80, green: 0.50, blue: 0.08, alpha: 1.0)),
                (NSColor(red: 0.12, green: 0.70, blue: 0.92, alpha: 1.0), NSColor(red: 0.02, green: 0.50, blue: 0.75, alpha: 1.0)),
                (NSColor(red: 0.92, green: 0.30, blue: 0.45, alpha: 1.0), NSColor(red: 0.78, green: 0.18, blue: 0.32, alpha: 1.0))
            ]
            let idx = abs(colorSeed ?? cleanName.hashValue) % palette.count
            bgGradient = palette[idx]
            
            if let tag = tag, !tag.isEmpty, tag.count <= 3 {
                badgeText = tag.uppercased()
            } else {
                let parts = cleanName.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "()-"))).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    let first = parts[0].prefix(1).uppercased()
                    let second = parts[1].prefix(1).uppercased()
                    badgeText = "\(first)\(second)"
                } else if let single = parts.first, single.count >= 2 {
                    badgeText = String(single.prefix(2)).uppercased()
                } else {
                    badgeText = String(cleanName.prefix(1)).uppercased()
                }
            }
        }
        
        let rect = NSRect(origin: .zero, size: size)
        let circlePath = NSBezierPath(ovalIn: rect)
        
        let gradient = NSGradient(starting: bgGradient.top, ending: bgGradient.bottom)
        gradient?.draw(in: circlePath, angle: 300)
        
        // Inner specular ring for modern glass depth
        let innerRing = NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
        NSColor.white.withAlphaComponent(0.35).setStroke()
        innerRing.lineWidth = 1.5
        innerRing.stroke()
        
        let text = badgeText.isEmpty ? "C" : badgeText
        let fontSize: CGFloat = text.count > 2 ? 30 : (text.count == 2 ? 36 : 42)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let strSize = str.size()
        let strRect = NSRect(
            x: (size.width - strSize.width) / 2,
            y: (size.height - strSize.height) / 2,
            width: strSize.width,
            height: strSize.height
        )
        str.draw(in: strRect)
        output.unlockFocus()
        return output
    }
}
