// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Gemini",
    platforms: [.iOS(.v14), .macOS(.v10_16)],
    products: [
        .library(
            name: "Gemini",
            targets: ["Gemini"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Gemini",
            dependencies: []
        ),
        .testTarget(
            name: "GeminiTests",
            dependencies: ["Gemini"]
        ),
    ]
)
