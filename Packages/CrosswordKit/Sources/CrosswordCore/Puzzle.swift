import Foundation

public enum Direction: String, Sendable, Hashable, CaseIterable, Codable {
    case across
    case down

    public var toggled: Direction { self == .across ? .down : .across }
    public var letter: String { self == .across ? "A" : "D" }
}

/// One square of the grid.
public struct PuzzleCell: Sendable, Hashable {
    public enum Kind: Sendable, Hashable {
        case open
        case block
        /// Not part of the puzzle at all (ipuz `null`, jpz `void`). Rendered as empty space.
        case void
    }

    public var kind: Kind
    /// Correct answer; may be multiple characters (rebus). `nil` when unknown.
    public var solution: String?
    public var number: Int?
    public var isCircled: Bool
    public var isShaded: Bool

    public init(
        kind: Kind,
        solution: String? = nil,
        number: Int? = nil,
        isCircled: Bool = false,
        isShaded: Bool = false
    ) {
        self.kind = kind
        self.solution = solution
        self.number = number
        self.isCircled = isCircled
        self.isShaded = isShaded
    }

    public var isOpen: Bool { kind == .open }

    public static let block = PuzzleCell(kind: .block)
    public static let void = PuzzleCell(kind: .void)
}

public struct ClueID: Sendable, Hashable, Codable {
    public var direction: Direction
    public var number: Int

    public init(_ direction: Direction, _ number: Int) {
        self.direction = direction
        self.number = number
    }
}

public struct Clue: Sendable, Hashable, Identifiable {
    public var id: ClueID
    /// Displayed label (usually the number, but some formats allow e.g. "1/12").
    public var label: String
    public var text: String
    /// Cell indices (row-major), in reading order.
    public var cells: [Int]

    public var direction: Direction { id.direction }
    public var number: Int { id.number }

    public init(direction: Direction, number: Int, label: String? = nil, text: String, cells: [Int]) {
        self.id = ClueID(direction, number)
        self.label = label ?? String(number)
        self.text = text
        self.cells = cells
    }
}

public struct PuzzleMetadata: Sendable, Hashable {
    public var title: String
    public var author: String
    public var copyright: String
    public var notes: String

    public init(title: String = "", author: String = "", copyright: String = "", notes: String = "") {
        self.title = title
        self.author = author
        self.copyright = copyright
        self.notes = notes
    }
}

public struct Puzzle: Sendable, Hashable {
    public var width: Int
    public var height: Int
    public var cells: [PuzzleCell]
    public var clues: [Clue]
    public var metadata: PuzzleMetadata

    public init(width: Int, height: Int, cells: [PuzzleCell], clues: [Clue], metadata: PuzzleMetadata) {
        precondition(cells.count == width * height, "cell count must equal width * height")
        self.width = width
        self.height = height
        self.cells = cells
        self.clues = clues
        self.metadata = metadata
    }

    public var cellCount: Int { width * height }

    public func row(of index: Int) -> Int { index / width }
    public func column(of index: Int) -> Int { index % width }
    public func index(row: Int, column: Int) -> Int { row * width + column }

    public func isOpen(row: Int, column: Int) -> Bool {
        guard row >= 0, row < height, column >= 0, column < width else { return false }
        return cells[index(row: row, column: column)].isOpen
    }

    /// True when every open cell has a known solution, so check / reveal work.
    public var hasSolution: Bool {
        cells.allSatisfy { !$0.isOpen || ($0.solution?.isEmpty == false) }
    }

    public var openCellIndices: [Int] {
        cells.indices.filter { cells[$0].isOpen }
    }

    public func clues(_ direction: Direction) -> [Clue] {
        clues.filter { $0.direction == direction }
    }
}
