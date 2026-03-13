// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TransOn",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "TransOn",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("Security"),
                .linkedFramework("SwiftUI"),
                .linkedFramework("WidgetKit")
            ]
        )
    ]
)
