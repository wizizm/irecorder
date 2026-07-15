// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iRecorder",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "IRecorderCore", targets: ["IRecorderCore"]),
        .executable(name: "iRecorder", targets: ["iRecorder"]),
    ],
    targets: [
        .target(name: "IRecorderCore"),
        .executableTarget(name: "iRecorder", dependencies: ["IRecorderCore"]),
        .testTarget(name: "IRecorderCoreTests", dependencies: ["IRecorderCore"]),
    ]
)
