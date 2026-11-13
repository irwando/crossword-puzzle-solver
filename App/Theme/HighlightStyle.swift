import SwiftUI

/// Color for the selected square. Each choice has tuned light and dark variants.
enum SquareColor: String, CaseIterable, Identifiable {
    case yellow, orange, green, pink, blue

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .yellow: Color(light: 0xFFD447, dark: 0xB48A12)
        case .orange: Color(light: 0xFFAE5E, dark: 0xB4621A)
        case .green: Color(light: 0x8FDB8A, dark: 0x2F8A3A)
        case .pink: Color(light: 0xFF9EC0, dark: 0xB0406A)
        case .blue: Color(light: 0x7FB8FF, dark: 0x2F6BC0)
        }
    }

    /// Shown while typing a rebus; always differs from the normal square color.
    var rebusColor: Color { self == .orange ? SquareColor.yellow.color : SquareColor.orange.color }
}

/// Color family for the current word (strong) and the crossing word (pale wash of the same hue).
enum WordColor: String, CaseIterable, Identifiable {
    case blue, green, purple, pink, teal, gray

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    var word: Color {
        switch self {
        case .blue: Color(light: 0xA8CBF0, dark: 0x335C8A)
        case .green: Color(light: 0xB5DFB0, dark: 0x356B3C)
        case .purple: Color(light: 0xD1C0EE, dark: 0x5A4685)
        case .pink: Color(light: 0xF5BCD0, dark: 0x84405A)
        case .teal: Color(light: 0xA6DDD8, dark: 0x2F6B66)
        case .gray: Color(light: 0xD3CFC8, dark: 0x4E4A44)
        }
    }

    var crossing: Color {
        switch self {
        case .blue: Color(light: 0xE6F0FA, dark: 0x2A3442)
        case .green: Color(light: 0xE9F5E6, dark: 0x29362A)
        case .purple: Color(light: 0xF1EBFA, dark: 0x332D40)
        case .pink: Color(light: 0xFCEAF0, dark: 0x3D2B32)
        case .teal: Color(light: 0xE5F5F3, dark: 0x283736)
        case .gray: Color(light: 0xEFEDE9, dark: 0x33312E)
        }
    }
}

/// Resolved highlight preferences, shared through the environment.
struct HighlightStyle: Equatable {
    var square = SquareColor.yellow
    var word = WordColor.blue
    var showsWord = true
    var showsCrossing = true

    var squareColor: Color { square.color }
    var rebusColor: Color { square.rebusColor }
    var wordColor: Color? { showsWord ? word.word : nil }
    var crossingColor: Color? { showsCrossing ? word.crossing : nil }
}

extension EnvironmentValues {
    @Entry var highlightStyle = HighlightStyle()
}
