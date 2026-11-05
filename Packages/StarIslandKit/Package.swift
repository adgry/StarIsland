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
        .executable(name: "StarIsland", targets: ["StarIsland"]),
        .executable(name: "com.adgry.starisland.helper", targets: ["StarIslandHelper"]),
    ],
    targets: [
        .target(name: "IslandCore"),
        .target(name: "MediaAudioKit", dependencies: ["IslandCore"]),
        .target(
            name: "ProductivityKit",
            dependencies: ["IslandCore"],
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .target(name: "SystemEnhanceKit", dependencies: ["IslandCore"]),
        .target(
            name: "HardwareCleanKit",
            dependencies: ["IslandCore"],
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .target(
            name: "LiveWidgetsKit",
            dependencies: ["IslandCore"],
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .target(name: "AIConnectKit", dependencies: ["IslandCore"]),

        .executableTarget(
            name: "StarIsland",
            dependencies: [
                "IslandCore",
                "MediaAudioKit",
                "ProductivityKit",
                "SystemEnhanceKit",
                "HardwareCleanKit",
                "LiveWidgetsKit",
                "AIConnectKit",
            ],
            path: "Sources/StarIslandApp",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .executableTarget(
            name: "StarIslandHelper",
            dependencies: [
                "IslandCore",
                "HardwareCleanKit",
            ],
            path: "Sources/StarIslandHelper",
            linkerSettings: [.linkedFramework("IOKit")]
        ),

        .testTarget(name: "IslandCoreTests", dependencies: ["IslandCore"]),
        .testTarget(name: "MediaAudioKitTests", dependencies: ["MediaAudioKit", "IslandCore"]),
        .testTarget(name: "ProductivityKitTests", dependencies: ["ProductivityKit", "IslandCore"]),
        .testTarget(name: "SystemEnhanceKitTests", dependencies: ["SystemEnhanceKit", "IslandCore"]),
        .testTarget(name: "HardwareCleanKitTests", dependencies: ["HardwareCleanKit", "IslandCore"]),
        .testTarget(name: "LiveWidgetsKitTests", dependencies: ["LiveWidgetsKit", "IslandCore"]),
        .testTarget(name: "AIConnectKitTests", dependencies: ["AIConnectKit", "IslandCore"]),
    ]
)
