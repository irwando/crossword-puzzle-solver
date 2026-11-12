import Foundation

/// Raw contents of an Across Lite file, kept byte-for-byte so it can be re-written faithfully.
struct PuzFile: Sendable, Hashable {
    struct Extra: Sendable, Hashable {
        var code: String
        var data: [UInt8]
    }

    static let headerSize = 0x34
    static let magic = Array("ACROSS&DOWN\0".utf8)
    static let blockByte = UInt8(ascii: ".")
    static let diagramlessBlockByte = UInt8(ascii: ":")
    static let emptyFillByte = UInt8(ascii: "-")
    static let scrambledFlag: UInt16 = 0x0004

    var preamble: [UInt8] = []
    var version: [UInt8] = Array("1.3\0".utf8)
    var reserved1C: [UInt8] = [0, 0]
    var scrambledChecksum: UInt16 = 0
    var reserved20: [UInt8] = Array(repeating: 0, count: 12)
    var width: Int
    var height: Int
    var puzzleType: UInt16 = 0x0001
    var scrambledTag: UInt16 = 0
    var solution: [UInt8]
    var fill: [UInt8]
    var title: [UInt8] = []
    var author: [UInt8] = []
    var copyright: [UInt8] = []
    var clues: [[UInt8]] = []
    var notes: [UInt8] = []
    var extras: [Extra] = []
    var trailing: [UInt8] = []

    var isScrambled: Bool { scrambledTag & Self.scrambledFlag != 0 }

    var versionString: String {
        String(decoding: version.prefix { $0 != 0 }, as: UTF8.self)
    }

    var encoding: String.Encoding {
        versionString.hasPrefix("2.") ? .utf8 : .windowsCP1252
    }

    func decode(_ bytes: [UInt8]) -> String {
        String(data: Data(bytes), encoding: encoding)
            ?? String(data: Data(bytes), encoding: .isoLatin1)
            ?? String(decoding: bytes, as: UTF8.self)
    }

    func encode(_ string: String) -> [UInt8] {
        Array(string.data(using: encoding, allowLossyConversion: true) ?? Data(string.utf8))
    }

    func extra(_ code: String) -> [UInt8]? {
        extras.first { $0.code == code }?.data
    }

    /// Returns a copy where `code` is set to `data` (or removed when nil), preserving section order.
    func settingExtra(_ code: String, _ data: [UInt8]?) -> PuzFile {
        var copy = self
        if let position = copy.extras.firstIndex(where: { $0.code == code }) {
            if let data { copy.extras[position].data = data } else { copy.extras.remove(at: position) }
        } else if let data {
            copy.extras.append(Extra(code: code, data: data))
        }
        return copy
    }
}

enum PuzChecksum {
    static func compute(_ bytes: some Sequence<UInt8>, seed: UInt16 = 0) -> UInt16 {
        var checksum = seed
        for byte in bytes {
            checksum = (checksum & 1 != 0) ? (checksum >> 1) | 0x8000 : checksum >> 1
            checksum = checksum &+ UInt16(byte)
        }
        return checksum
    }

    static func text(_ file: PuzFile, seed: UInt16) -> UInt16 {
        var checksum = seed
        for field in [file.title, file.author, file.copyright] where !field.isEmpty {
            checksum = compute(field + [0], seed: checksum)
        }
        for clue in file.clues where !clue.isEmpty {
            checksum = compute(clue, seed: checksum)
        }
        if file.versionString >= "1.3", !file.notes.isEmpty {
            checksum = compute(file.notes + [0], seed: checksum)
        }
        return checksum
    }
}
