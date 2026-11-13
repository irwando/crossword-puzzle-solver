import CrosswordCore
import Foundation

enum IPuzReader {
    static let marksKey = "com.irwando.crosswords:marks"

    struct Conventions {
        var block: String
        var empty: String

        init(json: JSONValue) {
            block = json["block"]?.scalarText ?? "#"
            empty = json["empty"]?.scalarText ?? "0"
        }
    }

    static func read(_ data: Data) throws(PuzzleFormatError) -> PuzzleDocument {
        let json = try decodeJSON(data)
        let (puzzle, state) = try model(from: json)
        return PuzzleDocument(format: .ipuz, puzzle: puzzle, state: state, source: .ipuz(json))
    }

    static func decodeJSON(_ data: Data) throws(PuzzleFormatError) -> JSONValue {
        var text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        if text.hasPrefix("ipuz("), text.hasSuffix(")") {
            text = String(text.dropFirst(5).dropLast())
        }
        guard let json = try? JSONDecoder().decode(JSONValue.self, from: Data(text.utf8)), json.objectValue != nil else {
            throw .malformed("invalid JSON")
        }
        return json
    }

    static func model(from json: JSONValue) throws(PuzzleFormatError) -> (Puzzle, SolveState) {
        if let kinds = json["kind"]?.arrayValue?.compactMap(\.stringValue), !kinds.isEmpty,
           !kinds.contains(where: { $0.lowercased().contains("crossword") }) {
            throw .unsupported(kinds.joined(separator: ", "))
        }
        guard let width = json["dimensions"]?["width"]?.intValue,
              let height = json["dimensions"]?["height"]?.intValue,
              GridLimits.isValid(width: width, height: height, maxCells: 10_000),
              let rows = json["puzzle"]?.arrayValue, rows.count >= height
        else { throw .malformed("missing dimensions or grid") }

        let conventions = Conventions(json: json)
        let solutionGrid = grid(json["solution"], width: width, height: height)
        var cells: [PuzzleCell] = []
        for r in 0..<height {
            let row = rows[r].arrayValue ?? []
            for c in 0..<width {
                let raw = c < row.count ? row[c] : .null
                cells.append(cell(raw, solution: solutionGrid?[r * width + c], conventions: conventions))
            }
        }

        let clues = parseClues(json["clues"], cells: &cells, width: width, height: height)
        let metadata = PuzzleMetadata(
            title: MarkupText.plain(json["title"]?.stringValue ?? ""),
            author: MarkupText.plain(json["author"]?.stringValue ?? ""),
            copyright: MarkupText.plain(json["copyright"]?.stringValue ?? ""),
            notes: MarkupText.plain(json["notes"]?.stringValue ?? json["intro"]?.stringValue ?? ""),
            date: TextLimits.clean(json["date"]?.stringValue ?? "", maxLength: 64)
        )
        let puzzle = Puzzle(width: width, height: height, cells: cells, clues: clues, metadata: metadata)
        return (puzzle, state(json: json, puzzle: puzzle, conventions: conventions))
    }

    // MARK: Cells

    private static func cell(_ raw: JSONValue, solution: JSONValue?, conventions: Conventions) -> PuzzleCell {
        var value = raw
        var style: JSONValue?
        if let object = raw.objectValue {
            value = object["cell"] ?? .int(0)
            style = object["style"]
        }
        if value.isNull { return .void }
        if value.scalarText == conventions.block || isBlock(solution, conventions) { return .block }

        var cell = PuzzleCell(kind: .open)
        if let label = value.scalarText, label != conventions.empty, let number = Int(label), number > 0 {
            cell.number = number
        }
        if let solution, let text = solutionText(solution), text != conventions.empty {
            cell.solution = TextLimits.entry(text)
        }
        if let style {
            cell.isCircled = style["shapebg"]?.stringValue?.lowercased() == "circle"
            cell.isShaded = style["highlight"] == .bool(true) || style["color"] != nil
        }
        return cell
    }

