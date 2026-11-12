import Foundation

/// Check, reveal, and clear.
extension SolveSession {
    mutating func check(_ scope: AssistScope) {
        if rebusBuffer != nil { commitRebus(advance: false) }
        for cell in cells(in: scope) {
            let current = state.cells[cell]
            guard !current.isEmpty, let solution = puzzle.cells[cell].solution, !solution.isEmpty else { continue }
            var updated = current
            if AnswerMatcher.matches(entry: current.entry, solution: solution) {
                updated.marks.remove(.incorrect)
            } else {
                updated.marks.formUnion([.incorrect, .previouslyIncorrect])
            }
            setCell(cell, updated)
        }
    }

    mutating func reveal(_ scope: AssistScope) {
        rebusBuffer = nil
        for cell in cells(in: scope) {
            let current = state.cells[cell]
            guard let solution = puzzle.cells[cell].solution, !solution.isEmpty else { continue }
            var updated = current
            updated.marks.subtract([.incorrect, .pencil])
            if !AnswerMatcher.matches(entry: current.entry, solution: solution) {
                if !current.isEmpty { updated.marks.insert(.previouslyIncorrect) }
                updated.entry = solution.uppercased()
                updated.marks.insert(.revealed)
            }
            setCell(cell, updated)
        }
    }

    mutating func clear(_ scope: AssistScope) {
        rebusBuffer = nil
        for cell in cells(in: scope) {
            clearCell(cell)
        }
    }

    mutating func resetPuzzle() {
        rebusBuffer = nil
        for cell in puzzle.openCellIndices {
            setCell(cell, .empty)
        }
    }
}
