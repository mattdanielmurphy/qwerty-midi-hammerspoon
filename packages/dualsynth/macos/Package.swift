// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DualSynth",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "DualSynthCore",
            targets: ["DualSynthCore"]
        ),
        .executable(
            name: "dualsynth-cli",
            targets: ["dualsynth-cli"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "DualSynthCore",
            dependencies: [],
            path: "Sources/DualSynthCore"
        ),
        .executableTarget(
            name: "dualsynth-cli",
            dependencies: ["DualSynthCore"],
            path: "Sources/dualsynth-cli"
        )
    ]
)
