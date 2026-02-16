// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SelectedTextOverlay",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "SelectedTextOverlay",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon")
            ]
        )
    ]
)
