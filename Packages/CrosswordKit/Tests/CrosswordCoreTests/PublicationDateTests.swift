import Testing
@testable import CrosswordCore

@Suite("Publication date")
struct PublicationDateTests {
    @Test("Finds dates in common title, file name, and field formats", arguments: [
        ("NY Times, Thu, Nov 11, 2026", PuzzleDate(year: 2026, month: 11, day: 11)),
        ("Thursday, November 11, 2026", PuzzleDate(year: 2026, month: 11, day: 11)),
        ("LA Times Sept. 3rd, 2025", PuzzleDate(year: 2025, month: 9, day: 3)),
        ("WSJ 3 March 2024", PuzzleDate(year: 2024, month: 3, day: 3)),
        ("nyt-2026-11-11.puz", PuzzleDate(year: 2026, month: 11, day: 11)),
        ("puzzle_2026.01.05", PuzzleDate(year: 2026, month: 1, day: 5)),
        ("nyt20261111.puz", PuzzleDate(year: 2026, month: 11, day: 11)),
        ("11/09/2026", PuzzleDate(year: 2026, month: 11, day: 9)),
        ("Puzzle 1/2/26", PuzzleDate(year: 2026, month: 1, day: 2)),
        ("Nov1126.puz", PuzzleDate(year: 2026, month: 11, day: 11)),
        ("Feb 29, 2024", PuzzleDate(year: 2024, month: 2, day: 29)),
    ])
    func findsDate(text: String, expected: PuzzleDate) {
        #expect(PublicationDate.find(in: text) == expected)
    }

    @Test("Ignores text without a full, valid date", arguments: [
        "Thursday Themeless",
        "© 2026 The New York Times",
        "Feb 30, 2024",
        "Puzzle 13/45/2026",
        "Grid 15x15, 78 words",
        "",
    ])
    func ignoresNonDates(text: String) {
        #expect(PublicationDate.find(in: text) == nil)
    }

    @Test func prefersDateFieldThenTitleThenFileName() {
        let withField = PuzzleMetadata(title: "Mon, Jan 5, 2026", date: "02/03/2025")
        #expect(PublicationDate.resolve(metadata: withField, fileName: "x.puz") == PuzzleDate(year: 2025, month: 2, day: 3))

        let titleOnly = PuzzleMetadata(title: "Mon, Jan 5, 2026")
        #expect(PublicationDate.resolve(metadata: titleOnly, fileName: "2024-01-01.puz") == PuzzleDate(year: 2026, month: 1, day: 5))

        let fileNameOnly = PuzzleMetadata(title: "Themeless", copyright: "© 2026")
        #expect(PublicationDate.resolve(metadata: fileNameOnly, fileName: "2024-01-01.puz") == PuzzleDate(year: 2024, month: 1, day: 1))

        let copyrightOnly = PuzzleMetadata(title: "Themeless", copyright: "Published May 4, 2023")
        #expect(PublicationDate.resolve(metadata: copyrightOnly, fileName: "a.puz") == PuzzleDate(year: 2023, month: 5, day: 4))

        #expect(PublicationDate.resolve(metadata: PuzzleMetadata(title: "Themeless"), fileName: "a.puz") == nil)
    }

    @Test func ordersChronologically() {
        let dates = [
            PuzzleDate(year: 2026, month: 1, day: 2),
            PuzzleDate(year: 2025, month: 12, day: 31),
            PuzzleDate(year: 2026, month: 1, day: 1),
        ]
        #expect(dates.sorted() == [
            PuzzleDate(year: 2025, month: 12, day: 31),
            PuzzleDate(year: 2026, month: 1, day: 1),
            PuzzleDate(year: 2026, month: 1, day: 2),
        ])
    }
}
