#if CloudKit
#if canImport(CloudKit)
  import GRDB
  import Foundation
  import os
  import SQL
  import SQL_Macros

  func defaultMetadatabase(
    logger: Logger,
    url: URL,
    configuration: Configuration,
    context: SyncEngine.Context
  ) throws -> any DatabaseWriter {
    logger.debug(
      """
      Metadatabase connection:
      open "\(url.path(percentEncoded: false))"
      """
    )

    guard !url.isInMemory || context != .live
    else {
      struct InMemoryDatabase: Error {}
      throw InMemoryDatabase()
    }

    var metadatabaseConfiguration = Configuration()
    metadatabaseConfiguration.observesSuspensionNotifications = configuration.observesSuspensionNotifications
    let metadatabase: any DatabaseWriter =
      if url.isInMemory {
        try DatabaseQueue(
          path: url.absoluteString,
          configuration: metadatabaseConfiguration
        )
      } else {
        try DatabasePool(
          path: url.path(percentEncoded: false),
          configuration: metadatabaseConfiguration
        )
      }
    try migrate(metadatabase: metadatabase)
    return metadatabase
  }

  func migrate(metadatabase: some DatabaseWriter) throws {
    var migrator = DatabaseMigrator()
    migrator.registerMigration("Create Metadata Tables") { db in
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
    #if DEBUG
      try metadatabase.read { db in
        let hasSchemaChanges = try migrator.hasSchemaChanges(db)
        assert(
          !hasSchemaChanges,
          """
          A previously run migration has been removed or edited. \
          Metadatabase migrations must not be modified after release.
          """
        )
      }
    #endif
    try migrator.migrate(metadatabase)
  }
#endif

#endif
