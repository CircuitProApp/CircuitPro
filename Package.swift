// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "CircuitPro",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CircuitPro", targets: ["CircuitPro"]),
    ],
    targets: [
        .target(name: "CircuitPro", path: "CircuitPro"),
        .testTarget(name: "CircuitProTests", dependencies: ["CircuitPro"], path: "Tests")
    ]
)
