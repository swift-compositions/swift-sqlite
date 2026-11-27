#if CloudKit && canImport(CloudKit)
    import CloudKit
    import Foundation
    import SQL
    import SQLite
    import SQLite_CloudKit
    import Testing

    @MainActor
    @Suite(.timeLimit(.minutes(5))) struct `Userland synchronization` {
        @Test func `a fetch observes rows written to a synchronized database`() async throws {
            let database = try await cloudKitTestDatabase(
                containerIdentifier: "tests",
                attachMetadatabase: false
            )
            let syncEngine = try await SyncEngine(
                for: database,
                tables: ModelA.self,
                ModelB.self,
                ModelC.self,
                containerIdentifier: "tests",
                context: .test,
                now: { Date(timeIntervalSince1970: 1) }
            )

            do {
                defer { withExtendedLifetime(syncEngine) {} }
                try await database.write { db in
                    try db.seed {
                        ModelA.Draft(id: 1)
                    }
                }
                @FetchAll(database: database) var modelAs: [ModelA]
                #expect(modelAs == [ModelA(id: 1, isEven: true)])
            }
        }
    }
#endif
