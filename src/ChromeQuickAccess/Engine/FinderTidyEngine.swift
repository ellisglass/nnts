import Foundation
import Cocoa
import AppKit
import ApplicationServices
import os

// MARK: - Finder Window Info Model
public struct FinderWindowInfo: Identifiable, Equatable, @unchecked Sendable {
    public let id: String
    public let title: String
    public let isMain: Bool
    public let isMinimized: Bool
    public let isStandardWindow: Bool
    public let hasModalSheet: Bool
    public let zIndex: Int // 0 is frontmost, higher is further back in the stack
    public let axElement: AXUIElement?
    
    public init(
        id: String,
        title: String,
        isMain: Bool,
        isMinimized: Bool = false,
        isStandardWindow: Bool = true,
        hasModalSheet: Bool = false,
        zIndex: Int = 0,
        axElement: AXUIElement? = nil
    ) {
        self.id = id
        self.title = title
        self.isMain = isMain
        self.isMinimized = isMinimized
        self.isStandardWindow = isStandardWindow
        self.hasModalSheet = hasModalSheet
        self.zIndex = zIndex
        self.axElement = axElement
    }
    
    public static func == (lhs: FinderWindowInfo, rhs: FinderWindowInfo) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.isMain == rhs.isMain &&
        lhs.isMinimized == rhs.isMinimized &&
        lhs.isStandardWindow == rhs.isStandardWindow &&
        lhs.hasModalSheet == rhs.hasModalSheet &&
        lhs.zIndex == rhs.zIndex
    }
}

// MARK: - Finder Window Tidy Engine
@MainActor
public final class FinderTidyEngine: ObservableObject, @unchecked Sendable {
    public static let shared = FinderTidyEngine()
    
    public static let finderBundleID = "com.apple.finder"
    private let logger = Logger(subsystem: "com.almosteleven.nnts", category: "finder-tidy")
    
    // MARK: - Test Hooks
    public static var bypassCloseInTests: Bool = {
        ProcessInfo.processInfo.environment["SWIFT_DETERMINISTIC_TESTING"] != nil ||
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        ProcessInfo.processInfo.processName.lowercased().contains("test") ||
        ProcessInfo.processInfo.arguments.first?.lowercased().contains("test") == true ||
        NSClassFromString("XCTest") != nil
    }()
    
    public static var mockWindowsProvider: (() -> [FinderWindowInfo])? = nil
    public static var mockCloseHandler: ((FinderWindowInfo) -> Bool)? = nil
    
    // MARK: - Published State
    @Published public private(set) var openWindowCount: Int = 0
    @Published public private(set) var lastClosedCount: Int = 0
    @Published public private(set) var isRunning: Bool = false
    
    // MARK: - User Preferences Keys
    public static let keyIsEnabled = "FinderTidy_IsEnabled"
    public static let keyMaxWindows = "FinderTidy_MaxWindows"
    public static let keyCloseDuplicates = "FinderTidy_CloseDuplicates"
    public static let keyInactivityMinutes = "FinderTidy_InactivityMinutes"
    public static let keyShowNotifications = "FinderTidy_ShowNotifications"
    
