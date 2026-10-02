// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusForge",
    products: [
        .library(name: "FocusForge", targets: ["FocusForge"]),
    ],
    targets: [
        .target(
            name: "FocusForge",
            path: "Sources/FocusForge"
        ),
        .testTarget(
            name: "FocusForgeTests",
            dependencies: ["FocusForge"],
            path: "Tests/FocusForgeTests"
        ),
    ]
)
