import CrosswordCore
import Foundation
import Testing
@testable import PuzzleFormats

enum Fixture {
    static func data(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    static func document(_ name: String) throws -> PuzzleDocument {
        try PuzzleCodec.decode(data(name))
    }
}

/// Writes `state` into the document and reads the result back.
func roundTrip(_ document: PuzzleDocument, state: SolveState) throws -> PuzzleDocument {
    try PuzzleCodec.decode(document.replacingState(state).encoded())
}

@Suite("PUZ")
struct PuzTests {
    @Test func readsBasicPuzzle() throws {
        let doc = try Fixture.document("basic.puz")
        let puzzle = doc.puzzle
        #expect(doc.format == .puz)
        #expect(puzzle.width == 5 && puzzle.height == 5)
        #expect(puzzle.metadata.title == "Basic Test")
        #expect(puzzle.metadata.copyright == "© 2026")
        #expect(puzzle.metadata.notes == "Some notes")
        #expect(puzzle.clues.first?.text == "Café order")
        #expect(puzzle.clues.first?.cells == [0, 1, 2, 3])
        #expect(puzzle.cells[4].kind == .block)
        #expect(puzzle.cells[0].isCircled)
        #expect(puzzle.cells[11].solution == "HEART")
        #expect(puzzle.hasSolution)
    }

    @Test func readsSavedProgress() throws {
        let state = try Fixture.document("basic.puz").state
        #expect(state[0] == CellState(entry: "C"))
        #expect(state[1] == CellState(entry: "X", marks: [.incorrect, .previouslyIncorrect]))
        #expect(state[2] == CellState(entry: "T", marks: [.revealed]))
        #expect(state[11].entry == "HEART")
        #expect(state[3].isEmpty)
    }

    @Test func unchangedRoundTripIsByteIdentical() throws {
        let original = try Fixture.data("basic.puz")
        let doc = try PuzzleCodec.decode(original)
        #expect(try doc.encoded() == original)
    }

    @Test func writesNewProgress() throws {
        let doc = try Fixture.document("basic.puz")
        var state = doc.state
        state[3] = CellState(entry: "S", marks: [.pencil])
        state[11] = CellState(entry: "H")
        state[1] = CellState(entry: "A", marks: [.previouslyIncorrect])
        state[20] = CellState(entry: "DOG")
        let reread = try roundTrip(doc, state: state)
        #expect(reread.state == state)
        #expect(reread.puzzle.cells[0].isCircled, "circle flag must survive GEXT rewrite")
    }

    @Test func removesRebusSectionWhenNoRebusEntries() throws {
        let doc = try Fixture.document("basic.puz")
        let cleared = SolveState.empty(for: doc.puzzle)
        let data = try doc.replacingState(cleared).encoded()
        let file = try PuzReader.parse([UInt8](data))
        #expect(file.extra("RUSR") == nil)
        #expect(file.extra("GEXT") != nil, "circles keep GEXT alive")
        #expect(try PuzzleCodec.decode(data).state == cleared)
    }

    @Test func unlocksScrambledSolution() throws {
        let original = try Fixture.data("scrambled.puz")
        let doc = try PuzzleCodec.decode(original)
        let solution = doc.puzzle.cells.compactMap(\.solution).joined()
        #expect(solution == "HEARTEMBERABUSERESINTREND")
        #expect(doc.canCheck)
        #expect(try doc.encoded() == original, "scrambled solution stays scrambled on disk")
    }

    @Test func scrambleRoundTrip() {
        let letters = Array(0..<17).map { $0 % 26 }
        let key = [4, 7, 3, 2]
        #expect(PuzScrambler.unscramble(PuzScrambler.scramble(letters, key: key), key: key) == letters)
    }