    private static func isBlock(_ solution: JSONValue?, _ conventions: Conventions) -> Bool {
        guard let solution else { return false }
        return solutionText(solution) == conventions.block
    }

    static func solutionText(_ value: JSONValue) -> String? {
        if let object = value.objectValue { return object["value"]?.scalarText }
        guard let text = value.scalarText, !text.isEmpty else { return nil }
        return text
    }

    /// Flattens a row-major 2D grid; nil when absent or the wrong shape.
    static func grid(_ value: JSONValue?, width: Int, height: Int) -> [JSONValue]? {
        guard let rows = value?.arrayValue, rows.count >= height else { return nil }
        return (0..<height).flatMap { r in
            let row = rows[r].arrayValue ?? []
            return (0..<width).map { c in c < row.count ? row[c] : .null }
        }
    }

    // MARK: Clues

    private static func parseClues(_ value: JSONValue?, cells: inout [PuzzleCell], width: Int, height: Int) -> [Clue] {
        guard let groups = value?.objectValue else { return [] }
        let snapshot = cells
        let isOpen = { (i: Int) in snapshot[i].isOpen }
        var numberToCell: [Int: Int] = [:]
        for (i, cell) in cells.enumerated() {
            if let number = cell.number, numberToCell[number] == nil { numberToCell[number] = i }
        }

        var result: [Clue] = []
        for direction in Direction.allCases {
            guard let key = groups.keys.first(where: { $0.lowercased().hasPrefix(direction.rawValue) }),
                  let items = groups[key]?.arrayValue else { continue }
            for (position, item) in items.enumerated() {
                let (rawLabel, text, explicitCells) = clueParts(item)
                let label = rawLabel.map(TextLimits.label)
                let number = label.flatMap { Int($0.split(separator: "/").first ?? "") } ?? position + 1
                let cellList: [Int]
                if let explicitCells {
                    cellList = explicitCells.compactMap { pair in
                        guard pair.count == 2, (1...width).contains(pair[0]), (1...height).contains(pair[1]) else { return nil }
                        return (pair[1] - 1) * width + (pair[0] - 1)
                    }
                } else if let start = numberToCell[number] {
                    cellList = GridNumbering.run(from: start, direction: direction, width: width, height: height, isOpen: isOpen)
                } else {
                    cellList = []
                }
                result.append(Clue(direction: direction, number: number, label: label, text: MarkupText.plain(text), cells: cellList))
            }
        }
        return result
    }

    private static func clueParts(_ item: JSONValue) -> (label: String?, text: String, cells: [[Int]]?) {
        switch item {
        case .array(let parts):
            return (parts.first?.scalarText, parts.dropFirst().first?.scalarText ?? "", nil)
        case .object(let object):
            let cells = object["cells"]?.arrayValue?.compactMap { $0.arrayValue?.compactMap(\.intValue) }
            return (object["number"]?.scalarText, object["clue"]?.scalarText ?? "", cells)
        default:
            return (nil, item.scalarText ?? "", nil)
        }
    }

    // MARK: Saved state

    private static func state(json: JSONValue, puzzle: Puzzle, conventions: Conventions) -> SolveState {
        let saved = grid(json["saved"], width: puzzle.width, height: puzzle.height)
        let marks = grid(json[marksKey], width: puzzle.width, height: puzzle.height)
        let cells = puzzle.cells.indices.map { i -> CellState in
            guard puzzle.cells[i].isOpen else { return .empty }
            var entry = saved.flatMap { solutionText($0[i]) } ?? ""
            if entry == conventions.empty || entry == conventions.block { entry = "" }
            let rawMarks = marks?[i].intValue.map { CellMarks(rawValue: UInt8(clamping: $0)) } ?? []
            return CellState(entry: TextLimits.entry(entry), marks: rawMarks)
        }
        return SolveState(cells: cells)
    }
}
