// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "ClearToneEngine",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClearToneEngine", targets: ["ClearToneEngine"])
    ],
    targets: [
        .executableTarget(
            name: "ClearToneEngine",
            path: "Sources/ClearToneEngine"
        )
    ]
)
