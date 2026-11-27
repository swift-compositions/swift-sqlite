#if CloudKit && canImport(CloudKit)
    import CloudKit
    import Foundation
    import OSLog
    import SQL
    import SQL_Macros
    import SQLite
    @testable import SQLite_CloudKit
    import Testing

    @Suite(.timeLimit(.minutes(5))) struct `Metadatabase` {
        @Test func `an in-memory database gets a metadatabase of its own in a temporary file`() async throws {
            let url = try URL.metadatabase(databasePath: ":memory:", containerIdentifier: nil)
            let other = try URL.metadatabase(databasePath: ":memory:", containerIdentifier: nil)
            #expect(!url.isInMemory)
            #expect(url != other)

            let metadatabase = try defaultMetadatabase(
                logger: Logger(subsystem: "test", category: "test"),
                url: url,
                context: .test
            )
            let mainDatabaseFile = try await metadatabase.read { db in
                try SQLite.Pragma.Database.List.where { $0.name.eq("main") }.select(\.file).fetch.one(db)
            }
            #expect(mainDatabaseFile?.hasSuffix(url.lastPathComponent) == true)
        }

        /// A metadatabase GRDB made records its migrations in `grdb_migrations`. The driver takes those names over:
        /// no migration runs a second time and the rows stay.
        @Test func `a metadatabase made by GRDB is taken over as it is`() async throws {
            let url = try URL.metadatabase(databasePath: ":memory:", containerIdentifier: nil)
            let metadatabase = try defaultMetadatabase(
                logger: Logger(subsystem: "test", category: "test"),
                url: url,
                context: .test
            )
            try await metadatabase.write { db in
                try migrate(metadatabase: db)
                try #sql(
                    """
                    INSERT INTO "swiftsqlite_icloud_metadata"
                      ("recordPrimaryKey", "recordType", "zoneName", "ownerName", "userModificationTime")
                    VALUES ('1', 'reminders', 'zone', 'owner', 0)
                    """
                )
                .execute(db)
                // The shape GRDB's migrator leaves: its own table of names, and none of the driver's.
                try #sql(#"CREATE TABLE "grdb_migrations" ("identifier" TEXT NOT NULL PRIMARY KEY)"#).execute(db)
                // The one migration the GRDB version registered, by the name it recorded.
                try #sql(#"INSERT INTO "grdb_migrations" VALUES ('Create Metadata Tables')"#).execute(db)
                try #sql(#"DROP TABLE "_sql_migrations""#).execute(db)
            }

            let counts = try await metadatabase.write { db in
                try migrate(metadatabase: db)
                return [
                    try #sql(#"SELECT count(*) FROM "swiftsqlite_icloud_metadata""#, as: Int.self).fetch.one(db),
                    try #sql(#"SELECT count(*) FROM "grdb_migrations""#, as: Int.self).fetch.one(db),
                    try #sql(#"SELECT count(*) FROM "_sql_migrations""#, as: Int.self).fetch.one(db),
                ]
            }
            #expect(counts[0] == 1)
            #expect(counts[1] == 1)
            #expect(counts[2] == 1)
        }
    }
#endif
