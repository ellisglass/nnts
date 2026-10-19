import Cocoa
import AppKit

@main
struct NNTSApp {
    static func main() {
        if NSClassFromString("XCTest") != nil ||
           ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
           ProcessInfo.processInfo.environment["XCTestBundlePath"] != nil ||
           ProcessInfo.processInfo.environment["SWIFT_DETERMINISTIC_HASHING"] != nil {
            print("Running in test environment, skipping NSApplication event loop.")
            return
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
