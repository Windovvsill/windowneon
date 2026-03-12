// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "windowneon",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "windowneon",
            path: "Sources/windowneon"
        )
    ]
)
