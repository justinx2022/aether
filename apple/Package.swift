// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AetherKit",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .tvOS(.v16)
    ],
    products: [
        .library(name: "AetherKit", targets: ["AetherKit"]),
    ],
    targets: [
        .target(
            name: "AetherCoreC",
            publicHeadersPath: "include"
        ),
        .target(
            name: "AetherKit",
            dependencies: ["AetherCoreC"]
        ),
        .testTarget(
            name: "AetherKitTests",
            dependencies: ["AetherKit"]
        )
    ]
)
