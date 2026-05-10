// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "TuttleMac",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/pvieito/PythonKit.git", branch: "master"),
    ],
    targets: [
        .executableTarget(
            name: "TuttleMac",
            dependencies: ["PythonKit"],
            path: "Sources/TuttleMac",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency=minimal"),
            ]
        ),
    ]
)
