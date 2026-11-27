#if CloudKit
    #if canImport(CloudKit)
        import SQLite
        import Foundation
        import ISO_9075_Call_Level_Interface
        import Path
        import SQL_Migrations
        import os
        import SQL
        import SQL_Macros

        func defaultMetadatabase(
            logger: Logger,
            url: URL,
            context: SyncEngine.Context
        ) throws -> UserDatabase {
            logger.debug(
                """
                Metadatabase connection:
                open "\(url.path(percentEncoded: false))"
                """
            )
            let database = try SQLite.Database(path: try Path::Path(validating: url.path(percentEncoded: false)))
            return UserDatabase(database: database)
        }

        /// GRDB's record of the migrations it ran, in a metadatabase made before the driver.
        private let legacyBookkeeping = "grdb_migrations"

        /// Brings the metadatabase's tables up to date, in the caller's transaction.
        ///
        /// A metadatabase made before the driver recorded its migrations in GRDB's table. Those names are taken over
        /// first, so that a migration that ran there does not run again.
        func migrate(metadatabase connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) {
            var migrator = Migrator<SQLite.Database>()
            // With no migration registered yet, this makes the bookkeeping table and nothing else.
            try migrator.migrate(in: connection)
            let legacy: [Bool] = try connection.fetchAll(
                "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = \(.text(legacyBookkeeping))"
            ) { _ throws(ISO.`9075`.Error) in true }
            if !legacy.isEmpty {
                let applied = try migrator.applied(in: connection)
                let names = try connection.fetchAll("SELECT \(quote: "identifier") FROM \(quote: legacyBookkeeping)") {
                    row throws(ISO.`9075`.Error) -> String in
                    guard case .text(let name) = try row.value(at: 0) else { throw .decoding("a migration name") }
                    return name
                }
                for name in names where !applied.contains(name) {
                    try migrator.record(name, in: connection)
                }
            }
            migrator.register("Create Metadata Tables") { db throws(ISO.`9075`.Error) in
                try #sql(
                    """
                    CREATE TABLE "\(raw: .sqliteCloudKitSchemaName)_metadata" (
                      "recordPrimaryKey" TEXT NOT NULL,
                      "recordType" TEXT NOT NULL,
                      "recordName" TEXT NOT NULL AS ("recordPrimaryKey" || ':' || "recordType"),
                      "zoneName" TEXT NOT NULL,
                      "ownerName" TEXT NOT NULL,
                      "parentRecordPrimaryKey" TEXT,
                      "parentRecordType" TEXT,
                      "parentRecordName" TEXT AS ("parentRecordPrimaryKey" || ':' || "parentRecordType"),
                      "lastKnownServerRecord" BLOB,
                      "_lastKnownServerRecordAllFields" BLOB,
                      "share" BLOB,
                      "hasLastKnownServerRecord" INTEGER NOT NULL AS ("lastKnownServerRecord" IS NOT NULL),
                      "isShared" INTEGER NOT NULL AS ("share" IS NOT NULL),
                      "userModificationTime" INTEGER NOT NULL DEFAULT ("swiftsqlite_icloud_currentTime"()),
                      "_isDeleted" INTEGER NOT NULL DEFAULT 0,

                      PRIMARY KEY ("recordPrimaryKey", "recordType"),
                      UNIQUE ("recordName")
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE INDEX "\(raw: .sqliteCloudKitSchemaName)_metadata_zoneID"
                    ON "\(raw: .sqliteCloudKitSchemaName)_metadata"("ownerName", "zoneName")
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE INDEX "\(raw: .sqliteCloudKitSchemaName)_metadata_parentRecordName"
                    ON "\(raw: .sqliteCloudKitSchemaName)_metadata"("parentRecordName")
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE INDEX "\(raw: .sqliteCloudKitSchemaName)_metadata_isShared"
                    ON "\(raw: .sqliteCloudKitSchemaName)_metadata"("isShared")
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE INDEX IF NOT EXISTS "\(raw: .sqliteCloudKitSchemaName)_metadata_hasLastKnownServerRecord"
                    ON "\(raw: .sqliteCloudKitSchemaName)_metadata"("hasLastKnownServerRecord")
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "\(raw: .sqliteCloudKitSchemaName)_recordTypes" (
                      "tableName" TEXT NOT NULL PRIMARY KEY,
                      "schema" TEXT NOT NULL,
                      "tableInfo" TEXT NOT NULL
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "\(raw: .sqliteCloudKitSchemaName)_stateSerialization" (
                      "scope" TEXT NOT NULL PRIMARY KEY,
                      "data" TEXT NOT NULL
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "\(raw: .sqliteCloudKitSchemaName)_unsyncedRecordIDs" (
                      "recordName" TEXT NOT NULL,
                      "zoneName" TEXT NOT NULL,
                      "ownerName" TEXT NOT NULL,
                      PRIMARY KEY ("recordName", "zoneName", "ownerName")
                    ) STRICT
                    """
                )
                .execute(db)
                try #sql(
                    """
                    CREATE TABLE "\(raw: .sqliteCloudKitSchemaName)_pendingRecordZoneChanges" (
                      "pendingRecordZoneChange" BLOB NOT NULL
                    ) STRICT
                    """
                )
                .execute(db)
            }
            try migrator.migrate(in: connection)
        }
    #endif

#endif
