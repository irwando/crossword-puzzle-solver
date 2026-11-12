import Foundation

/// Little-endian cursor over a byte buffer. Every read is bounds-checked.
struct ByteReader {
    let bytes: [UInt8]
    private(set) var offset: Int

    init(_ bytes: [UInt8], offset: Int = 0) {
        self.bytes = bytes
        self.offset = offset
    }

    var remaining: Int { bytes.count - offset }

    mutating func read(_ count: Int) throws(PuzzleFormatError) -> [UInt8] {
        guard count >= 0, remaining >= count else { throw .malformed("unexpected end of file") }
        defer { offset += count }
        return Array(bytes[offset..<offset + count])
    }

    mutating func uint8() throws(PuzzleFormatError) -> UInt8 {
        try read(1)[0]
    }

    mutating func uint16() throws(PuzzleFormatError) -> UInt16 {
        let pair = try read(2)
        return UInt16(pair[0]) | UInt16(pair[1]) << 8
    }

    mutating func uint32() throws(PuzzleFormatError) -> UInt32 {
        let quad = try read(4)
        return quad.enumerated().reduce(0) { $0 | UInt32($1.element) << (8 * UInt32($1.offset)) }
    }

    /// Reads up to (and consumes) a NUL terminator; tolerates a missing terminator at end of file.
    mutating func zeroTerminated() -> [UInt8] {
        let end = bytes[offset...].firstIndex(of: 0) ?? bytes.count
        defer { offset = min(end + 1, bytes.count) }
        return Array(bytes[offset..<end])
    }

    mutating func rest() -> [UInt8] {
        defer { offset = bytes.count }
        return Array(bytes[offset...])
    }
}

struct ByteWriter {
    private(set) var bytes: [UInt8] = []

    mutating func append(_ data: [UInt8]) { bytes += data }
    mutating func append(_ value: UInt8) { bytes.append(value) }
    mutating func append(_ value: UInt16) {
        bytes += [UInt8(value & 0xFF), UInt8(value >> 8)]
    }
    mutating func append(_ value: UInt32) {
        bytes += (0..<4).map { UInt8((value >> (8 * $0)) & 0xFF) }
    }

    mutating func overwrite(_ value: UInt16, at offset: Int) {
        bytes[offset] = UInt8(value & 0xFF)
        bytes[offset + 1] = UInt8(value >> 8)
    }
}
