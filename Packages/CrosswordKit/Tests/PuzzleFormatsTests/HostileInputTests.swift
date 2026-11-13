import CrosswordCore
import Foundation
import Testing
@testable import PuzzleFormats

/// Puzzle files come from the internet. A hostile file must fail cleanly (a thrown error) and quickly:
/// never crash, hang, or exhaust memory.
@Suite("Hostile input")
struct HostileInputTests {
    private static func expectFast(_ limit: Duration = .seconds(2), _ work: () throws -> Void) rethrows {
        let elapsed = try ContinuousClock().measure(work)
        #expect(elapsed < limit, "took \(elapsed)")
    }

    // MARK: Size limits

    @Test func rejectsOversizedFiles() {
        // A valid-looking ipuz padded past the limit: rejected for size, before parsing.
        let json = #"{"dimensions":{"width":1,"height":1},"puzzle":[[0]],"pad":""# + String(repeating: " ", count: PuzzleCodec.maxFileSize) + "\"}"
        #expect(throws: PuzzleFormatError.tooLarge) { try PuzzleCodec.decode(Data(json.utf8)) }
    }

    // MARK: ipuz

    @Test func ipuzHugeDimensionsDoNotOverflow() {
        let json = #"{"kind":["http://ipuz.org/crossword#1"],"dimensions":{"width":4611686018427387904,"height":4},"puzzle":[]}"#
        #expect(throws: PuzzleFormatError.self) { try PuzzleCodec.decode(Data(json.utf8)) }
    }

    @Test func ipuzDeeplyNestedJSONFails() throws {
        let json = "{\"x\":" + String(repeating: "[", count: 100_000) + String(repeating: "]", count: 100_000) + "}"
        try Self.expectFast {
            #expect(throws: PuzzleFormatError.self) { try PuzzleCodec.decode(Data(json.utf8)) }
        }
    }

    // MARK: jpz / XML / zip

    private static func jpz(grid: String, extra: String = "", width: String = "3", height: String = "3") -> Data {
        Data("""
        <?xml version="1.0"?><crossword-compiler><rectangular-puzzle><crossword>
        <grid width="\(width)" height="\(height)">\(grid)</grid>\(extra)
        </crossword></rectangular-puzzle></crossword-compiler>
        """.utf8)
    }

    @Test func jpzHugeDimensionsDoNotOverflow() {
        let data = Self.jpz(grid: "", width: "9223372036854775807", height: "2")
        #expect(throws: PuzzleFormatError.self) { try PuzzleCodec.decode(data) }
    }

