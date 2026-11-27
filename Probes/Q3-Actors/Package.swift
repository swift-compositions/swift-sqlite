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
        .package(url: "https://github.com/swift-compositions/swift-threads.git", branch: "main"),
        // `Thread Actor` does not re-export `Kernel.Thread.Executor`, which its initializer takes.
        .package(url: "https://github.com/swift-compositions/swift-executors.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "SQLite Actors",
            dependencies: [
                .product(name: "Lent Interface", package: "Q1-Protocol"),
                .product(name: "SQLite Handle", package: "Q2-Handle"),
                .product(name: "Thread Actor", package: "swift-threads"),
                .product(name: "Executors", package: "swift-executors"),
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
