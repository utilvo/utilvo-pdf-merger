// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "UtilvoPdfMerger",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(
            name: "UtilvoPdfMerger",
            targets: ["UtilvoPdfMerger"]
        ),
    ],
    targets: [
        .target(
            name: "UtilvoPdfMerger",
            dependencies: [],
            path: "Sources/UtilvoPdfMerger"
        ),
    ]
)
