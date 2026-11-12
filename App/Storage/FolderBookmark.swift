import Foundation
import OSLog

/// Persists access to the user-chosen puzzle folder across launches.
enum FolderBookmark {
    private static let log = Logger(subsystem: "com.irwando.crosswords", category: "bookmark")

    #if os(macOS)
    private static let creationOptions: URL.BookmarkCreationOptions = [.withSecurityScope]
    private static let resolutionOptions: URL.BookmarkResolutionOptions = [.withSecurityScope]
    #else
    private static let creationOptions: URL.BookmarkCreationOptions = []
    private static let resolutionOptions: URL.BookmarkResolutionOptions = []
    #endif

    static func save(_ url: URL, defaults: UserDefaults = .standard) throws {
        let data = try url.bookmarkData(options: creationOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: SettingsKey.folderBookmark)
    }

    /// Resolves the saved folder, refreshing a stale bookmark. Returns nil when none is saved or it no longer resolves.
    static func resolve(defaults: UserDefaults = .standard) -> URL? {
        guard let data = defaults.data(forKey: SettingsKey.folderBookmark) else { return nil }
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: data, options: resolutionOptions, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                try? save(url, defaults: defaults)
            }
            return url
        } catch {
            log.error("Could not resolve folder bookmark: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: SettingsKey.folderBookmark)
    }
}
