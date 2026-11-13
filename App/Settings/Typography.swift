import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Font families the user can pick. Tokens starting with "system" map to Apple's system designs;
/// anything else is an installed family name (missing families fall back to the system font).
enum FontFamily {
    static let system = "system"
    static let rounded = "system.rounded"
    static let serif = "system.serif"

    struct Option: Identifiable, Hashable {
        let id: String
        let name: String
    }

    /// Highly legible choices available on both iPadOS and macOS.
    static let featured: [Option] = [
        Option(id: system, name: "SF Pro (System)"),
        Option(id: rounded, name: "SF Pro Rounded"),
        Option(id: "Avenir Next", name: "Avenir Next"),
        Option(id: "Helvetica Neue", name: "Helvetica Neue"),
        Option(id: "Verdana", name: "Verdana"),
        Option(id: "Gill Sans", name: "Gill Sans"),
        Option(id: serif, name: "New York (Serif)"),
        Option(id: "Georgia", name: "Georgia"),
    ]

    /// Every other font family installed on this device.
    static let installed: [String] = {
        #if os(iOS)
        let families = UIFont.familyNames
        #else
        let families = NSFontManager.shared.availableFontFamilies
        #endif
        let featuredIDs = Set(featured.map(\.id))
        return families
            .filter { !$0.hasPrefix(".") && !featuredIDs.contains($0) }
            .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }()

    static func font(_ family: String, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch family {
        case system: .system(size: size, weight: weight)
        case rounded: .system(size: size, weight: weight, design: .rounded)
        case serif: .system(size: size, weight: weight, design: .serif)
        default: .custom(family, fixedSize: size).weight(weight)
        }
    }
}

/// Resolved fonts for titles and clues, derived from settings and shared through the environment.
struct Typography: Equatable {
    #if os(iOS)
    static let defaultClueSize: Double = 18
    static let titleSize: CGFloat = 17
    #else
    static let defaultClueSize: Double = 15
    static let titleSize: CGFloat = 14
    #endif
    static let clueSizeRange: ClosedRange<Double> = 12...28

    var titleFamily = FontFamily.system
    var clueFamily = FontFamily.system
    var clueSize = Typography.defaultClueSize

    var clue: Font { FontFamily.font(clueFamily, size: clueSize) }
    var clueBar: Font { FontFamily.font(clueFamily, size: (clueSize * 1.25).rounded(), weight: .medium) }
    var clueNumber: Font { .system(size: (clueSize * 0.9).rounded(), weight: .bold, design: .rounded) }
    var listTitle: Font { FontFamily.font(titleFamily, size: Self.titleSize, weight: .semibold) }
    var heading: Font { FontFamily.font(titleFamily, size: (Self.titleSize * 1.45).rounded(), weight: .bold) }
}

extension EnvironmentValues {
    @Entry var typography = Typography()
}
