// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MIDIAudioConverter",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "MIDIAudioConverter",
            targets: ["MIDIAudioConverter"]
        ),
    ],
    targets: [
        .target(
            name: "MIDIAudioConverter"
        ),
        .testTarget(
            name: "MIDIAudioConverterTests",
            dependencies: ["MIDIAudioConverter"]
        ),
    ]
)
