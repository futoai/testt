// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "testt",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "RemoteOpsCore", targets: ["RemoteOpsCore"]),
        .executable(name: "testt", targets: ["testt"])
    ],
    targets: [
        .target(name: "RemoteOpsCore"),
        .executableTarget(name: "testt", dependencies: ["RemoteOpsCore"]),
        .testTarget(name: "RemoteOpsCoreTests", dependencies: ["RemoteOpsCore"])
    ]
)
