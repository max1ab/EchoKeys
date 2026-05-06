// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MIDINotationConverter",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "MIDINotationConverter",
            targets: ["MIDINotationConverter"]
        ),
    ],
    targets: [
        .target(
            name: "MIDINotationConverter"
        ),
        .testTarget(
            name: "MIDINotationConverterTests",
            dependencies: ["MIDINotationConverter"]
        ),
    ]
)
