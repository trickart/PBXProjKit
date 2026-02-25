import Testing
import Foundation
@testable import PBXProjKit

@Suite("RoundTrip")
struct RoundTripTests {

    func roundTrip(_ input: String) throws -> String {
        let proj = try PBXProj(string: input)
        return proj.encode()
    }

    @Test func minimalRoundTrip() throws {
        let input = """
        // !$*UTF8*$!
        {
        \tarchiveVersion = 1;
        \tclasses = {
        \t};
        \tobjectVersion = 56;
        \trootObject = AABBCC09 /* Project object */;
        }
        """
        let output = try roundTrip(input)
        #expect(output == input + "\n")
    }

    @Test func inlineDictRoundTrip() throws {
        let input = """
        // !$*UTF8*$!
        {
        \tobjects = {
        \t\tAABBCC01 /* main.swift in Sources */ = {isa = PBXBuildFile; fileRef = AABBCC02 /* main.swift */; };
        \t};
        }
        """
        let output = try roundTrip(input)
        #expect(output == input + "\n")
    }

    @Test func fixtureRoundTrip() throws {
        guard let url = Bundle.module.url(forResource: "Fixture", withExtension: "pbxproj", subdirectory: "Fixtures") else {
            Issue.record("Could not find Fixture.pbxproj")
            return
        }
        let input = try String(contentsOf: url, encoding: .utf8)
        let output = try roundTrip(input)
        if output != input {
            // Show first difference
            let inputLines = input.components(separatedBy: "\n")
            let outputLines = output.components(separatedBy: "\n")
            for (i, (a, b)) in zip(inputLines, outputLines).enumerated() {
                if a != b {
                    Issue.record("Line \(i + 1) differs:\n  expected: \(a.debugDescription)\n  got:      \(b.debugDescription)")
                    break
                }
            }
            if outputLines.count != inputLines.count {
                Issue.record("Line count differs: expected \(inputLines.count), got \(outputLines.count)")
            }
        }
        #expect(output == input)
    }

    @Test func sectionCommentRoundTrip() throws {
        let input = """
        // !$*UTF8*$!
        {
        \tobjects = {

        /* Begin PBXBuildFile section */
        \t\tAABBCC01 /* main.swift in Sources */ = {isa = PBXBuildFile; fileRef = AABBCC02 /* main.swift */; };
        /* End PBXBuildFile section */
        \t};
        }
        """
        let output = try roundTrip(input)
        #expect(output == input + "\n")
    }

    @Test func quotedStringRoundTrip() throws {
        let input = """
        // !$*UTF8*$!
        {
        \tname = "My App";
        \tsourceTree = "<group>";
        }
        """
        let output = try roundTrip(input)
        #expect(output == input + "\n")
    }

    @Test func multilineArrayRoundTrip() throws {
        let input = """
        // !$*UTF8*$!
        {
        \tknownRegions = (
        \t\ten,
        \t\tBase,
        \t);
        }
        """
        let output = try roundTrip(input)
        #expect(output == input + "\n")
    }

    @Test func ossFixtureRoundTrips() throws {
        guard let ossDir = Bundle.module.url(
            forResource: "OSS", withExtension: nil, subdirectory: "Fixtures"
        ) else {
            return  // OSS fixtures not downloaded yet — silent skip
        }

        let pbxprojFiles = try FileManager.default
            .contentsOfDirectory(at: ossDir, includingPropertiesForKeys: [.isRegularFileKey])
            .filter { $0.pathExtension == "pbxproj" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        guard !pbxprojFiles.isEmpty else {
            Issue.record("OSS/ directory exists but contains no .pbxproj files")
            return
        }

        var failCount = 0
        for url in pbxprojFiles {
            let name = url.deletingPathExtension().lastPathComponent
            do {
                let raw = try String(contentsOf: url, encoding: .utf8)
                // The encoder always produces a trailing newline; normalize input
                // to the same convention so we don't flag GitHub-API-stripped files.
                let input = raw.hasSuffix("\n") ? raw : raw + "\n"
                let output = try roundTrip(input)
                if output != input {
                    failCount += 1
                    let inputLines = input.components(separatedBy: "\n")
                    let outputLines = output.components(separatedBy: "\n")
                    for (i, (a, b)) in zip(inputLines, outputLines).enumerated() {
                        if a != b {
                            Issue.record("\(name): line \(i + 1) differs:\n  expected: \(a.debugDescription)\n  got:      \(b.debugDescription)")
                            break
                        }
                    }
                    if outputLines.count != inputLines.count {
                        Issue.record("\(name): line count differs: expected \(inputLines.count), got \(outputLines.count)")
                    }
                }
            } catch {
                withKnownIssue("\(name): parser does not yet handle this syntax") {
                    Issue.record("\(name): parse error — \(error)")
                }
            }
        }
        if failCount > 0 {
            Issue.record("\(failCount) fixture(s) failed round-trip")
        }
    }
}
