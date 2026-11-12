import Foundation

/// Standard crossword numbering: a cell gets a number when it starts an across or down entry
/// of length >= 2.
public enum GridNumbering {
    public struct Entry: Sendable, Hashable {
        public var number: Int
        public var direction: Direction
        public var cells: [Int]
    }

    public static func entries(width: Int, height: Int, isOpen: (Int) -> Bool) -> [Entry] {
        var result: [Entry] = []
        var number = 0
        func open(_ r: Int, _ c: Int) -> Bool {
            r >= 0 && r < height && c >= 0 && c < width && isOpen(r * width + c)
        }
        for r in 0..<height {
            for c in 0..<width where open(r, c) {
                let startsAcross = !open(r, c - 1) && open(r, c + 1)
                let startsDown = !open(r - 1, c) && open(r + 1, c)
                guard startsAcross || startsDown else { continue }
                number += 1
                if startsAcross {
                    let cells = stride(from: c, to: width, by: 1)
                        .prefix { open(r, $0) }
                        .map { r * width + $0 }
                    result.append(Entry(number: number, direction: .across, cells: cells))
                }
                if startsDown {
                    let cells = stride(from: r, to: height, by: 1)
                        .prefix { open($0, c) }
                        .map { $0 * width + c }
                    result.append(Entry(number: number, direction: .down, cells: cells))
                }
            }
        }
        return result
    }

    /// Cells in a straight run starting at `start`, used when a format provides numbers but not word extents.
    public static func run(from start: Int, direction: Direction, width: Int, height: Int, isOpen: (Int) -> Bool) -> [Int] {
        var cells: [Int] = []
        var r = start / width
        var c = start % width
        while r < height, c < width, isOpen(r * width + c) {
            cells.append(r * width + c)
            if direction == .across { c += 1 } else { r += 1 }
        }
        return cells
    }
}
