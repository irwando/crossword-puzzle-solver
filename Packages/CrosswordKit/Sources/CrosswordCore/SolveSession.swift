import Foundation

public struct Cursor: Sendable, Hashable {
    public var cell: Int
    public var direction: Direction

    public init(cell: Int, direction: Direction) {
        self.cell = cell
        self.direction = direction
    }
}

public struct SolveSettings: Sendable, Hashable, Codable {
    public var skipFilledSquares: Bool
    public var pencil: Bool

    public init(skipFilledSquares: Bool = true, pencil: Bool = false) {
        self.skipFilledSquares = skipFilledSquares
        self.pencil = pencil
    }
}

public enum AssistScope: String, Sendable, Hashable, CaseIterable {
    case square
    case word
    case puzzle
}

public enum Movement: Sendable, Hashable {
    case up, down, left, right

    var axis: Direction { (self == .left || self == .right) ? .across : .down }
    var delta: (row: Int, column: Int) {
        switch self {
        case .up: (-1, 0)
        case .down: (1, 0)
        case .left: (0, -1)
        case .right: (0, 1)
        }
    }
}

public enum SolveAction: Sendable, Hashable {
    case type(String)
    case backspace
    case deleteForward
    case move(Movement)
    case nextClue
    case previousClue
    case toggleDirection
    case select(cell: Int)
    case selectClue(ClueID)
    /// Esc / Insert: begins rebus entry, or commits it when already active.
    case toggleRebus
    case commitRebus
    case cancelRebus
    case check(AssistScope)
    case reveal(AssistScope)
    case clear(AssistScope)
    /// Clears every cell including revealed ones and all marks.
    case resetPuzzle
    case setPencil(Bool)
    case setSkipFilledSquares(Bool)
}

/// The complete, immutable state of solving one puzzle. Every action returns a new session.
public struct SolveSession: Sendable, Hashable {
    public let puzzle: Puzzle
    public let index: PuzzleIndex
    public internal(set) var state: SolveState
    public internal(set) var cursor: Cursor
    /// Non-nil while the player is entering a multi-letter rebus.
    public internal(set) var rebusBuffer: String?
    public internal(set) var settings: SolveSettings
    /// Cells changed since the last `markingClean()`, used to merge remote edits.
    public internal(set) var dirtyCells: Set<Int>

    public init(puzzle: Puzzle, state: SolveState? = nil, settings: SolveSettings = SolveSettings()) {
        self.puzzle = puzzle
        self.index = PuzzleIndex(puzzle: puzzle)
        let resolvedState = state.flatMap { $0.cells.count == puzzle.cellCount ? $0 : nil }
        self.state = resolvedState ?? .empty(for: puzzle)
        self.settings = settings
        self.rebusBuffer = nil
        self.dirtyCells = []
        let firstClue = puzzle.clues.first
        let startCell = firstClue?.cells.first ?? puzzle.openCellIndices.first ?? 0
        self.cursor = Cursor(cell: startCell, direction: firstClue?.direction ?? .across)
    }

    public func performing(_ action: SolveAction) -> SolveSession {
        var next = self
        next.apply(action)
        return next
    }

    public func markingClean() -> SolveSession {
        var next = self
        next.dirtyCells = []
        return next
    }

    /// Marks clean only the cells whose current value matches what was persisted, so edits made
    /// while a save was in flight stay dirty.
    public func markingSaved(_ saved: SolveState) -> SolveSession {
        guard saved.cells.count == state.cells.count else { return self }
        var next = self
        next.dirtyCells = Set(state.cells.indices.filter { state.cells[$0] != saved.cells[$0] })
        return next
    }

    /// Adopts `remote` for every cell not edited locally since the last save.
    public func merging(remote: SolveState) -> SolveSession {
        guard remote.cells.count == state.cells.count else { return self }
        var next = self
        for cell in remote.cells.indices where !dirtyCells.contains(cell) {
            next.state.cells[cell] = remote.cells[cell]
        }
        return next
    }

    // MARK: Queries

    public var progress: SolveState.Progress { state.progress(in: puzzle) }
    public var isSolved: Bool { progress.isSolved }

    public var currentClue: Clue? { clue(for: cursor.cell, direction: cursor.direction) }

    public var crossingClue: Clue? { clue(for: cursor.cell, direction: cursor.direction.toggled) }

    public func clue(for cell: Int, direction: Direction) -> Clue? {
        index.clueIndex(for: cell, direction: direction).map { puzzle.clues[$0] }
    }

    public var currentWordCells: [Int] { currentClue?.cells ?? [cursor.cell] }

    public func isLocked(_ cell: Int) -> Bool {
        state.cells[cell].marks.contains(.revealed)
    }

    // MARK: Dispatch

    mutating func apply(_ action: SolveAction) {
        switch action {
        case .type(let text): type(text)
        case .backspace: backspace()
        case .deleteForward: clearCell(cursor.cell)
        case .move(let movement): move(movement)
        case .nextClue: jumpClue(by: 1)
        case .previousClue: jumpClue(by: -1)
        case .toggleDirection: toggleDirection()
        case .select(let cell): select(cell)
        case .selectClue(let id): selectClue(id)
        case .toggleRebus: rebusBuffer == nil ? beginRebus() : commitRebus()
        case .commitRebus: commitRebus()
        case .cancelRebus: rebusBuffer = nil
        case .check(let scope): check(scope)
        case .reveal(let scope): reveal(scope)
        case .clear(let scope): clear(scope)
        case .resetPuzzle: resetPuzzle()
        case .setPencil(let on): settings.pencil = on
        case .setSkipFilledSquares(let on): settings.skipFilledSquares = on
        }
    }

    mutating func setCell(_ cell: Int, _ newValue: CellState) {
        guard state.cells[cell] != newValue else { return }
        state.cells[cell] = newValue
        dirtyCells.insert(cell)
    }

    func cells(in scope: AssistScope) -> [Int] {
        switch scope {
        case .square: [cursor.cell]
        case .word: currentWordCells
        case .puzzle: puzzle.openCellIndices
        }
    }
}
