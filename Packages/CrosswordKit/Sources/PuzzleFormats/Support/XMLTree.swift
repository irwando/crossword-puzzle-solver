import Foundation

/// Minimal mutable-by-copy XML tree (Foundation's XMLDocument is unavailable on iOS).
struct XMLElement: Sendable, Hashable {
    var name: String
    var attributes: [String: String]
    var children: [XMLNode]

    init(name: String, attributes: [String: String] = [:], children: [XMLNode] = []) {
        self.name = name
        self.attributes = attributes
        self.children = children
    }

    /// Name without namespace prefix.
    var localName: String { name.split(separator: ":").last.map(String.init) ?? name }

    var elements: [XMLElement] {
        children.compactMap { if case .element(let element) = $0 { element } else { nil } }
    }

    func child(_ localName: String) -> XMLElement? {
        elements.first { $0.localName == localName }
    }

    func children(_ localName: String) -> [XMLElement] {
        elements.filter { $0.localName == localName }
    }

    /// Depth-first search for the first descendant (or self) with the given local name.
    func first(_ localName: String) -> XMLElement? {
        if self.localName == localName { return self }
        for element in elements {
            if let found = element.first(localName) { return found }
        }
        return nil
    }

    /// Concatenated text of this element and its descendants.
    var text: String {
        children.map { node in
            switch node {
            case .text(let text): text
            case .element(let element): element.text
            }
        }.joined()
    }

    /// Returns a copy with `transform` applied to every descendant element (post-order).
    func mapElements(_ transform: (XMLElement) -> XMLElement) -> XMLElement {
        var copy = self
        copy.children = children.map { node in
            if case .element(let element) = node { return .element(element.mapElements(transform)) }
            return node
        }
        return transform(copy)
    }
}

enum XMLNode: Sendable, Hashable {
    case element(XMLElement)
    case text(String)
}

enum XMLTree {
    /// Real .jpz files nest about 6 levels; deeper trees are rejected so recursion stays shallow.
    static let maxDepth = 64

    static func parse(_ data: Data) throws(PuzzleFormatError) -> XMLElement {
        let builder = Builder()
        let parser = XMLParser(data: data)
        parser.delegate = builder
        parser.shouldProcessNamespaces = false
        parser.shouldResolveExternalEntities = false
        let parsed = parser.parse()
        if builder.tooDeep { throw .malformed("XML is nested too deeply") }
        guard parsed, let root = builder.root else {
            throw .malformed("invalid XML (\(parser.parserError?.localizedDescription ?? "unknown error"))")
        }
        return root
    }

    static func serialize(_ root: XMLElement) -> Data {
        var output = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        write(root, into: &output)
        output += "\n"
        return Data(output.utf8)
    }

    private static func write(_ element: XMLElement, into output: inout String) {
        output += "<\(element.name)"
        for key in element.attributes.keys.sorted() {
            output += " \(key)=\"\(escape(element.attributes[key] ?? "", attribute: true))\""
        }
        guard !element.children.isEmpty else {
            output += "/>"
            return
        }
        output += ">"
        for child in element.children {
            switch child {
            case .text(let text): output += escape(text, attribute: false)
            case .element(let nested): write(nested, into: &output)
            }
        }
        output += "</\(element.name)>"
    }

    static func escape(_ text: String, attribute: Bool) -> String {
        var result = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        if attribute {
            result = result.replacingOccurrences(of: "\"", with: "&quot;")
        }
        return result
    }

    private final class Builder: NSObject, XMLParserDelegate {
        var stack: [XMLElement] = []
        var root: XMLElement?
        var tooDeep = false

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName: String?, attributes: [String: String] = [:]) {
            guard stack.count < XMLTree.maxDepth else {
                tooDeep = true
                stack.removeAll()
                parser.abortParsing()
                return
            }
            stack.append(XMLElement(name: elementName, attributes: attributes))
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
            guard !tooDeep, let finished = stack.popLast() else { return }
            if stack.isEmpty {
                root = finished
            } else {
                stack[stack.count - 1].children.append(.element(finished))
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            appendText(string)
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            appendText(String(decoding: CDATABlock, as: UTF8.self))
        }

        private func appendText(_ text: String) {
            guard !tooDeep, !stack.isEmpty else { return }
            if case .text(let existing) = stack[stack.count - 1].children.last {
                stack[stack.count - 1].children[stack[stack.count - 1].children.count - 1] = .text(existing + text)
            } else {
                stack[stack.count - 1].children.append(.text(text))
            }
        }
    }
}
