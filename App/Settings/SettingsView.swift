import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKey.appearance) private var appearance: AppearanceMode = .system
    @AppStorage(SettingsKey.titleFont) private var titleFont = FontFamily.system
    @AppStorage(SettingsKey.clueFont) private var clueFont = FontFamily.system
    @AppStorage(SettingsKey.clueSize) private var clueSize = Typography.defaultClueSize
    @AppStorage(SettingsKey.acrossCluesSide) private var acrossSide: ClueSide = .right
    @AppStorage(SettingsKey.downCluesSide) private var downSide: ClueSide = .right
    @AppStorage(SettingsKey.skipFilledSquares) private var skipFilled = true
    @Environment(\.typography) private var typography

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Theme", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .help("Follow the system appearance, or always use light or dark")
            }

            Section {
                FontPicker(title: "Puzzle titles", selection: $titleFont)
                FontPicker(title: "Clues", selection: $clueFont)
                LabeledContent("Clue size") {
                    HStack {
                        Slider(value: $clueSize, in: Typography.clueSizeRange, step: 1)
                            .frame(minWidth: 140)
                        Text("\(Int(clueSize)) pt").monospacedDigit().foregroundStyle(.secondary)
                    }
                }
                .help("Text size for clue lists and the current clue")
                preview
            } header: {
                Text("Fonts")
            }

            Section {
                Picker("Across clues", selection: $acrossSide) {
                    ForEach(ClueSide.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                .help("Where the Across list sits next to the grid")
                Picker("Down clues", selection: $downSide) {
                    ForEach(ClueSide.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                .help("Where the Down list sits next to the grid")
            } header: {
                Text("Clue Lists")
            } footer: {
                Text("Applies when the window is wider than it is tall. In narrow or portrait windows both lists sit below the grid.")
            }

            HighlightSettingsSection()

            Section("Solving") {
                Toggle("Skip filled squares while typing", isOn: $skipFilled)
                    .help("When on, the cursor jumps over squares that already have letters")
            }
        }
        .formStyle(.grouped)
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Thursday Themeless").font(typography.heading)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("17").font(typography.clueNumber)
                Text("Org. with a tight end? (3)").font(typography.clue)
            }
        }
        .foregroundStyle(Theme.ink)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: .rect(cornerRadius: 8))
        .accessibilityLabel("Font preview")
    }
}

private struct FontPicker: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        Picker(title, selection: $selection) {
            Section("Recommended") {
                ForEach(FontFamily.featured) { Text($0.name).tag($0.id) }
            }
            Section("All Fonts") {
                ForEach(FontFamily.installed, id: \.self) { Text($0).tag($0) }
            }
        }
        .pickerStyle(.menu)
        .help("Font used for \(title.lowercased())")
    }
}

/// Opens Settings: the Settings window on Mac, a sheet on iPad.
struct SettingsButton: View {
    #if os(macOS)
    @Environment(\.openSettings) private var openSettings
    #else
    @Environment(\.openAppSettings) private var openSettings
    #endif

    var body: some View {
        Button("Settings…", systemImage: "gearshape") { openSettings() }
            .help("Appearance, fonts, and clue layout")
    }
}

struct OpenAppSettingsAction {
    let handler: @MainActor @Sendable () -> Void

    @MainActor func callAsFunction() { handler() }
}

extension EnvironmentValues {
    @Entry var openAppSettings = OpenAppSettingsAction(handler: {})
}
