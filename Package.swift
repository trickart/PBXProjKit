// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PBXProjKit",
    products: [
        .library(name: "PBXProjKit", targets: ["PBXProjKit"]),
    ],
    targets: [
        .target(
            name: "PBXProjKit"
        ),
        .testTarget(
            name: "PBXProjKitTests",
            dependencies: ["PBXProjKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
