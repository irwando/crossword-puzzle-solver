import SwiftUI

enum SettingsKey {
    static let skipFilledSquares = "skipFilledSquares"
    static let folderBookmark = "folderBookmark"
    static let librarySort = "librarySort"
    static let libraryStatusFilter = "libraryStatusFilter"
    static let librarySizeFilter = "librarySizeFilter"
    static let appearance = "appearance"
    static let titleFont = "titleFont"
    static let clueFont = "clueFont"
    static let clueSize = "clueSize"
    static let acrossCluesSide = "acrossCluesSide"
    static let downCluesSide = "downCluesSide"
    static let squareColor = "squareColor"
    static let wordColor = "wordColor"
    static let highlightWord = "highlightWord"
    static let highlightCrossing = "highlightCrossing"
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Where a clue list sits relative to the grid in wide layouts.
enum ClueSide: String, CaseIterable, Identifiable {
    case left, right, below

    var id: String { rawValue }

    var label: String {
        switch self {
        case .left: "Left"
        case .right: "Right"
        case .below: "Below"
        }
    }
}

/// Applies appearance and typography settings to a view hierarchy.
struct AppSettingsModifier: ViewModifier {
    @AppStorage(SettingsKey.appearance) private var appearance: AppearanceMode = .system
    @AppStorage(SettingsKey.titleFont) private var titleFont = FontFamily.system
    @AppStorage(SettingsKey.clueFont) private var clueFont = FontFamily.system
    @AppStorage(SettingsKey.clueSize) private var clueSize = Typography.defaultClueSize
    @AppStorage(SettingsKey.squareColor) private var squareColor: SquareColor = .yellow
    @AppStorage(SettingsKey.wordColor) private var wordColor: WordColor = .blue
    @AppStorage(SettingsKey.highlightWord) private var highlightWord = true
    @AppStorage(SettingsKey.highlightCrossing) private var highlightCrossing = true

    func body(content: Content) -> some View {
        content
            .environment(\.typography, Typography(titleFamily: titleFont, clueFamily: clueFont, clueSize: clueSize))
            .environment(\.highlightStyle, HighlightStyle(square: squareColor, word: wordColor,
                                                          showsWord: highlightWord, showsCrossing: highlightCrossing))
            #if os(macOS)
            // NSApp.appearance (rather than preferredColorScheme) reliably returns to System on macOS.
            .onChange(of: appearance, initial: true) { _, mode in
                NSApp.appearance = switch mode {
                case .system: nil
                case .light: NSAppearance(named: .aqua)
                case .dark: NSAppearance(named: .darkAqua)
                }
            }
            #else
            .preferredColorScheme(appearance.colorScheme)
            #endif
    }
}

extension View {
    func appSettings() -> some View { modifier(AppSettingsModifier()) }
}
