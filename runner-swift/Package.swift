// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "runner",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        // Library containing all core logic (testable)
        .target(
            name: "RunnerLib",
            dependencies: [
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "GRDB", package: "GRDB.swift")
            ],
            path: "Sources/RunnerLib"
        ),
        // Executable that uses the library
        .executableTarget(
            name: "Runner",
            dependencies: ["RunnerLib"],
            path: "Sources/Runner"
        ),
        .testTarget(
            name: "RunnerTests",
            dependencies: ["RunnerLib"],
            path: "Tests/RunnerTests"
        )
    ]
)
