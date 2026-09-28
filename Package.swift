// swift-tools-version: 6.4

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "swift-sqlite",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "SQLite", targets: ["SQLite"]),
        .library(name: "SQLite Test Support", targets: ["SQLite Test Support"]),
    ],
    traits: [
        .trait(name: "GRDB", description: "Connection, execution and decoding over GRDB"),
        .trait(name: "Observation", description: "Observed fetches", enabledTraits: ["GRDB"]),
        .trait(name: "CloudKit", description: "CloudKit synchronization", enabledTraits: ["GRDB", "Observation"]),
        .trait(name: "Tagged", description: "SQLite conformances for swift-atoms Tagged"),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.6.0"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.18.4"),
        .package(
            url: "https://github.com/swift-compositions/swift-sql.git",
            branch: "main",
            traits: [.trait(name: "Tagged", condition: .when(traits: ["Tagged"]))]
        ),
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-iso/swift-iso-9075.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-4122.git", branch: "main"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0"),
        .package(url: "https://github.com/swift-atoms/swift-tagged.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-time.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "SQLite",
            dependencies: [
                "SQLite Macros Implementation",
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "ISO 9075 Foundation", package: "swift-iso-9075"),
                .product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "RFC 4122", package: "swift-rfc-4122"),
                .product(name: "GRDB", package: "GRDB.swift", condition: .when(traits: ["GRDB"])),
                .product(
                    name: "OrderedCollections",
                    package: "swift-collections",
                    condition: .when(traits: ["Observation", "CloudKit"])
                ),
                .product(name: "Tagged", package: "swift-tagged", condition: .when(traits: ["Tagged"])),
            ]
        ),
        .macro(
            name: "SQLite Macros Implementation",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "SQLite Test Support",
            dependencies: [
                "SQLite",
                .product(name: "SQL Test Support", package: "swift-sql"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(
            name: "SQLite Tests",
            dependencies: [
                "SQLite",
                "SQLite Test Support",
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
