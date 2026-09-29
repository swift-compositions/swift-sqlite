#if CloudKit
    import CloudKit
    import Foundation
    import GRDB
    import OSLog
    @testable import SQLite
    import Testing

    @Suite struct `Metadatabase` {
        @Test func `an in-memory database gets an in-memory metadatabase`() throws {
            let url = try URL.metadatabase(databasePath: ":memory:", containerIdentifier: nil)
            #expect(url.isInMemory)

            let metadatabase = try defaultMetadatabase(
                logger: Logger(subsystem: "test", category: "test"),
                url: url,
                configuration: Configuration(),
                context: .test
            )
            let mainDatabaseFile = try metadatabase.read { db in
                try String.fetchOne(db, sql: "SELECT file FROM pragma_database_list WHERE name = 'main'")
            }
            #expect(mainDatabaseFile == "")
        }
    }
#endif
