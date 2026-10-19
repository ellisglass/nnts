import Foundation
import Security
import CryptoKit
import os

public struct LicenseBundle: Codable, Equatable, Sendable {
    public let key: String
    public let activationId: String
    public let receipt: String
    
    public init(key: String, activationId: String, receipt: String) {
        self.key = key
        self.activationId = activationId
        self.receipt = receipt
    }
}

@MainActor
public final class LicenseEngine: ObservableObject, @unchecked Sendable {
    public static let shared = LicenseEngine()
    
    /// Computes a cryptographically verified receipt token to prevent UserDefaults spoofing (defaults write)
    public static func computeReceiptToken(key: String, activationId: String) -> String {
        let raw = "\(key.trimmingCharacters(in: .whitespacesAndNewlines)):\(activationId.trimmingCharacters(in: .whitespacesAndNewlines)):\(polarOrganizationId):nnts_receipt_salt_2026"
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    public static let productionServiceName = "com.almosteleven.nnts.license"
    public static var serviceName: String {
        return isRunningTests ? "com.almosteleven.nnts.license.test" : productionServiceName
    }
    
    public static var storage: UserDefaults {
        if isRunningTests {
            return UserDefaults(suiteName: "com.almosteleven.nnts.tests") ?? .standard
        }
        return .standard
    }
    
    public static let bundleAccount = "pro_license_bundle"
    public static let licenseAccount = "pro_license_key"
    public static let activationAccount = "pro_activation_id"
    public static let receiptAccount = "pro_receipt_token"
    public static let proPrice = "$19 Lifetime"
    public static let freeSlotsLimit = 5
    public static let freePinnedAppsLimit = 4 // 1 browser hub slot + 4 user pinned app slots = 5 free slots
    
    public static let polarCheckoutUrl = "https://buy.polar.sh/polar_cl_v5lBa882Ea4dkTo9gvABMVxVbMgRyjkkhUcY43ktCAo"
    public static let polarActivateEndpoint = "https://api.polar.sh/v1/customer-portal/license-keys/activate"
    public static let polarDeactivateEndpoint = "https://api.polar.sh/v1/customer-portal/license-keys/deactivate"
    public static let polarOrganizationId = "fabcbc99-df59-4b60-9485-20a8dddca3c3"
    
    public enum ActivationResult: Equatable, Sendable {
        case success
        case invalidKey(String)
        case activationLimitReached
        case networkError(String)
    }
    
    public static var isRunningTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
               ProcessInfo.processInfo.arguments.contains(where: { $0.contains(".xctest") || $0.contains("swift-testing") }) ||
               NSClassFromString("XCTestCase") != nil
    }
    
    private let logger = Logger(subsystem: "com.almosteleven.nnts", category: "license")
    
    /// Test hook to override Pro status during automated unit tests
    public var testOverrideProStatus: Bool? = nil
    /// Test hook to mock online Polar activation responses in automated tests
    public var testMockOnlineValidationResult: Bool? = nil
    /// Test hook to control whether receipt verification is strictly enforced during unit tests
    public static var testIgnoreReceiptCheckInTests: Bool = true
    
    @Published private var internalIsPro: Bool = false
    @Published public private(set) var activeLicenseKey: String? = nil
    @Published public private(set) var activeActivationId: String? = nil
    
    public var isPro: Bool {
        if let override = testOverrideProStatus {
            return override
        }
        return internalIsPro
    }
    
    public init() {
        checkLicenseStatus()
    }
    
    public func checkLicenseStatus() {
        if let override = testOverrideProStatus {
            self.internalIsPro = override
            return
        }
        
        // 1. Try reading unified bundle from macOS Keychain (1 single access)
        if let bundle = readKeychainBundle(),
           validateLicenseKey(bundle.key),
           !bundle.activationId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let expectedReceipt = Self.computeReceiptToken(key: bundle.key, activationId: bundle.activationId)
            if bundle.receipt == expectedReceipt || (Self.isRunningTests && Self.testIgnoreReceiptCheckInTests) {
                self.internalIsPro = true
                self.activeLicenseKey = bundle.key
                self.activeActivationId = bundle.activationId
                return
            } else {
                logger.warning("Tampered or unverified Keychain license bundle detected; ignoring.")
            }
        }
        
