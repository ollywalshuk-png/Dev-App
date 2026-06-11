// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LocalForge",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "LocalForgeCore",
            targets: ["LocalForgeCore"]
        ),
        .executable(
            name: "LocalForge",
            targets: ["LocalForgeApp"]
        ),
        .executable(
            name: "localforge",
            targets: ["LocalForgeCLI"]
        )
    ],
    targets: [
        .target(
            name: "LocalForgeCore"
        ),
        .executableTarget(
            name: "LocalForgeApp",
            dependencies: ["LocalForgeCore"]
        ),
        .executableTarget(
            name: "LocalForgeCLI",
            dependencies: ["LocalForgeCore"]
        ),
        .testTarget(
            name: "LocalForgeCoreTests",
            dependencies: ["LocalForgeCore"]
        )
    ]
)
