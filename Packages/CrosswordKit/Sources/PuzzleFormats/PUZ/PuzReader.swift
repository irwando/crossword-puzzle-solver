import CrosswordCore
import Foundation

enum PuzReader {
    enum GextFlag {
        static let pencil: UInt8 = 0x08
        static let previouslyIncorrect: UInt8 = 0x10
        static let incorrect: UInt8 = 0x20
        static let revealed: UInt8 = 0x40
        static let circled: UInt8 = 0x80
        static let managed: UInt8 = pencil | previouslyIncorrect | incorrect | revealed
    }

    static func magicOffset(in bytes: [UInt8]) -> Int? {
        let magic = PuzFile.magic
        guard bytes.count >= magic.count + 2 else { return nil }
        for start in 2...(bytes.count - magic.count) where bytes[start] == magic[0] {
            if Array(bytes[start..<start + magic.count]) == magic { return start - 2 }
        }
        return nil
    }

    static func read(_ data: Data) throws(PuzzleFormatError) -> PuzzleDocument {
        let file = try parse([UInt8](data))
        let (puzzle, state) = try model(from: file)
        return PuzzleDocument(format: .puz, puzzle: puzzle, state: state, source: .puz(file))
    }

    static func parse(_ bytes: [UInt8]) throws(PuzzleFormatError) -> PuzFile {
        guard let start = magicOffset(in: bytes) else { throw .unrecognizedFormat }
        var reader = ByteReader(bytes, offset: start)
        _ = try reader.read(0x18)  // checksums + magic: recomputed on write
        let version = try reader.read(4)
        let reserved1C = try reader.read(2)
        let scrambledChecksum = try reader.uint16()
        let reserved20 = try reader.read(12)
        let width = Int(try reader.uint8())
        let height = Int(try reader.uint8())
        let clueCount = Int(try reader.uint16())
        let puzzleType = try reader.uint16()
        let scrambledTag = try reader.uint16()
        guard width > 0, height > 0 else { throw .malformed("grid has no cells") }

        let solution = try reader.read(width * height)
        let fill = try reader.read(width * height)
        let title = reader.zeroTerminated()
        let author = reader.zeroTerminated()
        let copyright = reader.zeroTerminated()
        let clues = (0..<clueCount).map { _ in reader.zeroTerminated() }
        let notes = reader.zeroTerminated()
        let (extras, trailing) = parseExtras(&reader)

        return PuzFile(
            preamble: Array(bytes[..<start]), version: version, reserved1C: reserved1C,
            scrambledChecksum: scrambledChecksum, reserved20: reserved20,
            width: width, height: height, puzzleType: puzzleType, scrambledTag: scrambledTag,
            solution: solution, fill: fill, title: title, author: author, copyright: copyright,
            clues: clues, notes: notes, extras: extras, trailing: trailing
        )
    }

    private static func parseExtras(_ reader: inout ByteReader) -> ([PuzFile.Extra], [UInt8]) {
        var extras: [PuzFile.Extra] = []
        while reader.remaining >= 8 {
            var probe = reader
            guard let codeBytes = try? probe.read(4),
                  codeBytes.allSatisfy({ (0x20...0x7E).contains($0) }),
                  let length = try? probe.uint16(),
                  (try? probe.uint16()) != nil,
                  let data = try? probe.read(Int(length))
            else { break }
            _ = try? probe.read(1)  // NUL terminator
            extras.append(PuzFile.Extra(code: String(decoding: codeBytes, as: UTF8.self), data: data))
            reader = probe
        }
        return (extras, reader.rest())
    }

    // MARK: Model

    static func model(from file: PuzFile) throws(PuzzleFormatError) -> (Puzzle, SolveState) {
        let count = file.width * file.height
        let solutionLetters = file.isScrambled ? PuzScrambler.unlock(file) : file.solution
        let rebus = rebusSolutions(file)
        let gext = file.extra("GEXT").flatMap { $0.count == count ? $0 : nil } ?? Array(repeating: 0, count: count)

        var cells = (0..<count).map { i -> PuzzleCell in
            let byte = file.solution[i]
            guard byte != PuzFile.blockByte, byte != PuzFile.diagramlessBlockByte else { return .block }
            let solution = rebus[i] ?? solutionLetters.map { file.decode([$0[i]]) }
            return PuzzleCell(kind: .open, solution: solution.map(TextLimits.entry), isCircled: gext[i] & GextFlag.circled != 0)
        }

        let entries = GridNumbering.entries(width: file.width, height: file.height) { cells[$0].isOpen }
        var clues: [Clue] = []
        for (position, entry) in entries.enumerated() {
            cells[entry.cells[0]].number = entry.number
            let text = position < file.clues.count ? file.text(file.clues[position]) : ""
            clues.append(Clue(direction: entry.direction, number: entry.number, text: text, cells: entry.cells))
        }
        let ordered = clues.filter { $0.direction == .across } + clues.filter { $0.direction == .down }

        let metadata = PuzzleMetadata(
            title: file.text(file.title), author: file.text(file.author),
            copyright: file.text(file.copyright), notes: file.text(file.notes)
        )
        let puzzle = Puzzle(width: file.width, height: file.height, cells: cells, clues: ordered, metadata: metadata)
        return (puzzle, state(from: file, cells: cells, gext: gext))
    }

    private static func state(from file: PuzFile, cells: [PuzzleCell], gext: [UInt8]) -> SolveState {
        let rusr = file.extra("RUSR").map(splitZeroTerminated) ?? []
        let states = cells.indices.map { i -> CellState in
            guard cells[i].isOpen else { return .empty }
            let byte = file.fill[i]
            var entry = (byte == PuzFile.emptyFillByte || byte == 0 || byte == PuzFile.blockByte) ? "" : file.decode([byte])
            if i < rusr.count, !rusr[i].isEmpty { entry = file.decode(rusr[i]) }
            var marks: CellMarks = []
            let flags = gext[i]
            if flags & GextFlag.incorrect != 0 { marks.insert(.incorrect) }
            if flags & GextFlag.previouslyIncorrect != 0 { marks.insert(.previouslyIncorrect) }
            if flags & GextFlag.revealed != 0 { marks.insert(.revealed) }
            if flags & GextFlag.pencil != 0 { marks.insert(.pencil) }
            return CellState(entry: TextLimits.entry(entry), marks: marks)
        }
        return SolveState(cells: states)
    }

    private static func rebusSolutions(_ file: PuzFile) -> [Int: String] {
        guard let grbs = file.extra("GRBS"), grbs.count == file.width * file.height,
              let rtbl = file.extra("RTBL") else { return [:] }
        var table: [Int: String] = [:]
        for item in file.decode(rtbl).split(separator: ";") {
            let parts = item.split(separator: ":", maxSplits: 1)
            guard parts.count == 2, let key = Int(parts[0].trimmingCharacters(in: .whitespaces)) else { continue }
            table[key] = String(parts[1])
        }
        var result: [Int: String] = [:]
        for (i, value) in grbs.enumerated() where value != 0 {
            result[i] = table[Int(value) - 1]
        }
        return result
    }

    static func splitZeroTerminated(_ data: [UInt8]) -> [[UInt8]] {
        var reader = ByteReader(data)
        var items: [[UInt8]] = []
        while reader.remaining > 0 { items.append(reader.zeroTerminated()) }
        return items
    }
}
