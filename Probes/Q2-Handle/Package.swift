// swift-tools-version: 6.4

// Question 2 of swift-sqlite#24: a `~Copyable, ~Escapable` handle that borrows a `~Copyable` connection (a private
// `OpaquePointer`) and is lent to the body, with `execute` and `fetchAll` on it. `Rejected/` holds the three escapes
// the issue names, and more; `Probes/rejected.sh Probes/Q2-Handle` records the diagnostic of each.

import PackageDescription

let package = Package(
    name: "Q2-Handle",
    platforms: [.macOS(.v27)],
    products: [.library(name: "SQLite Handle", targets: ["SQLite Handle"])],
    dependencies: [
        .package(path: "../Q1-Protocol")
    ],
    targets: [
        .systemLibrary(name: "CSQLite", pkgConfig: "sqlite3", providers: [.apt(["libsqlite3-dev"])]),
        .target(
            name: "SQLite Handle",
            dependencies: ["CSQLite", .product(name: "Lent Interface", package: "Q1-Protocol")]
        ),
        .executableTarget(name: "Lend", dependencies: ["SQLite Handle"]),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where target.type != .system {
    target.swiftSettings = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableExperimentalFeature("Lifetimes"),
        .treatAllWarnings(as: .error),
    ]
}