    @Test func jpzHugeWordRangeIsClamped() throws {
        let word = #"<word id="1" x="1-9223372036854775807" y="-9223372036854775807-9223372036854775807"/>"#
        let data = Self.jpz(grid: #"<cell x="1" y="1" solution="A"/>"#, extra: word)
        try Self.expectFast { _ = try PuzzleCodec.decode(data) }
    }

    @Test func xmlEntityExpansionFails() throws {
        var dtd = #"<!DOCTYPE lolz [<!ENTITY l0 "lollollollollollollollollollol">"#
        for level in 1...10 {
            dtd += "<!ENTITY l\(level) \"" + String(repeating: "&l\(level - 1);", count: 10) + "\">"
        }
        dtd += "]>"
        let xml = #"<?xml version="1.0"?>"# + dtd
            + #"<crossword-compiler><metadata><title>&l10;</title></metadata></crossword-compiler>"#
        try Self.expectFast {
            #expect(throws: PuzzleFormatError.self) { try PuzzleCodec.decode(Data(xml.utf8)) }
        }
    }

    @Test func xmlExternalEntitiesAreNotLoaded() throws {
        let xml = #"<?xml version="1.0"?><!DOCTYPE x [<!ENTITY ext SYSTEM "file:///etc/passwd">]>"#
            + #"<crossword-compiler><rectangular-puzzle><metadata><title>&ext;</title></metadata><crossword>"#
            + #"<grid width="1" height="1"><cell x="1" y="1" solution="A"/></grid></crossword></rectangular-puzzle></crossword-compiler>"#
        let title = (try? PuzzleCodec.decode(Data(xml.utf8)))?.puzzle.metadata.title ?? ""
        #expect(!title.contains("root"))
    }

    @Test func xmlDeepNestingFails() throws {
        let xml = String(repeating: "<a>", count: 100_000) + String(repeating: "</a>", count: 100_000)
        try Self.expectFast {
            #expect(throws: PuzzleFormatError.self) { try PuzzleCodec.decode(Data(xml.utf8)) }
        }
    }

    @Test func zipBombIsRejected() throws {
        // Lies about its size in the header; must still stop inflating at the limit.
        let payload = Data(count: PuzzleCodec.maxUncompressedSize + 1)
        let deflated = try (payload as NSData).compressed(using: .zlib) as Data
        let zip = ZipFixture.archive(name: "bomb.xml", deflated: deflated, uncompressedSize: 100)
        try Self.expectFast {
            #expect(throws: PuzzleFormatError.tooLarge) { try ZipArchive.firstEntry(in: zip) }
        }
    }

    // MARK: Text

    @Test func unclosedTagsDoNotTakeQuadraticTime() throws {
        let text = String(repeating: "<", count: 200_000)
        try Self.expectFast { _ = MarkupText.plain(text) }
    }

    @Test func longTextIsTruncated() {
        let clue = MarkupText.plain(String(repeating: "x", count: 100_000))
        #expect(clue.count <= TextLimits.maxTextLength)
    }

    @Test func controlCharactersAreRemoved() {
        #expect(TextLimits.clean("A\u{0}B\u{7}C\u{1B}[31mD\nE\tF") == "ABC[31mD\nE\tF")
    }

    // MARK: Solving engine

    /// Every action on puzzles whose clues point at blocks, repeat cells, or nothing must not crash or hang.
    @Test(arguments: [
        // No open squares at all.
        ##"{"dimensions":{"width":2,"height":2},"puzzle":[["#","#"],["#","#"]],"clues":{"Across":[[1,"x"]]}}"##,
        // Explicit clue cells on blocks, duplicates, and out of range; an empty clue list.
        ##"{"dimensions":{"width":3,"height":1},"puzzle":[[1,"#",null]],"##
            + ##""clues":{"Across":[{"number":1,"clue":"a","cells":[[2,1],[2,1],[1,1],[9,9]]}],"Down":[{"number":7,"clue":"b","cells":[]}]}}"##,
        // A single open square with no clues.
        #"{"dimensions":{"width":1,"height":1},"puzzle":[[0]]}"#,
    ])
    func engineSurvivesOddClues(json: String) throws {
        let document = try PuzzleCodec.decode(Data(json.utf8))
        var session = SolveSession(puzzle: document.puzzle, state: document.state)
        let actions: [SolveAction] = [
            .type("A"), .backspace, .deleteForward, .move(.right), .move(.down), .move(.left), .move(.up),
            .nextClue, .previousClue, .toggleDirection, .select(cell: 0), .toggleRebus, .type("XYZ"), .commitRebus,
            .check(.word), .check(.puzzle), .reveal(.square), .reveal(.word), .reveal(.puzzle),
            .clear(.word), .clear(.puzzle), .resetPuzzle,
        ]
        for _ in 0..<3 {
            for action in actions { session = session.performing(action) }
        }
        _ = try document.replacingState(session.state).encoded()
    }

    // MARK: puz

    @Test func scrambledGiantPuzzleDoesNotHang() throws {
        let count = 255 * 255
        let file = PuzFile(
            scrambledChecksum: 1, width: 255, height: 255, scrambledTag: PuzFile.scrambledFlag,
            solution: Array(repeating: UInt8(ascii: "A"), count: count),
            fill: Array(repeating: UInt8(ascii: "-"), count: count)
        )
        try Self.expectFast { _ = try PuzReader.model(from: file) }
    }

    @Test func puzLongRebusEntryIsTruncated() throws {
        var file = PuzFile(width: 1, height: 1, solution: Array("A".utf8), fill: Array("-".utf8))
        file = file.settingExtra("RUSR", Array(String(repeating: "Z", count: 50_000).utf8) + [0])
        let (_, state) = try PuzReader.model(from: file)
        #expect(state[0].entry.count <= TextLimits.maxEntryLength)
    }
}

/// Builds a one-entry zip whose entry is stored with DEFLATE (method 8).
enum ZipFixture {
    static func archive(name: String, deflated: Data, uncompressedSize: UInt32) -> Data {
        let nameBytes = Array(name.utf8)
        var local = ByteWriter()
        local.append(UInt32(0x0403_4B50))
        local.append(UInt16(20)); local.append(UInt16(0)); local.append(UInt16(8))
        local.append(UInt32(0)); local.append(UInt32(0))
        local.append(UInt32(deflated.count)); local.append(uncompressedSize)
        local.append(UInt16(nameBytes.count)); local.append(UInt16(0))
        local.append(nameBytes)
        local.append([UInt8](deflated))

        var central = ByteWriter()
        central.append(UInt32(0x0201_4B50))
        central.append(UInt16(20)); central.append(UInt16(20)); central.append(UInt16(0)); central.append(UInt16(8))
        central.append(UInt32(0)); central.append(UInt32(0))
        central.append(UInt32(deflated.count)); central.append(uncompressedSize)
        central.append(UInt16(nameBytes.count))
        central.append([UInt8](repeating: 0, count: 12))
        central.append(UInt32(0))
        central.append(nameBytes)

        var end = ByteWriter()
        end.append(UInt32(0x0605_4B50)); end.append(UInt32(0))
        end.append(UInt16(1)); end.append(UInt16(1))
        end.append(UInt32(central.bytes.count)); end.append(UInt32(local.bytes.count))
        end.append(UInt16(0))
        return Data(local.bytes + central.bytes + end.bytes)
    }
}
