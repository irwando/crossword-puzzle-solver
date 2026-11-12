import CrosswordCore
import Foundation
import Observation
import OSLog
import PuzzleFormats

@Observable
@MainActor
final class PuzzleViewModel {
    enum LoadState {
        case loading
        case ready
        case failed(String)
    }

    enum SaveStatus: Equatable {
        case saved
        case pending
        case failed(String)
    }

    enum Confirmation: Identifiable {
        case revealPuzzle
        case resetPuzzle

        var id: Self { self }
    }

    enum Banner: Equatable {
        case solved
        case notQuite
        case checked(wrong: Int)
    }

    let url: URL
    private(set) var loadState: LoadState = .loading
    private(set) var session: SolveSession?
    private(set) var saveStatus: SaveStatus = .saved
    var banner: Banner?
    /// Destructive actions requested from menus wait here for the screen to confirm.
    var pendingConfirmation: Confirmation?

    @ObservationIgnored private var document: PuzzleDocument?
    /// The state most recently written to (or read from) disk.
    @ObservationIgnored private var persistedState: SolveState?
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var bannerTask: Task<Void, Never>?
    @ObservationIgnored private var presenter: FilePresenter?
    @ObservationIgnored private let io = PuzzleFileIO.shared
    @ObservationIgnored private let log = Logger(subsystem: "com.irwando.crosswords", category: "puzzle")
    @ObservationIgnored var onProgressChange: ((SolveState.Progress) -> Void)?

    static let saveDelay: Duration = .seconds(1)

    init(url: URL) {
        self.url = url
    }

    var canCheck: Bool { document?.canCheck ?? false }
    var format: PuzzleFormat? { document?.format }

    // MARK: Lifecycle

    func load(skipFilledSquares: Bool) async {
        let presenter = FilePresenter(url: url) { [weak self] in
            Task { @MainActor in await self?.reloadFromDisk() }
        }
        do {
            let loaded = try await io.read(url, presenter: presenter)
            let conflicts = await io.takeConflictStates(url)
            let merged = conflicts.reduce(loaded.state) { $0.fillingGaps(from: $1) }
            document = loaded
            persistedState = loaded.state
            session = SolveSession(
                puzzle: loaded.puzzle, state: merged,
                settings: SolveSettings(skipFilledSquares: skipFilledSquares)
            )
            if merged != loaded.state { scheduleSave() }
            presenter.start()
            self.presenter = presenter
            loadState = .ready
        } catch {
            log.error("Load failed for \(self.url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            loadState = .failed(error.localizedDescription)
        }
    }

    /// Saves any pending changes immediately and stops watching the file.
    func close() async {
        presenter?.stop()
        presenter = nil
        await flush()
    }

    // MARK: Actions

    func perform(_ action: SolveAction) {
        guard let current = session else { return }
        let next = current.performing(action)
        guard next != current else { return }
        session = next
        if next.state != current.state {
            stateDidChange(from: current, to: next, action: action)
        }
    }

    private func stateDidChange(from old: SolveSession, to new: SolveSession, action: SolveAction) {
        scheduleSave()
        let progress = new.progress
        onProgressChange?(progress)
        if progress.isSolved && !old.isSolved {
            showBanner(.solved, duration: .seconds(4))
        } else if !progress.isSolved, progress.filled == progress.total, old.progress.filled < progress.total, canCheck {
            showBanner(.notQuite, duration: .seconds(3))
        } else if case .check = action {
            let wrong = new.state.cells.filter { $0.marks.contains(.incorrect) }.count
            showBanner(.checked(wrong: wrong), duration: .seconds(2))
        }
    }

    private func showBanner(_ value: Banner, duration: Duration) {
        bannerTask?.cancel()
        banner = value
        bannerTask = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            banner = nil
        }
    }

    // MARK: Saving

    private func scheduleSave() {
        saveStatus = .pending
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: Self.saveDelay)
            guard !Task.isCancelled else { return }
            await save()
        }
    }

    func flush() async {
        saveTask?.cancel()
        saveTask = nil
        if saveStatus != .saved { await save() }
    }

    private func save() async {
        guard let document, let snapshot = session?.state else { return }
        guard snapshot != persistedState else {
            saveStatus = .saved
            return
        }
        do {
            try await io.write(document.replacingState(snapshot), to: url, presenter: presenter)
            persistedState = snapshot
            session = session?.markingSaved(snapshot)
            if session?.dirtyCells.isEmpty ?? true { saveStatus = .saved }
        } catch {
            log.error("Save failed: \(error.localizedDescription, privacy: .public)")
            saveStatus = .failed(error.localizedDescription)
        }
    }

    // MARK: Remote changes

    /// Called when another device (via iCloud) or app changed the file. Remote cells win except
    /// where we have unsaved local edits.
    func reloadFromDisk() async {
        guard let current = session else { return }
        do {
            let remote = try await io.read(url, presenter: presenter)
            let conflicts = await io.takeConflictStates(url)
            let remoteState = conflicts.reduce(remote.state) { $0.fillingGaps(from: $1) }
            guard remoteState != persistedState, remote.puzzle == current.puzzle else { return }
            document = remote
            persistedState = remote.state
            let merged = (session ?? current).merging(remote: remoteState)
            session = merged
            onProgressChange?(merged.progress)
            if merged.state != remote.state { scheduleSave() }
            log.info("Merged remote changes for \(self.url.lastPathComponent, privacy: .public)")
        } catch {
            log.error("Reload failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension PuzzleViewModel {
    var pencilOn: Bool { session?.settings.pencil ?? false }

    func togglePencil() {
        perform(.setPencil(!pencilOn))
    }
}
