import Testing
@testable import PBXProjKit

@Suite("PBXScanner")
struct ScannerTests {

    func scan(_ s: String) throws -> [Token] {
        var scanner = PBXScanner(source: s)
        return try scanner.scanAll()
    }

    @Test func identifier() throws {
        let tokens = try scan("hello")
        #expect(tokens == [.identifier("hello")])
    }

    @Test func identifierWithSpecialChars() throws {
        let tokens = try scan("AABBCC01")
        #expect(tokens == [.identifier("AABBCC01")])
    }

    @Test func quotedString() throws {
        let tokens = try scan("\"hello world\"")
        #expect(tokens == [.quotedString("hello world")])
    }

    @Test func quotedStringWithEscapes() throws {
        let tokens = try scan("\"hello\\nworld\"")
        #expect(tokens == [.quotedString("hello\nworld")])
    }

    @Test func blockComment() throws {
        let tokens = try scan("/* main.m */")
        #expect(tokens == [.blockComment(" main.m ")])
    }

    @Test func lineComment() throws {
        let tokens = try scan("// !$*UTF8*$!")
        #expect(tokens == [.lineComment(" !$*UTF8*$!")])
    }

    @Test func punctuation() throws {
        let tokens = try scan("{};=(,)")
        #expect(tokens == [.lbrace, .rbrace, .semicolon, .equals, .lparen, .comma, .rparen])
    }

    @Test func newline() throws {
        let tokens = try scan("a\nb")
        #expect(tokens == [.identifier("a"), .newline("\n"), .identifier("b")])
    }

    @Test func spaces() throws {
        let tokens = try scan("a b")
        #expect(tokens == [.identifier("a"), .space(" "), .identifier("b")])
    }

    @Test func mixedWhitespace() throws {
        let tokens = try scan("a \n b")
        #expect(tokens == [.identifier("a"), .newline(" \n "), .identifier("b")])
    }

    @Test func uuidWithComment() throws {
        let tokens = try scan("AABBCC /* main.m */")
        #expect(tokens == [
            .identifier("AABBCC"),
            .space(" "),
            .blockComment(" main.m ")
        ])
    }

    @Test func pbxprojHeader() throws {
        let tokens = try scan("// !$*UTF8*$!")
        #expect(tokens == [.lineComment(" !$*UTF8*$!")])
    }

    @Test func unterminatedString() throws {
        #expect(throws: PBXScanError.self) {
            _ = try scan("\"unterminated")
        }
    }

    @Test func unterminatedComment() throws {
        #expect(throws: PBXScanError.self) {
            _ = try scan("/* unterminated")
        }
    }

    @Test func dollarInIdentifier() throws {
        let tokens = try scan("$(TARGET_NAME)")
        #expect(tokens == [.identifier("$(TARGET_NAME)")])
    }

    @Test func angleInIdentifier() throws {
        let tokens = try scan("<group>")
        #expect(tokens == [.identifier("<group>")])
    }
}
