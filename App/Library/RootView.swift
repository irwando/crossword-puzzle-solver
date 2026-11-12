import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @Environment(LibraryStore.self) private var library
    @State private var selection: URL?
    @State private var columnVisibility: NavigationSplitViewVisibility = .automatic
    @State private var showingFolderPicker = false

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            LibraryView(selection: $selection, showingFolderPicker: $showingFolderPicker)
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
        .fileImporter(isPresented: $showingFolderPicker, allowedContentTypes: [.folder]) { result in
            switch result {
            case .success(let url):
                selection = nil
                library.chooseFolder(url)
            case .failure(let error):
                library.errorMessage = error.localizedDescription
            }
        }
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
        }
        #endif
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
