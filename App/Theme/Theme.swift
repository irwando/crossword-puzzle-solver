import SwiftUI

#if os(iOS)
import UIKit
typealias PlatformColor = UIColor
#else
import AppKit
typealias PlatformColor = NSColor
#endif

extension Color {
    /// A color that adapts to light / dark appearance.
    init(light: UInt32, dark: UInt32) {
        #if os(iOS)
        self.init(uiColor: UIColor { traits in
            PlatformColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return PlatformColor(hex: isDark ? dark : light)
        })
        #endif
    }
}

extension PlatformColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// "Newsprint" palette: warm paper and dense ink (highlight colors live in HighlightStyle). Colors carry meaning (red = wrong, blue = revealed, gray = pencil).
enum Theme {
    static let paper = Color(light: 0xF6F1E7, dark: 0x1B1A18)
    static let surface = Color(light: 0xFFFDF8, dark: 0x262421)
    static let cell = Color(light: 0xFFFEFB, dark: 0x2B2926)
    static let block = Color(light: 0x161513, dark: 0x050505)
    static let ink = Color(light: 0x161513, dark: 0xEDE7DA)
    static let mutedInk = Color(light: 0x6E685E, dark: 0x9C958A)
    static let gridLine = Color(light: 0x4A463F, dark: 0x5A554D)
    static let cursor = SquareColor.yellow.color
    static let shaded = Color(light: 0xE4DED2, dark: 0x3A3631)
    static let incorrect = Color(light: 0xD62839, dark: 0xFF5A67)
    static let revealed = Color(light: 0x1D5FD1, dark: 0x6FA8FF)
    static let pencil = Color(light: 0x8C877E, dark: 0x8F897F)
    static let success = Color(light: 0x23854A, dark: 0x4CC383)

    static let labelFont = Font.system(.subheadline, design: .rounded).weight(.semibold)
}
