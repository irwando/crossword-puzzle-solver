import CrosswordCore
import Foundation

enum IPuzWriter {
    static func write(json: JSONValue, puzzle: Puzzle, state: SolveState) throws(PuzzleFormatError) -> Data {
        guard state.cells.count == puzzle.cellCount else { throw .malformed("state does not match grid") }
        let conventions = IPuzReader.Conventions(json: json)

        let saved: JSONValue = .array((0..<puzzle.height).map { r in
            .array((0..<puzzle.width).map { c in
                let i = puzzle.index(row: r, column: c)
                switch puzzle.cells[i].kind {
                case .void: return .null
                case .block: return .string(conventions.block)
                case .open: return .string(state.cells[i].entry)
                }
            })
        })

        let hasMarks = state.cells.contains { !$0.marks.isEmpty }
        let marks: JSONValue? = hasMarks
            ? .array((0..<puzzle.height).map { r in
                .array((0..<puzzle.width).map { c in .int(Int(state.cells[puzzle.index(row: r, column: c)].marks.rawValue)) })
            })
            : nil

        let updated = json
            .setting("saved", saved)
            .setting(IPuzReader.marksKey, marks)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(updated) else { throw .malformed("could not encode JSON") }
        return data
    }
}
