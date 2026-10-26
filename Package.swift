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
        .library(name: "SQLite SQL", targets: ["SQLite SQL"]),
        .library(name: "SQLite", targets: ["SQLite"]),
        .library(name: "SQLite CloudKit", targets: ["SQLite CloudKit"]),
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
        .package(url: "https://github.com/pointfreeco/swift-custom-dump.git", from: "1.3.3"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.6.3"),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", from: "1.18.4"),
        .package(
            url: "https://github.com/swift-compositions/swift-sql.git",
            branch: "main",
            traits: [.trait(name: "Tagged", condition: .when(traits: ["Tagged"]))]
        ),
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-order.git", branch: "main"),
        .package(url: "https://github.com/swift-iso/swift-iso-9075.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-4122.git", branch: "main"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0"),
        .package(url: "https://github.com/swift-atoms/swift-tagged.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-time.git", branch: "main"),
    ],
    targets: [
        // SQLite's dialect as statements and expressions: functions, FTS5, JSON, dates, pragmas, triggers, views and the
        // schema table. It runs nothing, so a target that depends on it alone can build every statement and execute none.
        .target(
            name: "SQLite SQL",
            dependencies: [
                "SQLite Macros Implementation",
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "ISO 9075 Foundation", package: "swift-iso-9075"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Order", package: "swift-order"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "RFC 4122", package: "swift-rfc-4122"),
                .product(name: "Tagged", package: "swift-tagged", condition: .when(traits: ["Tagged"])),
            ]
        ),
        // The database: connections, execution, observation, over GRDB as a private driver.
        .target(
            name: "SQLite",
            dependencies: [
                "SQLite SQL",
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "ISO 9075 Foundation", package: "swift-iso-9075"),
                .product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Order", package: "swift-order"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "RFC 4122", package: "swift-rfc-4122"),
                .product(name: "GRDB", package: "GRDB.swift", condition: .when(traits: ["GRDB", "Observation", "CloudKit"])),
                .product(
                    name: "OrderedCollections",
                    package: "swift-collections",
                    condition: .when(traits: ["GRDB", "Observation", "CloudKit"])
                ),
                .product(name: "Tagged", package: "swift-tagged", condition: .when(traits: ["Tagged"])),
            ]
        ),
        .target(
            name: "SQLite CloudKit",
            dependencies: [
                "SQLite",
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "RFC 4122", package: "swift-rfc-4122"),
                .product(name: "GRDB", package: "GRDB.swift", condition: .when(traits: ["CloudKit"])),
                .product(
                    name: "OrderedCollections",
                    package: "swift-collections",
                    condition: .when(traits: ["CloudKit"])
                ),
                .product(name: "Tagged", package: "swift-tagged", condition: .when(traits: ["Tagged"])),
            ],
            path: "Sources/SQLite CloudKit"
        ),
        .macro(
            name: "SQLite Macros Implementation",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "SQLite Test Support",
            dependencies: [
                "SQLite",
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "SQL Test Support", package: "swift-sql"),
                .product(name: "SQL Foundation Integration", package: "swift-sql"),
                .product(name: "ISO 9075 Foundation", package: "swift-iso-9075"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "RFC 4122", package: "swift-rfc-4122"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "GRDB", package: "GRDB.swift", condition: .when(traits: ["GRDB"])),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
            ]
        ),
        .testTarget(
            name: "SQLite Tests",
            dependencies: [
                "SQLite",
                "SQLite Test Support",
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "SQL Migrations", package: "swift-sql"),
                .product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075"),
                .product(name: "GRDB", package: "GRDB.swift", condition: .when(traits: ["GRDB"])),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .testTarget(
            name: "SQLite CloudKit Tests",
            dependencies: [
                "SQLite",
                "SQLite CloudKit",
                "SQLite Test Support",
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "CustomDump", package: "swift-custom-dump"),
                .product(name: "InlineSnapshotTesting", package: "swift-snapshot-testing"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        // A consumer's view: the Institute's modules only, never the driver. It compiles only while no public
        // declaration of SQLite or SQLite CloudKit needs a GRDB type.
        .testTarget(
            name: "SQLite Consumer Tests",
            dependencies: [
                "SQLite",
                .target(name: "SQLite CloudKit", condition: .when(traits: ["CloudKit"])),
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "SQL Migrations", package: "swift-sql"),
                .product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .testTarget(
            name: "SQLite Macros Implementation Tests",
            dependencies: [
                "SQLite Macros Implementation",
                .product(name: "MacroTesting", package: "swift-macro-testing"),
                .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
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
