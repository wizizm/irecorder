// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iRecorder",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "IRecorderCore", targets: ["IRecorderCore"]),
        .executable(name: "iRecorder", targets: ["iRecorder"]),
    ],
    targets: [
        .target(name: "IRecorderCore"),
        .executableTarget(
            name: "iRecorder",
            dependencies: ["IRecorderCore"],
            exclude: ["Info.plist"],
            linkerSettings: [
                .linkedFramework("Carbon"),
            ]
        ),
        .testTarget(name: "IRecorderCoreTests", dependencies: ["IRecorderCore"]),
    ]
)
