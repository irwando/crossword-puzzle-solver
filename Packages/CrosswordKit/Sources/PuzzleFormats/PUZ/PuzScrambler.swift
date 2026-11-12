import Foundation

/// Across Lite "scrambled" solutions. The 4-digit key is recovered by brute force, verified
/// against the checksum of the real solution stored in the header.
enum PuzScrambler {
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ".utf8)

    /// Returns the unscrambled solution grid, or nil when no key matches.
    static func unlock(_ file: PuzFile) -> [UInt8]? {
        let columnOrder = columnMajorOpenCells(file)
        let scrambled = columnOrder.map { file.solution[$0] }
        guard !scrambled.isEmpty, scrambled.allSatisfy(alphabet.contains) else { return nil }
        let letters = scrambled.map { Int($0 - UInt8(ascii: "A")) }

        for key in 0...9999 {
            let candidate = unscramble(letters, key: digits(key)).map { UInt8($0) + UInt8(ascii: "A") }
            if PuzChecksum.compute(candidate) == file.scrambledChecksum {
                var solution = file.solution
                for (position, cell) in columnOrder.enumerated() { solution[cell] = candidate[position] }
                return solution
            }
        }
        return nil
    }

    static func digits(_ key: Int) -> [Int] {
        [key / 1000 % 10, key / 100 % 10, key / 10 % 10, key % 10]
    }

    static func columnMajorOpenCells(_ file: PuzFile) -> [Int] {
        (0..<file.width).flatMap { column in
            (0..<file.height).map { $0 * file.width + column }
        }.filter { file.solution[$0] != PuzFile.blockByte && file.solution[$0] != PuzFile.diagramlessBlockByte }
    }

    static func scramble(_ letters: [Int], key: [Int]) -> [Int] {
        var s = letters
        for k in key {
            s = shift(s, by: key, sign: 1)
            s = Array(s[k...] + s[..<k])
            s = interleave(s)
        }
        return s
    }

    static func unscramble(_ letters: [Int], key: [Int]) -> [Int] {
        let count = letters.count
        var s = letters
        for k in key.reversed() {
            s = deinterleave(s)
            let cut = count - k
            s = Array(s[cut...] + s[..<cut])
            s = shift(s, by: key, sign: -1)
        }
        return s
    }

    private static func shift(_ s: [Int], by key: [Int], sign: Int) -> [Int] {
        s.enumerated().map { i, letter in ((letter + sign * key[i % key.count]) % 26 + 26) % 26 }
    }

    private static func interleave(_ s: [Int]) -> [Int] {
        let mid = s.count / 2
        var result = zip(s[mid...], s[..<mid]).flatMap { [$0, $1] }
        if s.count % 2 == 1 { result.append(s[s.count - 1]) }
        return result
    }

    private static func deinterleave(_ s: [Int]) -> [Int] {
        let odd = stride(from: 1, to: s.count, by: 2).map { s[$0] }
        let even = stride(from: 0, to: s.count, by: 2).map { s[$0] }
        return odd + even
    }
}
