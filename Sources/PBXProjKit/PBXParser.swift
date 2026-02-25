public enum PBXParseError: Error, Equatable, Sendable {
    case unexpectedToken(String, offset: Int)
    case unexpectedEnd
    case missingHeader
}

public struct PBXParser {
    private var tokens: [Token]
    private var pos: Int = 0

    init(tokens: [Token]) {
        self.tokens = tokens
    }

    // MARK: - Public entry point

    public mutating func parseDocument() throws -> PBXDocument {
        // Skip leading whitespace only (not comments)
        skipWhitespace()
        // Expect header line comment
        guard case let .lineComment(header) = peek() else {
            throw PBXParseError.missingHeader
        }
        advance()
        // The header token content is " !$*UTF8*$!" — reconstruct the full line
        let headerLine = "//" + header

        skipNonSignificant()
        let root = try parseDict()

        return PBXDocument(header: headerLine, root: root)
    }

    // MARK: - Dict

    private mutating func parseDict() throws -> PBXDict {
        try expect(.lbrace)

        // Determine format: check if next significant token is on same line
        let format = determineDictFormat()

        if format == .inline {
            return try parseInlineDict()
        } else {
            return try parseMultilineDict()
        }
    }

    private mutating func parseInlineDict() throws -> PBXDict {
        // Already consumed {
        var entries: [PBXDictEntry] = []
        // skip spaces (no newlines in inline)
        skipSpaces()
        while let t = peek(), t != .rbrace {
            let key = try parsePBXString()
            skipSpaces()
            try expect(.equals)
            skipSpaces()
            let value = try parseNode()
            skipSpaces()
            try expect(.semicolon)
            skipSpaces()
            entries.append(.pair(key: key, value: value))
        }
        try expect(.rbrace)
        return PBXDict(entries: entries, format: .inline)
    }

    private mutating func parseMultilineDict() throws -> PBXDict {
        // Already consumed {
        var entries: [PBXDictEntry] = []

        // Track blank lines: count consecutive newlines
        var pendingNewlines = 0

        while true {
            // Consume whitespace, counting newlines
            while let t = peek() {
                if case .newline(let s) = t {
                    pendingNewlines += s.filter({ $0 == "\n" }).count
                    advance()
                } else if case .space(_) = t {
                    advance()
                } else {
                    break
                }
            }

            guard let t = peek() else {
                throw PBXParseError.unexpectedEnd
            }

            if t == .rbrace {
                advance()
                break
            }

            // Insert blank line entry if we had extra newlines (>1 newline = blank line between entries)
            if pendingNewlines >= 2 {
                entries.append(.blankLine)
            }
            pendingNewlines = 0

            // Block comment at key position -> section comment
            if case .blockComment(let text) = t {
                advance()
                entries.append(.comment(text))
                continue
            }

            // Key = Value ; pair
            let key = try parsePBXString()
            skipNonSignificant()
            try expect(.equals)
            skipNonSignificant()
            let value = try parseNode()
            skipNonSignificant()
            try expect(.semicolon)
            entries.append(.pair(key: key, value: value))
        }

        return PBXDict(entries: entries, format: .multiline)
    }

    // MARK: - Array

    private mutating func parseArray() throws -> PBXArray {
        try expect(.lparen)

        let format = determineArrayFormat()

        if format == .inline {
            return try parseInlineArray()
        } else {
            return try parseMultilineArray()
        }
    }

    private mutating func parseInlineArray() throws -> PBXArray {
        var elements: [PBXArrayElement] = []
        skipSpaces()
        var hasTrailingComma = false
        while let t = peek(), t != .rparen {
            let node = try parseNode()
            elements.append(PBXArrayElement(value: node))
            skipSpaces()
            if peek() == .comma {
                advance()
                skipSpaces()
                if peek() == .rparen {
                    hasTrailingComma = true
                    break
                }
            } else {
                break
            }
        }
        try expect(.rparen)
        return PBXArray(elements: elements, format: .inline, hasTrailingComma: hasTrailingComma)
    }

