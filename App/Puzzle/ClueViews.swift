import CrosswordCore
import SwiftUI

/// The active clue above the grid. Tapping the text toggles direction; chevrons step clues.
struct ClueBar: View {
    let session: SolveSession
    let perform: (SolveAction) -> Void

    var body: some View {
        HStack(spacing: 4) {
            stepButton("chevron.left", label: "Previous clue") { perform(.previousClue) }
            Button { perform(.toggleDirection) } label: {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    if let clue = session.currentClue {
                        Text("\(clue.label)\(clue.direction.letter)")
                            .font(Theme.labelFont)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Theme.cursor, in: .rect(cornerRadius: 5))
                            .foregroundStyle(Theme.ink)
                        Text(clue.text)
                            .font(Theme.clueBarFont)
                            .foregroundStyle(Theme.ink)
                            .lineLimit(3)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(" ").font(Theme.clueBarFont).frame(maxWidth: .infinity)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Switches between across and down")
            if let rebus = session.rebusBuffer {
                Text("REBUS: \(rebus.isEmpty ? "…" : rebus)")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.rebusCursor, in: .capsule)
                    .foregroundStyle(.black)
                    .transition(.scale.combined(with: .opacity))
            }
            stepButton("chevron.right", label: "Next clue") { perform(.nextClue) }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .frame(minHeight: 64)
        .background(Theme.surface, in: .rect(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.gridLine.opacity(0.15)))
        .animation(.snappy(duration: 0.2), value: session.rebusBuffer != nil)
    }

    private func stepButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .frame(width: 36, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.mutedInk)
        .accessibilityLabel(label)
    }
}

struct ClueListView: View {
    let direction: Direction
    let session: SolveSession
    let perform: (SolveAction) -> Void

    var body: some View {
        let clues = session.puzzle.clues(direction)
        let current = session.currentClue?.id
        let crossing = session.crossingClue?.id
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(clues) { clue in
                            ClueRow(
                                clue: clue,
                                emphasis: clue.id == current ? .primary : clue.id == crossing ? .secondary : .none,
                                isComplete: clue.cells.allSatisfy { !session.state[$0].isEmpty }
                            )
                            .id(clue.id)
                            .onTapGesture { perform(.selectClue(clue.id)) }
                        }
                    } header: {
                        Text(direction == .across ? "ACROSS" : "DOWN")
                            .font(.system(.caption, design: .rounded).weight(.heavy))
                            .tracking(1.5)
                            .foregroundStyle(Theme.mutedInk)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(Theme.paper)
                    }
                }
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .onChange(of: current) { scroll(proxy, to: [current, crossing]) }
            .onChange(of: crossing) { scroll(proxy, to: [current, crossing]) }
            .onAppear { scroll(proxy, to: [current, crossing], animated: false) }
        }
    }

    private func scroll(_ proxy: ScrollViewProxy, to ids: [ClueID?], animated: Bool = true) {
        guard let target = ids.compactMap({ $0 }).first(where: { $0.direction == direction }) else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(target, anchor: .center) }
        } else {
            proxy.scrollTo(target, anchor: .center)
        }
    }
}

private struct ClueRow: View {
    enum Emphasis { case primary, secondary, none }

    let clue: Clue
    let emphasis: Emphasis
    let isComplete: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(clue.label)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .frame(minWidth: 26, alignment: .trailing)
            Text(clue.text)
                .font(Theme.clueFont)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(isComplete && emphasis == .none ? Theme.mutedInk : Theme.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(background, in: .rect(cornerRadius: 8))
        .overlay(alignment: .leading) {
            if emphasis == .primary {
                RoundedRectangle(cornerRadius: 2).fill(Color.accentColor).frame(width: 3).padding(.vertical, 6)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(emphasis == .primary ? [.isSelected, .isButton] : .isButton)
    }

    private var background: Color {
        switch emphasis {
        case .primary: Theme.wordHighlight
        case .secondary: Theme.crossHighlight
        case .none: .clear
        }
    }
}
