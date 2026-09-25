// swift-tools-version:5.9
// Unit tests for the home-screen widget's shared logic (F11):
//   swift test --package-path apps/mobile/ios/AuraWidgetCore
// The source file is compiled as-is into the AuraWidget extension and the
// Runner app by ios/Runner.xcodeproj; this package exists only to test it.
import PackageDescription

let package = Package(
  name: "AuraWidgetCore",
  platforms: [.macOS(.v13), .iOS(.v15)],
  targets: [
    .target(name: "AuraWidgetCore", path: "Sources/AuraWidgetCore"),
    .testTarget(
      name: "AuraWidgetCoreTests",
      dependencies: ["AuraWidgetCore"],
      path: "Tests/AuraWidgetCoreTests",
      resources: []
    ),
  ],
  swiftLanguageVersions: [.v5]
)
