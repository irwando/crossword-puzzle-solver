import Foundation

public struct CellMarks: OptionSet, Sendable, Hashable, Codable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }

    /// Currently wrong after a check.
    public static let incorrect = CellMarks(rawValue: 1 << 0)
    /// Was wrong at some point (persists after correction).
    public static let previouslyIncorrect = CellMarks(rawValue: 1 << 1)
    /// Filled by reveal; locked against editing.
    public static let revealed = CellMarks(rawValue: 1 << 2)
    /// Tentative (pencil) entry.
    public static let pencil = CellMarks(rawValue: 1 << 3)
}

public struct CellState: Sendable, Hashable {
    /// Uppercased entry; empty when blank. May contain several characters (rebus).
    public var entry: String
    public var marks: CellMarks

    public init(entry: String = "", marks: CellMarks = []) {
        self.entry = entry
        self.marks = marks
    }

    public var isEmpty: Bool { entry.isEmpty }
    public static let empty = CellState()
}

public struct SolveState: Sendable, Hashable {
    public var cells: [CellState]

    public init(cells: [CellState]) {
        self.cells = cells
    }

    public static func empty(for puzzle: Puzzle) -> SolveState {
        SolveState(cells: Array(repeating: .empty, count: puzzle.cellCount))
    }

    public subscript(index: Int) -> CellState {
        get { cells[index] }
        set { cells[index] = newValue }
    }

    public func replacing(_ index: Int, with cell: CellState) -> SolveState {
        var copy = self
        copy.cells[index] = cell
        return copy
    }
}

public extension SolveState {
    struct Progress: Sendable, Hashable {
        public var filled: Int
        public var total: Int
        public var isSolved: Bool

        public var fraction: Double { total == 0 ? 0 : Double(filled) / Double(total) }
    }

    func progress(in puzzle: Puzzle) -> Progress {
        let open = puzzle.openCellIndices
        let filled = open.filter { !cells[$0].isEmpty }.count
        let solved = puzzle.hasSolution && !open.isEmpty
            && open.allSatisfy { AnswerMatcher.matches(entry: cells[$0].entry, solution: puzzle.cells[$0].solution) }
        return Progress(filled: filled, total: open.count, isSolved: solved)
    }
}

public enum AnswerMatcher {
    /// Case-insensitive comparison of a player entry against the solution.
    public static func matches(entry: String, solution: String?) -> Bool {
        guard let solution, !solution.isEmpty, !entry.isEmpty else { return false }
        return entry.uppercased() == solution.uppercased()
    }

    public static func normalize(_ text: String) -> String {
        text.uppercased().filter { !$0.isWhitespace && !$0.isNewline }
    }
}
