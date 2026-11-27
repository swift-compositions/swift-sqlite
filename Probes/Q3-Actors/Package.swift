// swift-tools-version: 6.4

// Question 3 of swift-sqlite#24: the writer as an actor on a dedicated thread (`Kernel.Thread.Actor` and
// `Kernel.Thread.Executor`, swift-threads and swift-executors) and each reader another. Can the nonsending `write`
// hop to the writer, run the `sending` body there with a non-Sendable capture, and return a non-Sendable result?

import PackageDescription

let package = Package(
    name: "Q3-Actors",
    platforms: [.macOS(.v27)],
    dependencies: [
        .package(path: "../Q1-Protocol"),
        .package(path: "../Q2-Handle"),
        // The branch of swift-threads where `Thread Actor` re-exports `Executors` and `Kernel.Thread.Actor.executor`
        // is nonisolated. On swift-threads `main` (b30bc10) this package does not build: a client could not name
        // `Kernel.Thread.Executor`, and could read the actor's executor only with an `await`.
        .package(url: "https://github.com/swift-compositions/swift-threads.git", branch: "probe/lent-connection"),
    ],
    targets: [
        .target(
            name: "SQLite Actors",
            dependencies: [
                .product(name: "Lent Interface", package: "Q1-Protocol"),
                .product(name: "SQLite Handle", package: "Q2-Handle"),
                .product(name: "Thread Actor", package: "swift-threads"),
            ]
        ),
        .executableTarget(name: "Hop", dependencies: ["SQLite Actors"]),
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
