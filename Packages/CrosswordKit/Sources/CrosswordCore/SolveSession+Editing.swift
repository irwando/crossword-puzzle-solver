import Foundation

extension SolveSession {
    static let maxRebusLength = 12

    mutating func type(_ text: String) {
        let characters = AnswerMatcher.normalize(text)
        guard !characters.isEmpty else { return }
        if let buffer = rebusBuffer {
            rebusBuffer = String((buffer + characters).prefix(Self.maxRebusLength))
            return
        }
        for character in characters {
            write(String(character), to: cursor.cell)
            advanceAfterEntry()
        }
    }

    mutating func write(_ entry: String, to cell: Int) {
        guard puzzle.cells[cell].isOpen, !isLocked(cell) else { return }
        var updated = state.cells[cell]
        updated.entry = entry
        updated.marks.remove(.incorrect)
        if settings.pencil && !entry.isEmpty {
            updated.marks.insert(.pencil)
        } else {
            updated.marks.remove(.pencil)
        }
        setCell(cell, updated)
    }

    mutating func clearCell(_ cell: Int) {
        guard puzzle.cells[cell].isOpen, !isLocked(cell) else { return }
        var updated = state.cells[cell]
        updated.entry = ""
        updated.marks.subtract([.incorrect, .pencil])
        setCell(cell, updated)
    }

    mutating func backspace() {
        if let buffer = rebusBuffer {
            rebusBuffer = String(buffer.dropLast())
            return
        }
        if !state.cells[cursor.cell].isEmpty && !isLocked(cursor.cell) {
            clearCell(cursor.cell)
            return
        }
        if let previous = previousCell() {
            cursor.cell = previous
            clearCell(previous)
        }
    }

    mutating func beginRebus() {
        guard puzzle.cells[cursor.cell].isOpen, !isLocked(cursor.cell) else { return }
        rebusBuffer = state.cells[cursor.cell].entry
    }

    mutating func commitRebus(advance: Bool = true) {
        guard let buffer = rebusBuffer else { return }
        rebusBuffer = nil
        if buffer.isEmpty {
            clearCell(cursor.cell)
            return
        }
        write(buffer, to: cursor.cell)
        if advance { advanceAfterEntry() }
    }
}
