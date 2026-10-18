// swift-tools-version: 6.0
// Phase 0 spike: can a background menu-bar app detect a Finder drag, a
// modifier tap during it, and accept the drop on an overlay? See
// docs/DECISIONS.md (D-001..D-004) for the results.
import PackageDescription

let package = Package(
    name: "DragProbe",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "DragProbe",
            path: "Sources",
            swiftSettings: [.swiftLanguageMode(.v6)]
        )
    ]
)
