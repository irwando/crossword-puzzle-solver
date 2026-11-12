import CrosswordCore
import Foundation

struct JPZSource: Sendable, Hashable {
    var root: XMLElement
    /// Entry name when the original file was a zip archive.
    var zipEntryName: String?
}

enum JPZReader {
    static let marksAttribute = "xw-marks"

    static func read(_ data: Data) throws(PuzzleFormatError) -> PuzzleDocument {
        var xml = data
        var zipEntryName: String?
        if data.starts(with: [0x50, 0x4B, 0x03, 0x04]) {
            let entry = try ZipArchive.firstEntry(in: data)
            xml = entry.data
            zipEntryName = entry.name
        }
        let root = try XMLTree.parse(xml)
        let (puzzle, state) = try model(from: root)
        return PuzzleDocument(
            format: .jpz, puzzle: puzzle, state: state,
            source: .jpz(JPZSource(root: root, zipEntryName: zipEntryName))
        )
    }

    static func model(from root: XMLElement) throws(PuzzleFormatError) -> (Puzzle, SolveState) {
        guard let crossword = root.first("crossword") else {
            throw root.first("rectangular-puzzle") != nil ? .unsupported("non-crossword JPZ puzzle") : .malformed("no <crossword> element")
        }
        guard let gridElement = crossword.child("grid"),
              let width = gridElement.attributes["width"].flatMap(Int.init),
              let height = gridElement.attributes["height"].flatMap(Int.init),
              width > 0, height > 0, width * height <= 10_000
        else { throw .malformed("missing grid size") }

        var cells = [PuzzleCell](repeating: .block, count: width * height)
        var states = [CellState](repeating: .empty, count: width * height)
        for element in gridElement.children("cell") {
            guard let i = index(of: element, width: width, height: height) else { continue }
            cells[i] = cell(from: element)
            if cells[i].isOpen { states[i] = cellState(from: element) }
        }

        let words = parseWords(crossword, width: width, height: height)
        let clues = parseClues(crossword, words: words, cells: cells, width: width, height: height)
        let metadata = parseMetadata(root)
        let puzzle = Puzzle(width: width, height: height, cells: cells, clues: clues, metadata: metadata)
        return (puzzle, SolveState(cells: states))
    }

    static func index(of cell: XMLElement, width: Int, height: Int) -> Int? {
        guard let x = cell.attributes["x"].flatMap(Int.init), let y = cell.attributes["y"].flatMap(Int.init),
              (1...width).contains(x), (1...height).contains(y) else { return nil }
        return (y - 1) * width + (x - 1)
    }

    private static func cell(from element: XMLElement) -> PuzzleCell {
        switch element.attributes["type"] {
        case "block", "clue": return .block
        case "void": return .void
        default: break
        }
        let background = element.attributes["background-color"]?.lowercased()
        return PuzzleCell(
            kind: .open,
            solution: element.attributes["solution"].flatMap { $0.isEmpty ? nil : $0.uppercased() },
            number: element.attributes["number"].flatMap(Int.init),
            isCircled: element.attributes["background-shape"] == "circle",
            isShaded: background != nil && background != "#ffffff" && background != "white"
        )
    }

    private static func cellState(from element: XMLElement) -> CellState {
        var marks = element.attributes[marksAttribute]
            .flatMap(UInt8.init)
            .map(CellMarks.init(rawValue:)) ?? []
        if element.attributes["solve-status"] == "revealed" { marks.insert(.revealed) }
        let entry = element.attributes["solve-state"]?.trimmingCharacters(in: .whitespaces).uppercased() ?? ""
        return CellState(entry: entry, marks: marks)
    }

    private static func parseMetadata(_ root: XMLElement) -> PuzzleMetadata {
        let metadata = root.first("metadata")
        func field(_ name: String) -> String { MarkupText.plain(metadata?.child(name)?.text ?? "") }
        return PuzzleMetadata(
            title: field("title"), author: field("creator"),
            copyright: field("copyright"), notes: field("description")
        )
    }

    // MARK: Words & clues

    private static func parseWords(_ crossword: XMLElement, width: Int, height: Int) -> [String: [Int]] {
        var words: [String: [Int]] = [:]
        for word in crossword.children("word") {
            guard let id = word.attributes["id"] else { continue }
            var cells = cellRange(x: word.attributes["x"], y: word.attributes["y"], width: width, height: height)
            for part in word.children("cells") {
                cells += cellRange(x: part.attributes["x"], y: part.attributes["y"], width: width, height: height)
            }
            words[id] = cells
        }
        return words
    }

    /// Expands `x="1-5" y="2"` style ranges (1-based, inclusive, possibly descending).
    static func cellRange(x: String?, y: String?, width: Int, height: Int) -> [Int] {
        guard let xs = span(x), let ys = span(y) else { return [] }
        return ys.flatMap { row in xs.map { column in (row, column) } }
            .filter { (1...height).contains($0.0) && (1...width).contains($0.1) }
            .map { ($0.0 - 1) * width + ($0.1 - 1) }
    }

    private static func span(_ value: String?) -> [Int]? {
        guard let value else { return nil }
        let bounds = value.split(separator: "-").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        switch bounds.count {
        case 1: return bounds
        case 2: return bounds[0] <= bounds[1] ? Array(bounds[0]...bounds[1]) : Array((bounds[1]...bounds[0]).reversed())
        default: return nil
        }
    }

    private static func parseClues(
        _ crossword: XMLElement, words: [String: [Int]], cells: [PuzzleCell], width: Int, height: Int
    ) -> [Clue] {
        let groups = crossword.children("clues")
        var numberToCell: [Int: Int] = [:]
        for (i, cell) in cells.enumerated() {
            if let number = cell.number, numberToCell[number] == nil { numberToCell[number] = i }
        }

        var result: [Clue] = []
        for (position, group) in groups.enumerated() {
            let title = group.child("title")?.text.lowercased() ?? ""
            let direction: Direction = title.contains("down") ? .down : title.contains("across") ? .across : (position == 0 ? .across : .down)
            for (offset, clue) in group.children("clue").enumerated() {
                let label = clue.attributes["number"]
                let number = label.flatMap { Int($0.split(separator: "/").first ?? "") } ?? offset + 1
                var clueCells = clue.attributes["word"].flatMap { words[$0] } ?? []
                if clueCells.isEmpty, let start = numberToCell[number] {
                    clueCells = GridNumbering.run(from: start, direction: direction, width: width, height: height) { cells[$0].isOpen }
                }
                result.append(Clue(direction: direction, number: number, label: label, text: MarkupText.plain(clue.text), cells: clueCells))
            }
        }
        return result
    }
}
