// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MIDIInputKit",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "MIDIInputKit",
            targets: ["MIDIInputKit"]
        ),
    ],
    dependencies: [
        .package(path: "../PianoPracticeCore"),
        .package(path: "../MIDIPracticeKit"),
    ],
    targets: [
        .target(
            name: "MIDIInputKit",
            dependencies: ["PianoPracticeCore"]
        ),
        .testTarget(
            name: "MIDIInputKitTests",
            dependencies: [
                "MIDIInputKit",
                "MIDIPracticeKit",
            ]
        ),
    ]
)
