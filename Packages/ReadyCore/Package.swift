// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReadyCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "ReadyCore", targets: ["ReadyCore"])],
    targets: [
        .target(name: "ReadyCore", dependencies: ["llama"], resources: [.process("Resources")]),
        // Built by scripts/setup-llama.sh: official llama.cpp slices plus a simulator slice.
        .binaryTarget(name: "llama", path: "../../Vendor/llama.xcframework"),
        .testTarget(name: "ReadyCoreTests", dependencies: ["ReadyCore"]),
    ]
)
