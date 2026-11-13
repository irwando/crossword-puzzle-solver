import Foundation
import os

/// Debug-only defaults from a git-ignored `LocalDefaults.plist` at the project root, copied into
/// Debug builds by a build phase. Values are registered (never persisted), so launch arguments and
/// saved settings still win. See `LocalDefaults.example.plist`.
enum LocalDefaults {
    static let resourceName = "LocalDefaults"

    static func register() {
        #if DEBUG
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "plist") else { return }
        let logger = Logger(subsystem: "com.irwando.crosswords", category: "debug")
        do {
            let data = try Data(contentsOf: url)
            guard let values = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                logger.error("LocalDefaults.plist must be a dictionary")
                return
            }
            UserDefaults.standard.register(defaults: values)
            logger.debug("Registered local defaults: \(values.keys.sorted(), privacy: .public)")
        } catch {
            logger.error("Couldn't read LocalDefaults.plist: \(error.localizedDescription, privacy: .public)")
        }
        #endif
    }
}
