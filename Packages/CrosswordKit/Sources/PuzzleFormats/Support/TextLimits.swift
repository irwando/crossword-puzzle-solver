import Foundation

/// Bounds on grids and text taken from puzzle files, which may come from anywhere.
enum TextLimits {
    /// Longest clue, title, or note we keep; real ones are well under 500 characters.
    static let maxTextLength = 4_000
    /// Longest clue label ("17", "17/23-Down").
    static let maxLabelLength = 24
    /// Longest square entry or solution; rebus entries are a handful of letters.
    static let maxEntryLength = 24

    /// Removes control characters (keeping newlines and tabs) and truncates to `maxLength` characters.
    static func clean(_ text: String, maxLength: Int = maxTextLength) -> String {
        var scalars = String.UnicodeScalarView()
        var count = 0
        for scalar in text.unicodeScalars where !isControl(scalar) {
            scalars.append(scalar)
            count += 1
            // Count scalars as a cheap upper bound; trim to characters below.
            if count >= maxLength * 4 { break }
        }
        let cleaned = String(scalars)
        return cleaned.count > maxLength ? String(cleaned.prefix(maxLength)) : cleaned
    }

    static func entry(_ text: String) -> String {
        clean(text, maxLength: maxEntryLength).uppercased()
    }

    static func label(_ text: String) -> String {
        clean(text, maxLength: maxLabelLength)
    }

    private static func isControl(_ scalar: Unicode.Scalar) -> Bool {
        if scalar == "\n" || scalar == "\t" { return false }
        switch scalar.value {
        case 0x00...0x1F, 0x7F...0x9F: return true
        default: return false
        }
    }
}

/// Grid dimensions accepted from any format (the .puz format's own maximum).
enum GridLimits {
    static let maxSide = 255

    /// Validates untrusted dimensions without risking integer overflow.
    static func isValid(width: Int, height: Int, maxCells: Int = maxSide * maxSide) -> Bool {
        (1...maxSide).contains(width) && (1...maxSide).contains(height) && width * height <= maxCells
    }
}
