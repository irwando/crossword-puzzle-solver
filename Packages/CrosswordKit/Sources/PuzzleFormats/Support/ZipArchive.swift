import Compression
import Foundation

/// Just enough ZIP support for single-file .jpz archives.
enum ZipArchive {
    struct Entry: Sendable, Hashable {
        var name: String
        var data: Data
    }

    private static let localHeaderSignature: UInt32 = 0x0403_4B50
    private static let centralHeaderSignature: UInt32 = 0x0201_4B50
    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50

    /// Extracts the first file entry from the archive.
    static func firstEntry(in data: Data) throws(PuzzleFormatError) -> Entry {
        let bytes = [UInt8](data)
        guard let eocd = findEndOfCentralDirectory(bytes) else { throw .malformed("zip directory not found") }
        var directory = ByteReader(bytes, offset: eocd + 16)
        var reader = ByteReader(bytes, offset: Int(try directory.uint32()))

        while reader.remaining >= 46 {
            guard try reader.uint32() == centralHeaderSignature else { break }
            _ = try reader.read(6)
            let method = try reader.uint16()
            _ = try reader.read(8)
            let compressedSize = Int(try reader.uint32())
            let uncompressedSize = Int(try reader.uint32())
            let nameLength = Int(try reader.uint16())
            let extraLength = Int(try reader.uint16())
            let commentLength = Int(try reader.uint16())
            _ = try reader.read(8)
            let localOffset = Int(try reader.uint32())
            let name = String(decoding: try reader.read(nameLength), as: UTF8.self)
            _ = try reader.read(extraLength + commentLength)
            if name.hasSuffix("/") || name.hasPrefix("__MACOSX") { continue }

            var local = ByteReader(bytes, offset: localOffset)
            guard try local.uint32() == localHeaderSignature else { throw .malformed("bad zip entry") }
            _ = try local.read(22)
            let localNameLength = Int(try local.uint16())
            let localExtraLength = Int(try local.uint16())
            _ = try local.read(localNameLength + localExtraLength)
            guard compressedSize <= PuzzleCodec.maxFileSize, uncompressedSize <= PuzzleCodec.maxUncompressedSize else {
                throw .tooLarge
            }
            let payload = Data(try local.read(compressedSize))
            return Entry(name: name, data: try decompress(payload, method: method))
        }
        throw .malformed("zip archive is empty")
    }

    private static func findEndOfCentralDirectory(_ bytes: [UInt8]) -> Int? {
        guard bytes.count >= 22 else { return nil }
        let lowest = max(0, bytes.count - 22 - 65_535)
        for offset in stride(from: bytes.count - 22, through: lowest, by: -1)
        where bytes[offset] == 0x50 && bytes[offset + 1] == 0x4B && bytes[offset + 2] == 0x05 && bytes[offset + 3] == 0x06 {
            return offset
        }
        return nil
    }

    private static func decompress(_ data: Data, method: UInt16) throws(PuzzleFormatError) -> Data {
        switch method {
        case 0:
            return data
        case 8:
            return try inflate(data, limit: PuzzleCodec.maxUncompressedSize)
        default:
            throw .unsupported("zip compression method \(method)")
        }
    }

    /// Streams raw DEFLATE (Apple's "zlib" algorithm) and stops once the output passes `limit`, so a
    /// zip bomb can't exhaust memory no matter what sizes its headers claim.
    static func inflate(_ data: Data, limit: Int) throws(PuzzleFormatError) -> Data {
        var output = Data()
        do {
            var offset = 0
            let filter = try InputFilter(.decompress, using: .zlib) { (length: Int) -> Data? in
                let end = min(offset + length, data.count)
                defer { offset = end }
                return offset < end ? data.subdata(in: offset..<end) : nil
            }
            while let page = try filter.readData(ofLength: 64 * 1024) {
                output.append(page)
                if output.count > limit { throw PuzzleFormatError.tooLarge }
            }
        } catch let error as PuzzleFormatError {
            throw error
        } catch {
            throw .malformed("could not inflate zip entry")
        }
        guard !output.isEmpty || data.isEmpty else { throw .malformed("could not inflate zip entry") }
        return output
    }

    /// Writes a single uncompressed entry.
    static func archive(_ entry: Entry) -> Data {
        let name = Array(entry.name.utf8)
        let payload = [UInt8](entry.data)
        let crc = CRC32.checksum(payload)

        var local = ByteWriter()
        local.append(localHeaderSignature)
        local.append(UInt16(20))  // version needed
        local.append(UInt16(0x0800))  // UTF-8 names
        local.append(UInt16(0))  // stored
        local.append(UInt32(0))  // time + date
        local.append(crc)
        local.append(UInt32(payload.count))
        local.append(UInt32(payload.count))
        local.append(UInt16(name.count))
        local.append(UInt16(0))
        local.append(name)
        local.append(payload)

        var central = ByteWriter()
        central.append(centralHeaderSignature)
        central.append(UInt16(20))
        central.append(UInt16(20))
        central.append(UInt16(0x0800))
        central.append(UInt16(0))
        central.append(UInt32(0))
        central.append(crc)
        central.append(UInt32(payload.count))
        central.append(UInt32(payload.count))
        central.append(UInt16(name.count))
        central.append([UInt8](repeating: 0, count: 12))  // extra, comment, disk, attributes
        central.append(UInt32(0))  // local header offset
        central.append(name)

        var end = ByteWriter()
        end.append(endOfCentralDirectorySignature)
        end.append(UInt32(0))  // disk numbers
        end.append(UInt16(1))
        end.append(UInt16(1))
        end.append(UInt32(central.bytes.count))
        end.append(UInt32(local.bytes.count))
        end.append(UInt16(0))

        return Data(local.bytes + central.bytes + end.bytes)
    }
}

enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { n in
        (0..<8).reduce(UInt32(n)) { c, _ in c & 1 != 0 ? 0xEDB8_8320 ^ (c >> 1) : c >> 1 }
    }

    static func checksum(_ bytes: [UInt8]) -> UInt32 {
        ~bytes.reduce(UInt32.max) { crc, byte in table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
    }
}
