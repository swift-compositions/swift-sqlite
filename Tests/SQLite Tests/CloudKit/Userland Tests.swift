#if CloudKit
    import CloudKit
    import Foundation
    import GRDB
    import SQL
    import SQLite
    import Testing

    @MainActor
    @Suite struct `Userland synchronization` {
        @Test func `a fetch observes rows written to a synchronized database`() throws {
            let database = try cloudKitTestDatabase(
                containerIdentifier: "tests",
                attachMetadatabase: false
            )
            let syncEngine = try SyncEngine(
                for: database,
                tables: ModelA.self,
                ModelB.self,
                ModelC.self,
                containerIdentifier: "tests",
                context: .test,
                now: { Date(timeIntervalSince1970: 1) }
            )

            try withExtendedLifetime(syncEngine) {
                try database.write { db in
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
