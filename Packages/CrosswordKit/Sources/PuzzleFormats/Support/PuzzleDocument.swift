import CrosswordCore
import Foundation

public enum PuzzleFormat: String, Sendable, Hashable, CaseIterable {
    case puz
    case ipuz
    case jpz

    public static let fileExtensions: Set<String> = ["puz", "ipuz", "jpz"]

    public var displayName: String {
        switch self {
        case .puz: "Across Lite"
        case .ipuz: "ipuz"
        case .jpz: "JPZ"
        }
    }
}

public enum PuzzleFormatError: Error, Sendable, Equatable, LocalizedError {
    case unrecognizedFormat
    case malformed(String)
    case unsupported(String)
    case tooLarge

    public var errorDescription: String? {
        switch self {
        case .unrecognizedFormat: "This file isn't a .puz, .ipuz, or .jpz crossword."
        case .malformed(let detail): "The puzzle file is damaged: \(detail)"
        case .unsupported(let detail): "This puzzle type isn't supported: \(detail)"
        case .tooLarge: "This file is too large to be a crossword puzzle."
        }
    }
}

/// A parsed puzzle file: the puzzle, the player's saved progress, and enough of the original
/// file to write progress back without losing anything else.
public struct PuzzleDocument: Sendable {
    enum Source: Sendable {
        case puz(PuzFile)
        case ipuz(JSONValue)
        case jpz(JPZSource)
    }

    public let format: PuzzleFormat
    public let puzzle: Puzzle
    public let state: SolveState
    /// False for scrambled .puz files that could not be unlocked, or files without solutions.
    public var canCheck: Bool { puzzle.hasSolution }
    let source: Source

    init(format: PuzzleFormat, puzzle: Puzzle, state: SolveState, source: Source) {
        self.format = format
        self.puzzle = puzzle
        self.state = state
        self.source = source
    }

    public func replacingState(_ newState: SolveState) -> PuzzleDocument {
        PuzzleDocument(format: format, puzzle: puzzle, state: newState, source: source)
    }

    /// Serializes the document, including the current `state`, in its original format.
    public func encoded() throws(PuzzleFormatError) -> Data {
        switch source {
        case .puz(let file): try PuzWriter.write(file: file, puzzle: puzzle, state: state)
        case .ipuz(let json): try IPuzWriter.write(json: json, puzzle: puzzle, state: state)
        case .jpz(let source): try JPZWriter.write(source: source, puzzle: puzzle, state: state)
        }
    }
}

public enum PuzzleCodec {
    /// Real puzzle files are a few KB; anything this large is rejected before parsing.
    public static let maxFileSize = 8 * 1024 * 1024
    /// Largest .jpz entry we will inflate from a zip archive.
    public static let maxUncompressedSize = 16 * 1024 * 1024

    public static func decode(_ data: Data) throws(PuzzleFormatError) -> PuzzleDocument {
        guard data.count <= maxFileSize else { throw .tooLarge }
        return switch sniff(data) {
        case .puz: try PuzReader.read(data)
        case .ipuz: try IPuzReader.read(data)
        case .jpz: try JPZReader.read(data)
        case nil: throw .unrecognizedFormat
        }
    }

    static func sniff(_ data: Data) -> PuzzleFormat? {
        let bytes = [UInt8](data.prefix(4096))
        if bytes.starts(with: [0x50, 0x4B, 0x03, 0x04]) { return .jpz }
        if PuzReader.magicOffset(in: bytes) != nil { return .puz }
        let text = String(decoding: bytes, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "\u{FEFF}")))
        if text.hasPrefix("{") || text.hasPrefix("ipuz(") { return .ipuz }
        if text.hasPrefix("<") { return .jpz }
        return nil
    }
}
