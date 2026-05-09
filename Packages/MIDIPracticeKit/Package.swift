// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MIDIPracticeKit",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "MIDIPracticeKit",
            targets: ["MIDIPracticeKit"]
        ),
    ],
    dependencies: [
        .package(path: "../PianoPracticeCore"),
    ],
    targets: [
        .target(
            name: "MIDIPracticeKit",
            dependencies: ["PianoPracticeCore"]
        ),
        .testTarget(
            name: "MIDIPracticeKitTests",
            dependencies: ["MIDIPracticeKit"]
        ),
    ]
)
