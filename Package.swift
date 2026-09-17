// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "KlangLadder",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "KlangLadderApp", targets: ["KlangLadderApp"]),  // used by the Raycast extension
    ],
    targets: [
        .target(name: "KlangLadderCore"),
        .target(name: "KlangLadderApp", dependencies: ["KlangLadderCore"]),
        .executableTarget(name: "KlangLadder", dependencies: ["KlangLadderApp"]),
        .testTarget(name: "KlangLadderCoreTests", dependencies: ["KlangLadderCore"]),
    ]
)
