import Foundation

/// A calendar day, independent of time zone.
public struct PuzzleDate: Sendable, Hashable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Returns nil unless the components name a real Gregorian date.
    init?(validYear year: Int, month: Int, day: Int) {
        guard (1900...2199).contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        let components = DateComponents(year: year, month: month, day: day)
        guard components.isValidDate(in: Calendar(identifier: .gregorian)) else { return nil }
        self.init(year: year, month: month, day: day)
    }

    public static func < (lhs: PuzzleDate, rhs: PuzzleDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// Finds a puzzle's publication date. Only .ipuz has a date field, so titles, file names, and
/// copyright lines are searched too ("NY Times, Thu, Nov 11, 2026", "nyt-2026-11-11.puz", …).
public enum PublicationDate {
    public static func resolve(metadata: PuzzleMetadata, fileName: String) -> PuzzleDate? {
        let sources = [metadata.date, metadata.title, fileName, metadata.copyright]
        return sources.lazy.compactMap { find(in: $0) }.first
    }

    public static func find(in text: String) -> PuzzleDate? {
        guard !text.isEmpty else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for pattern in patterns {
            for match in pattern.regex.matches(in: text, range: range) {
                let groups = (1..<match.numberOfRanges).map { index -> String in
                    guard let swiftRange = Range(match.range(at: index), in: text) else { return "" }
                    return String(text[swiftRange])
                }
                if let date = pattern.build(groups) { return date }
            }
        }
        return nil
    }

    // MARK: Patterns

    private struct Pattern: @unchecked Sendable {
        let regex: NSRegularExpression
        let build: @Sendable ([String]) -> PuzzleDate?

        init(_ pattern: String, build: @escaping @Sendable ([String]) -> PuzzleDate?) {
            // Patterns are compile-time constants; a failure here is a programming error.
            // swiftlint:disable:next force_try
            regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            self.build = build
        }
    }

    private static let monthNames = "(jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:t(?:ember)?)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)"

    private static let monthShortNames = "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)"

    private static let patterns: [Pattern] = [
        // Nov 11, 2026 · November 11th 2026 · Sept. 3rd, 2025
        Pattern("\\b\(monthNames)\\.?\\s+(\\d{1,2})(?:st|nd|rd|th)?,?\\s+((?:19|20|21)\\d{2})\\b") { g in
            date(year: g[2], month: month(g[0]), day: g[1])
        },
        // 3 March 2024
        Pattern("\\b(\\d{1,2})(?:st|nd|rd|th)?\\s+\(monthNames)\\.?,?\\s+((?:19|20|21)\\d{2})\\b") { g in
            date(year: g[2], month: month(g[1]), day: g[0])
        },
        // 2026-11-11 · 2026.01.05 · 2026_11_11
        Pattern("(?<!\\d)((?:19|20|21)\\d{2})[-./_](\\d{1,2})[-./_](\\d{1,2})(?!\\d)") { g in
            date(year: g[0], month: Int(g[1]), day: g[2])
        },
        // 20261111
        Pattern("(?<!\\d)((?:19|20|21)\\d{2})(\\d{2})(\\d{2})(?!\\d)") { g in
            date(year: g[0], month: Int(g[1]), day: g[2])
        },
        // 11/09/2026 · 1/2/26 (US month/day order, as in the ipuz spec)
        Pattern("(?<!\\d)(\\d{1,2})[/.-](\\d{1,2})[/.-](\\d{4}|\\d{2})(?!\\d)") { g in
            date(year: g[2], month: Int(g[0]), day: g[1])
        },
        // Nov1126 (common file naming: month, day, two-digit year)
        Pattern("(?<![a-z])\(monthShortNames)(\\d{2})(\\d{2})(?!\\d)") { g in
            date(year: g[2], month: month(g[0]), day: g[1])
        },
    ]

    private static func month(_ name: String) -> Int? {
        let prefixes = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        let key = String(name.lowercased().prefix(3))
        return prefixes.firstIndex(of: key).map { $0 + 1 }
    }

    private static func date(year: String, month: Int?, day: String) -> PuzzleDate? {
        guard var year = Int(year), let month, let day = Int(day) else { return nil }
        if year < 100 { year += 2000 }
        return PuzzleDate(validYear: year, month: month, day: day)
    }
}
