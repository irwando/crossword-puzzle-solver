import CrosswordCore
import Foundation

enum LibrarySort: String, CaseIterable, Identifiable {
    case newestPublished
    case oldestPublished
    case title

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newestPublished: "Published Date (Newest First)"
        case .oldestPublished: "Published Date (Oldest First)"
        case .title: "Title"
        }
    }
}

enum StatusFilter: String, CaseIterable, Identifiable {
    case all, notStarted, inProgress, solved

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All Puzzles"
        case .notStarted: "Not Started"
        case .inProgress: "In Progress"
        case .solved: "Solved"
        }
    }

    func matches(_ item: PuzzleItem) -> Bool {
        guard self != .all else { return true }
        guard let progress = item.summary?.progress else { return false }
        switch self {
        case .all: return true
        case .notStarted: return progress.filled == 0
        case .inProgress: return progress.filled > 0 && !progress.isSolved
        case .solved: return progress.isSolved
        }
    }
}

/// Search, filter, and sort applied to the library list.
struct LibraryQuery {
    var search = ""
    var sort = LibrarySort.newestPublished
    var status = StatusFilter.all
    /// A size label such as "15×15", or empty for any size.
    var size = ""

    var isFiltering: Bool { status != .all || !size.isEmpty }

    func apply(to items: [PuzzleItem]) -> [PuzzleItem] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return items
            .filter { query.isEmpty || Self.matches($0, query: query) }
            .filter { status.matches($0) }
            .filter { size.isEmpty || $0.summary?.sizeLabel == size }
            .sorted(by: areInOrder)
    }

    /// Distinct grid sizes in the library, smallest first.
    static func sizes(in items: [PuzzleItem]) -> [String] {
        let summaries = items.compactMap(\.summary)
        let unique = Dictionary(summaries.map { ($0.sizeLabel, $0.width * $0.height) }, uniquingKeysWith: { first, _ in first })
        return unique.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value < $1.value }.map(\.key)
    }

    private static func matches(_ item: PuzzleItem, query: String) -> Bool {
        item.displayTitle.lowercased().contains(query)
            || (item.summary?.author.lowercased().contains(query) ?? false)
            || item.fileName.lowercased().contains(query)
    }

    private func areInOrder(_ a: PuzzleItem, _ b: PuzzleItem) -> Bool {
        switch sort {
        case .title:
            return titleOrder(a, b)
        case .newestPublished, .oldestPublished:
            let dateA = Self.sortDate(a)
            let dateB = Self.sortDate(b)
            if dateA == dateB { return titleOrder(a, b) }
            return sort == .newestPublished ? dateA > dateB : dateA < dateB
        }
    }

    private func titleOrder(_ a: PuzzleItem, _ b: PuzzleItem) -> Bool {
        a.displayTitle.localizedStandardCompare(b.displayTitle) == .orderedAscending
    }

    /// Publication date when known, otherwise when the file was added.
    static func sortDate(_ item: PuzzleItem) -> Date {
        item.summary?.published?.date ?? item.created
    }
}

extension PuzzleDate {
    /// Noon local time on this day (avoids time-zone edge cases when formatting).
    var date: Date? {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
    }
}
