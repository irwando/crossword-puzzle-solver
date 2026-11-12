import SwiftUI

enum LibrarySort: String, CaseIterable, Identifiable {
    case newest
    case title
    case progress

    var id: String { rawValue }
    var label: String {
        switch self {
        case .newest: "Newest First"
        case .title: "Title"
        case .progress: "In Progress First"
        }
    }
}

struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Binding var selection: URL?
    @Binding var showingFolderPicker: Bool
    @AppStorage(SettingsKey.librarySort) private var sort: LibrarySort = .newest
    @State private var searchText = ""

    var body: some View {
        Group {
            if library.folderURL == nil {
                chooseFolderPrompt
            } else if library.items.isEmpty && !library.isRefreshing {
                ContentUnavailableView(
                    "No Puzzles Yet",
                    systemImage: "tray",
                    description: Text("Add .puz, .ipuz, or .jpz files to “\(library.folderURL?.lastPathComponent ?? "")” in iCloud Drive.")
                )
            } else {
                puzzleList
            }
        }
        .navigationTitle(library.folderURL?.lastPathComponent ?? "Crosswords")
        .toolbar { toolbarContent }
    }

    private var chooseFolderPrompt: some View {
        ContentUnavailableView {
            Label("Choose a Puzzle Folder", systemImage: "folder.badge.plus")
        } description: {
            Text("Pick a folder in iCloud Drive. Your progress is saved into the puzzle files, so it follows you to every device that uses the same folder.")
        } actions: {
            Button("Choose Folder…") { showingFolderPicker = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var puzzleList: some View {
        List(selection: $selection) {
            ForEach(groupedItems, id: \.folder) { group in
                Section(group.folder.isEmpty ? "Puzzles" : group.folder) {
                    ForEach(group.items) { item in
                        PuzzleRow(item: item)
                            .tag(item.url)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search titles and authors")
        .refreshable { library.refresh() }
        .overlay(alignment: .bottom) {
            if library.isRefreshing {
                ProgressView().controlSize(.small).padding(8)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem {
            Menu {
                Picker("Sort", selection: $sort) {
                    ForEach(LibrarySort.allCases) { Text($0.label).tag($0) }
                }
                Divider()
                Button("Refresh", systemImage: "arrow.clockwise") { library.refresh() }
                    .disabled(library.folderURL == nil)
                Button("Choose Folder…", systemImage: "folder") { showingFolderPicker = true }
                if library.folderURL != nil {
                    Button("Forget Folder", systemImage: "folder.badge.minus", role: .destructive) {
                        selection = nil
                        library.forgetFolder()
                    }
                }
            } label: {
                Label("Library Options", systemImage: "ellipsis.circle")
            }
        }
    }

    private var filteredItems: [PuzzleItem] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let matching = query.isEmpty ? library.items : library.items.filter { item in
            item.displayTitle.lowercased().contains(query)
                || (item.summary?.author.lowercased().contains(query) ?? false)
                || item.fileName.lowercased().contains(query)
        }
        return matching.sorted(by: sortOrder)
    }

    private func sortOrder(_ a: PuzzleItem, _ b: PuzzleItem) -> Bool {
        switch sort {
        case .newest:
            return a.modified > b.modified
        case .title:
            return a.displayTitle.localizedStandardCompare(b.displayTitle) == .orderedAscending
        case .progress:
            let rank = { (item: PuzzleItem) -> Int in
                guard let progress = item.summary?.progress else { return 2 }
                if progress.isSolved { return 3 }
                return progress.filled > 0 ? 0 : 1
            }
            return rank(a) == rank(b) ? a.modified > b.modified : rank(a) < rank(b)
        }
    }

    private var groupedItems: [(folder: String, items: [PuzzleItem])] {
        let groups = Dictionary(grouping: filteredItems, by: \.folder)
        return groups.keys.sorted { lhs, rhs in
            lhs.isEmpty ? true : rhs.isEmpty ? false : lhs.localizedStandardCompare(rhs) == .orderedAscending
        }.map { ($0, groups[$0] ?? []) }
    }
}

struct PuzzleRow: View {
    let item: PuzzleItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(.system(.body, design: .serif).weight(.semibold))
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            status
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        if let error = item.loadError { return error }
        let parts = [item.summary?.author, item.summary?.format.displayName].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? item.fileName : parts.joined(separator: " · ")
    }

    @ViewBuilder
    private var status: some View {
        if !item.isDownloaded {
            Image(systemName: "icloud.and.arrow.down")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Downloading")
        } else if item.loadError != nil {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(Theme.incorrect)
                .accessibilityLabel("Can't open")
        } else if let progress = item.summary?.progress {
            if progress.isSolved {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Theme.success)
                    .accessibilityLabel("Solved")
            } else if progress.filled > 0 {
                ProgressRing(fraction: progress.fraction)
                    .frame(width: 20, height: 20)
                    .accessibilityLabel("\(Int(progress.fraction * 100)) percent filled")
            }
        }
    }
}

struct ProgressRing: View {
    let fraction: Double

    var body: some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.03, fraction))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
