import SwiftUI

@main
struct CrosswordsApp: App {
    @State private var library = LibraryStore()
    @State private var navigation = AppNavigation()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(navigation)
                .appSettings()
        }
        .commands {
            LibraryCommands(library: library, navigation: navigation)
            PuzzleCommands()
        }
        #if os(macOS)
        Settings {
            SettingsView()
                .frame(width: 480)
                .fixedSize(horizontal: false, vertical: true)
                .appSettings()
        }
        #endif
    }
}
