// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "windowneon",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0"),
    ],
    targets: [
        .target(
            name: "windowneon",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/windowneon"
        ),
        .executableTarget(
            name: "windowneonApp",
            dependencies: ["windowneon"],
            path: "Sources/windowneonApp"
        ),
        .testTarget(
            name: "windowneonTests",
            dependencies: [
                "windowneon",
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
            ],
            path: "Tests/windowneonTests",
            resources: [.copy("__Snapshots__")]
        ),
    ]
)