    @Test func checksumMatchesReference() {
        #expect(PuzChecksum.compute(Array("ABC".utf8)) == 0x4074)
    }
}

@Suite("IPUZ")
struct IPuzTests {
    @Test func readsPuzzle() throws {
        let doc = try Fixture.document("basic.ipuz")
        let puzzle = doc.puzzle
        #expect(doc.format == .ipuz)
        #expect(puzzle.metadata.title == "Ipuz Test")
        #expect(puzzle.cells[3].kind == .void)
        #expect(puzzle.cells[5].kind == .block)
        #expect(puzzle.cells[0].isCircled)
        #expect(puzzle.cells[0].number == 1)
        #expect(puzzle.cells[10].solution == "DOG")
        let across = puzzle.clues(.across)
        #expect(across.map(\.text) == ["Feline & friend", "Sleeping spot"])
        #expect(across[0].cells == [0, 1, 2])
        #expect(puzzle.clues(.down)[1].cells == [2, 6, 10])
        #expect(doc.state[0].entry == "C")
        #expect(doc.state[2].entry == "X")
        #expect(doc.state[1].isEmpty)
    }

    @Test func writesProgressAndKeepsUnknownKeys() throws {
        let doc = try Fixture.document("basic.ipuz")
        var state = doc.state
        state[1] = CellState(entry: "A", marks: [.revealed])
        state[10] = CellState(entry: "DOG", marks: [.pencil])
        let data = try doc.replacingState(state).encoded()
        let reread = try PuzzleCodec.decode(data)
        #expect(reread.state == state)
        let json = try IPuzReader.decodeJSON(data)
        #expect(json["com.example:custom"]?["keep"] == .bool(true))
    }

    @Test func acceptsJSONPWrapper() throws {
        let text = "ipuz(" + String(decoding: try Fixture.data("basic.ipuz"), as: UTF8.self) + ")"
        #expect(try PuzzleCodec.decode(Data(text.utf8)).puzzle.width == 4)
    }
}

@Suite("JPZ")
struct JPZTests {
    @Test(arguments: ["basic.jpz", "zipped.jpz"])
    func readsPuzzle(name: String) throws {
        let doc = try Fixture.document(name)
        let puzzle = doc.puzzle
        #expect(doc.format == .jpz)
        #expect(puzzle.metadata.title == "JPZ Test")
        #expect(puzzle.metadata.notes == "A test & more")
        #expect(puzzle.cells[4].kind == .block)
        #expect(puzzle.cells[0].isCircled)
        #expect(puzzle.cells[8].solution == "DOG")
        #expect(puzzle.clues(.across).map(\.text) == ["Feline friend", "Sleeping spot"])
        #expect(puzzle.clues(.down)[1].cells == [2, 5, 8])
        #expect(doc.state[0] == CellState(entry: "C"))
        #expect(doc.state[2] == CellState(entry: "T", marks: [.revealed]))
    }

    @Test(arguments: ["basic.jpz", "zipped.jpz"])
    func writesProgress(name: String) throws {
        let doc = try Fixture.document(name)
        var state = doc.state
        state[0] = .empty
        state[1] = CellState(entry: "Q", marks: [.incorrect, .previouslyIncorrect])
        state[8] = CellState(entry: "DOG")
        let data = try doc.replacingState(state).encoded()
        #expect(data.starts(with: [0x50, 0x4B]) == (name == "zipped.jpz"))
        let reread = try PuzzleCodec.decode(data)
        #expect(reread.state == state)
        #expect(reread.puzzle == doc.puzzle)
    }
}

@Suite("Codec")
struct CodecTests {
    @Test func rejectsUnknownData() {
        #expect(throws: PuzzleFormatError.unrecognizedFormat) {
            try PuzzleCodec.decode(Data("hello world".utf8))
        }
    }

    @Test func rejectsTruncatedPuz() throws {
        let data = try Fixture.data("basic.puz").prefix(80)
        #expect(throws: PuzzleFormatError.self) { try PuzzleCodec.decode(Data(data)) }
    }

    @Test func markupStripping() {
        #expect(MarkupText.plain("<b>Bold</b> &amp; <i>it</i>&#233;&#x41;") == "Bold & itéA")
    }

    @Test func crc32() {
        #expect(CRC32.checksum(Array("123456789".utf8)) == 0xCBF4_3926)
    }
}
