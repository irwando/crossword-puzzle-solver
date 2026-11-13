import CrosswordCore
import SwiftUI

/// Landscape / Mac layout: clue bar and grid in the center, each clue list placed on the left,
/// right, or below the grid according to settings.
struct WidePuzzleLayout<Grid: View>: View {
    let session: SolveSession
    /// Space available to the layout (outer padding already removed).
    let size: CGSize
    let acrossSide: ClueSide
    let downSide: ClueSide
    let perform: (SolveAction) -> Void
    @ViewBuilder let grid: () -> Grid

    private static var sideSpacing: CGFloat { 16 }
    private static var listSpacing: CGFloat { 8 }
    private static var clueBarHeight: CGFloat { 64 }

    var body: some View {
        let left = directions(on: .left)
        let right = directions(on: .right)
        let below = directions(on: .below)
        HStack(alignment: .top, spacing: Self.sideSpacing) {
            sideColumn(left)
            VStack(spacing: 12) {
                ClueBar(session: session, perform: perform)
                if below.isEmpty {
                    grid()
                } else {
                    grid().frame(height: gridHeight(sideCount: left.count + right.count))
                    clueLists(below).frame(minHeight: 0, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
            sideColumn(right)
        }
    }

    private func directions(on side: ClueSide) -> [Direction] {
        [Direction.across, .down].filter { ($0 == .across ? acrossSide : downSide) == side }
    }

    private var columnWidth: CGFloat { min(320, max(220, size.width * 0.2)) }

    private func sideWidth(_ count: Int) -> CGFloat {
        count == 0 ? 0 : CGFloat(count) * columnWidth + CGFloat(count - 1) * Self.listSpacing + Self.sideSpacing
    }

    @ViewBuilder
    private func sideColumn(_ directions: [Direction]) -> some View {
        if !directions.isEmpty {
            clueLists(directions)
                .frame(width: sideWidth(directions.count) - Self.sideSpacing)
        }
    }

    private func clueLists(_ directions: [Direction]) -> some View {
        HStack(alignment: .top, spacing: Self.listSpacing) {
            ForEach(directions, id: \.self) { direction in
                ClueListView(direction: direction, session: session, perform: perform)
            }
        }
    }

    /// Grid height when lists sit below it: leave roughly a third of the height for the lists.
    private func gridHeight(sideCount: Int) -> CGFloat {
        let puzzle = session.puzzle
        let width = size.width - sideWidth(sideCount)
        let height = size.height - Self.clueBarHeight - 24
        let cell = min(
            GridLayout.maxCellSize,
            width / CGFloat(puzzle.width),
            height * 0.65 / CGFloat(puzzle.height)
        )
        return max(80, floor(cell) * CGFloat(puzzle.height))
    }
}
