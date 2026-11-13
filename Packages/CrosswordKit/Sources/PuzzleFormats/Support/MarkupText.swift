import Foundation

/// Clue and title text in ipuz / jpz may contain simple HTML. We display it as plain text.
enum MarkupText {
    private static let entities: [String: String] = [
        "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&#39;": "'",
        "&nbsp;": " ", "&mdash;": "—", "&ndash;": "–", "&hellip;": "…",
        "&lsquo;": "‘", "&rsquo;": "’", "&ldquo;": "“", "&rdquo;": "”",
    ]

    /// Strips tags (`<br>` becomes a newline), decodes entities, removes control characters, and
    /// limits the length. Runs in linear time on any input.
    static func plain(_ text: String) -> String {
        let bounded = String(text.prefix(TextLimits.maxTextLength * 4))
        let stripped = stripTags(bounded)
        return TextLimits.clean(decodeEntities(stripped)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Removes `<…>` tags in one pass. A `<` that never closes is kept as literal text.
    static func stripTags(_ text: String) -> String {
        var result = ""
        var tagStart: String.Index?  // position of an unmatched "<"
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if character == "<" {
                if let start = tagStart { result += text[start..<index] }  // never closed: literal
                tagStart = index
            } else if character == ">", let start = tagStart, text.index(after: start) < index {
                if isLineBreak(text[text.index(after: start)..<index]) { result += "\n" }
                tagStart = nil
            } else if tagStart == nil {
                result.append(character)
            }
            index = text.index(after: index)
        }
        if let start = tagStart { result += text[start...] }
        return result
    }

    private static func isLineBreak(_ tagBody: Substring) -> Bool {
        let name = tagBody.prefix(8).trimmingCharacters(in: .whitespaces).lowercased()
        return name == "br" || name.hasPrefix("br ") || name.hasPrefix("br/")
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        let numeric = #/&#(x?)([0-9A-Fa-f]{1,8});/#
        return result.replacing(numeric) { match in
            let radix = match.output.1.isEmpty ? 10 : 16
            guard let code = UInt32(match.output.2, radix: radix), let scalar = Unicode.Scalar(code) else {
                return String(match.output.0)
            }
            return String(Character(scalar))
        }
    }
}
