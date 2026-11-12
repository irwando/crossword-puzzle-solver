import CrosswordCore

enum TestPuzzles {
    /// 3x3 with one block in the center-right:
    ///   C A T
    ///   A # E
    ///   B E D      (solutions; # = block)
    static func small() -> Puzzle {
        let rows = ["CAT", "A#E", "BED"]
        return make(rows: rows)
    }

    /// 5x5 word square HEART / EMBER / ABUSE / RESIN / TREND.
    static func wordSquare() -> Puzzle {
        make(rows: ["HEART", "EMBER", "ABUSE", "RESIN", "TREND"])
    }

    static func make(rows: [String], rebus: [Int: String] = [:]) -> Puzzle {
        let height = rows.count
        let width = rows[0].count
        let letters = rows.flatMap { Array($0) }
        let isOpen: (Int) -> Bool = { letters[$0] != "#" }
        let entries = GridNumbering.entries(width: width, height: height, isOpen: isOpen)
        var cells = letters.enumerated().map { i, ch in
            ch == "#" ? PuzzleCell.block : PuzzleCell(kind: .open, solution: rebus[i] ?? String(ch))
        }
        for entry in entries { cells[entry.cells[0]].number = entry.number }
        let clues = entries
            .sorted { ($0.direction == .across ? 0 : 1, $0.number) < ($1.direction == .across ? 0 : 1, $1.number) }
            .map { Clue(direction: $0.direction, number: $0.number, text: "Clue \($0.number)\($0.direction.letter)", cells: $0.cells) }
        return Puzzle(width: width, height: height, cells: cells, clues: clues, metadata: PuzzleMetadata(title: "Test"))
    }
}
