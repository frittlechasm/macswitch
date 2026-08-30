// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "AppSwitcher",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AppSwitcher", targets: ["AppSwitcher"])
    ],
    targets: [
        .executableTarget(
            name: "AppSwitcher",
            path: "Sources/AppSwitcher"
        ),
        .testTarget(
            name: "AppSwitcherTests",
            dependencies: ["AppSwitcher"],
            path: "Tests/AppSwitcherTests"
        )
    ]
)
