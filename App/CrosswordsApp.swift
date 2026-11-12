import SwiftUI

@main
struct CrosswordsApp: App {
    @State private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
        }
        .commands {
            PuzzleCommands(library: library)
        }
        #if os(macOS)
        Settings {
            SettingsView()
                .frame(width: 380)
                .padding()
        }
        #endif
    }
}

enum SettingsKey {
    static let skipFilledSquares = "skipFilledSquares"
    static let folderBookmark = "folderBookmark"
    static let librarySort = "librarySort"
}

struct SettingsView: View {
    @AppStorage(SettingsKey.skipFilledSquares) private var skipFilled = true

    var body: some View {
        Form {
            Toggle("Skip filled squares while typing", isOn: $skipFilled)
            Text("When on, the cursor jumps over squares that already have letters.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
