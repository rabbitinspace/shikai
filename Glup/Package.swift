// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "Glup",
    platforms: [.iOS(.v14), .macOS(.v10_16)],
    products: [
        .library(
            name: "Glup",
            targets: ["Glup"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Glup",
            dependencies: []),
        .testTarget(
            name: "GlupTests",
            dependencies: ["Glup"]),
    ]
)
