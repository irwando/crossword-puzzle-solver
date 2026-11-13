import SwiftUI

/// Filter and sort menus shown at the top of the puzzle list, so they hide with the column.
struct LibraryControls: View {
    @Binding var status: StatusFilter
    @Binding var size: String
    @Binding var sort: LibrarySort
    let sizes: [String]

    var body: some View {
        HStack(spacing: 12) {
            filterMenu
            Spacer(minLength: 4)
            sortMenu
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var isFiltering: Bool { status != .all || !size.isEmpty }

    private var filterMenu: some View {
        Menu {
            Picker("Status", selection: $status) {
                ForEach(StatusFilter.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.inline)
            Picker("Grid Size", selection: $size) {
                Text("All Sizes").tag("")
                ForEach(sizes, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.inline)
            if isFiltering {
                Divider()
                Button("Clear Filters", systemImage: "xmark.circle") {
                    status = .all
                    size = ""
                }
            }
        } label: {
            Label(Self.filterSummary(status: status, size: size) ?? "All Puzzles",
                  systemImage: isFiltering ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .fixedSize()
        .foregroundStyle(isFiltering ? Color.accentColor : Color.secondary)
        .help(isFiltering ? "Filtering: \(Self.filterSummary(status: status, size: size) ?? "")" : "Filter by status or grid size")
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort By", selection: $sort) {
                ForEach(LibrarySort.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.inline)
        } label: {
            Label(sort.shortLabel, systemImage: "arrow.up.arrow.down")
        }
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .fixedSize()
        .foregroundStyle(.secondary)
        .help("Sort by \(sort.label.lowercased())")
    }

    /// "In Progress, 15×15", or nil when nothing is filtered.
    static func filterSummary(status: StatusFilter, size: String) -> String? {
        let parts = [status == .all ? nil : status.label, size.isEmpty ? nil : size].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }
}

extension LibrarySort {
    var shortLabel: String {
        switch self {
        case .newestPublished: "Newest"
        case .oldestPublished: "Oldest"
        case .title: "Title"
        }
    }
}
