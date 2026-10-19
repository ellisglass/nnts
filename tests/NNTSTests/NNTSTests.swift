import Foundation
import Testing
import AppKit
@testable import NNTS

@Suite(.serialized)
struct NNTSUnitTests {
    // 156 automated unit tests are modularized across 7 domain test suites:
    // - CapsLockAndKeyCodesTests.swift (10 tests)
    // - ChromeProfileEngineTests.swift (25 tests)
    // - CopyOnSelectEngineTests.swift (36 tests)
    // - AppGroupEngineTests.swift (28 tests)
    // - FinderTidyEngineTests.swift (7 tests)
    // - HUDAndViewsTests.swift (30 tests)
    // - LicenseAndUpdateTests.swift (20 tests)
}

typealias ChromeQuickAccessUnitTests = NNTSUnitTests
