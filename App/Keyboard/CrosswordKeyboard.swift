import CrosswordCore
import SwiftUI

/// On-screen keyboard tailored to crosswords: letters, delete, rebus, pencil, and clue navigation.
struct CrosswordKeyboard: View {
    let rebusActive: Bool
    let pencilOn: Bool
    let perform: (SolveAction) -> Void
    let togglePencil: () -> Void

    private static let rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
    private let spacing: CGFloat = 6

    var body: some View {
        GeometryReader { proxy in
            let unit = (proxy.size.width - spacing * 9) / 10
            VStack(spacing: spacing) {
                letterRow(Self.rows[0], unit: unit)
                letterRow(Self.rows[1], unit: unit)
                HStack(spacing: spacing) {
                    KeyButton(style: rebusActive ? .accent : .function, width: unit * 1.5) {
                        perform(.toggleRebus)
                    } label: {
                        Text(rebusActive ? "Done" : "Rebus").font(.system(.callout, design: .rounded).weight(.semibold))
                    }
                    ForEach(Array(Self.rows[2]), id: \.self) { letter in letterKey(letter, unit: unit) }
                    KeyButton(style: .function, width: unit * 1.5) { perform(.backspace) } label: {
                        Image(systemName: "delete.left")
                    }
                    .accessibilityLabel("Delete")
                }
                HStack(spacing: spacing) {
                    KeyButton(style: pencilOn ? .accent : .function, width: unit * 2) { togglePencil() } label: {
                        Label("Pencil", systemImage: pencilOn ? "pencil.circle.fill" : "pencil")
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                    }
                    KeyButton(style: .function, width: unit * 1.5) { perform(.previousClue) } label: {
                        Image(systemName: "chevron.left.2")
                    }
                    .accessibilityLabel("Previous clue")
                    KeyButton(style: .function, width: unit * 3) { perform(.toggleDirection) } label: {
                        Label("Across / Down", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(.callout, design: .rounded).weight(.semibold))
                    }
                    KeyButton(style: .function, width: unit * 1.5) { perform(.nextClue) } label: {
                        Image(systemName: "chevron.right.2")
                    }
                    .accessibilityLabel("Next clue")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 4 * 50 + 3 * spacing)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func letterRow(_ letters: String, unit: CGFloat) -> some View {
        HStack(spacing: spacing) {
            ForEach(Array(letters), id: \.self) { letterKey($0, unit: unit) }
        }
    }

    private func letterKey(_ letter: Character, unit: CGFloat) -> some View {
        KeyButton(style: .letter, width: unit) { perform(.type(String(letter))) } label: {
            Text(String(letter)).font(.system(size: 22, weight: .medium, design: .rounded))
        }
    }
}

private enum KeyKind { case letter, function, accent }

private struct KeyButton<Label: View>: View {
    let style: KeyKind
    let width: CGFloat
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    var body: some View {
        Button(action: action, label: label)
            .buttonStyle(KeyStyle(style: style))
            .frame(width: max(0, width), height: 50)
    }
}

private struct KeyStyle: ButtonStyle {
    let style: KeyKind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(style == .accent ? Color.white : Theme.ink)
            .background(fill(pressed: configuration.isPressed), in: .rect(cornerRadius: 8))
            .shadow(color: .black.opacity(configuration.isPressed ? 0 : 0.18), radius: 0, y: 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }

    private func fill(pressed: Bool) -> Color {
        switch style {
        case .letter: pressed ? Theme.cursor : Theme.surface
        case .function: pressed ? Theme.cursor : Theme.shaded
        case .accent: Color.accentColor.opacity(pressed ? 0.8 : 1)
        }
    }
}
