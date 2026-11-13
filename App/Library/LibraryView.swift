import SwiftUI

struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(AppNavigation.self) private var navigation
    @Binding var selection: URL?
    @AppStorage(SettingsKey.librarySort) private var sort: LibrarySort = .newestPublished
    @AppStorage(SettingsKey.libraryStatusFilter) private var statusFilter: StatusFilter = .all
    @AppStorage(SettingsKey.librarySizeFilter) private var sizeFilter = ""
    @State private var searchText = ""

    private var query: LibraryQuery {
        LibraryQuery(search: searchText, sort: sort, status: statusFilter, size: sizeFilter)
    }

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
    }

    private var chooseFolderPrompt: some View {
        ContentUnavailableView {
            Label("Choose a Puzzle Folder", systemImage: "folder.badge.plus")
        } description: {
            Text("Pick a folder in iCloud Drive. Your progress is saved into the puzzle files, so it follows you to every device that uses the same folder.")
        } actions: {
            Button("Choose Folder…") { navigation.showingFolderPicker = true }
                .buttonStyle(.borderedProminent)
        }
    }

    private var puzzleList: some View {
        List(selection: $selection) {
            if filteredItems.isEmpty && query.isFiltering {
                ContentUnavailableView {
                    Label("No Matching Puzzles", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("No puzzles match \(filterSummary).")
                } actions: {
                    Button("Clear Filters", action: clearFilters)
                }
                .listRowSeparator(.hidden)
            }
            ForEach(groupedItems, id: \.folder) { group in
                Section(group.folder.isEmpty ? "Puzzles" : group.folder) {
                    ForEach(group.items) { item in
                        PuzzleRow(item: item)
                            .tag(item.url)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            LibraryControls(
                status: $statusFilter, size: $sizeFilter, sort: $sort,
                sizes: LibraryQuery.sizes(in: library.items)
            )
        }
        .searchable(text: $searchText, placement: .sidebar, prompt: "Search titles and authors")
        .refreshable { library.refresh() }
        .overlay(alignment: .bottom) {
            if library.isRefreshing {
                ProgressView().controlSize(.small).padding(8)
            }
        }
    }

    private var filteredItems: [PuzzleItem] { query.apply(to: library.items) }

    private func clearFilters() {
        statusFilter = .all
        sizeFilter = ""
    }

    private var filterSummary: String {
        LibraryControls.filterSummary(status: statusFilter, size: sizeFilter) ?? ""
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
    @Environment(\.typography) private var typography

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayTitle)
                    .font(typography.listTitle)
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
        guard let summary = item.summary else { return item.fileName }
        let published = summary.published?.date?.formatted(date: .abbreviated, time: .omitted)
        let parts = [summary.author, published, summary.sizeLabel].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
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
