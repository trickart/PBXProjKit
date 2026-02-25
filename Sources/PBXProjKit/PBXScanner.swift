public enum PBXScanError: Error, Equatable, Sendable {
    case unexpectedCharacter(Character, offset: Int)
    case unterminatedString(offset: Int)
    case unterminatedComment(offset: Int)
    case invalidEscape(Character, offset: Int)
}

enum Token: Equatable, Sendable {
    case identifier(String)
    case quotedString(String)
    case blockComment(String)
    case lineComment(String)
    case lbrace
    case rbrace
    case lparen
    case rparen
    case equals
    case semicolon
    case comma
    case newline(String)
    case space(String)
}

struct PBXScanner {
    private let source: [Character]
    private var pos: Int = 0

    init(source: String) {
        self.source = Array(source)
    }

    var offset: Int { pos }

    private var current: Character? {
        pos < source.count ? source[pos] : nil
    }

    private mutating func advance() -> Character? {
        guard pos < source.count else { return nil }
        let c = source[pos]
        pos += 1
        return c
    }

    private func peek(offset: Int = 1) -> Character? {
        let i = pos + offset
        guard i < source.count else { return nil }
        return source[i]
    }

    mutating func scanAll() throws -> [Token] {
        var tokens: [Token] = []
        while let tok = try scanNext() {
            tokens.append(tok)
        }
        return tokens
    }

    mutating func scanNext() throws -> Token? {
        guard let c = current else { return nil }

        // Whitespace (with or without newlines)
        if c.isWhitespace {
            return try scanWhitespace()
        }

        switch c {
        case "{":
            _ = advance()
            return .lbrace
        case "}":
            _ = advance()
            return .rbrace
        case "(":
            _ = advance()
            return .lparen
        case ")":
            _ = advance()
            return .rparen
        case "=":
            _ = advance()
            return .equals
        case ";":
            _ = advance()
            return .semicolon
        case ",":
            _ = advance()
            return .comma
        case "\"":
            return try scanQuotedString()
        case "/":
            if peek() == "*" {
                return try scanBlockComment()
            } else if peek() == "/" {
                return scanLineComment()
            } else {
                // treat as identifier char
                return try scanIdentifier()
            }
        default:
            if isIdentifierChar(c) {
                return try scanIdentifier()
            }
            throw PBXScanError.unexpectedCharacter(c, offset: pos)
        }
    }

    private mutating func scanWhitespace() throws -> Token {
        var buf = ""
        var hasNewline = false
        while let c = current, c.isWhitespace {
            if c == "\n" || c == "\r" {
                hasNewline = true
            }
            buf.append(c)
            _ = advance()
        }
        if hasNewline {
            return .newline(buf)
        } else {
            return .space(buf)
        }
    }

    private mutating func scanIdentifier() throws -> Token {
        var buf = ""
        var parenDepth = 0
        while let c = current {
            if c == "(" && !buf.isEmpty && buf.last == "$" {
                parenDepth += 1
                buf.append(c)
                _ = advance()
            } else if c == ")" && parenDepth > 0 {
                parenDepth -= 1
                buf.append(c)
                _ = advance()
            } else if isIdentifierChar(c) {
                buf.append(c)
                _ = advance()
            } else {
                break
            }
        }
        return .identifier(buf)
    }

    private mutating func scanQuotedString() throws -> Token {
        let startPos = pos
        _ = advance() // consume opening "
        var buf = ""
        while let c = current {
            if c == "\"" {
                _ = advance()
                return .quotedString(buf)
            } else if c == "\\" {
                _ = advance()
                guard let esc = advance() else {
                    throw PBXScanError.unterminatedString(offset: startPos)
                }
                switch esc {
                case "\"": buf.append("\"")
                case "\\": buf.append("\\")
                case "n":  buf.append("\n")
                case "t":  buf.append("\t")
                case "r":  buf.append("\r")
                case "0":  buf.append("\0")
                default:
                    throw PBXScanError.invalidEscape(esc, offset: pos - 1)
                }
            } else {
                buf.append(c)
                _ = advance()
            }
        }
        throw PBXScanError.unterminatedString(offset: startPos)
    }

    private mutating func scanBlockComment() throws -> Token {
        let startPos = pos
        _ = advance() // /
        _ = advance() // *
        var buf = ""
        while pos < source.count {
            if source[pos] == "*" && pos + 1 < source.count && source[pos + 1] == "/" {
                pos += 2
                return .blockComment(buf)
            }
            buf.append(source[pos])
            pos += 1
        }
        throw PBXScanError.unterminatedComment(offset: startPos)
    }

    private mutating func scanLineComment() -> Token {
        _ = advance() // /
        _ = advance() // /
        var buf = ""
        while let c = current, c != "\n" && c != "\r" {
            buf.append(c)
            _ = advance()
        }
        return .lineComment(buf)
    }

    private func isIdentifierChar(_ c: Character) -> Bool {
        c.isLetter || c.isNumber || "_.$\\/[]+-*@!<>|&^~%#`?'".contains(c)
    }
}