    private mutating func parseMultilineArray() throws -> PBXArray {
        var elements: [PBXArrayElement] = []
        var hasTrailingComma = false

        while true {
            skipNonSignificant()
            guard let t = peek() else { throw PBXParseError.unexpectedEnd }
            if t == .rparen { advance(); break }

            let node = try parseNode()
            elements.append(PBXArrayElement(value: node))
            skipNonSignificant()
            if peek() == .comma {
                advance()
                hasTrailingComma = true
                // peek ahead: is there another element?
                let savedPos = pos
                skipNonSignificant()
                if peek() == .rparen {
                    advance()
                    break
                }
                pos = savedPos
                hasTrailingComma = false
            }
        }
        return PBXArray(elements: elements, format: .multiline, hasTrailingComma: hasTrailingComma)
    }

    // MARK: - Node

    private mutating func parseNode() throws -> PBXNode {
        guard let t = peek() else { throw PBXParseError.unexpectedEnd }
        switch t {
        case .lbrace:
            return .dict(try parseDict())
        case .lparen:
            return .array(try parseArray())
        default:
            return .string(try parsePBXString())
        }
    }

    // MARK: - PBXString

    private mutating func parsePBXString() throws -> PBXString {
        guard let t = peek() else { throw PBXParseError.unexpectedEnd }
        let value: String
        let quoted: Bool
        switch t {
        case .identifier(let s):
            value = s
            quoted = false
            advance()
        case .quotedString(let s):
            value = s
            quoted = true
            advance()
        default:
            throw PBXParseError.unexpectedToken("\(t)", offset: pos)
        }

        // Check for inline block comment annotation
        var comment: String? = nil
        // Skip spaces (not newlines)
        let spaceSaved = pos
        skipSpaces()
        if case .blockComment(let c) = peek() {
            comment = c.trimmingCharacters(in: .whitespaces)
            advance()
        } else {
            pos = spaceSaved
        }

        return PBXString(value: value, quoted: quoted, comment: comment)
    }

    // MARK: - Format detection

    private func determineDictFormat() -> CollectionFormat {
        // Look ahead: skip spaces (not newlines). If next is newline, multiline
        var i = pos
        while i < tokens.count {
            switch tokens[i] {
            case .space(_): i += 1
            case .newline(_): return .multiline
            default: return .inline
            }
        }
        return .multiline
    }

    private func determineArrayFormat() -> CollectionFormat {
        var i = pos
        while i < tokens.count {
            switch tokens[i] {
            case .space(_): i += 1
            case .newline(_): return .multiline
            default: return .inline
            }
        }
        return .multiline
    }

    // MARK: - Token helpers

    private func peek() -> Token? {
        pos < tokens.count ? tokens[pos] : nil
    }

    @discardableResult
    private mutating func advance() -> Token? {
        guard pos < tokens.count else { return nil }
        let t = tokens[pos]
        pos += 1
        return t
    }

    private mutating func expect(_ expected: Token) throws {
        guard let t = peek() else { throw PBXParseError.unexpectedEnd }
        guard t == expected else {
            throw PBXParseError.unexpectedToken("expected \(expected), got \(t)", offset: pos)
        }
        advance()
    }

    /// Skip spaces and newlines and line comments (but not block comments)
    private mutating func skipNonSignificant() {
        while let t = peek() {
            switch t {
            case .space(_), .newline(_), .lineComment(_): advance()
            default: return
            }
        }
    }

    /// Skip spaces only (no newlines)
    private mutating func skipSpaces() {
        while let t = peek(), case .space(_) = t {
            advance()
        }
    }

    /// Skip spaces and newlines only (not comments)
    private mutating func skipWhitespace() {
        while let t = peek() {
            switch t {
            case .space(_), .newline(_): advance()
            default: return
            }
        }
    }
}
