public struct PBXEncoder {
    public init() {}

    public func encode(_ document: PBXDocument) -> String {
        var out = ""
        out += document.header
        out += "\n"
        encodeDict(document.root, into: &out, depth: 0)
        out += "\n"
        return out
    }

    // MARK: - Dict

    private func encodeDict(_ dict: PBXDict, into out: inout String, depth: Int) {
        switch dict.format {
        case .inline:
            encodeInlineDict(dict, into: &out)
        case .multiline:
            encodeMultilineDict(dict, into: &out, depth: depth)
        }
    }

    private func encodeInlineDict(_ dict: PBXDict, into out: inout String) {
        out += "{"
        for entry in dict.entries {
            switch entry {
            case .pair(let key, let value):
                encodeString(key, into: &out)
                out += " = "
                encodeNode(value, into: &out, depth: 0)
                out += "; "
            case .comment(_), .blankLine:
                break  // not expected in inline dicts
            }
        }
        out += "}"
    }

    private func encodeMultilineDict(_ dict: PBXDict, into out: inout String, depth: Int) {
        out += "{"
        for entry in dict.entries {
            switch entry {
            case .pair(let key, let value):
                out += "\n"
                out += String(repeating: "\t", count: depth + 1)
                encodeString(key, into: &out)
                out += " = "
                encodeNode(value, into: &out, depth: depth + 1)
                out += ";"
            case .comment(let text):
                out += "\n"
                // Section comments are always at column 0. The raw text from the scanner
                // already contains the surrounding spaces (e.g. " Begin Foo section "),
                // so we output /*text*/ without adding extra spaces.
                out += "/*\(text)*/"
            case .blankLine:
                out += "\n"
            }
        }
        out += "\n"
        out += String(repeating: "\t", count: depth)
        out += "}"
    }

    // MARK: - Array

    private func encodeArray(_ array: PBXArray, into out: inout String, depth: Int) {
        switch array.format {
        case .inline:
            encodeInlineArray(array, into: &out, depth: depth)
        case .multiline:
            encodeMultilineArray(array, into: &out, depth: depth)
        }
    }

    private func encodeInlineArray(_ array: PBXArray, into out: inout String, depth: Int) {
        out += "("
        for (i, elem) in array.elements.enumerated() {
            encodeNode(elem.value, into: &out, depth: depth)
            if i < array.elements.count - 1 {
                out += ", "
            }
        }
        if array.hasTrailingComma && !array.elements.isEmpty {
            out += ", "
        }
        out += ")"
    }

    private func encodeMultilineArray(_ array: PBXArray, into out: inout String, depth: Int) {
        out += "("
        for (i, elem) in array.elements.enumerated() {
            out += "\n"
            out += String(repeating: "\t", count: depth + 1)
            encodeNode(elem.value, into: &out, depth: depth + 1)
            let isLast = i == array.elements.count - 1
            if !isLast || array.hasTrailingComma {
                out += ","
            }
        }
        out += "\n"
        out += String(repeating: "\t", count: depth)
        out += ")"
    }

    // MARK: - Node

    private func encodeNode(_ node: PBXNode, into out: inout String, depth: Int) {
        switch node {
        case .string(let s):
            encodeString(s, into: &out)
        case .array(let a):
            encodeArray(a, into: &out, depth: depth)
        case .dict(let d):
            encodeDict(d, into: &out, depth: depth)
        }
    }

    // MARK: - String

    private func encodeString(_ s: PBXString, into out: inout String) {
        if s.quoted {
            out += "\""
            out += escapeString(s.value)
            out += "\""
        } else {
            out += s.value
        }
        if let comment = s.comment {
            out += " /* \(comment) */"
        }
    }

    private func escapeString(_ s: String) -> String {
        var out = ""
        for c in s {
            switch c {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            case "\0": out += "\\0"
            default: out.append(c)
            }
        }
        return out
    }
}
