public enum CollectionFormat: Equatable, Sendable {
    case inline
    case multiline
}

public struct PBXString: Equatable, Hashable, Sendable {
    public var value: String
    public var quoted: Bool
    public var comment: String?

    public init(value: String, quoted: Bool = false, comment: String? = nil) {
        self.value = value
        self.quoted = quoted
        self.comment = comment
    }
}

public enum PBXDictEntry: Equatable, Sendable {
    case pair(key: PBXString, value: PBXNode)
    case comment(String)
    case blankLine
}

public struct PBXDict: Equatable, Sendable {
    public var entries: [PBXDictEntry]
    public var format: CollectionFormat

    public init(entries: [PBXDictEntry] = [], format: CollectionFormat = .multiline) {
        self.entries = entries
        self.format = format
    }
}

public struct PBXArrayElement: Equatable, Sendable {
    public var value: PBXNode

    public init(value: PBXNode) {
        self.value = value
    }
}

public struct PBXArray: Equatable, Sendable {
    public var elements: [PBXArrayElement]
    public var format: CollectionFormat
    public var hasTrailingComma: Bool

    public init(elements: [PBXArrayElement] = [], format: CollectionFormat = .multiline, hasTrailingComma: Bool = false) {
        self.elements = elements
        self.format = format
        self.hasTrailingComma = hasTrailingComma
    }
}

public indirect enum PBXNode: Equatable, Sendable {
    case string(PBXString)
    case array(PBXArray)
    case dict(PBXDict)
}

public struct PBXDocument: Equatable, Sendable {
    public var header: String
    public var root: PBXDict

    public init(header: String = "// !$*UTF8*$!", root: PBXDict = PBXDict()) {
        self.header = header
        self.root = root
    }
}
