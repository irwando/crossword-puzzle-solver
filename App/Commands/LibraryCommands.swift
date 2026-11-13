import SwiftUI

/// Library folder actions in the File menu (Mac, and the iPad menu bar).
struct LibraryCommands: Commands {
    let library: LibraryStore
    let navigation: AppNavigation

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Choose Puzzle Folder…") { navigation.showingFolderPicker = true }
                .keyboardShortcut("o", modifiers: .command)
            Button("Refresh Library") { library.refresh() }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(library.folderURL == nil)
            Divider()
            Button("Forget Puzzle Folder") { library.forgetFolder() }
                .disabled(library.folderURL == nil)
        }
        #if os(iOS)
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") { navigation.showingSettings = true }
                .keyboardShortcut(",", modifiers: .command)
        }
        #endif
    }
}
