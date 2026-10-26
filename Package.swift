// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MobileExplorer",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "MobileExplorer", targets: ["MobileExplorer"])],
    targets: [
        .executableTarget(name: "MobileExplorer", path: "Sources/MobileExplorer"),
        .testTarget(name: "MobileExplorerTests", dependencies: ["MobileExplorer"], path: "Tests/MobileExplorerTests")
    ]
)
