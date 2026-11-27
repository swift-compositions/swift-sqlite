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
        .trait(name: "Observation", description: "Observed fetches"),
        .trait(name: "CloudKit", description: "CloudKit synchronization", enabledTraits: ["Observation"]),
        .trait(name: "Tagged", description: "SQLite conformances for swift-atoms Tagged"),
        .trait(name: "Dependencies", description: "The ambient database as a dependency value", enabledTraits: ["GRDB"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.2"),
        .package(url: "https://github.com/swift-compositions/GRDB.swift.git", branch: "main"),
        .package(
            url: "https://github.com/swift-compositions/swift-sql.git",
            branch: "lent-connection",
            traits: [.trait(name: "Tagged", condition: .when(traits: ["Tagged"]))]
        ),
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-order.git", branch: "main"),
        .package(url: "https://github.com/swift-iso/swift-iso-9075.git", branch: "lent-connection"),
        .package(url: "https://github.com/swift-compositions/swift-threads.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-4122.git", branch: "main"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "604.0.0"..<"605.0.0"),
        .package(url: "https://github.com/swift-atoms/swift-path.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-tagged.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-time.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-dependencies.git", branch: "main"),
        .package(url: "https://github.com/swift-molecules/swift-test.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-tests.git", branch: "main"),
    ],
    targets: [
        // SQLite's dialect as statements and expressions: functions, FTS5, JSON, dates, pragmas, triggers, views and the
        // schema table. It runs nothing, so a target that depends on it alone can build every statement and execute none.
        .target(
            name: "SQLite SQL",
            dependencies: [
                .target(name: "SQLite Macros Implementation"),
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
        // The system's SQLite, on every platform, and the one call Swift cannot make of it. No logic.
        .target(
            name: "SQLite Shims",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        // The database: connections, execution and the writer and reader actors, over the driver in Sources/SQLite/Driver.
        // What still runs on GRDB itself (cursors, CloudKit) sits behind the GRDB trait and is not ported yet.
        .target(
            name: "SQLite",
            dependencies: [
                .target(name: "SQLite SQL"),
                .target(name: "SQLite Shims"),
                .product(name: "Thread Actor", package: "swift-threads"),
                .product(name: "Path", package: "swift-path"),
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "ISO 9075 Foundation", package: "swift-iso-9075"),
                .product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Order", package: "swift-order"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "RFC 4122", package: "swift-rfc-4122"),
                .product(name: "GRDB", package: "GRDB.swift", condition: .when(traits: ["GRDB"])),
                .product(
                    name: "OrderedCollections",
                    package: "swift-collections",
                    condition: .when(traits: ["GRDB"])
                ),
                .product(name: "Tagged", package: "swift-tagged", condition: .when(traits: ["Tagged"])),
                .product(name: "Dependencies", package: "swift-dependencies", condition: .when(traits: ["Dependencies"])),
            ]
        ),
        .target(
            name: "SQLite CloudKit",
            dependencies: [
                .target(name: "SQLite"),
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "SQL Migrations", package: "swift-sql"),
                .product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075"),
                .product(name: "Path", package: "swift-path"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "RFC 4122", package: "swift-rfc-4122"),
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
                .target(name: "SQLite"),
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "SQL Test Support", package: "swift-sql"),
                .product(name: "SQL Foundation Integration", package: "swift-sql"),
                .product(name: "ISO 9075 Foundation", package: "swift-iso-9075"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "RFC 4122", package: "swift-rfc-4122"),
                .product(name: "Time", package: "swift-time"),
                .product(name: "GRDB", package: "GRDB.swift", condition: .when(traits: ["GRDB"])),
                .product(name: "Test", package: "swift-test"),
            ]
        ),
        .testTarget(
            name: "SQLite Tests",
            dependencies: [
                .target(name: "SQLite"),
                .product(name: "Path", package: "swift-path"),
                .target(name: "SQLite Test Support"),
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "SQL Migrations", package: "swift-sql"),
                .product(name: "SQL Test Support", package: "swift-sql"),
                .product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075"),
                .product(name: "GRDB", package: "GRDB.swift", condition: .when(traits: ["GRDB"])),
                .product(name: "Dependencies", package: "swift-dependencies", condition: .when(traits: ["Dependencies"])),
                .product(name: "Tests Inline Snapshot", package: "swift-tests"),
                .product(name: "Tests Apple Testing Bridge", package: "swift-tests"),
            ],
            swiftSettings: [
                .treatAllWarnings(as: .error)
            ]
        ),
        .testTarget(
            name: "SQLite CloudKit Tests",
            dependencies: [
                .target(name: "SQLite"),
                .product(name: "Path", package: "swift-path"),
                .target(name: "SQLite CloudKit"),
                .target(name: "SQLite Test Support"),
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "Tests Inline Snapshot", package: "swift-tests"),
                .product(name: "Test", package: "swift-test"),
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
                .target(name: "SQLite"),
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
                .target(name: "SQLite Macros Implementation"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacroExpansion", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosGenericTestSupport", package: "swift-syntax"),
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
        .enableExperimentalFeature("Lifetimes"),
    ]

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
