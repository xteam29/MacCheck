// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacCheck",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "MacCheck", targets: ["MacCheck"])],
    targets: [
        .executableTarget(name: "MacCheck", path: "Sources/MacCheck")
    ]
)
