// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ExciteMessenger",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ExciteMessenger", targets: ["ExciteMessenger"])
    ],
    targets: [
        .executableTarget(
            name: "ExciteMessenger",
            path: "Sources/ExciteMessenger"
        )
    ]
)
