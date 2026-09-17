// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "KlangLadder",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "KlangLadderCore"),
        .executableTarget(name: "KlangLadder", dependencies: ["KlangLadderCore"]),
        .testTarget(name: "KlangLadderCoreTests", dependencies: ["KlangLadderCore"]),
    ]
)
