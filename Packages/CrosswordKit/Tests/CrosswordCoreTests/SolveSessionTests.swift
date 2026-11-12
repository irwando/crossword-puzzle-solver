import Testing
@testable import CrosswordCore

@Suite("Grid numbering")
struct GridNumberingTests {
    @Test func numbersSmallGrid() {
        let puzzle = TestPuzzles.small()
        let ids = puzzle.clues.map { "\($0.number)\($0.direction.letter)" }
        #expect(ids == ["1A", "3A", "1D", "2D"])
        #expect(puzzle.clues[0].cells == [0, 1, 2])
        #expect(puzzle.clues[1].cells == [6, 7, 8])
        #expect(puzzle.clues[2].cells == [0, 3, 6])
        #expect(puzzle.clues[3].cells == [2, 5, 8])
    }
}

@Suite("Solve session")
struct SolveSessionTests {
    let puzzle = TestPuzzles.wordSquare()

    func session(skip: Bool = true) -> SolveSession {
        SolveSession(puzzle: puzzle, settings: SolveSettings(skipFilledSquares: skip))
    }

    @Test func startsOnFirstClue() {
        let s = session()
        #expect(s.cursor == Cursor(cell: 0, direction: .across))
        #expect(s.currentClue?.id == ClueID(.across, 1))
    }

    @Test func typingFillsAndAdvances() {
        let s = session().performing(.type("h")).performing(.type("e"))
        #expect(s.state[0].entry == "H")
        #expect(s.state[1].entry == "E")
        #expect(s.cursor.cell == 2)
        #expect(s.dirtyCells == [0, 1])
    }

    @Test func endOfWordJumpsToNextIncompleteClue() {
        let s = session().performing(.type("HEART"))
        #expect(s.cursor == Cursor(cell: 5, direction: .across))
    }

    @Test func skipFilledSquaresSkipsOverEntries() {
        var s = session().performing(.select(cell: 2)).performing(.type("A"))
        s = s.performing(.select(cell: 0)).performing(.type("H"))
        #expect(s.cursor.cell == 1)
        s = s.performing(.type("E"))
        #expect(s.cursor.cell == 3, "should skip filled cell 2")
    }

    @Test func withoutSkipMovesToNextCell() {
        var s = session(skip: false).performing(.select(cell: 2)).performing(.type("A"))
        s = s.performing(.select(cell: 1)).performing(.type("E"))
        #expect(s.cursor.cell == 2)
    }

    @Test func tappingSelectedCellTogglesDirection() {
        let s = session().performing(.select(cell: 0))
        #expect(s.cursor.direction == .down)
    }

    @Test func perpendicularArrowSwitchesDirectionFirst() {
        let s = session().performing(.move(.down))
        #expect(s.cursor == Cursor(cell: 0, direction: .down))
        let moved = s.performing(.move(.down))
        #expect(moved.cursor == Cursor(cell: 5, direction: .down))
    }

    @Test func arrowsSkipBlocks() {
        let s = SolveSession(puzzle: TestPuzzles.small()).performing(.select(cell: 3))
        #expect(s.cursor.direction == .down, "cell 3 has no across word")
        let moved = s.performing(.move(.right))
        #expect(moved.cursor == Cursor(cell: 5, direction: .down))
    }

    @Test func backspaceClearsThenMovesBack() {
        var s = session().performing(.type("HE"))
        #expect(s.cursor.cell == 2)
        s = s.performing(.backspace)
        #expect(s.cursor.cell == 1)
        #expect(s.state[1].isEmpty)
        s = s.performing(.type("E")).performing(.select(cell: 1)).performing(.select(cell: 1))
        s = s.performing(.backspace)
        #expect(s.state[1].isEmpty)
        #expect(s.cursor.cell == 1)
    }

    @Test func tabCyclesClues() {
        let s = session().performing(.nextClue)
        #expect(s.currentClue?.id == ClueID(.across, 6))
        let back = s.performing(.previousClue).performing(.previousClue)
        #expect(back.currentClue?.id == ClueID(.down, 5))
    }

