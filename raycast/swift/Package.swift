// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KlangLadderRaycast",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/raycast/extensions-swift-tools", from: "1.1.0"),
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "KlangLadderRaycast",
            dependencies: [
                .product(name: "RaycastSwiftMacros", package: "extensions-swift-tools"),
                .product(name: "KlangLadderApp", package: "KlangLadder"),
            ],
            path: "Sources",
            plugins: [
                // No RaycastSwiftPlugin: main.swift is ours, so the same binary can also run as the app.
                .plugin(name: "RaycastTypeScriptPlugin", package: "extensions-swift-tools"),
            ]
        ),
    ]
)