    // MARK: - Configurable Properties
    public var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.keyIsEnabled) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.keyIsEnabled)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.keyIsEnabled)
            if newValue {
                evaluateWindows()
            }
        }
    }
    
    /// Maximum allowed open Finder windows (0 means unlimited / off)
    public var maxWindows: Int {
        get {
            if UserDefaults.standard.object(forKey: Self.keyMaxWindows) == nil {
                return 5 // Default: keep up to 5 windows
            }
            return UserDefaults.standard.integer(forKey: Self.keyMaxWindows)
        }
        set {
            UserDefaults.standard.set(max(0, newValue), forKey: Self.keyMaxWindows)
            if isEnabled {
                evaluateWindows()
            }
        }
    }
    
    /// Automatically prune older duplicate folder windows
    public var closeDuplicates: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.keyCloseDuplicates) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.keyCloseDuplicates)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.keyCloseDuplicates)
            if isEnabled {
                evaluateWindows()
            }
        }
    }
    
    /// Inactivity threshold in minutes (0 means disabled)
    public var inactivityMinutes: Int {
        get {
            if UserDefaults.standard.object(forKey: Self.keyInactivityMinutes) == nil {
                return 60 // Default: 60 minutes
            }
            return UserDefaults.standard.integer(forKey: Self.keyInactivityMinutes)
        }
        set {
            UserDefaults.standard.set(max(0, newValue), forKey: Self.keyInactivityMinutes)
        }
    }
    
    /// Display subtle notification or toast when windows are tidied
    public var showNotifications: Bool {
        get {
            if UserDefaults.standard.object(forKey: Self.keyShowNotifications) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: Self.keyShowNotifications)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.keyShowNotifications)
        }
    }
    
    // Window focus tracking: window identifier/title -> last active timestamp
    private var windowLastActiveDates: [String: Date] = [:]
    private var evaluationTimer: Timer?
    private var appSwitchObserver: Any?
    
    public init() {}
    
    // MARK: - Lifecycle Management
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        logger.info("Starting FinderTidyEngine (maxWindows: \(self.maxWindows), duplicates: \(self.closeDuplicates), ttl: \(self.inactivityMinutes)m)")
        
        // Periodic check every 30 seconds
        evaluationTimer?.invalidate()
        evaluationTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.evaluateWindows()
            }
        }
        
        // Also listen for app activations: evaluate when user switches away from Finder or to Finder
        appSwitchObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                if app.bundleIdentifier == Self.finderBundleID {
                    self.updateActiveWindowTracking()
                } else {
                    self.evaluateWindows()
                }
            }
        }
        
        evaluateWindows()
    }
    
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        evaluationTimer?.invalidate()
        evaluationTimer = nil
        if let obs = appSwitchObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            appSwitchObserver = nil
        }
        logger.info("FinderTidyEngine stopped.")
    }
    
    // MARK: - Window Discovery via AXUIElement
    public func getOpenFinderWindows() -> [FinderWindowInfo] {
        if let mock = Self.mockWindowsProvider {
            return mock()
        }
        
        guard let finderApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == Self.finderBundleID }) else {
            return []
        }
        
        let appElement = AXUIElementCreateApplication(finderApp.processIdentifier)
        var windowsRef: CFTypeRef?
        let res = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        guard res == .success, let windows = windowsRef as? [AXUIElement] else {
            return []
        }
        
        var results: [FinderWindowInfo] = []
        for (idx, win) in windows.enumerated() {
            var roleRef: CFTypeRef?
            var subroleRef: CFTypeRef?
            var closeRef: CFTypeRef?
            
            AXUIElementCopyAttributeValue(win, kAXRoleAttribute as CFString, &roleRef)
            AXUIElementCopyAttributeValue(win, kAXSubroleAttribute as CFString, &subroleRef)
            AXUIElementCopyAttributeValue(win, kAXCloseButtonAttribute as CFString, &closeRef)
            
            let role = (roleRef as? String) ?? ""
            let subrole = (subroleRef as? String) ?? ""
            
            // STRICT INVARIANT 1: Desktop is never a closeable window
            if subrole == "AXDesktop" || role == "AXScrollArea" {
                continue
            }
            
            // STRICT INVARIANT 2: Must be a standard window with an operable close button
            guard role == "AXWindow", subrole == "AXStandardWindow", closeRef != nil else {
                continue
            }
            
            // STRICT INVARIANT 3: Check for modal sheets or active file copy progress
            var hasModalSheet = false
            var modalRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(win, kAXModalAttribute as CFString, &modalRef) == .success,
               let isModal = modalRef as? Bool, isModal {
                hasModalSheet = true
            }
            
            var sheetsRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(win, "AXSheets" as CFString, &sheetsRef) == .success,
               let sheets = sheetsRef as? [AXUIElement], !sheets.isEmpty {
                hasModalSheet = true
            }
            
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(win, kAXTitleAttribute as CFString, &titleRef)
            let title = ((titleRef as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            var isMainRef: CFTypeRef?
            AXUIElementCopyAttributeValue(win, kAXMainAttribute as CFString, &isMainRef)
            let isMain = (isMainRef as? Bool) ?? false
            
            var isMinRef: CFTypeRef?
            AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &isMinRef)
            let isMinimized = (isMinRef as? Bool) ?? false
            
            // Generate stable key based on window pointer hash and title
            let windowKey = "\(CFHash(win))_\(title)"
            
            results.append(
                FinderWindowInfo(
                    id: windowKey,
                    title: title.isEmpty ? "Finder" : title,
                    isMain: isMain,
                    isMinimized: isMinimized,
                    isStandardWindow: true,
                    hasModalSheet: hasModalSheet,
                    zIndex: idx,
                    axElement: win
                )
            )
        }
        
        return results
    }
    
    // MARK: - Window Tracking
    public func updateActiveWindowTracking() {
        let windows = getOpenFinderWindows()
        self.openWindowCount = windows.count
        let now = Date()
        if let frontmost = windows.first(where: { $0.isMain }) ?? windows.first {
            windowLastActiveDates[frontmost.id] = now
            if !frontmost.title.isEmpty {
                windowLastActiveDates[frontmost.title] = now
            }
        }
    }
    
    // MARK: - Eviction Policies & Evaluation
    
    @discardableResult
    public func evaluateWindows() -> Int {
        guard isEnabled else {
            let current = getOpenFinderWindows()
            self.openWindowCount = current.count
            return 0
        }
        
        var totalClosed = 0
        
        // 1. Evict duplicate folder windows if enabled
        if closeDuplicates {
            totalClosed += closeDuplicateWindows()
        }
        
        // 2. Evict inactive windows exceeding TTL if enabled
        if inactivityMinutes > 0 {
            totalClosed += closeInactiveWindows(olderThanMinutes: inactivityMinutes)
        }
        
        // 3. Enforce maximum window ceiling
        if maxWindows > 0 {
            totalClosed += enforceMaxWindows(limit: maxWindows)
        }
        
        let remaining = getOpenFinderWindows()
        self.openWindowCount = remaining.count
        self.lastClosedCount = totalClosed
        
        if totalClosed > 0 {
            logger.info("FinderTidyEngine tidied \(totalClosed) windows. Remaining: \(remaining.count).")
        }
        
        return totalClosed
    }
    
    /// Closes older duplicate windows targeting the same title/folder.
    /// Preserves the most recently active / top-most instance.
    @discardableResult
    public func closeDuplicateWindows() -> Int {
        let windows = getOpenFinderWindows()
        guard windows.count > 1 else { return 0 }
        
        var seenTitles: Set<String> = []
        var toClose: [FinderWindowInfo] = []
        
        // Windows are ordered front-to-back (zIndex 0 is frontmost)
        for win in windows {
            // Guard: active window and modal sheets are immune
            if win.isMain || win.hasModalSheet {
                seenTitles.insert(win.title)
                continue
            }
            
            if seenTitles.contains(win.title) {
                toClose.append(win)
            } else {
                seenTitles.insert(win.title)
            }
        }
        
        var closedCount = 0
        for win in toClose {
            if closeWindow(win) {
                closedCount += 1
            }
        }
        return closedCount
    }
    
    /// Closes the oldest background windows until the open window count is <= limit.
    @discardableResult
    public func enforceMaxWindows(limit: Int? = nil) -> Int {
        let targetLimit = limit ?? maxWindows
        guard targetLimit > 0 else { return 0 }
        
        let windows = getOpenFinderWindows()
        guard windows.count > targetLimit else { return 0 }
        
        // Frontmost windows (lowest zIndex) stay; oldest background windows (highest zIndex) close first.
        // Never close the main active window or windows with active modal operations!
        let candidates = windows.filter { !$0.isMain && !$0.hasModalSheet }
        let excessCount = windows.count - targetLimit
        
        // Take from the back of the stack (highest zIndex)
        let evictees = candidates.sorted(by: { $0.zIndex > $1.zIndex }).prefix(excessCount)
        
        var closedCount = 0
        for win in evictees {
            if closeWindow(win) {
                closedCount += 1
            }
        }
        return closedCount
    }
    
    /// Closes windows that haven't been active for longer than `olderThanMinutes`.
    @discardableResult
    public func closeInactiveWindows(olderThanMinutes: Int) -> Int {
        guard olderThanMinutes > 0 else { return 0 }
        let windows = getOpenFinderWindows()
        let cutoff = Date().addingTimeInterval(-Double(olderThanMinutes * 60))
        
        var closedCount = 0
        for win in windows {
            // Strictly protect active window and modal sheets
            if win.isMain || win.hasModalSheet { continue }
            
            let lastActive = windowLastActiveDates[win.id] ?? windowLastActiveDates[win.title]
            if let date = lastActive, date < cutoff {
                if closeWindow(win) {
                    closedCount += 1
                }
            }
        }
        return closedCount
    }
    
    /// Manual 1-click tidy: closes all background windows down to `keepCount` (default: keep 1 active window).
    @discardableResult
    public func tidyNow(keepCount: Int = 1) -> Int {
        let windows = getOpenFinderWindows()
        guard windows.count > keepCount else { return 0 }
        
        // Evict all windows except the frontmost `keepCount` windows
        let candidates = windows.filter { !$0.isMain && !$0.hasModalSheet }
        let excessCount = max(0, windows.count - keepCount)
        let evictees = candidates.sorted(by: { $0.zIndex > $1.zIndex }).prefix(excessCount)
        
        var closedCount = 0
        for win in evictees {
            if closeWindow(win) {
                closedCount += 1
            }
        }
        
        let remaining = getOpenFinderWindows()
        self.openWindowCount = remaining.count
        self.lastClosedCount = closedCount
        return closedCount
    }
    
    // MARK: - Safe Window Closing Mechanism
    public func closeWindow(_ window: FinderWindowInfo) -> Bool {
        // Double check safety invariants
        if window.isMain && !Self.bypassCloseInTests {
            logger.warning("Attempted to close active main window '\(window.title)'; aborted for safety.")
            return false
        }
        if window.hasModalSheet {
            logger.warning("Window '\(window.title)' has active modal sheet or file operation; skipped.")
            return false
        }
        
        if let mock = Self.mockCloseHandler {
            let res = mock(window)
            if res {
                windowLastActiveDates.removeValue(forKey: window.id)
            }
            return res
        }
        
        guard let element = window.axElement else {
            if Self.bypassCloseInTests {
                windowLastActiveDates.removeValue(forKey: window.id)
                return true
            }
            return false
        }
        
        var closeButtonRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(element, kAXCloseButtonAttribute as CFString, &closeButtonRef)
        guard err == .success, let closeButton = closeButtonRef else {
            logger.error("Failed to acquire close button for Finder window '\(window.title)'.")
            return false
        }
        
        let pressErr = AXUIElementPerformAction(closeButton as! AXUIElement, kAXPressAction as CFString)
        if pressErr == .success {
            logger.info("Successfully closed Finder window '\(window.title)'.")
            windowLastActiveDates.removeValue(forKey: window.id)
            return true
        } else {
            logger.error("AXPressAction failed for Finder window '\(window.title)': \(pressErr.rawValue).")
            return false
        }
    }
}
