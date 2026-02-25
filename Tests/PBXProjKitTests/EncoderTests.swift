import Testing
@testable import PBXProjKit

@Suite("PBXEncoder")
struct EncoderTests {

    func encode(_ doc: PBXDocument) -> String {
        PBXEncoder().encode(doc)
    }

    @Test func inlineDictEncoding() {
        let dict = PBXDict(
            entries: [
                .pair(
                    key: PBXString(value: "isa"),
                    value: .string(PBXString(value: "PBXBuildFile"))
                ),
                .pair(
                    key: PBXString(value: "fileRef"),
                    value: .string(PBXString(value: "AABBCC", comment: "main.m"))
                ),
            ],
            format: .inline
        )
        let doc = PBXDocument(
            root: PBXDict(
                entries: [.pair(key: PBXString(value: "x"), value: .dict(dict))],
                format: .multiline
            )
        )
        let result = encode(doc)
        #expect(result.contains("{isa = PBXBuildFile; fileRef = AABBCC /* main.m */; }"))
    }

    @Test func uuidCommentAnnotation() {
        let doc = PBXDocument(
            root: PBXDict(
                entries: [
                    .pair(
                        key: PBXString(value: "rootObject"),
                        value: .string(PBXString(value: "AABBCC09", comment: "Project object"))
                    )
                ],
                format: .multiline
            )
        )
        let result = encode(doc)
        #expect(result.contains("AABBCC09 /* Project object */"))
    }

    @Test func sectionCommentIndent() {
        let objectsDict = PBXDict(
            entries: [
                .blankLine,
                .comment(" Begin PBXBuildFile section "),
                .pair(
                    key: PBXString(value: "AABBCC"),
                    value: .dict(PBXDict(
                        entries: [.pair(key: PBXString(value: "isa"), value: .string(PBXString(value: "PBXBuildFile")))],
                        format: .inline
                    ))
                ),
                .comment(" End PBXBuildFile section "),
            ],
            format: .multiline
        )
        let doc = PBXDocument(
            root: PBXDict(
                entries: [.pair(key: PBXString(value: "objects"), value: .dict(objectsDict))],
                format: .multiline
            )
        )
        let result = encode(doc)
        // Section comments should be at column 0 (no leading tabs before them)
        let lines = result.components(separatedBy: "\n")
        let beginLine = lines.first(where: { $0.contains("Begin PBXBuildFile section") })
        #expect(beginLine != nil)
        #expect(beginLine?.hasPrefix("/*") == true || beginLine?.hasPrefix("/* ") == true)
    }

    @Test func quotedStringEncoding() {
        let doc = PBXDocument(
            root: PBXDict(
                entries: [
                    .pair(
                        key: PBXString(value: "name"),
                        value: .string(PBXString(value: "My App", quoted: true))
                    )
                ],
                format: .multiline
            )
        )
        let result = encode(doc)
        #expect(result.contains("\"My App\""))
    }

    @Test func headerEncoding() {
        let doc = PBXDocument()
        let result = encode(doc)
        #expect(result.hasPrefix("// !$*UTF8*$!"))
    }

    @Test func multilineArrayEncoding() {
        let array = PBXArray(
            elements: [
                PBXArrayElement(value: .string(PBXString(value: "en"))),
                PBXArrayElement(value: .string(PBXString(value: "Base"))),
            ],
            format: .multiline,
            hasTrailingComma: true
        )
        let doc = PBXDocument(
            root: PBXDict(
                entries: [.pair(key: PBXString(value: "regions"), value: .array(array))],
                format: .multiline
            )
        )
        let result = encode(doc)
        #expect(result.contains("en,"))
        #expect(result.contains("Base,"))
    }
}
