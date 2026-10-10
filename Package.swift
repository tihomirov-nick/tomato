// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Tomato",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Tomato", targets: ["Tomato"]),
    ],
    targets: [
        // Localization and the interface language (InterfaceLanguage.swift is the family's shared file)
        .target(
            name: "TomatoCore",
            path: "Sources/TomatoCore"
        ),
        // The menu bar app: the icon, its menu and panel, Settings, updates, sounds
        .executableTarget(
            name: "Tomato",
            dependencies: ["TomatoCore"],
            path: "Sources/Tomato"
        ),
        .testTarget(
            name: "TomatoTests",
            dependencies: ["Tomato", "TomatoCore"],
            path: "Tests/TomatoTests"
        ),
    ]
)
