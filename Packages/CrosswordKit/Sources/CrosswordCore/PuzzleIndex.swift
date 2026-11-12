import Foundation

/// Precomputed lookups from cells to the clues that cover them.
public struct PuzzleIndex: Sendable, Hashable {
    /// Position in `puzzle.clues` of the across / down clue covering each cell.
    public let acrossClue: [Int?]
    public let downClue: [Int?]
    public let clueByID: [ClueID: Int]

    public init(puzzle: Puzzle) {
        var across = [Int?](repeating: nil, count: puzzle.cellCount)
        var down = [Int?](repeating: nil, count: puzzle.cellCount)
        var byID: [ClueID: Int] = [:]
        for (position, clue) in puzzle.clues.enumerated() {
            byID[clue.id] = position
            for cell in clue.cells where cell >= 0 && cell < puzzle.cellCount {
                switch clue.direction {
                case .across where across[cell] == nil: across[cell] = position
                case .down where down[cell] == nil: down[cell] = position
                default: break
                }
            }
        }
        self.acrossClue = across
        self.downClue = down
        self.clueByID = byID
    }

    public func clueIndex(for cell: Int, direction: Direction) -> Int? {
        guard cell >= 0, cell < acrossClue.count else { return nil }
        return direction == .across ? acrossClue[cell] : downClue[cell]
    }
}
