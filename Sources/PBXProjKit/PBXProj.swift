import Foundation

public enum PBXError: Error, Sendable {
    case scanError(PBXScanError)
    case parseError(PBXParseError)
}

public struct PBXProj: Sendable {
    public var document: PBXDocument

    public init(string: String) throws {
        var scanner = PBXScanner(source: string)
        let tokens: [Token]
        do {
            tokens = try scanner.scanAll()
        } catch let e as PBXScanError {
            throw PBXError.scanError(e)
        }
        var parser = PBXParser(tokens: tokens)
        do {
            self.document = try parser.parseDocument()
        } catch let e as PBXParseError {
            throw PBXError.parseError(e)
        }
    }

    public init(document: PBXDocument) {
        self.document = document
    }

    public init(url: URL) throws {
        let string = try String(contentsOf: url, encoding: .utf8)
        try self.init(string: string)
    }

    public func encode() -> String {
        PBXEncoder().encode(document)
    }

    public func write(to url: URL) throws {
        let string = encode()
        try string.write(to: url, atomically: true, encoding: .utf8)
    }
}
