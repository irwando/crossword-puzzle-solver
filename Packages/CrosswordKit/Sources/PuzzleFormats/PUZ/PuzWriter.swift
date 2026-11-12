import CrosswordCore
import Foundation

enum PuzWriter {
    typealias Flag = PuzReader.GextFlag

    static func write(file: PuzFile, puzzle: Puzzle, state: SolveState) throws(PuzzleFormatError) -> Data {
        guard state.cells.count == file.width * file.height else { throw .malformed("state does not match grid") }
        return Data(serialize(applying(state, to: file)))
    }

    /// Copies player progress into the fill grid and the RUSR / GEXT sections.
    static func applying(_ state: SolveState, to file: PuzFile) -> PuzFile {
        let count = file.width * file.height
        let isOpen = { (i: Int) in
            file.solution[i] != PuzFile.blockByte && file.solution[i] != PuzFile.diagramlessBlockByte
        }

        let fill = (0..<count).map { i -> UInt8 in
            guard isOpen(i) else { return file.fill[i] }
            return file.encode(String(state.cells[i].entry.prefix(1))).first ?? PuzFile.emptyFillByte
        }

        let hasRebusEntry = state.cells.indices.contains { isOpen($0) && state.cells[$0].entry.count > 1 }
        let rusr: [UInt8]? = hasRebusEntry
            ? state.cells.indices.flatMap { i in
                (isOpen(i) && state.cells[i].entry.count > 1 ? file.encode(state.cells[i].entry) : []) + [0]
            }
            : nil

        let original = file.extra("GEXT").flatMap { $0.count == count ? $0 : nil } ?? Array(repeating: 0, count: count)
        let gext = (0..<count).map { i -> UInt8 in
            var flags = original[i] & ~Flag.managed
            guard isOpen(i) else { return flags }
            let marks = state.cells[i].marks
            if marks.contains(.incorrect) { flags |= Flag.incorrect }
            if marks.contains(.previouslyIncorrect) { flags |= Flag.previouslyIncorrect }
            if marks.contains(.revealed) { flags |= Flag.revealed }
            if marks.contains(.pencil) { flags |= Flag.pencil }
            return flags
        }

        var updated = file
        updated.fill = fill
        return updated
            .settingExtra("RUSR", rusr)
            .settingExtra("GEXT", gext.contains { $0 != 0 } ? gext : nil)
    }

    static func serialize(_ file: PuzFile) -> [UInt8] {
        var header = ByteWriter()
        header.append(UInt16(0))  // global checksum placeholder
        header.append(PuzFile.magic)
        header.append(UInt16(0))  // CIB checksum placeholder
        header.append([UInt8](repeating: 0, count: 8))  // masked checksums placeholder
        header.append(padded(file.version, to: 4))
        header.append(padded(file.reserved1C, to: 2))
        header.append(file.scrambledChecksum)
        header.append(padded(file.reserved20, to: 12))
        header.append(UInt8(file.width))
        header.append(UInt8(file.height))
        header.append(UInt16(file.clues.count))
        header.append(file.puzzleType)
        header.append(file.scrambledTag)

        var bytes = header.bytes
        let cib = PuzChecksum.compute(bytes[0x2C..<0x34])
        let solutionChecksum = PuzChecksum.compute(file.solution)
        let fillChecksum = PuzChecksum.compute(file.fill)
        let textChecksum = PuzChecksum.text(file, seed: 0)
        var global = PuzChecksum.compute(file.solution, seed: cib)
        global = PuzChecksum.compute(file.fill, seed: global)
        global = PuzChecksum.text(file, seed: global)

        let low = [cib, solutionChecksum, fillChecksum, textChecksum].map { UInt8($0 & 0xFF) }
        let high = [cib, solutionChecksum, fillChecksum, textChecksum].map { UInt8($0 >> 8) }
        let masked = zip(Array("ICHE".utf8), low).map { $0 ^ $1 } + zip(Array("ATED".utf8), high).map { $0 ^ $1 }

        var writer = ByteWriter()
        writer.append(bytes)
        writer.overwrite(global, at: 0x00)
        writer.overwrite(cib, at: 0x0E)
        bytes = writer.bytes
        bytes.replaceSubrange(0x10..<0x18, with: masked)

        var body = ByteWriter()
        body.append(file.solution)
        body.append(file.fill)
        for field in [file.title, file.author, file.copyright] + file.clues + [file.notes] {
            body.append(field)
            body.append(UInt8(0))
        }
        for extra in file.extras {
            body.append(padded(Array(extra.code.utf8), to: 4))
            body.append(UInt16(extra.data.count))
            body.append(PuzChecksum.compute(extra.data))
            body.append(extra.data)
            body.append(UInt8(0))
        }
        body.append(file.trailing)
        return file.preamble + bytes + body.bytes
    }

    private static func padded(_ bytes: [UInt8], to length: Int) -> [UInt8] {
        Array((bytes + [UInt8](repeating: 0, count: length)).prefix(length))
    }
}
