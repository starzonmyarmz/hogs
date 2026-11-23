// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Hogs",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HogsCore"),
        .executableTarget(name: "Hogs", dependencies: ["HogsCore"]),
        .testTarget(name: "HogsCoreTests", dependencies: ["HogsCore"]),
    ]
)
