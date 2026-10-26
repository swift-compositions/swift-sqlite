#if GRDB
    import Foundation
    import GRDB
    import ISO_9075_Call_Level_Interface
    import SQL_Migrations
    import SQLite
    import Testing

    /// Migration DDL must invalidate the driver's per-connection schema metadata. A typed fetch alone cannot
    /// reveal this bug: SQLite reparses statements while GRDB can still return cached column metadata.
    @Suite struct `A connection's schema cache` {
        @Suite struct Integration {}
    }

    extension `A connection's schema cache`.Integration {
        private static func migrator() -> Migrator<SQLite.Database> {
            var migrator = Migrator<SQLite.Database>()
            migrator.register("Create items") { connection throws(ISO_9075.Error) in
                // Migration schema uses a fragment rather than today's table model.
                _ = try connection.execute(#"CREATE TABLE "items" ("id" INTEGER PRIMARY KEY)"#)
            }
            return migrator
        }

        private static func columns(_ database: SQLite.Database) throws -> [String] {
            try database.read { connection in try connection.database.columns(in: "items").map(\.name) }
        }

        private func verify(_ database: SQLite.Database) async throws {
            var migrator = Self.migrator()
            try await migrator.migrate(database)
            #expect(try Self.columns(database) == ["id"])
            migrator.register("Add a note") { connection throws(ISO_9075.Error) in
                // Migration schema uses a fragment rather than today's table model.
                _ = try connection.execute(#"ALTER TABLE "items" ADD COLUMN "note" TEXT"#)
            }
            try await migrator.migrate(database)
            #expect(try Self.columns(database) == ["id", "note"])
        }

        @Test func queue() async throws {
            try await verify(try SQLite.Database())
        }

        @Test func pool() async throws {
            let directory = URL.temporaryDirectory
                .appending(path: ProcessInfo.processInfo.globallyUniqueString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: directory) }
            var configuration = SQLite.Configuration()
            configuration.maximumReaderCount = 1
            try await verify(
                try SQLite.Database(
                    path: directory.appending(path: "schema.sqlite").path(percentEncoded: false),
                    kind: .pool,
                    configuration: configuration
                )
            )
        }
    }
#endif
