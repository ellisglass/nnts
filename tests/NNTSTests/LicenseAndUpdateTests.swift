import Foundation
import Testing
import AppKit
@testable import NNTS

extension ChromeQuickAccessUnitTests {
    @Test @MainActor
    func testLicenseEngineValidationAndConstants() {
        let engine = LicenseEngine.shared
        
        #expect(LicenseEngine.freeSlotsLimit == 5)
        #expect(LicenseEngine.freePinnedAppsLimit == 4)
        #expect(LicenseEngine.proPrice == "$19 Lifetime")
        #expect(LicenseEngine.productionServiceName == "com.almosteleven.nnts.license")
        #expect(LicenseEngine.serviceName == "com.almosteleven.nnts.license.test")
        #expect(LicenseEngine.licenseAccount == "pro_license_key")
        
        // Invalid key checks: empty or whitespace
        #expect(engine.validateLicenseKey("") == false)
        #expect(engine.validateLicenseKey("   ") == false)
        #expect(engine.validateLicenseKey("\n\t") == false)
        
        // Invalid key checks: shorter than 8 characters or missing NNTS prefix
        #expect(engine.validateLicenseKey("ABC") == false)
        #expect(engine.validateLicenseKey("1234567") == false)
        #expect(engine.validateLicenseKey("   short   ") == false)
        #expect(engine.validateLicenseKey("12345678") == false)
        #expect(engine.validateLicenseKey("RANDOM-KEY-123") == false)
        #expect(engine.validateLicenseKey("NNTS-PRO-LICENSE-001") == true)
        #expect(engine.validateLicenseKey("  NNTS-VALID-KEY  ") == true)
        #expect(engine.validateLicenseKey("NNTS-OWNER-KEY-001") == true)
    }
    

    @Test @MainActor
    func testLicenseEngineActivationAndDeactivation() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        defer {
            engine.testOverrideProStatus = originalOverride
            engine.deactivate()
        }
        
        // Ensure clean state
        engine.testOverrideProStatus = nil
        engine.deactivate()
        #expect(engine.isPro == false)
        #expect(engine.activeLicenseKey == nil)
        
        // Attempt activation with invalid key
        let invalidResult = engine.activate(key: "bad")
        #expect(invalidResult == false)
        #expect(engine.isPro == false)
        #expect(engine.activeLicenseKey == nil)
        
        // Attempt activation with valid key via mocked Polar validation
        engine.testMockOnlineValidationResult = true
        let validKey = "NNTS-TEST-MOCKED-LICENSE"
        let validResult = engine.activate(key: "  \(validKey)  ")
        #expect(validResult == true)
        #expect(engine.isPro == true)
        #expect(engine.activeLicenseKey == validKey)
        
        // Verify persistent fallback in isolated test storage
        #expect(LicenseEngine.storage.string(forKey: "NNTSProLicenseKey") == validKey)
        
