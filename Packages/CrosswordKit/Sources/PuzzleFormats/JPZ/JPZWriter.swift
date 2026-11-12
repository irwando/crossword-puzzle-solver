import CrosswordCore
import Foundation

enum JPZWriter {
    static func write(source: JPZSource, puzzle: Puzzle, state: SolveState) throws(PuzzleFormatError) -> Data {
        guard state.cells.count == puzzle.cellCount else { throw .malformed("state does not match grid") }

        let root = source.root.mapElements { element in
            guard element.localName == "grid" else { return element }
            var grid = element
            grid.children = element.children.map { node in
                guard case .element(let cell) = node, cell.localName == "cell",
                      let i = JPZReader.index(of: cell, width: puzzle.width, height: puzzle.height),
                      puzzle.cells[i].isOpen
                else { return node }
                return .element(applying(state.cells[i], to: cell))
            }
            return grid
        }

        let xml = XMLTree.serialize(root)
        guard let entryName = source.zipEntryName else { return xml }
        return ZipArchive.archive(ZipArchive.Entry(name: entryName, data: xml))
    }

    private static func applying(_ cellState: CellState, to cell: XMLElement) -> XMLElement {
        var updated = cell
        updated.attributes["solve-state"] = cellState.entry.isEmpty ? nil : cellState.entry
        updated.attributes["solve-status"] = cellState.marks.contains(.revealed) ? "revealed" : nil
        updated.attributes[JPZReader.marksAttribute] = cellState.marks.isEmpty ? nil : String(cellState.marks.rawValue)
        return updated
    }
}
