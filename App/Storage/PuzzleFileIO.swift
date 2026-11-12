import CrosswordCore
import Foundation
import PuzzleFormats

/// Coordinated reads and writes so iCloud Drive and other devices see consistent files.
/// All work runs off the main actor.
actor PuzzleFileIO {
    static let shared = PuzzleFileIO()

    func read(_ url: URL, presenter: (any NSFilePresenter)? = nil) throws -> PuzzleDocument {
        try PuzzleCodec.decode(readData(url, presenter: presenter))
    }

    func write(_ document: PuzzleDocument, to url: URL, presenter: (any NSFilePresenter)? = nil) throws {
        let data = try document.encoded()
        var coordinationError: NSError?
        var writeError: (any Error)?
        NSFileCoordinator(filePresenter: presenter).coordinate(
            writingItemAt: url, options: .forReplacing, error: &coordinationError
        ) { target in
            do { try data.write(to: target, options: .atomic) } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError { throw error }
    }

    /// Solve states from iCloud conflict versions of `url`. The conflicts are marked resolved and removed,
    /// so the caller must merge the returned states into the current file.
    func takeConflictStates(_ url: URL) -> [SolveState] {
        guard let versions = NSFileVersion.unresolvedConflictVersionsOfItem(at: url), !versions.isEmpty else { return [] }
        let states = versions.compactMap { version -> SolveState? in
            guard let data = try? Data(contentsOf: version.url) else { return nil }
            return try? PuzzleCodec.decode(data).state
        }
        for version in versions { version.isResolved = true }
        try? NSFileVersion.removeOtherVersionsOfItem(at: url)
        return states
    }

    private func readData(_ url: URL, presenter: (any NSFilePresenter)?) throws -> Data {
        var coordinationError: NSError?
        var result: Result<Data, any Error> = .failure(CocoaError(.fileReadUnknown))
        NSFileCoordinator(filePresenter: presenter).coordinate(
            readingItemAt: url, options: [], error: &coordinationError
        ) { target in
            result = Result { try Data(contentsOf: target) }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }
}

extension SolveState {
    /// Conflict merge: keep our cell unless it's empty and the other version has an entry.
    func fillingGaps(from other: SolveState) -> SolveState {
        guard other.cells.count == cells.count else { return self }
        return SolveState(cells: zip(cells, other.cells).map { mine, theirs in
            mine.isEmpty && !theirs.isEmpty ? theirs : mine
        })
    }
}
