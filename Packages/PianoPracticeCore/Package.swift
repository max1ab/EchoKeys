// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "PianoPracticeCore",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "PianoPracticeCore",
            targets: ["PianoPracticeCore"]
        ),
    ],
    targets: [
        .target(
            name: "PianoPracticeCore"
        ),
        .testTarget(
            name: "PianoPracticeCoreTests",
            dependencies: ["PianoPracticeCore"]
        ),
    ]
)
