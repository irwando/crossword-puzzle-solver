import SwiftUI

@main
struct CrosswordsApp: App {
    @State private var library: LibraryStore
    @State private var navigation = AppNavigation()

    init() {
        LocalDefaults.register()
        _library = State(initialValue: LibraryStore())
    }

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
