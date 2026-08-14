// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "BilingualSubtitle",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "BilingualSubtitle", targets: ["BilingualSubtitle"])
    ],
    targets: [
        .executableTarget(
            name: "BilingualSubtitle",
            path: "Sources/BilingualSubtitle"
        ),
        .testTarget(
            name: "BilingualSubtitleTests",
            dependencies: ["BilingualSubtitle"],
            path: "Tests/BilingualSubtitleTests"
        )
    ]
)
