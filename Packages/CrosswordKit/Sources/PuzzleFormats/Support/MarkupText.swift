import Foundation

/// Clue and title text in ipuz / jpz may contain simple HTML. We display it as plain text.
enum MarkupText {
    private static let entities: [String: String] = [
        "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'", "&#39;": "'",
        "&nbsp;": " ", "&mdash;": "—", "&ndash;": "–", "&hellip;": "…",
        "&lsquo;": "‘", "&rsquo;": "’", "&ldquo;": "“", "&rdquo;": "”",
    ]

    static func plain(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        result = decodeEntities(result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = text
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        let numeric = #/&#(x?)([0-9A-Fa-f]+);/#
        return result.replacing(numeric) { match in
            let radix = match.output.1.isEmpty ? 10 : 16
            guard let code = UInt32(match.output.2, radix: radix), let scalar = Unicode.Scalar(code) else {
                return String(match.output.0)
            }
            return String(Character(scalar))
        }
    }
}
