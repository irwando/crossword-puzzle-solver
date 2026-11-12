import CrosswordCore
import SwiftUI

/// Geometry for a puzzle laid out in a given size, square cells, centered.
struct GridLayout {
    static let maxCellSize: CGFloat = 96

    let columns: Int
    let rows: Int
    let cellSize: CGFloat

    init(available: CGSize, columns: Int, rows: Int) {
        self.columns = columns
        self.rows = rows
        let raw = min(available.width / CGFloat(columns), available.height / CGFloat(rows))
        self.cellSize = min(Self.maxCellSize, max(8, floor(raw)))
    }

    var size: CGSize { CGSize(width: cellSize * CGFloat(columns), height: cellSize * CGFloat(rows)) }

    func rect(for index: Int) -> CGRect {
        CGRect(x: CGFloat(index % columns) * cellSize, y: CGFloat(index / columns) * cellSize, width: cellSize, height: cellSize)
    }

    func cell(at point: CGPoint) -> Int? {
        let column = Int(point.x / cellSize)
        let row = Int(point.y / cellSize)
        guard point.x >= 0, point.y >= 0, column < columns, row < rows else { return nil }
        return row * columns + column
    }
}

struct GridView: View {
    let session: SolveSession
    let onSelect: (Int) -> Void

    var body: some View {
        GeometryReader { proxy in
            let layout = GridLayout(available: proxy.size, columns: session.puzzle.width, rows: session.puzzle.height)
            Canvas(rendersAsynchronously: false) { context, _ in
                GridRenderer(session: session, layout: layout).draw(in: &context)
            }
            .frame(width: layout.size.width, height: layout.size.height)
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { value in
                if let cell = layout.cell(at: value.location) { onSelect(cell) }
            })
            #if os(macOS)
            .onContinuousHover { phase in
                if case .active = phase { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            }
            #endif
            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .accessibilityElement()
        .accessibilityLabel("Crossword grid")
        .accessibilityValue(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let cell = session.state[session.cursor.cell]
        let clue = session.currentClue.map { "\($0.label) \($0.direction.rawValue): \($0.text)" } ?? ""
        let entry = cell.isEmpty ? "empty" : cell.entry
        return "\(clue). Square \(entry)."
    }
}

private struct GridRenderer {
    let session: SolveSession
    let layout: GridLayout

    private var puzzle: Puzzle { session.puzzle }

    func draw(in context: inout GraphicsContext) {
        let word = Set(session.currentWordCells)
        let crossing = Set(session.crossingClue?.cells ?? [])

        for index in puzzle.cells.indices {
            context.fill(Path(layout.rect(for: index)), with: .color(background(index, word: word, crossing: crossing)))
        }
        drawGridLines(in: &context)
        for index in puzzle.cells.indices where puzzle.cells[index].isOpen {
            drawContents(of: index, in: &context)
        }
    }

    private func background(_ index: Int, word: Set<Int>, crossing: Set<Int>) -> Color {
        let cell = puzzle.cells[index]
        switch cell.kind {
        case .void: return .clear
        case .block: return Theme.block
        case .open: break
        }
        if index == session.cursor.cell {
            return session.rebusBuffer == nil ? Theme.cursor : Theme.rebusCursor
        }
        if word.contains(index) { return Theme.wordHighlight }
        if cell.isShaded { return Theme.shaded }
        if crossing.contains(index) { return Theme.crossHighlight }
        return Theme.cell
    }

    private func drawGridLines(in context: inout GraphicsContext) {
        var lines = Path()
        var border = Path()
        for index in puzzle.cells.indices where puzzle.cells[index].kind != .void {
            lines.addRect(layout.rect(for: index))
        }
        let hasVoid = puzzle.cells.contains { $0.kind == .void }
        if hasVoid {
            border = lines
        } else {
            border.addRect(CGRect(origin: .zero, size: layout.size))
        }
        context.stroke(lines, with: .color(Theme.gridLine), lineWidth: max(0.5, layout.cellSize / 60))
        context.stroke(border, with: .color(Theme.block), lineWidth: hasVoid ? 1 : max(1.5, layout.cellSize / 18))
    }

    private func drawContents(of index: Int, in context: inout GraphicsContext) {
        let rect = layout.rect(for: index)
        let size = layout.cellSize
        let cell = puzzle.cells[index]
        let state = session.state[index]

        if cell.isCircled {
            context.stroke(Path(ellipseIn: rect.insetBy(dx: size * 0.04, dy: size * 0.04)),
                           with: .color(Theme.mutedInk), lineWidth: max(0.75, size / 40))
        }

        if let number = cell.number {
            let label = context.resolve(
                Text("\(number)").font(.system(size: min(size * 0.27, 20), weight: .medium)).foregroundStyle(Theme.ink)
            )
            context.draw(label, at: CGPoint(x: rect.minX + size * 0.06, y: rect.minY + size * 0.02), anchor: .topLeading)
        }

        let isEditingRebus = index == session.cursor.cell && session.rebusBuffer != nil
        let entry = isEditingRebus ? (session.rebusBuffer ?? "") + "▏" : state.entry
        if !entry.isEmpty {
            let color: Color = state.marks.contains(.revealed) ? Theme.revealed
                : state.marks.contains(.pencil) ? Theme.pencil : Theme.ink
            let weight: Font.Weight = state.marks.contains(.pencil) ? .regular : .semibold
            let resolver = context
            let resolve = { (fontSize: CGFloat) in
                resolver.resolve(Text(entry).font(.system(size: fontSize, weight: weight)).foregroundStyle(color))
            }
            let baseSize = size * 0.6
            var text = resolve(baseSize)
            let measured = text.measure(in: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
            let maxWidth = size * 0.9
            if measured.width > maxWidth {
                text = resolve(max(size * 0.14, baseSize * maxWidth / measured.width))
            }
            context.draw(text, at: CGPoint(x: rect.midX, y: rect.midY + size * 0.1), anchor: .center)
        }

        drawMarks(state.marks, in: rect, context: &context)
    }

    private func drawMarks(_ marks: CellMarks, in rect: CGRect, context: inout GraphicsContext) {
        let size = layout.cellSize
        if marks.contains(.incorrect) {
            var slash = Path()
            slash.move(to: CGPoint(x: rect.minX + size * 0.12, y: rect.maxY - size * 0.12))
            slash.addLine(to: CGPoint(x: rect.maxX - size * 0.12, y: rect.minY + size * 0.12))
            context.stroke(slash, with: .color(Theme.incorrect), style: StrokeStyle(lineWidth: max(1.5, size / 16), lineCap: .round))
        }
        let corner: Color? = marks.contains(.revealed) ? Theme.revealed
            : marks.contains(.previouslyIncorrect) ? Theme.incorrect : nil
        if let corner {
            let side = size * 0.26
            var triangle = Path()
            triangle.move(to: CGPoint(x: rect.maxX - side, y: rect.minY))
            triangle.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            triangle.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + side))
            triangle.closeSubpath()
            context.fill(triangle, with: .color(corner))
        }
    }
}
