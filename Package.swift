// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SelectedTextOverlay",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SelectedTextOverlay",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("Security"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
