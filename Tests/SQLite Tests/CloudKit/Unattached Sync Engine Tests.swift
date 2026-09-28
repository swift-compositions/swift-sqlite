#if CloudKit
    import Foundation
    import GRDB
    import SQLite
    import Testing

    @MainActor
    @Suite struct `Unattached sync engine` {
        @Test func `starts on a database without an attached metadatabase`() async throws {
            let database = try DatabasePool(
                path: "\(NSTemporaryDirectory())\(ProcessInfo.processInfo.globallyUniqueString)"
            )
            _ = try await SyncEngine(
                container: MockCloudContainer(
                    containerIdentifier: "iCloud.org.swift-institute.SQLite.Testing",
                    privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
                    sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
                ),
                userDatabase: UserDatabase(database: database),
                tables: []
            )
        }
    }
#endif
