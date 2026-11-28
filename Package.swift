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
        .trait(name: "Observation", description: "Observed fetches"),
        .trait(name: "CloudKit", description: "CloudKit synchronization", enabledTraits: ["Observation"]),
        .trait(name: "Tagged", description: "SQLite conformances for swift-atoms Tagged"),
        .trait(name: "Dependencies", description: "The ambient database as a dependency value"),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.1.2"),
        .package(
            url: "https://github.com/swift-compositions/swift-sql.git",
            branch: "main",
            traits: [.trait(name: "Tagged", condition: .when(traits: ["Tagged"]))]
        ),
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-atoms/swift-order.git", branch: "main"),
        .package(url: "https://github.com/swift-iso/swift-iso-9075.git", branch: "main"),
        .package(url: "https://github.com/swift-compositions/swift-executors.git", branch: "main"),
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
        // SQLite, and the one call Swift cannot make of it. No logic. Apple platforms use the system's SQLite; elsewhere
        // the target compiles the amalgamation of SQLite 3.54.1 in Sources/SQLite Shims/sqlite (sqlite.org,
        // sqlite-amalgamation-3540100.zip, SHA3-256 92281c86e2957f9b9305890f9ac04204caa7b677cc868dc326d942689df28e30).
        .target(
            name: "SQLite Shims",
            exclude: ["sqlite/sqlite3.c"],
            cSettings: [
                .define("SQLITE_ENABLE_FTS5"),
                .define("SQLITE_ENABLE_COLUMN_METADATA"),
                .define("SQLITE_ENABLE_MATH_FUNCTIONS"),
                .define("SQLITE_OMIT_LOAD_EXTENSION"),
                .define("HAVE_USLEEP", to: "1"),
            ],
            linkerSettings: [
                .linkedLibrary("sqlite3", .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS, .macCatalyst]))
            ]
        ),
        // The database: connections, execution and the writer and reader actors, over the driver in Sources/SQLite/Driver.
        .target(
            name: "SQLite",
            dependencies: [
                .target(name: "SQLite SQL"),
                .target(name: "SQLite Shims"),
                .product(name: "Executors", package: "swift-executors"),
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
                .product(name: "Test", package: "swift-test"),
            ]
        ),
        // Not a product: it prints the driver's fixed costs, each as two variants in one run.
        .executableTarget(
            name: "SQLite Benchmark",
            dependencies: [
                .target(name: "SQLite"),
                .target(name: "SQLite Test Support"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Path", package: "swift-path"),
                .product(name: "SQL", package: "swift-sql"),
                .product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075"),
                .product(name: "Executors", package: "swift-executors"),
                .product(name: "Thread Actor", package: "swift-threads"),
            ],
            path: "Benchmarks/SQLite Benchmark"
        ),
        .testTarget(
            name: "SQLite Tests",
            dependencies: [
                .target(name: "SQLite"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "Path", package: "swift-path"),
                .target(name: "SQLite Test Support"),
                .product(name: "SQL Macros", package: "swift-sql"),
                .product(name: "SQL Migrations", package: "swift-sql"),
                .product(name: "SQL Test Support", package: "swift-sql"),
                .product(name: "ISO 9075 Call-Level Interface", package: "swift-iso-9075"),
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
        // A consumer's view: the public modules only, as a product names them.
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
