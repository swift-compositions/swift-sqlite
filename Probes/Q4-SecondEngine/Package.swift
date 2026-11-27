// swift-tools-version: 6.4

// Question 4 of swift-sqlite#24: can a connection that is not SQLite's conform to the same protocol? The engine is
// swift-postgresql as it is on `main`, over PostgresNIO. `Conform` runs against a PostgreSQL server:
//
//   PROBE_POSTGRES=postgres://postgres:probe@127.0.0.1:5432/probe swift run Conform

import PackageDescription

let package = Package(
    name: "Q4-SecondEngine",
    platforms: [.macOS(.v27)],
    dependencies: [
        .package(path: "../Q1-Protocol"),
        .package(
            url: "https://github.com/swift-compositions/swift-postgresql.git",
            branch: "main",
            traits: ["PostgresNIO"]
        ),
    ],
    targets: [
        .target(
            name: "PostgreSQL Lent",
            dependencies: [
                .product(name: "Lent Interface", package: "Q1-Protocol"),
                .product(name: "PostgreSQL", package: "swift-postgresql"),
            ]
        ),
        .executableTarget(name: "Conform", dependencies: ["PostgreSQL Lent"]),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
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
