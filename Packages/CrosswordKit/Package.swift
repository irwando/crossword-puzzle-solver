// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CrosswordKit",
    platforms: [.iOS(.v26), .macOS(.v26)],
    products: [
        .library(name: "CrosswordCore", targets: ["CrosswordCore"]),
        .library(name: "PuzzleFormats", targets: ["PuzzleFormats"]),
    ],
    targets: [
        .target(name: "CrosswordCore"),
        .target(name: "PuzzleFormats", dependencies: ["CrosswordCore"]),
        .testTarget(name: "CrosswordCoreTests", dependencies: ["CrosswordCore"]),
        .testTarget(
            name: "PuzzleFormatsTests",
            dependencies: ["PuzzleFormats"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
