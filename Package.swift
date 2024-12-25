// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "KeyColor",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .visionOS(.v1),
    ],
    products: [
        .library(
            name: "KeyColor",
            targets: ["KeyColor"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/heestand-xyz/PixelColor",
            from: "3.0.0"
        ),
        .package(
            url: "https://github.com/heestand-xyz/AsyncGraphics",
            from: "2.1.1"
        ),
        .package(
            url: "https://github.com/heestand-xyz/TextureMap",
            from: "1.0.3"
        ),
    ],
    targets: [
        .target(
            name: "KeyColor",
            dependencies: [
                "AsyncGraphics",
                "TextureMap",
                "PixelColor",
            ]
        ),
        .testTarget(
            name: "KeyColorTests",
            dependencies: ["KeyColor"]
        ),
    ]
)
