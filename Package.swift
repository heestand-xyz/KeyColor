// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "KeyColor",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
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
            from: "3.1.0"
        ),
        .package(
            url: "https://github.com/heestand-xyz/AsyncGraphics",
            from: "2.1.1"
        ),
        .package(
            url: "https://github.com/heestand-xyz/TextureMap",
            from: "2.1.0"
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
