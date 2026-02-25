import Testing
@testable import PBXProjKit

@Suite("PBXParser")
struct ParserTests {

    func parse(_ s: String) throws -> PBXDocument {
        try PBXProj(string: s).document
    }

    func parseDict(_ s: String) throws -> PBXDict {
        var scanner = PBXScanner(source: s)
        let tokens = try scanner.scanAll()
        var parser = PBXParser(tokens: tokens)
        return try parser.parseDocument().root
    }

    @Test func minimalDocument() throws {
        let src = """
        // !$*UTF8*$!
        {
        \tarchiveVersion = 1;
        }
        """
        let doc = try parse(src)
        #expect(doc.header == "// !$*UTF8*$!")
        #expect(doc.root.format == .multiline)
        #expect(doc.root.entries.count == 1)
        if case .pair(let key, let value) = doc.root.entries[0] {
            #expect(key.value == "archiveVersion")
            if case .string(let s) = value {
                #expect(s.value == "1")
            } else {
                Issue.record("Expected string value")
            }
        } else {
            Issue.record("Expected pair entry")
        }
    }

    @Test func inlineDict() throws {
        let src = """
        // !$*UTF8*$!
        {
        \tx = {isa = PBXBuildFile; fileRef = AABB; };
        }
        """
        let doc = try parse(src)
        if case .pair(_, let value) = doc.root.entries[0],
           case .dict(let d) = value {
            #expect(d.format == .inline)
            #expect(d.entries.count == 2)
        } else {
            Issue.record("Expected inline dict")
        }
    }

    @Test func multilineDict() throws {
        let src = """
        // !$*UTF8*$!
        {
        \tobjects = {
        \t\tkey = value;
        \t};
        }
        """
        let doc = try parse(src)
        if case .pair(_, let value) = doc.root.entries[0],
           case .dict(let d) = value {
            #expect(d.format == .multiline)
        } else {
            Issue.record("Expected multiline dict")
        }
    }

    @Test func sectionComment() throws {
        let src = """
        // !$*UTF8*$!
        {
        \tobjects = {

        /* Begin PBXBuildFile section */
        \t\tAABBCC = {isa = PBXBuildFile; };
        /* End PBXBuildFile section */
        \t};
        }
        """
        let doc = try parse(src)
        if case .pair(_, let value) = doc.root.entries[0],
           case .dict(let d) = value {
            let comments = d.entries.compactMap({ entry -> String? in
                if case .comment(let c) = entry { return c }
                return nil
            })
            #expect(comments.contains(where: { $0.contains("Begin PBXBuildFile section") }))
            #expect(comments.contains(where: { $0.contains("End PBXBuildFile section") }))
        } else {
            Issue.record("Expected objects dict")
        }
    }

    @Test func blankLineEntry() throws {
        let src = """
        // !$*UTF8*$!
        {
        \tobjects = {

        /* Begin section */
        \t\tkey = val;

        /* End section */
        \t};
        }
        """
        let doc = try parse(src)
        if case .pair(_, let value) = doc.root.entries[0],
           case .dict(let d) = value {
            let hasBlankLine = d.entries.contains(where: { if case .blankLine = $0 { return true }; return false })
            #expect(hasBlankLine)
        } else {
            Issue.record("Expected objects dict")
        }
    }

    @Test func multilineArray() throws {
        let src = """
        // !$*UTF8*$!
        {
        \tknownRegions = (
        \t\ten,
        \t\tBase,
        \t);
        }
        """
        let doc = try parse(src)
        if case .pair(_, let value) = doc.root.entries[0],
           case .array(let a) = value {
            #expect(a.format == .multiline)
            #expect(a.elements.count == 2)
        } else {
            Issue.record("Expected array")
        }
    }

    @Test func inlineArray() throws {
        let src = """
        // !$*UTF8*$!
        {
        \tx = (a, b, c);
        }
        """
        let doc = try parse(src)
        if case .pair(_, let value) = doc.root.entries[0],
           case .array(let a) = value {
            #expect(a.format == .inline)
            #expect(a.elements.count == 3)
        } else {
            Issue.record("Expected inline array")
        }
    }

    @Test func uuidWithComment() throws {
        let src = """
        // !$*UTF8*$!
        {
        \trootObject = AABBCC /* Project object */;
        }
        """
        let doc = try parse(src)
        if case .pair(_, let value) = doc.root.entries[0],
           case .string(let s) = value {
            #expect(s.value == "AABBCC")
            #expect(s.comment == "Project object")
        } else {
            Issue.record("Expected string with comment")
        }
    }

    @Test func quotedValue() throws {
        let src = """
        // !$*UTF8*$!
        {
        \tname = "My App";
        }
        """
        let doc = try parse(src)
        if case .pair(_, let value) = doc.root.entries[0],
           case .string(let s) = value {
            #expect(s.value == "My App")
            #expect(s.quoted == true)
        } else {
            Issue.record("Expected quoted string")
        }
    }
}
