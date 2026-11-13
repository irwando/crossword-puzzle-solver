import SwiftUI

/// Settings for what gets highlighted while solving, and in which colors.
struct HighlightSettingsSection: View {
    @AppStorage(SettingsKey.squareColor) private var squareColor: SquareColor = .yellow
    @AppStorage(SettingsKey.wordColor) private var wordColor: WordColor = .blue
    @AppStorage(SettingsKey.highlightWord) private var highlightWord = true
    @AppStorage(SettingsKey.highlightCrossing) private var highlightCrossing = true

    var body: some View {
        Section {
            Toggle("Highlight current clue", isOn: $highlightWord)
                .help("Shade the squares of the clue you're solving, and the clue in the list")
            Toggle("Highlight crossing clue", isOn: $highlightCrossing)
                .help("Lightly shade the other direction's clue through the selected square")
            LabeledContent("Selected square") {
                SwatchPicker(options: SquareColor.allCases, selection: $squareColor,
                             label: \.label, fill: \.color)
            }
            LabeledContent("Clue highlight") {
                SwatchPicker(options: WordColor.allCases, selection: $wordColor,
                             label: \.label, fill: \.word)
            }
            HighlightPreview(style: HighlightStyle(square: squareColor, word: wordColor,
                                                   showsWord: highlightWord, showsCrossing: highlightCrossing))
        } header: {
            Text("Highlighting")
        } footer: {
            Text("The crossing clue uses a paler shade of the clue highlight color.")
        }
    }
}

private struct SwatchPicker<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: KeyPath<Option, String>
    let fill: KeyPath<Option, Color>

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button { selection = option } label: {
                    Circle()
                        .fill(option[keyPath: fill])
                        .overlay(Circle().strokeBorder(Theme.gridLine.opacity(0.35), lineWidth: 1))
                        .frame(width: 22, height: 22)
                        .padding(3)
                        .overlay(Circle().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(option[keyPath: label])
                .accessibilityLabel(option[keyPath: label])
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

/// A small sample grid: an across word with the cursor on it and a down word crossing it.
private struct HighlightPreview: View {
    let style: HighlightStyle
    private static let letters = ["", "C", "A", "T", "S"]
    private static let cursorColumn = 2
    private static let cellSize: CGFloat = 26

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { column in
                        cell(row: row, column: column)
                    }
                }
            }
        }
        .overlay(Rectangle().strokeBorder(Theme.block, lineWidth: 1.5))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }

    private func cell(row: Int, column: Int) -> some View {
        let isBlock = row != 1 && column == 0
        let letter = row == 1 ? Self.letters[column] : ""
        return Text(letter)
            .font(.system(size: Self.cellSize * 0.55, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(width: Self.cellSize, height: Self.cellSize)
            .background(isBlock ? Theme.block : background(row: row, column: column))
            .border(Theme.gridLine, width: 0.5)
    }

    private func background(row: Int, column: Int) -> Color {
        if row == 1 && column == Self.cursorColumn { return style.squareColor }
        if row == 1, let color = style.wordColor { return color }
        if column == Self.cursorColumn, let color = style.crossingColor { return color }
        return Theme.cell
    }
}