    @Test func rebusEntry() {
        var s = session().performing(.toggleRebus)
        #expect(s.rebusBuffer == "")
        s = s.performing(.type("h")).performing(.type("ea")).performing(.backspace)
        #expect(s.rebusBuffer == "HE")
        s = s.performing(.toggleRebus)
        #expect(s.rebusBuffer == nil)
        #expect(s.state[0].entry == "HE")
        #expect(s.cursor.cell == 1)
    }

    @Test func pencilMarksEntries() {
        let s = session().performing(.setPencil(true)).performing(.type("H"))
            .performing(.setPencil(false)).performing(.type("E"))
        #expect(s.state[0].marks.contains(.pencil))
        #expect(!s.state[1].marks.contains(.pencil))
    }

    @Test func checkMarksIncorrectAndCorrectingClearsIt() {
        var s = session().performing(.type("HX"))
        s = s.performing(.check(.word))
        #expect(!s.state[0].marks.contains(.incorrect))
        #expect(s.state[1].marks.contains([.incorrect, .previouslyIncorrect]))
        s = s.performing(.select(cell: 1)).performing(.select(cell: 1)).performing(.type("E"))
        #expect(!s.state[1].marks.contains(.incorrect))
        #expect(s.state[1].marks.contains(.previouslyIncorrect))
    }

    @Test func checkSquareOnlyAffectsCursor() {
        let s = session().performing(.type("XX")).performing(.select(cell: 0)).performing(.select(cell: 0))
            .performing(.check(.square))
        #expect(s.state[0].marks.contains(.incorrect))
        #expect(!s.state[1].marks.contains(.incorrect))
    }

    @Test func revealLocksCells() {
        var s = session().performing(.type("X")).performing(.reveal(.word))
        #expect(s.state[0].entry == "H")
        #expect(s.state[0].marks.contains([.revealed, .previouslyIncorrect]))
        #expect(s.state[4].marks.contains(.revealed))
        s = s.performing(.select(cell: 0)).performing(.select(cell: 0)).performing(.type("Z"))
        #expect(s.state[0].entry == "H", "revealed cells are locked")
    }

    @Test func revealPuzzleSolves() {
        let s = session().performing(.reveal(.puzzle))
        #expect(s.isSolved)
    }

    @Test func clearKeepsRevealed() {
        let s = session().performing(.type("HEA")).performing(.select(cell: 0))
            .performing(.reveal(.square)).performing(.clear(.puzzle))
        #expect(s.state[1].isEmpty)
        let reset = s.performing(.resetPuzzle)
        #expect(reset.state.cells.allSatisfy { $0 == .empty })
    }

    @Test func solvedDetection() {
        let s = session().performing(.type("HEARTEMBERABUSERESINTREND"))
        #expect(s.isSolved)
        #expect(s.progress.fraction == 1)
    }

    @Test func mergeKeepsLocalDirtyCells() {
        let local = session().markingClean().performing(.type("H"))
        var remote = SolveState.empty(for: puzzle)
        remote[0] = CellState(entry: "Q")
        remote[10] = CellState(entry: "A")
        let merged = local.merging(remote: remote)
        #expect(merged.state[0].entry == "H")
        #expect(merged.state[10].entry == "A")
    }

    @Test func markingSavedKeepsInFlightEdits() {
        let typed = session().performing(.type("H"))
        let snapshot = typed.state
        let later = typed.performing(.type("E")).markingSaved(snapshot)
        #expect(later.dirtyCells == [1])
    }

    @Test func rebusSolutionMatchesCaseInsensitively() {
        let p = TestPuzzles.make(rows: ["AB", "CD"], rebus: [0: "STAR"])
        let s = SolveSession(puzzle: p).performing(.toggleRebus).performing(.type("star")).performing(.commitRebus)
            .performing(.check(.square))
        #expect(s.state[0].entry == "STAR")
        #expect(!s.state[0].marks.contains(.incorrect))
    }
}
