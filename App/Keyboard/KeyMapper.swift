import CrosswordCore
import SwiftUI

/// Maps hardware key presses to solve actions.
enum KeyMapper {
    /// NSInsertFunctionKey (the Insert / Help key on extended keyboards).
    static let insertKey: Character = "\u{F727}"
    /// NSDeleteFunctionKey (fn-Delete / ⌦ on Mac).
    static let forwardDeleteKey: Character = "\u{F728}"
    /// What the Backspace key reports: DEL (0x7F) on Mac, BS (0x08) on iPad.
    /// SwiftUI's `KeyEquivalent.deleteForward` is also 0x7F, so these must be matched first.
    static let backspaceKeys: Set<Character> = ["\u{7F}", "\u{08}"]
    /// Shift-Tab arrives as back-tab (0x19) on Mac rather than `.tab` + shift.
    static let backTabKey: Character = "\u{19}"

    static func action(for press: KeyPress, rebusActive: Bool) -> SolveAction? {
        action(key: press.key, characters: press.characters, modifiers: press.modifiers, rebusActive: rebusActive)
    }

    static func action(key: KeyEquivalent, characters: String, modifiers: EventModifiers, rebusActive: Bool) -> SolveAction? {
        // Leave shortcut chords to the menu system.
        if modifiers.contains(.command) || modifiers.contains(.control) { return nil }

        if backspaceKeys.contains(key.character) || characters.contains(where: backspaceKeys.contains) {
            return .backspace
        }
        if key.character == backTabKey || characters.contains(backTabKey) { return .previousClue }
        if key.character == forwardDeleteKey || characters.contains(forwardDeleteKey) {
            return rebusActive ? nil : .deleteForward
        }

        switch key {
        case .upArrow: return .move(.up)
        case .downArrow: return .move(.down)
        case .leftArrow: return .move(.left)
        case .rightArrow: return .move(.right)
        case .tab: return modifiers.contains(.shift) ? .previousClue : .nextClue
        case .space: return rebusActive ? nil : .toggleDirection
        case .escape: return .toggleRebus
        case .return: return rebusActive ? .commitRebus : .nextClue
        default: break
        }

        if characters.contains(insertKey) { return .toggleRebus }
        let letters = characters.filter { $0.isLetter || $0.isNumber || (rebusActive && $0.isPunctuation) }
        return letters.isEmpty ? nil : .type(String(letters))
    }
}
