// swift-tools-version: 6.0
// DragSense is MIT-licensed and standalone: no dependency on the anyfmt app.
import PackageDescription

let package = Package(
    name: "DragSense",
    platforms: [.macOS(.v13)],
    products: [.library(name: "DragSense", targets: ["DragSense"])],
    targets: [
        .target(name: "DragSense", swiftSettings: [.swiftLanguageMode(.v6)]),
        .testTarget(name: "DragSenseTests", dependencies: ["DragSense"], swiftSettings: [.swiftLanguageMode(.v6)]),
    ]
)
