// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "runner",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .executableTarget(
            name: "runner",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/Runner"
        ),
        .testTarget(
            name: "RunnerTests",
            dependencies: ["runner"],
            path: "Tests/RunnerTests"
        ),
    ]
)
