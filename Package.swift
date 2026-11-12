// swift-tools-version: 6.1
import PackageDescription

/* This package exists only so that `swift test` can cover the gesture logic, which has no system
   dependencies. The app itself is built from the Xcode project. */
let package = Package(
    name: "EdgeGestures",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "EdgeGestures", path: "trackpad-edges/Gestures"),
        .testTarget(
            name: "EdgeGesturesTests", dependencies: ["EdgeGestures"],
            path: "Tests/EdgeGesturesTests"),
    ],
    swiftLanguageModes: [.v5]
)
