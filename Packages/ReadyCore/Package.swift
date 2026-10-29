// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReadyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ReadyCore", targets: ["ReadyCore"])],
    targets: [
        .target(name: "ReadyCore", resources: [.process("Resources")]),
        .testTarget(name: "ReadyCoreTests", dependencies: ["ReadyCore"]),
    ]
)
