// swift-tools-version: 6.0
// RadialMenu is MIT-licensed and standalone: no dependency on the anyfmt app.
import PackageDescription

let package = Package(
    name: "RadialMenu",
    platforms: [.macOS(.v13)],
    products: [.library(name: "RadialMenu", targets: ["RadialMenu"])],
    targets: [
        .target(name: "RadialMenu", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "RadialMenuTests", dependencies: ["RadialMenu"], swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
