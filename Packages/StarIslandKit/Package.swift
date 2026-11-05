// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "StarIslandKit",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "IslandCore", targets: ["IslandCore"]),
        .library(name: "MediaAudioKit", targets: ["MediaAudioKit"]),
        .library(name: "ProductivityKit", targets: ["ProductivityKit"]),
        .library(name: "SystemEnhanceKit", targets: ["SystemEnhanceKit"]),
        .library(name: "HardwareCleanKit", targets: ["HardwareCleanKit"]),
        .library(name: "LiveWidgetsKit", targets: ["LiveWidgetsKit"]),
        .library(name: "AIConnectKit", targets: ["AIConnectKit"]),
    ],
    targets: [
        .target(name: "IslandCore"),
        .target(name: "MediaAudioKit", dependencies: ["IslandCore"]),
        .target(name: "ProductivityKit", dependencies: ["IslandCore"]),
        .target(name: "SystemEnhanceKit", dependencies: ["IslandCore"]),
        .target(name: "HardwareCleanKit", dependencies: ["IslandCore"]),
        .target(name: "LiveWidgetsKit", dependencies: ["IslandCore"]),
        .target(name: "AIConnectKit", dependencies: ["IslandCore"]),

        .testTarget(name: "IslandCoreTests", dependencies: ["IslandCore"]),
        .testTarget(name: "MediaAudioKitTests", dependencies: ["MediaAudioKit", "IslandCore"]),
        .testTarget(name: "ProductivityKitTests", dependencies: ["ProductivityKit", "IslandCore"]),
        .testTarget(name: "SystemEnhanceKitTests", dependencies: ["SystemEnhanceKit", "IslandCore"]),
        .testTarget(name: "HardwareCleanKitTests", dependencies: ["HardwareCleanKit", "IslandCore"]),
        .testTarget(name: "LiveWidgetsKitTests", dependencies: ["LiveWidgetsKit", "IslandCore"]),
        .testTarget(name: "AIConnectKitTests", dependencies: ["AIConnectKit", "IslandCore"]),
    ]
)
