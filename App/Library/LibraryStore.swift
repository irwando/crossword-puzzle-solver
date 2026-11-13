import CrosswordCore
import Foundation
import Observation
import OSLog
import PuzzleFormats

struct PuzzleSummary: Sendable, Hashable {
    var title: String
    var author: String
    var format: PuzzleFormat
    var progress: SolveState.Progress
    var width: Int
    var height: Int
    /// Publication date from the file's date field, title, file name, or copyright line.
    var published: PuzzleDate?

    var sizeLabel: String { "\(width)×\(height)" }
}

struct PuzzleItem: Identifiable, Hashable, Sendable {
    let url: URL
    let fileName: String
    /// Subfolder path relative to the library folder ("" for top level).
    let folder: String
    let modified: Date
    /// When the file was added; the fallback for puzzles with no publication date.
    let created: Date
    let isDownloaded: Bool
    var summary: PuzzleSummary?
    var loadError: String?

    var id: URL { url }
    var displayTitle: String {
        if let title = summary?.title, !title.isEmpty { return title }
        return (fileName as NSString).deletingPathExtension
    }
}

@Observable
@MainActor
final class LibraryStore {
    private(set) var folderURL: URL?
    private(set) var items: [PuzzleItem] = []
    private(set) var isRefreshing = false
    var errorMessage: String?

    @ObservationIgnored private var presenter: FilePresenter?
    @ObservationIgnored private var summaryCache: [URL: (modified: Date, summary: PuzzleSummary)] = [:]
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?
    @ObservationIgnored private let io = PuzzleFileIO()
    @ObservationIgnored private let log = Logger(subsystem: "com.irwando.crosswords", category: "library")

    init() {
        if let url = Self.debugFolderOverride() ?? FolderBookmark.resolve() {
            open(url)
        }
    }

    // MARK: Folder

    func chooseFolder(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        do {
            try FolderBookmark.save(url)
        } catch {
            errorMessage = "Couldn't remember this folder: \(error.localizedDescription)"
            log.error("Bookmark save failed: \(error.localizedDescription, privacy: .public)")
        }
        if accessing { url.stopAccessingSecurityScopedResource() }
        open(FolderBookmark.resolve() ?? url)
    }

    func forgetFolder() {
        close()
        FolderBookmark.clear()
        items = []
        summaryCache = [:]
    }

    private func open(_ url: URL) {
        close()
        _ = url.startAccessingSecurityScopedResource()
        folderURL = url
        let presenter = FilePresenter(url: url) { [weak self] in
            Task { @MainActor in self?.scheduleRefresh() }
        }
        presenter.start()
        self.presenter = presenter
        refresh()
    }

    private func close() {
        presenter?.stop()
        presenter = nil
        folderURL?.stopAccessingSecurityScopedResource()
        folderURL = nil
    }

    // MARK: Listing

    func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            refresh()
        }
    }

    func refresh() {
        guard let folderURL else { return }
        refreshTask?.cancel()
        isRefreshing = true
        refreshTask = Task {
            let listed = await Task.detached(priority: .userInitiated) { Self.listPuzzles(in: folderURL) }.value
            guard !Task.isCancelled else { return }
            items = listed.map { item in
                var copy = item
                if let cached = summaryCache[item.url], cached.modified == item.modified { copy.summary = cached.summary }
                return copy
            }
            await loadSummaries()
            isRefreshing = false
        }
    }

    private func loadSummaries() async {
        for item in items where item.summary == nil && item.isDownloaded {
            guard !Task.isCancelled else { return }
            do {
                let document = try await io.read(item.url)
                let puzzle = document.puzzle
                let summary = PuzzleSummary(
                    title: puzzle.metadata.title,
                    author: puzzle.metadata.author,
                    format: document.format,
                    progress: document.state.progress(in: puzzle),
                    width: puzzle.width,
                    height: puzzle.height,
                    published: PublicationDate.resolve(metadata: puzzle.metadata, fileName: item.fileName)
                )
                summaryCache[item.url] = (item.modified, summary)
                update(item.url) { $0.summary = summary; $0.loadError = nil }
            } catch {
                update(item.url) { $0.loadError = error.localizedDescription }
            }
        }
    }

    /// Keeps the list's progress in sync with a puzzle being solved.
    func updateProgress(for url: URL, progress: SolveState.Progress) {
        update(url) { item in
            item.summary?.progress = progress
        }
        if var cached = summaryCache[url] {
            cached.summary.progress = progress
            summaryCache[url] = cached
        }
    }

    private func update(_ url: URL, _ change: (inout PuzzleItem) -> Void) {
        guard let position = items.firstIndex(where: { $0.url == url }) else { return }
        var item = items[position]
        change(&item)
        items[position] = item
    }

    nonisolated static func listPuzzles(in folder: URL) -> [PuzzleItem] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .creationDateKey, .isRegularFileKey, .ubiquitousItemDownloadingStatusKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: keys, options: [.skipsPackageDescendants]
        ) else { return [] }

        var results: [PuzzleItem] = []
        let basePath = folder.standardizedFileURL.path
        for case let url as URL in enumerator {
            var name = url.lastPathComponent
            var target = url
            var downloaded = true
            // Legacy iCloud placeholders look like ".Name.puz.icloud".
            if name.hasPrefix("."), name.hasSuffix(".icloud") {
                name = String(name.dropFirst().dropLast(".icloud".count))
                target = url.deletingLastPathComponent().appendingPathComponent(name)
                downloaded = false
            } else if name.hasPrefix(".") {
                continue
            }
            guard PuzzleFormat.fileExtensions.contains((name as NSString).pathExtension.lowercased()) else { continue }

            let values = try? url.resourceValues(forKeys: Set(keys))
            if let status = values?.ubiquitousItemDownloadingStatus, status == .notDownloaded { downloaded = false }
            if !downloaded { try? FileManager.default.startDownloadingUbiquitousItem(at: target) }

            let parent = target.deletingLastPathComponent().standardizedFileURL.path
            let folderName = parent.hasPrefix(basePath) ? String(parent.dropFirst(basePath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/")) : ""
            results.append(PuzzleItem(
                url: target, fileName: name, folder: folderName,
                modified: values?.contentModificationDate ?? .distantPast,
                created: values?.creationDate ?? values?.contentModificationDate ?? .distantPast,
                isDownloaded: downloaded
            ))
        }
        return results
    }

    private static func debugFolderOverride() -> URL? {
        #if DEBUG
        guard let path = UserDefaults.standard.string(forKey: "CrosswordsFolder") else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
        #else
        return nil
        #endif
    }
}
