import Foundation

extension SolveSession {
    mutating func select(_ cell: Int) {
        guard cell >= 0, cell < puzzle.cellCount, puzzle.cells[cell].isOpen else { return }
        if rebusBuffer != nil { commitRebus(advance: false) }
        if cell == cursor.cell {
            toggleDirection()
            return
        }
        cursor.cell = cell
        if clue(for: cell, direction: cursor.direction) == nil,
           clue(for: cell, direction: cursor.direction.toggled) != nil {
            cursor.direction = cursor.direction.toggled
        }
    }

    mutating func toggleDirection() {
        let other = cursor.direction.toggled
        if clue(for: cursor.cell, direction: other) != nil {
            cursor.direction = other
        }
    }

    mutating func selectClue(_ id: ClueID) {
        guard let position = index.clueByID[id] else { return }
        moveToClue(at: position)
    }

    mutating func moveToClue(at position: Int) {
        let clue = puzzle.clues[position]
        guard let first = clue.cells.first else { return }
        if rebusBuffer != nil { commitRebus(advance: false) }
        cursor = Cursor(
            cell: clue.cells.first(where: { state.cells[$0].isEmpty }) ?? first,
            direction: clue.direction
        )
    }

    mutating func jumpClue(by step: Int) {
        guard !puzzle.clues.isEmpty else { return }
        let current = index.clueIndex(for: cursor.cell, direction: cursor.direction) ?? 0
        let count = puzzle.clues.count
        moveToClue(at: ((current + step) % count + count) % count)
    }

    /// Arrow keys: a perpendicular arrow first switches direction; otherwise step to the next open cell.
    mutating func move(_ movement: Movement) {
        if rebusBuffer != nil { commitRebus(advance: false) }
        if movement.axis != cursor.direction,
           clue(for: cursor.cell, direction: movement.axis) != nil {
            cursor.direction = movement.axis
            return
        }
        var row = puzzle.row(of: cursor.cell) + movement.delta.row
        var column = puzzle.column(of: cursor.cell) + movement.delta.column
        while row >= 0, row < puzzle.height, column >= 0, column < puzzle.width {
            if puzzle.isOpen(row: row, column: column) {
                cursor.cell = puzzle.index(row: row, column: column)
                if clue(for: cursor.cell, direction: cursor.direction) == nil {
                    toggleDirection()
                }
                return
            }
            row += movement.delta.row
            column += movement.delta.column
        }
    }

    /// Cursor movement after a cell has been filled.
    mutating func advanceAfterEntry() {
        guard let clue = currentClue,
              let position = clue.cells.firstIndex(of: cursor.cell) else { return }
        let after = clue.cells[(position + 1)...]

        if settings.skipFilledSquares {
            if let next = after.first(where: { state.cells[$0].isEmpty }) ?? clue.cells.first(where: { state.cells[$0].isEmpty }) {
                cursor.cell = next
            } else if let nextClue = nextIncompleteClue(after: clue.id) {
                moveToClue(at: nextClue)
            } else if let next = after.first {
                cursor.cell = next
            }
            return
        }

        if let next = after.first {
            cursor.cell = next
        } else if let current = index.clueByID[clue.id] {
            moveToClue(at: (current + 1) % puzzle.clues.count)
        }
    }

    func nextIncompleteClue(after id: ClueID) -> Int? {
        guard let start = index.clueByID[id] else { return nil }
        let count = puzzle.clues.count
        return (1...count)
            .map { (start + $0) % count }
            .first { puzzle.clues[$0].cells.contains { state.cells[$0].isEmpty } }
    }

    /// Previous cell for backspace: previous cell in the word, else last cell of the previous clue.
    func previousCell() -> Int? {
        guard let clue = currentClue,
              let position = clue.cells.firstIndex(of: cursor.cell) else { return nil }
        if position > 0 { return clue.cells[position - 1] }
        return nil
    }
}
