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
        ),
        .executable(
            name: "dualsynth-gui",
            targets: ["dualsynth-gui"]
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
        ),
        .executableTarget(
            name: "dualsynth-gui",
            dependencies: ["DualSynthCore"],
            path: "Sources/dualsynth-gui"
        )
    ]
)
