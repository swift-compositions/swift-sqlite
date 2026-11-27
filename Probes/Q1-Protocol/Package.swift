// swift-tools-version: 6.4

// Question 1 of swift-sqlite#24: does the new shape of `ISO_9075.Database` compile, as a requirement and at a call
// site that reads and writes through `some Database`? The real `Failure`, `Error`, `Rendering`, `Fragment`,
// `Dialect` and `Row` come from swift-iso-9075; only the three protocols are redeclared here in their new shape.

import PackageDescription

let package = Package(
    name: "Q1-Protocol",
    platforms: [.macOS(.v27)],
    dependencies: [
        .package(url: "https://github.com/swift-iso/swift-iso-9075.git", branch: "main")
    ],
    targets: [
        .target(
            name: "Lent Interface",
            dependencies: [.product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075")]
        ),
        .executableTarget(name: "Call Site", dependencies: ["Lent Interface"]),
        // The same call site in a module that does not enable NonisolatedNonsendingByDefault.
        .executableTarget(name: "Call Site Without Feature", dependencies: ["Lent Interface"]),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    var settings: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableExperimentalFeature("Lifetimes"),
        .treatAllWarnings(as: .error),
    ]
    if target.name != "Call Site Without Feature" {
        settings.append(.enableUpcomingFeature("NonisolatedNonsendingByDefault"))
    }
    target.swiftSettings = settings
}
