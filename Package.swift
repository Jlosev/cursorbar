// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CursorBar",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "PaceCore",
            path: "Sources/PaceCore"
        ),
        .executableTarget(
            // Keep product name CursorBar until Task 4 so scripts/package.sh still works mid-branch.
            name: "CursorBar",
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