        // Deactivation clears state
        engine.deactivate()
        #expect(engine.isPro == false)
        #expect(engine.activeLicenseKey == nil)
        #expect(LicenseEngine.storage.string(forKey: "NNTSProLicenseKey") == nil)
        engine.testMockOnlineValidationResult = nil
    }
    

    @Test @MainActor
    func testLicenseEngineTestOverride() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        defer {
            engine.testOverrideProStatus = originalOverride
        }
        
        engine.testOverrideProStatus = true
        #expect(engine.isPro == true)
        
        engine.testOverrideProStatus = false
        #expect(engine.isPro == false)
        
        engine.testOverrideProStatus = nil
    }
    

    @Test @MainActor
    func testSlotLimitRulesFreeVsPro() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        let originalSaved = UserDefaults.standard.stringArray(forKey: "SelectedAppBundleIDs")
        defer {
            engine.testOverrideProStatus = originalOverride
            if let saved = originalSaved {
                UserDefaults.standard.set(saved, forKey: "SelectedAppBundleIDs")
            } else {
                UserDefaults.standard.removeObject(forKey: "SelectedAppBundleIDs")
            }
        }
        
        // 1. Free Tier verification: 4 pinned apps + 1 browser = 5 free slots total
        engine.testOverrideProStatus = false
        #expect(LicenseEngine.freeSlotsLimit == 5)
        #expect(LicenseEngine.freePinnedAppsLimit == 4)
        #expect(AppGroupEngine.maxPinnedQuickApps == 4)
        
        // Free tier enforces 4-slot ceiling on selected bundle IDs
        let testSixIDs = Set([
            "com.google.antigravity",
            "com.google.antigravity-ide",
            "com.googlecode.iterm2",
            "com.apple.Notes",
            "com.tdesktop.Telegram",
            "com.tinyspeck.slackmacgap"
        ])
        AppGroupEngine.selectedBundleIDs = testSixIDs
        #expect(AppGroupEngine.selectedBundleIDs.count <= 4)
        #expect(AppGroupEngine.pinnedAppItems().count <= 4)
        
        // 2. Pro Tier verification: unlimited/26 pinned quick apps
        engine.testOverrideProStatus = true
        #expect(AppGroupEngine.maxPinnedQuickApps == 26)
        
        AppGroupEngine.selectedBundleIDs = testSixIDs
        #expect(AppGroupEngine.selectedBundleIDs.count == 6)
        #expect(AppGroupEngine.canPinMoreApps == true)
    }
    

    @Test @MainActor
    func testLicenseEngineActivationWithOverrideClearing() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        defer {
            engine.testOverrideProStatus = originalOverride
            engine.deactivate()
        }
        
        // If an override was set to false, activate() should clear the override and make isPro true
        engine.testOverrideProStatus = false
        #expect(engine.isPro == false)
        
        engine.testMockOnlineValidationResult = true
        let success = engine.activate(key: "NNTS-OVERRIDE-CLEAR-KEY")
        #expect(success == true)
        #expect(engine.isPro == true)
        #expect(engine.testOverrideProStatus == nil)
        engine.testMockOnlineValidationResult = nil
    }
    

    @Test @MainActor
    func testLicenseEngineRejectsUnmockedKeysWithoutPolar() {
        let engine = LicenseEngine.shared
        defer {
            engine.testMockOnlineValidationResult = nil
            engine.deactivate()
        }
        
        // 1. Format validation: NNTS- prefix passes basic format check
        #expect(engine.validateLicenseKey("NNTS-OWNER-KEY-001") == true)
        #expect(engine.validateLicenseKey("nnts-owner-lowercase") == true)
        #expect(engine.validateLicenseKey("NNTS-VIP-CHAMPION-2026") == true)
        #expect(engine.validateLicenseKey("NNTS-GIVEAWAY-FREE-ACCESS") == true)
        #expect(engine.validateLicenseKey("RANDOM-KEY-123") == false)
        #expect(engine.validateLicenseKey("NNTS") == false) // too short (< 8 chars)
        
        // 2. Unmocked backdoor keys MUST NOT activate offline without Polar validation
        engine.deactivate()
        engine.testMockOnlineValidationResult = nil
        #expect(engine.isPro == false)
        
        let formerBackdoorKeys = [
            "NNTS-OWNER-DIRECT-ACCESS",
            "NNTS-VIP-CONTEST-WINNER",
            "NNTS-GIVEAWAY-OFFLINE"
        ]
        
        for key in formerBackdoorKeys {
            let res = engine.activate(key: key)
            #expect(res == false)
            #expect(engine.isPro == false)
            #expect(engine.activeLicenseKey == nil)
        }
    }
    

    @Test @MainActor
    func testLicenseEnginePolarValidationMockAndAsync() async {
        let engine = LicenseEngine.shared
        let originalMock = engine.testMockOnlineValidationResult
        defer {
            engine.testMockOnlineValidationResult = originalMock
            engine.deactivate()
        }
        
        // Verify polar constants
        #expect(LicenseEngine.polarCheckoutUrl == "https://buy.polar.sh/polar_cl_v5lBa882Ea4dkTo9gvABMVxVbMgRyjkkhUcY43ktCAo")
        #expect(LicenseEngine.polarActivateEndpoint == "https://api.polar.sh/v1/customer-portal/license-keys/activate")
        #expect(LicenseEngine.polarDeactivateEndpoint == "https://api.polar.sh/v1/customer-portal/license-keys/deactivate")
        #expect(LicenseEngine.polarOrganizationId == "fabcbc99-df59-4b60-9485-20a8dddca3c3")
        
        // 1. Unmocked customer key in tests fails cleanly without bypass cheat
        engine.deactivate()
        engine.testMockOnlineValidationResult = nil
        let unmockedResult = engine.activate(key: "NNTS-UNMOCKED-CUSTOMER-KEY")
        #expect(unmockedResult == false)
        #expect(engine.isPro == false)
        
        // 2. Mock failure: online validation fails (e.g. invalid customer key on Polar)
        engine.deactivate()
        engine.testMockOnlineValidationResult = false
        let failedResult = engine.activate(key: "NNTS-INVALID-CUSTOMER-KEY")
        #expect(failedResult == false)
        #expect(engine.isPro == false)
        
        // 3. Mock success: online validation passes (valid customer key on Polar)
        engine.testMockOnlineValidationResult = true
        let validCustomerKey = "NNTS-CUSTOMER-VALID-KEY"
        let successResult = engine.activate(key: validCustomerKey)
        #expect(successResult == true)
        #expect(engine.isPro == true)
        #expect(engine.activeLicenseKey == validCustomerKey)
        
        // 4. Async activation test (Bool and Detailed)
        engine.deactivate()
        engine.testMockOnlineValidationResult = false
        let asyncFail = await engine.activateOnline(key: "NNTS-ASYNC-FAIL")
        #expect(asyncFail == false)
        #expect(engine.isPro == false)
        
        let detailedFail = await engine.activateOnlineDetailed(key: "NNTS-ASYNC-FAIL")
        #expect(detailedFail != .success)
        
        engine.testMockOnlineValidationResult = true
        let asyncSuccess = await engine.activateOnline(key: "NNTS-ASYNC-SUCCESS")
        #expect(asyncSuccess == true)
        #expect(engine.isPro == true)
        #expect(engine.activeLicenseKey == "NNTS-ASYNC-SUCCESS")
        
        let detailedSuccess = await engine.activateOnlineDetailed(key: "NNTS-ASYNC-SUCCESS")
        #expect(detailedSuccess == .success)
    }
    

    @Test @MainActor
    func testAboutAndCheckForUpdatesMenuItems() {
        #expect(!AppDelegate.appVersion.isEmpty)
        #expect(!AppDelegate.appBuild.isEmpty)
        
        let appDelegate = AppDelegate()
        let menu = appDelegate.buildStatusMenu()
        
        let aboutItem = menu.items.first(where: { $0.title.contains("About NNTS") })
        #expect(aboutItem != nil, "About NNTS menu item must exist")
        #expect(aboutItem?.attributedTitle?.string.contains("v\(AppDelegate.appVersion)") == true)
        #expect(aboutItem?.action == #selector(AppDelegate.handleAbout))
        
        // Check for Updates action exists on AppDelegate
        #expect(appDelegate.responds(to: #selector(AppDelegate.handleCheckForUpdates)))
    }
    
    // MARK: - UpdateEngine Tests

    @Test
    func testUpdateEngineDetectsHomebrewViaBundlePath() {
        let bundlePath = "/opt/homebrew/Caskroom/nnts/2.0.1/NNTS.app"
        let source = UpdateEngine.detectInstallationSource(bundlePath: bundlePath) { _ in false }
        #expect(source == .homebrew)
    }


    @Test
    func testUpdateEngineDetectsHomebrewViaCaskroomDirectory() {
        let bundlePath = "/Applications/NNTS.app"
        let source = UpdateEngine.detectInstallationSource(bundlePath: bundlePath) { path in
            path == "/opt/homebrew/Caskroom/nnts"
        }
        #expect(source == .homebrew)

        let sourceIntel = UpdateEngine.detectInstallationSource(bundlePath: bundlePath) { path in
            path == "/usr/local/Caskroom/nnts"
        }
        #expect(sourceIntel == .homebrew)
    }


    @Test
    func testUpdateEngineDetectsDirectDownloadWhenNoCaskroom() {
        let bundlePath = "/Applications/NNTS.app"
        let source = UpdateEngine.detectInstallationSource(bundlePath: bundlePath) { _ in false }
        #expect(source == .directDownload)
    }


    @Test
    func testUpdateEngineDownloadUrlAndCommand() {
        #expect(UpdateEngine.directDmgDownloadUrl.absoluteString == "https://github.com/ellisglass/nnts/releases/latest/download/NNTS.dmg")
        #expect(UpdateEngine.homebrewUpgradeCommand == "brew update && brew upgrade --cask nnts")
    }


    @Test
    func testRunHomebrewUpgradeInTerminalUsesWorkspaceWithoutTouchingPasteboard() {
        var openedUrl: URL?
        let success = UpdateEngine.runHomebrewUpgradeInTerminal { url in
            openedUrl = url
            return true
        }
        
        #expect(success == true)
        #expect(openedUrl?.pathExtension == "command")
    }


    @Test
    func testTelemetryBufferRingCapacityAndFIFO() {
        let buffer = TelemetryBuffer.shared
        buffer.clear()
        #expect(buffer.getAll().isEmpty)

        // Append 350 items to verify 300-capacity FIFO truncation
        for i in 1...350 {
            buffer.append(category: "test", level: "INFO", message: "Event #\(i)")
        }

        let events = buffer.getAll()
        #expect(events.count == 300)
        #expect(events.first?.message == "Event #51")
        #expect(events.last?.message == "Event #350")

        let exportText = buffer.exportTimelineText()
        #expect(exportText.contains("Event #51"))
        #expect(exportText.contains("Event #350"))
        #expect(!exportText.contains("Event #1\n") && !exportText.contains("Event #50\n"))
    }


    @Test @MainActor
    func testDiagnosticArchiveCreation() throws {
        TelemetryBuffer.shared.clear()
        TelemetryBuffer.shared.append(category: "engine", level: "INFO", message: "Diagnostic test start")

        let zipURL = try DiagnosticBundleService.createDiagnosticArchive()
        defer { try? FileManager.default.removeItem(at: zipURL) }

        #expect(FileManager.default.fileExists(atPath: zipURL.path))
        #expect(zipURL.lastPathComponent == "nnts-diagnostic.zip")
        #expect(zipURL.path.contains("Downloads"))

        let attr = try FileManager.default.attributesOfItem(atPath: zipURL.path)
        let size = attr[.size] as? Int64 ?? 0
        #expect(size > 0, "ZIP archive must not be empty")

        let ghURL = DiagnosticBundleService.makeGitHubIssueURL(description: "Test issue")
        #expect(ghURL != nil)
        #expect(ghURL?.host == "github.com")
        #expect(ghURL?.path.contains("ellisglass/nnts/issues/new") == true)
        #expect(ghURL?.absoluteString.contains("%5BBug%20Report%5D") == true || ghURL?.absoluteString.contains("[Bug") == true)
    }


    @Test @MainActor
    func testFullDiagnosticReportIncludesSystemSummaryAndTimeline() {
        TelemetryBuffer.shared.clear()
        TelemetryBuffer.shared.append(category: "switcher", level: "INFO", message: "User triggered CapsLock+C")
        TelemetryBuffer.shared.append(category: "copy-on-select", level: "INFO", message: "Selection evaluated")

        let report = DiagnosticBundleService.makeFullDiagnosticReport()
        #expect(report.contains("=== NNTS System Diagnostic Summary ==="))
        #expect(report.contains("App Version:"))
        #expect(report.contains("macOS Version:"))
        #expect(report.contains("Accessibility Permissions:"))
        #expect(report.contains("License Status:"))
        #expect(report.contains("Copy-on-Select:"))
        #expect(report.contains("=== Event Timeline ==="))
        #expect(report.contains("User triggered CapsLock+C"))
        #expect(report.contains("Selection evaluated"))
    }


    @Test @MainActor
    func testTelemetryBufferPIISanitization() {
        let input = "Switched to Chrome profile 'john.appleseed@company.com' (Profile 1) for user alice.smith+work@gmail.com"
        let sanitized = TelemetryBuffer.sanitizePII(input)
        #expect(!sanitized.contains("john.appleseed@company.com"))
        #expect(!sanitized.contains("alice.smith+work@gmail.com"))
        #expect(sanitized.contains("[REDACTED_EMAIL]"))
    }


    @Test @MainActor
    func testLicenseEngineRejectsTamperedKeychainLicense() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        defer {
            LicenseEngine.testIgnoreReceiptCheckInTests = true
            engine.testOverrideProStatus = originalOverride
            engine.deactivate()
        }
        
        engine.testOverrideProStatus = nil
        // When receipt check is enforced, a raw key without valid receipt is rejected
        LicenseEngine.testIgnoreReceiptCheckInTests = false
        _ = engine.saveKeychainLicense(key: "NNTS-PIRATED-KEY-12345")
        engine.deleteKeychainReceipt()
        engine.deleteKeychainActivationId()
        LicenseEngine.storage.removeObject(forKey: "NNTSProReceiptToken")
        LicenseEngine.storage.removeObject(forKey: "NNTSProActivationId")
        LicenseEngine.storage.removeObject(forKey: "NNTSProLicenseKey")
        
        engine.checkLicenseStatus()
        #expect(engine.isPro == false, "Tampered license without cryptographic receipt must be rejected")
    }


    @Test @MainActor
    func testUnifiedLicenseBundleKeychainStorageAndTamperProtection() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        defer {
            LicenseEngine.testIgnoreReceiptCheckInTests = true
            engine.testOverrideProStatus = originalOverride
            engine.deactivate()
        }
        
        engine.testOverrideProStatus = nil
        LicenseEngine.testIgnoreReceiptCheckInTests = false
        
        let testKey = "NNTS-BUNDLE-TEST-KEY-1"
        let testAid = "act_bundle_\(UUID().uuidString)"
        let validReceipt = LicenseEngine.computeReceiptToken(key: testKey, activationId: testAid)
        
        // 1. Valid bundle in Keychain enables Pro
        let validBundle = LicenseBundle(key: testKey, activationId: testAid, receipt: validReceipt)
        let saved = engine.saveKeychainBundle(validBundle)
        #expect(saved == true)
        
        engine.checkLicenseStatus()
        #expect(engine.isPro == true)
        #expect(engine.activeLicenseKey == testKey)
        #expect(engine.activeActivationId == testAid)
        
        // 2. Tampered receipt in bundle must be rejected
        let tamperedBundle = LicenseBundle(key: testKey, activationId: testAid, receipt: "bogus_receipt_token")
        _ = engine.saveKeychainBundle(tamperedBundle)
        engine.checkLicenseStatus()
        #expect(engine.isPro == false, "Tampered receipt token in unified bundle must be rejected")
    }


    @Test @MainActor
    func testLegacyKeychainItemsMigrateToUnifiedBundle() {
        let engine = LicenseEngine.shared
        let originalOverride = engine.testOverrideProStatus
        defer {
            LicenseEngine.testIgnoreReceiptCheckInTests = true
            engine.testOverrideProStatus = originalOverride
            engine.deactivate()
        }
        
        engine.deactivate()
        engine.testOverrideProStatus = nil
        LicenseEngine.testIgnoreReceiptCheckInTests = false
        
        let legacyKey = "NNTS-LEGACY-MIGRATION-KEY"
        let legacyAid = "act_legacy_\(UUID().uuidString)"
        let legacyReceipt = LicenseEngine.computeReceiptToken(key: legacyKey, activationId: legacyAid)
        
        // Setup legacy separate items
        _ = engine.saveKeychainLicense(key: legacyKey)
        _ = engine.saveKeychainActivationId(id: legacyAid)
        _ = engine.saveKeychainReceipt(receipt: legacyReceipt)
        engine.deleteKeychainBundle()
        
        // Verify legacy items are present initially
        #expect(engine.readKeychainLicense() == legacyKey)
        #expect(engine.readKeychainBundle() == nil)
        
        // Run checkLicenseStatus - should migrate legacy items to unified bundle
        engine.checkLicenseStatus()
        #expect(engine.isPro == true)
        #expect(engine.activeLicenseKey == legacyKey)
        #expect(engine.activeActivationId == legacyAid)
        
        // Verify migration result: bundle created, legacy items purged
        let migratedBundle = engine.readKeychainBundle()
        #expect(migratedBundle != nil)
        #expect(migratedBundle?.key == legacyKey)
        #expect(migratedBundle?.activationId == legacyAid)
        #expect(migratedBundle?.receipt == legacyReceipt)
        
        #expect(engine.readKeychainLicense() == nil)
        #expect(engine.readKeychainActivationId() == nil)
        #expect(engine.readKeychainReceipt() == nil)
    }

}
