// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Macwal",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "macwal", targets: ["MacwalCLI"]),
        .library(name: "MacwalCore", targets: ["MacwalCore"])
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0")
    ],
    targets: [
        .executableTarget(
            name: "MacwalCLI",
            dependencies: ["MacwalCore"]
        ),
        .target(
            name: "MacwalCore"
        ),
        .testTarget(
            name: "MacwalCoreTests",
            dependencies: [
                "MacwalCore",
                .product(name: "Testing", package: "swift-testing")
            ],
            resources: [
                .process("Snapshots")
            ]
        )
    ]
)
