// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "NNTS",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "ChromeQuickAccess",
            dependencies: [],
            path: "src/ChromeQuickAccess",
            exclude: ["Info.plist", "main.swift", "Resources"],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"])
            ],
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "ChromeQuickAccessTests",
            dependencies: [
                "ChromeQuickAccess",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "tests/ChromeQuickAccessTests"
        )
    ]
)
