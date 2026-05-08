// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MIDIPracticeSamples",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(
            name: "MIDIPracticeSampleGenerator",
            targets: ["MIDIPracticeSampleGenerator"]
        ),
        .executable(
            name: "MIDIPracticeSampleRunner",
            targets: ["MIDIPracticeSampleRunner"]
        ),
    ],
    dependencies: [
        .package(path: "../../Packages/MIDIPracticeKit"),
    ],
    targets: [
        .target(
            name: "MIDIPracticeSampleSupport"
        ),
        .executableTarget(
            name: "MIDIPracticeSampleGenerator",
            dependencies: ["MIDIPracticeSampleSupport"]
        ),
        .executableTarget(
            name: "MIDIPracticeSampleRunner",
            dependencies: [
                "MIDIPracticeSampleSupport",
                .product(name: "MIDIPracticeKit", package: "MIDIPracticeKit"),
            ]
        ),
    ]
)
