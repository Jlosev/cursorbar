// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CursorBarPace",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "PaceCore",
            path: "Sources/PaceCore"
        ),
        .executableTarget(
            name: "CursorBarPace",
            dependencies: ["PaceCore"],
            path: "Sources/CursorBar",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "PaceCoreTests",
            dependencies: ["PaceCore"],
            path: "Tests/PaceCoreTests"
        ),
    ]
)
