// swift-tools-version: 6.4

// Question 5 of swift-sqlite#24: a sequence whose iterator implements `next(isolation:)` records its listener's
// isolation. After a commit, `write` resumes the waiter and then awaits a job enqueued on that isolation. Is the
// listener's body always run before that job?
//
//   swift run -c release Table 20000        the table of every configuration
//   swift test -c release                   the same as tests that fail when the order breaks

import PackageDescription

let package = Package(
    name: "Q5-Followed",
    platforms: [.macOS(.v27)],
    dependencies: [
        .package(url: "https://github.com/swift-compositions/swift-executors.git", branch: "main")
    ],
    targets: [
        .target(name: "Followed", dependencies: [.product(name: "Executors", package: "swift-executors")]),
        .executableTarget(name: "Table", dependencies: ["Followed"]),
        .executableTarget(name: "Mechanism"),
        .testTarget(name: "Followed Tests", dependencies: ["Followed"]),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    target.swiftSettings = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .treatAllWarnings(as: .error),
    ]
}
