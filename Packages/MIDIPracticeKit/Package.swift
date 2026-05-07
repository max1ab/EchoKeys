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
    targets: [
        .target(
            name: "MIDIPracticeKit"
        ),
        .testTarget(
            name: "MIDIPracticeKitTests",
            dependencies: ["MIDIPracticeKit"]
        ),
    ]
)
