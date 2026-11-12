import CrosswordCore
import SwiftUI

extension FocusedValues {
    @Entry var puzzleModel: PuzzleViewModel?
}

/// Menu bar commands (Mac, and iPad with a hardware keyboard).
struct PuzzleCommands: Commands {
    let library: LibraryStore
    @FocusedValue(\.puzzleModel) private var model

    var body: some Commands {
        CommandMenu("Puzzle") {
            Section {
                Button("Check Square") { model?.perform(.check(.square)) }
                    .keyboardShortcut("1", modifiers: [.command, .option])
                Button("Check Word") { model?.perform(.check(.word)) }
                    .keyboardShortcut("2", modifiers: [.command, .option])
                Button("Check Puzzle") { model?.perform(.check(.puzzle)) }
                    .keyboardShortcut("3", modifiers: [.command, .option])
            }
            .disabled(model?.canCheck != true)

            Section {
                Button("Reveal Square") { model?.perform(.reveal(.square)) }
                    .keyboardShortcut("1", modifiers: [.command, .option, .control])
                Button("Reveal Word") { model?.perform(.reveal(.word)) }
                    .keyboardShortcut("2", modifiers: [.command, .option, .control])
                Button("Reveal Puzzle…") { model?.pendingConfirmation = .revealPuzzle }
                    .keyboardShortcut("3", modifiers: [.command, .option, .control])
            }
            .disabled(model?.canCheck != true)

            Section {
                Button("Rebus Entry") { model?.perform(.toggleRebus) }
                    .keyboardShortcut("r", modifiers: [.command, .option])
                Button(model?.pencilOn == true ? "Turn Pencil Off" : "Turn Pencil On") { model?.togglePencil() }
                    .keyboardShortcut("p", modifiers: [.command, .shift])
            }
            .disabled(model == nil)

            Section {
                Button("Clear Word") { model?.perform(.clear(.word)) }
                Button("Clear Puzzle") { model?.perform(.clear(.puzzle)) }
                Button("Reset Puzzle…") { model?.pendingConfirmation = .resetPuzzle }
            }
            .disabled(model == nil)

            Divider()
            Button("Refresh Library") { library.refresh() }
                .keyboardShortcut("r", modifiers: .command)
        }
    }
}
