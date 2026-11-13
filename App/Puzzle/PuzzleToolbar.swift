import CrosswordCore
import SwiftUI

struct PuzzleToolbar: ToolbarContent {
    let model: PuzzleViewModel
    @Binding var showKeyboard: Bool
    @AppStorage(SettingsKey.skipFilledSquares) private var skipFilled = true
    @State private var showingInfo = false

    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            SaveStatusView(status: model.saveStatus)
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.togglePencil()
            } label: {
                Label("Pencil", systemImage: model.pencilOn ? "pencil.circle.fill" : "pencil")
            }
            .help(model.pencilOn ? "Pencil mode is on: letters are tentative (⇧⌘P)" : "Pencil mode: enter tentative letters (⇧⌘P)")

            Button {
                model.perform(.toggleRebus)
            } label: {
                Label("Rebus", systemImage: "character.textbox")
            }
            .help("Rebus: enter several letters in one square (Esc)")

            Menu {
                ForEach(AssistScope.allCases, id: \.self) { scope in
                    Button("Check \(scope.title)") { model.perform(.check(scope)) }
                }
            } label: {
                Label("Check", systemImage: "checkmark.circle")
            }
            .disabled(!model.canCheck)
            .help(model.canCheck ? "Check square, word, or puzzle (⌥⌘1 / 2 / 3)" : "This puzzle has no answers to check against")

            Menu {
                Button("Reveal Square") { model.perform(.reveal(.square)) }
                Button("Reveal Word") { model.perform(.reveal(.word)) }
                Button("Reveal Puzzle…") { model.pendingConfirmation = .revealPuzzle }
            } label: {
                Label("Reveal", systemImage: "eye")
            }
            .disabled(!model.canCheck)
            .help(model.canCheck ? "Reveal square, word, or puzzle (⌃⌥⌘1 / 2 / 3)" : "This puzzle has no answers to reveal")

            Menu {
                Button("Clear Word", systemImage: "eraser") { model.perform(.clear(.word)) }
                Button("Clear Puzzle", systemImage: "eraser.line.dashed") { model.perform(.clear(.puzzle)) }
                Button("Reset Puzzle…", systemImage: "arrow.counterclockwise", role: .destructive) {
                    model.pendingConfirmation = .resetPuzzle
                }
                Divider()
                Toggle("Skip Filled Squares", isOn: $skipFilled)
                #if os(iOS)
                Toggle("On-Screen Keyboard", isOn: $showKeyboard)
                #endif
                Divider()
                Button("Puzzle Info", systemImage: "info.circle") { showingInfo = true }
                SettingsButton()
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
            .help("Clear, reset, puzzle info, and settings")
            .popover(isPresented: $showingInfo) {
                if let puzzle = model.session?.puzzle {
                    PuzzleInfoView(metadata: puzzle.metadata, format: model.format?.displayName ?? "", canCheck: model.canCheck)
                }
            }
        }
    }
}

extension AssistScope {
    var title: String {
        switch self {
        case .square: "Square"
        case .word: "Word"
        case .puzzle: "Puzzle"
        }
    }
}

private struct SaveStatusView: View {
    let status: PuzzleViewModel.SaveStatus

    var body: some View {
        switch status {
        case .saved:
            Image(systemName: "checkmark.icloud")
                .foregroundStyle(.secondary)
                .help("Progress saved")
                .accessibilityLabel("Progress saved")
        case .pending:
            Image(systemName: "icloud")
                .foregroundStyle(.secondary)
                .symbolEffect(.pulse)
                .help("Saving…")
                .accessibilityLabel("Saving")
        case .failed(let message):
            Image(systemName: "exclamationmark.icloud")
                .foregroundStyle(Theme.incorrect)
                .help("Couldn't save: \(message)")
                .accessibilityLabel("Couldn't save: \(message)")
        }
    }
}

private struct PuzzleInfoView: View {
    let metadata: PuzzleMetadata
    let format: String
    let canCheck: Bool
    @Environment(\.typography) private var typography

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(metadata.title.nonEmpty ?? "Untitled").font(typography.heading)
            if !metadata.author.isEmpty { Text("By \(metadata.author)").font(.headline) }
            if !metadata.copyright.isEmpty { Text(metadata.copyright).font(.caption).foregroundStyle(.secondary) }
            if !metadata.notes.isEmpty {
                Divider()
                Text(metadata.notes).font(typography.clue)
            }
            Divider()
            Text("\(format) file").font(.caption).foregroundStyle(.secondary)
            if !canCheck {
                Label("No answer key — check and reveal are unavailable.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(minWidth: 280, maxWidth: 420, alignment: .leading)
    }
}