        // 2. Migration fallback: Check legacy separate Keychain items if unified bundle is absent
        if let key = readKeychainLicense(),
           validateLicenseKey(key),
           let aid = readKeychainActivationId() ?? Self.storage.string(forKey: "NNTSProActivationId"),
           !aid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let savedReceipt = readKeychainReceipt() ?? Self.storage.string(forKey: "NNTSProReceiptToken")
            let expectedReceipt = Self.computeReceiptToken(key: key, activationId: aid)
            if savedReceipt == expectedReceipt || (Self.isRunningTests && Self.testIgnoreReceiptCheckInTests) {
                self.internalIsPro = true
                self.activeLicenseKey = key
                self.activeActivationId = aid
                
                // Migrate to unified bundle and cleanup legacy items
                let migratedBundle = LicenseBundle(key: key, activationId: aid, receipt: savedReceipt ?? expectedReceipt)
                if saveKeychainBundle(migratedBundle) {
                    deleteKeychainLicense()
                    deleteKeychainActivationId()
                    deleteKeychainReceipt()
                    logger.info("Successfully migrated legacy Keychain license to unified bundle.")
                }
                return
            } else {
                logger.warning("Tampered or unverified Keychain license detected; ignoring.")
            }
        }
        
        // 3. Fallback to UserDefaults (Requires valid activationId and cryptographic receipt verification)
        if let fallbackKey = Self.storage.string(forKey: "NNTSProLicenseKey"),
           validateLicenseKey(fallbackKey),
           let fallbackAid = Self.storage.string(forKey: "NNTSProActivationId"),
           !fallbackAid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let savedReceipt = Self.storage.string(forKey: "NNTSProReceiptToken")
            let expectedReceipt = Self.computeReceiptToken(key: fallbackKey, activationId: fallbackAid)
            if savedReceipt == expectedReceipt || (Self.isRunningTests && Self.testIgnoreReceiptCheckInTests) {
                self.internalIsPro = true
                self.activeLicenseKey = fallbackKey
                self.activeActivationId = fallbackAid
                // Promote UserDefaults license to unified Keychain bundle
                let promotedBundle = LicenseBundle(key: fallbackKey, activationId: fallbackAid, receipt: savedReceipt ?? expectedReceipt)
                _ = saveKeychainBundle(promotedBundle)
                return
            } else {
                logger.warning("Tampered or unverified UserDefaults license detected; ignoring.")
            }
        }
        
        self.internalIsPro = false
        self.activeLicenseKey = nil
        self.activeActivationId = nil
    }
    
    public func validateLicenseKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let upper = trimmed.uppercased()
        
        // Polar customer keys (prefix NNTS-)
        if upper.hasPrefix("NNTS-") && trimmed.count >= 8 {
            return true
        }
        
        return false
    }
    
    public func validateWithPolar(key: String, timeout: TimeInterval = 5.0) -> Bool {
        if let mock = testMockOnlineValidationResult {
            return mock
        }
        
        // In headless tests without mock, don't execute unmocked network calls; fail explicitly
        if Self.isRunningTests && testMockOnlineValidationResult == nil {
            return false
        }
        
        guard let url = URL(string: Self.polarActivateEndpoint) else { return false }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("NNTS/2.0.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = timeout
        
        let label = Host.current().localizedName ?? "Mac"
        let payload: [String: Any] = [
            "key": key,
            "organization_id": Self.polarOrganizationId,
            "label": label
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            return false
        }
        request.httpBody = httpBody
        
        let semaphore = DispatchSemaphore(value: 0)
        var isSuccess = false
        var parsedActivationId: String? = nil
        
        let session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: OperationQueue())
        let task = session.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error = error {
                self.logger.error("Polar license activation network error: \(error.localizedDescription)")
                return
            }
            guard let httpResponse = response as? HTTPURLResponse else {
                return
            }
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                isSuccess = true
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let aid = json["id"] as? String {
                    parsedActivationId = aid
                }
            } else {
                let bodyString = data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                self.logger.warning("Polar activation rejected with status \(httpResponse.statusCode): \(bodyString)")
            }
        }
        task.resume()
        
        _ = semaphore.wait(timeout: .now() + timeout)
        if isSuccess, let aid = parsedActivationId {
            _ = saveKeychainActivationId(id: aid)
            Self.storage.set(aid, forKey: "NNTSProActivationId")
            self.activeActivationId = aid
        }
        return isSuccess
    }
    
    public func activateOnlineDetailed(key: String) async -> ActivationResult {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validateLicenseKey(trimmed) else {
            logger.warning("License activation rejected: invalid key format for '\(key)'.")
            return .invalidKey("Invalid key format. NNTS license keys start with 'NNTS-'.")
        }
        
        if let mock = testMockOnlineValidationResult {
            if mock {
                _ = activateOffline(key: trimmed)
                return .success
            } else {
                return .invalidKey("License key rejected by validation service.")
            }
        }
        
        if Self.isRunningTests && testMockOnlineValidationResult == nil {
            return .invalidKey("No mock configured for online validation in automated test run.")
        }
        
        guard let url = URL(string: Self.polarActivateEndpoint) else {
            return .networkError("Invalid validation endpoint URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("NNTS/2.0.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8.0
        
        let label = Host.current().localizedName ?? "Mac"
        let payload: [String: Any] = [
            "key": trimmed,
            "organization_id": Self.polarOrganizationId,
            "label": label
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            return .networkError("Failed to serialize activation payload.")
        }
        request.httpBody = httpBody
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .networkError("Invalid server response.")
            }
            if httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 {
                var activationId: String? = nil
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let aid = json["id"] as? String {
                    activationId = aid
                }
                _ = activateOffline(key: trimmed, activationId: activationId)
                return .success
            } else if httpResponse.statusCode == 403 || httpResponse.statusCode == 400 {
                let body = String(data: data, encoding: .utf8) ?? ""
                if body.lowercased().contains("limit") || body.lowercased().contains("maximum") {
                    return .activationLimitReached
                } else {
                    return .invalidKey("This license key could not be activated (\(httpResponse.statusCode)).")
                }
            } else if httpResponse.statusCode == 404 {
                return .invalidKey("License key not found. Please verify the key entered.")
            } else {
                let body = String(data: data, encoding: .utf8) ?? ""
                logger.warning("Polar async activation rejected (\(httpResponse.statusCode)): \(body)")
                return .invalidKey("Validation error (\(httpResponse.statusCode)).")
            }
        } catch {
            logger.error("Polar async activation error: \(error.localizedDescription)")
            return .networkError(error.localizedDescription)
        }
    }
    
    public func activateOnline(key: String) async -> Bool {
        return await activateOnlineDetailed(key: key) == .success
    }
    
    @discardableResult
    public func activate(key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard validateLicenseKey(trimmed) else {
            logger.warning("License activation rejected: invalid key format for '\(key)'.")
            return false
        }
        
        // Customer key: validate with Polar endpoint
        let valid = validateWithPolar(key: trimmed)
        guard valid else {
            logger.warning("License validation failed via Polar endpoint for '\(key)'.")
            return false
        }
        
        return activateOffline(key: trimmed, activationId: self.activeActivationId)
    }
    
    private func activateOffline(key: String, activationId: String? = nil) -> Bool {
        let effectiveAid = activationId ?? self.activeActivationId ?? (Self.isRunningTests ? "act_test_\(UUID().uuidString)" : "")
        Self.storage.set(key, forKey: "NNTSProLicenseKey")
        if !effectiveAid.isEmpty {
            Self.storage.set(effectiveAid, forKey: "NNTSProActivationId")
            let receipt = Self.computeReceiptToken(key: key, activationId: effectiveAid)
            Self.storage.set(receipt, forKey: "NNTSProReceiptToken")
            let bundle = LicenseBundle(key: key, activationId: effectiveAid, receipt: receipt)
            _ = saveKeychainBundle(bundle)
            deleteKeychainLicense()
            deleteKeychainActivationId()
            deleteKeychainReceipt()
            self.activeActivationId = effectiveAid
        } else {
            let receipt = Self.computeReceiptToken(key: key, activationId: "")
            let bundle = LicenseBundle(key: key, activationId: "", receipt: receipt)
            _ = saveKeychainBundle(bundle)
        }
        self.testOverrideProStatus = nil
        self.internalIsPro = true
        self.activeLicenseKey = key
        logger.info("NNTS Pro activated successfully with key: '\(key)'!")
        return true
    }
    
    public func deactivate() {
        if let key = activeLicenseKey, let aid = activeActivationId {
            deactivateOnPolar(key: key, activationId: aid)
        }
        deleteKeychainBundle()
        deleteKeychainLicense()
        deleteKeychainActivationId()
        deleteKeychainReceipt()
        Self.storage.removeObject(forKey: "NNTSProLicenseKey")
        Self.storage.removeObject(forKey: "NNTSProActivationId")
        Self.storage.removeObject(forKey: "NNTSProReceiptToken")
        self.testOverrideProStatus = nil
        self.internalIsPro = false
        self.activeLicenseKey = nil
        self.activeActivationId = nil
        logger.info("NNTS Pro deactivated.")
    }
    
    private func deactivateOnPolar(key: String, activationId: String) {
        guard let url = URL(string: Self.polarDeactivateEndpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("NNTS/2.0.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 5.0
        
        let payload: [String: Any] = [
            "key": key,
            "organization_id": Self.polarOrganizationId,
            "activation_id": activationId
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else { return }
        request.httpBody = httpBody
        
        let session = URLSession(configuration: .ephemeral, delegate: nil, delegateQueue: OperationQueue())
        session.dataTask(with: request) { [logger] _, response, error in
            if let error = error {
                logger.warning("Polar deactivation notice: \(error.localizedDescription)")
            } else if let http = response as? HTTPURLResponse {
                logger.info("Polar deactivation status: \(http.statusCode)")
            }
        }.resume()
    }
    
    // MARK: - Keychain Operations
    public func readKeychainBundle() -> LicenseBundle? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.bundleAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(LicenseBundle.self, from: data)
    }
    
    @discardableResult
    public func saveKeychainBundle(_ bundle: LicenseBundle) -> Bool {
        guard let data = try? JSONEncoder().encode(bundle) else { return false }
        
        deleteKeychainBundle()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.bundleAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func deleteKeychainBundle() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.bundleAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    public func readKeychainLicense() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.licenseAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    public func saveKeychainLicense(key: String) -> Bool {
        guard let data = key.data(using: .utf8) else { return false }
        
        deleteKeychainLicense()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.licenseAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func deleteKeychainLicense() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.licenseAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    public func readKeychainActivationId() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.activationAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    public func saveKeychainActivationId(id: String) -> Bool {
        guard let data = id.data(using: .utf8) else { return false }
        
        deleteKeychainActivationId()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.activationAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func deleteKeychainActivationId() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.activationAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    public func readKeychainReceipt() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.receiptAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    public func saveKeychainReceipt(receipt: String) -> Bool {
        guard let data = receipt.data(using: .utf8) else { return false }
        
        deleteKeychainReceipt()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.receiptAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    public func deleteKeychainReceipt() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.serviceName,
            kSecAttrAccount as String: Self.receiptAccount
        ]
        SecItemDelete(query as CFDictionary)
    }
}
