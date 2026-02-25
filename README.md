# PBXProjKit

A Swift library for parsing, manipulating, and encoding Xcode project files (`.pbxproj`).

PBXProjKit provides a complete parser and encoder for the ASCII plist format used by Xcode, with **full round-trip fidelity** — parsing and re-encoding produces byte-identical output.

## Features

- Parse `.pbxproj` files into a structured, type-safe Swift representation
- Encode documents back to the `.pbxproj` format
- Preserve formatting: inline vs. multiline collections, comments, blank lines, trailing commas
- Handle all `.pbxproj` syntax: quoted/unquoted strings, escape sequences, section markers, inline annotations
- Zero external dependencies
- Swift 6 concurrency ready (`Sendable` types throughout)

## Requirements

- Swift 6.0+

## Installation

Add PBXProjKit to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/trickart/PBXProjKit.git", from: "1.0.0"),
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["PBXProjKit"]
    ),
]
```

## Usage

### Parsing a project file

```swift
import PBXProjKit

// From a file
let proj = try PBXProj(url: fileURL)

// From a string
let proj = try PBXProj(string: pbxprojContent)
```

### Accessing the document structure

```swift
let document = proj.document
let root = document.root // PBXDict

for entry in root.entries {
    switch entry {
    case .pair(let key, let value):
        print("\(key.value) = ...")
    case .comment(let text):
        print("// \(text)")
    case .blankLine:
        break
    }
}
```

### Encoding and writing

```swift
// Encode to string
let output = proj.encode()

// Write to file
try proj.write(to: outputURL)
```

### Building documents programmatically

```swift
let dict = PBXDict(
    entries: [
        .pair(
            key: PBXString(value: "isa"),
            value: .string(PBXString(value: "PBXBuildFile"))
        ),
        .pair(
            key: PBXString(value: "fileRef"),
            value: .string(PBXString(value: "ABC123", comment: "Main.swift"))
        ),
    ],
    format: .inline
)
```

## API Overview

| Type | Description |
|------|-------------|
| `PBXProj` | Main entry point for parsing and encoding |
| `PBXDocument` | Top-level document (header + root dictionary) |
| `PBXNode` | Union type: `.string`, `.array`, or `.dict` |
| `PBXString` | String value with `quoted` flag and optional inline `comment` |
| `PBXDict` | Ordered dictionary with entries, comments, and blank lines |
| `PBXArray` | Array with elements and trailing comma preservation |
| `CollectionFormat` | `.inline` or `.multiline` formatting |

## Error Handling

PBXProjKit provides detailed error reporting with character offsets:

```swift
do {
    let proj = try PBXProj(string: input)
} catch let error as PBXError {
    switch error {
    case .scanError(let e):
        // e.g. .unexpectedCharacter('!', offset: 42)
        break
    case .parseError(let e):
        // e.g. .unexpectedToken("{", offset: 10)
        break
    }
}
```

## License

MIT License. See [LICENSE](LICENSE) for details.
