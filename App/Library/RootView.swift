import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(AppNavigation.self) private var navigation
    @State private var selection: URL?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic

    var body: some View {
        @Bindable var navigation = navigation
        NavigationSplitView(columnVisibility: $columnVisibility) {
            LibraryView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        } detail: {
            if let selection {
                PuzzleScreen(url: selection)
                    .id(selection)
            } else {
                ContentUnavailableView(
                    "No Puzzle Selected",
                    systemImage: "square.grid.3x3.square",
                    description: Text(library.folderURL == nil
                        ? "Choose the iCloud Drive folder where you keep your puzzles."
                        : "Pick a puzzle from the list.")
                )
                .background(Theme.paper)
            }
        }
        .fileImporter(isPresented: $navigation.showingFolderPicker, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                selection = nil
                library.chooseFolder(url)
            case .failure(let error):
                library.errorMessage = error.localizedDescription
            }
        }
        #if os(iOS)
        .environment(\.openAppSettings, OpenAppSettingsAction { [navigation] in navigation.showingSettings = true })
        .sheet(isPresented: $navigation.showingSettings) {
            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { navigation.showingSettings = false }
                        }
                    }
            }
            .appSettings()
        }
        #endif
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK") { library.errorMessage = nil }
        } message: {
            Text(library.errorMessage ?? "")
        }
        #if DEBUG
        .task {
            // UI smoke tests: `-CrosswordsAutoOpen thursday.puz`
            if let name = UserDefaults.standard.string(forKey: "CrosswordsAutoOpen"), let folder = library.folderURL {
                selection = folder.appendingPathComponent(name)
            }
            if UserDefaults.standard.bool(forKey: "CrosswordsShowSettings") { navigation.showingSettings = true }
        }
        #endif
        .onChange(of: library.folderURL) { _, folder in
            if folder == nil { selection = nil }
        }
        #if os(iOS)
        .onChange(of: selection) { _, newValue in
            if newValue != nil {
                withAnimation { columnVisibility = .detailOnly }
            }
        }
        #endif
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { library.errorMessage != nil }, set: { if !$0 { library.errorMessage = nil } })
    }
}
