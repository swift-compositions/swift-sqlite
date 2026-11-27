#if CloudKit && canImport(CloudKit)
    import CloudKit
    import Foundation
    import SQLite
    import Path
    import SQLite_CloudKit
    import Testing

    @MainActor
    @Suite(.timeLimit(.minutes(5))) struct `Unattached sync engine` {
        @Test func `starts on a database without an attached metadatabase`() async throws {
            let database = try SQLite.Database(
                path: try Path::Path(
                    validating: "\(NSTemporaryDirectory())\(ProcessInfo.processInfo.globallyUniqueString)"
                )
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
