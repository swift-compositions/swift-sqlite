#if CloudKit && canImport(CloudKit)
    import Cardinal
    import CloudKit
    import Foundation
    import SQL
    import SQL_Macros
    import SQLite
    import SQLite_CloudKit
    import Testing
    import Tests_Inline_Snapshot

    extension CloudKitTestBase {
        @MainActor
        final class `Record types`: CloudKitTestBase, @unchecked Sendable {
            @Test func `setting up records the schema of every synchronized table`() async throws {
                let recordTypes = try await syncEngine.metadatabase.read { db in
                    try RecordType.all.fetch.all(db)
                }
                await snapshot(as: .state) {
                    recordTypes
                } matches: {
                    #"""
                    [
                      [0]: RecordType(
                        tableName: "remindersLists",
                        schema: "CREATE TABLE \"remindersLists\" (\n  \"id\" INT PRIMARY KEY NOT NULL,\n  \"title\" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT \'\'\n) STRICT",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "id",
                            isNotNull: true,
                            type: "INT"
                          ),
                          [1]: TableInfo(
                            defaultValue: "\'\'",
                            isPrimaryKey: false,
                            name: "title",
                            isNotNull: true,
                            type: "TEXT"
                          )
                        ]
                      ),
                      [1]: RecordType(
                        tableName: "remindersListAssets",
                        schema: "CREATE TABLE \"remindersListAssets\" (\n  \"remindersListID\" INTEGER NOT NULL PRIMARY KEY\n    REFERENCES \"remindersLists\"(\"id\") ON DELETE CASCADE,\n  \"coverImage\" BLOB NOT NULL\n) STRICT",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: false,
                            name: "coverImage",
                            isNotNull: true,
                            type: "BLOB"
                          ),
                          [1]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "remindersListID",
                            isNotNull: true,
                            type: "INTEGER"
                          )
                        ]
                      ),
                      [2]: RecordType(
                        tableName: "remindersListPrivates",
                        schema: "CREATE TABLE \"remindersListPrivates\" (\n  \"remindersListID\" INTEGER PRIMARY KEY NOT NULL REFERENCES \"remindersLists\"(\"id\") \n    ON DELETE CASCADE,\n  \"position\" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0\n) STRICT",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: "0",
                            isPrimaryKey: false,
                            name: "position",
                            isNotNull: true,
                            type: "INTEGER"
                          ),
                          [1]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "remindersListID",
                            isNotNull: true,
                            type: "INTEGER"
                          )
                        ]
                      ),
                      [3]: RecordType(
                        tableName: "reminders",
                        schema: "CREATE TABLE \"reminders\" (\n  \"id\" INT PRIMARY KEY NOT NULL,\n  \"dueDate\" TEXT,\n  \"isCompleted\" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,\n  \"priority\" INTEGER,\n  \"title\" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT \'\',\n  \"remindersListID\" INTEGER NOT NULL,\n  \n  FOREIGN KEY(\"remindersListID\") REFERENCES \"remindersLists\"(\"id\") ON DELETE CASCADE ON UPDATE CASCADE\n) STRICT",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: false,
                            name: "dueDate",
                            isNotNull: false,
                            type: "TEXT"
                          ),
                          [1]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "id",
                            isNotNull: true,
                            type: "INT"
                          ),
                          [2]: TableInfo(
                            defaultValue: "0",
                            isPrimaryKey: false,
                            name: "isCompleted",
                            isNotNull: true,
                            type: "INTEGER"
                          ),
                          [3]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: false,
                            name: "priority",
                            isNotNull: false,
                            type: "INTEGER"
                          ),
                          [4]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: false,
                            name: "remindersListID",
                            isNotNull: true,
                            type: "INTEGER"
                          ),
                          [5]: TableInfo(
                            defaultValue: "\'\'",
                            isPrimaryKey: false,
                            name: "title",
                            isNotNull: true,
                            type: "TEXT"
                          )
                        ]
                      ),
                      [4]: RecordType(
                        tableName: "tags",
                        schema: "CREATE TABLE \"tags\" (\n  \"title\" TEXT PRIMARY KEY NOT NULL COLLATE NOCASE \n) STRICT",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "title",
                            isNotNull: true,
                            type: "TEXT"
                          )
                        ]
                      ),
                      [5]: RecordType(
                        tableName: "reminderTags",
                        schema: "CREATE TABLE \"reminderTags\" (\n  \"id\" INT PRIMARY KEY NOT NULL,\n  \"reminderID\" INTEGER NOT NULL REFERENCES \"reminders\"(\"id\") ON DELETE CASCADE,\n  \"tagID\" TEXT NOT NULL REFERENCES \"tags\"(\"title\") ON DELETE CASCADE ON UPDATE CASCADE\n) STRICT",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "id",
                            isNotNull: true,
                            type: "INT"
                          ),
                          [1]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: false,
                            name: "reminderID",
                            isNotNull: true,
                            type: "INTEGER"
                          ),
                          [2]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: false,
                            name: "tagID",
                            isNotNull: true,
                            type: "TEXT"
                          )
                        ]
                      ),
                      [6]: RecordType(
                        tableName: "parents",
                        schema: "CREATE TABLE \"parents\"(\n  \"id\" INT PRIMARY KEY NOT NULL\n) STRICT",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "id",
                            isNotNull: true,
                            type: "INT"
                          )
                        ]
                      ),
                      [7]: RecordType(
                        tableName: "childWithOnDeleteSetNulls",
                        schema: "CREATE TABLE \"childWithOnDeleteSetNulls\"(\n  \"id\" INT PRIMARY KEY NOT NULL,\n  \"parentID\" INTEGER REFERENCES \"parents\"(\"id\") ON DELETE SET NULL ON UPDATE SET NULL\n) STRICT",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "id",
                            isNotNull: true,
                            type: "INT"
                          ),
                          [1]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: false,
                            name: "parentID",
                            isNotNull: false,
                            type: "INTEGER"
                          )
                        ]
                      ),
                      [8]: RecordType(
                        tableName: "childWithOnDeleteSetDefaults",
                        schema: "CREATE TABLE \"childWithOnDeleteSetDefaults\"(\n  \"id\" INT PRIMARY KEY NOT NULL,\n  \"parentID\" INTEGER NOT NULL DEFAULT 0 \n    REFERENCES \"parents\"(\"id\") ON DELETE SET DEFAULT ON UPDATE SET DEFAULT\n) STRICT",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "id",
                            isNotNull: true,
                            type: "INT"
                          ),
                          [1]: TableInfo(
                            defaultValue: "0",
                            isPrimaryKey: false,
                            name: "parentID",
                            isNotNull: true,
                            type: "INTEGER"
                          )
                        ]
                      ),
                      [9]: RecordType(
                        tableName: "modelAs",
                        schema: "CREATE TABLE \"modelAs\" (\n  \"id\" INT PRIMARY KEY NOT NULL,\n  \"count\" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,\n  \"isEven\" INTEGER GENERATED ALWAYS AS (\"count\" % 2 == 0) VIRTUAL \n)",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: "0",
                            isPrimaryKey: false,
                            name: "count",
                            isNotNull: true,
                            type: "INTEGER"
                          ),
                          [1]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "id",
                            isNotNull: true,
                            type: "INT"
                          )
                        ]
                      ),
                      [10]: RecordType(
                        tableName: "modelBs",
                        schema: "CREATE TABLE \"modelBs\" (\n  \"id\" INT PRIMARY KEY NOT NULL,\n  \"isOn\" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,\n  \"modelAID\" INTEGER NOT NULL REFERENCES \"modelAs\"(\"id\") ON DELETE CASCADE\n)",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "id",
                            isNotNull: true,
                            type: "INT"
                          ),
                          [1]: TableInfo(
                            defaultValue: "0",
                            isPrimaryKey: false,
                            name: "isOn",
                            isNotNull: true,
                            type: "INTEGER"
                          ),
                          [2]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: false,
                            name: "modelAID",
                            isNotNull: true,
                            type: "INTEGER"
                          )
                        ]
                      ),
                      [11]: RecordType(
                        tableName: "modelCs",
                        schema: "CREATE TABLE \"modelCs\" (\n  \"id\" INT PRIMARY KEY NOT NULL,\n  \"title\" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT \'\',\n  \"modelBID\" INTEGER NOT NULL REFERENCES \"modelBs\"(\"id\") ON DELETE CASCADE\n)",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "id",
                            isNotNull: true,
                            type: "INT"
                          ),
                          [1]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: false,
                            name: "modelBID",
                            isNotNull: true,
                            type: "INTEGER"
                          ),
                          [2]: TableInfo(
                            defaultValue: "\'\'",
                            isPrimaryKey: false,
                            name: "title",
                            isNotNull: true,
                            type: "TEXT"
                          )
                        ]
                      ),
                      [12]: RecordType(
                        tableName: "scopedModels",
                        schema: "CREATE TABLE \"scopedModels\" (\n  \"id\" INT PRIMARY KEY NOT NULL,\n  \"title\" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT \'\',\n  \"isDeleted\" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0\n) STRICT",
                        tableInfo: [
                          [0]: TableInfo(
                            defaultValue: nil,
                            isPrimaryKey: true,
                            name: "id",
                            isNotNull: true,
                            type: "INT"
                          ),
                          [1]: TableInfo(
                            defaultValue: "0",
                            isPrimaryKey: false,
                            name: "isDeleted",
                            isNotNull: true,
                            type: "INTEGER"
                          ),
                          [2]: TableInfo(
                            defaultValue: "\'\'",
                            isPrimaryKey: false,
                            name: "title",
                            isNotNull: true,
                            type: "TEXT"
                          )
                        ]
                      )
                    ]
                    """#
                }
            }

            @Test func `tearing down erases the metadata`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed { RemindersList(id: 1, title: "Personal") }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                try await syncEngine.metadatabase.read { db in
                    try #expect(SyncMetadata.all.fetch.count(db) > 0)
                    try #expect(RecordType.all.fetch.count(db) > 0)
                    try #expect(StateSerialization.all.fetch.count(db) == 0)
                }

                try await syncEngine.tearDownSyncEngine()
                try await syncEngine.metadatabase.read { db in
                    try #expect(SyncMetadata.all.fetch.count(db) == 0)
                    try #expect(RecordType.all.fetch.count(db) == 0)
                    try #expect(StateSerialization.all.fetch.count(db) == 0)
                }
                try await syncEngine.setUpSyncEngine()
            }

            @Test func `setting up again yields the same record types`() async throws {
                let recordTypes = try await syncEngine.metadatabase.read { db in
                    try RecordType.all.fetch.all(db)
                }
                syncEngine.stop()
                try await syncEngine.tearDownSyncEngine()
                try await syncEngine.setUpSyncEngine()
                try await syncEngine.start()
                try await syncEngine.processPendingDatabaseChanges(scope: .private)
                let recordTypesAfterReSetup = try await syncEngine.metadatabase.read { db in
                    try RecordType.all.fetch.all(db)
                }
                #expect(recordTypes == recordTypesAfterReSetup)
            }

            @Test func `a migration updates only the migrated record type`() async throws {
                let recordTypes = try await syncEngine.metadatabase.read { db in
                    try RecordType.order(by: \.tableName).fetch.all(db)
                }
                syncEngine.stop()
                try await syncEngine.tearDownSyncEngine()
                try await userDatabase.userWrite { db in
                    try #sql(
                        """
                        ALTER TABLE "reminders" ADD COLUMN "newFeature" INTEGER NOT NULL 
                        """
                    )
                    .execute(db)
                }
                try await syncEngine.setUpSyncEngine()
                try await syncEngine.start()
                try await syncEngine.processPendingDatabaseChanges(scope: .private)

                let recordTypesAfterMigration = try await syncEngine.metadatabase.read { db in
                    try RecordType.order(by: \.tableName).fetch.all(db)
                }
                let remindersTableIndex = try #require(
                    recordTypesAfterMigration.firstIndex { $0.tableName == Reminder.tableName }
                )
                #expect(
                    recordTypes[0..<remindersTableIndex] == recordTypesAfterMigration[0..<remindersTableIndex]
                )
                #expect(
                    recordTypes[(remindersTableIndex + 1)...]
                        == recordTypesAfterMigration[(remindersTableIndex + 1)...]
                )

                await snapshot(as: .state) {
                    recordTypesAfterMigration[remindersTableIndex]
                } matches: {
                    #"""
                    RecordType(
                      tableName: "reminders",
                      schema: "CREATE TABLE \"reminders\" (\n  \"id\" INT PRIMARY KEY NOT NULL,\n  \"dueDate\" TEXT,\n  \"isCompleted\" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0,\n  \"priority\" INTEGER,\n  \"title\" TEXT NOT NULL ON CONFLICT REPLACE DEFAULT \'\',\n  \"remindersListID\" INTEGER NOT NULL, \"newFeature\" INTEGER NOT NULL,\n  \n  FOREIGN KEY(\"remindersListID\") REFERENCES \"remindersLists\"(\"id\") ON DELETE CASCADE ON UPDATE CASCADE\n) STRICT",
                      tableInfo: [
                        [0]: TableInfo(
                          defaultValue: nil,
                          isPrimaryKey: false,
                          name: "dueDate",
                          isNotNull: false,
                          type: "TEXT"
                        ),
                        [1]: TableInfo(
                          defaultValue: nil,
                          isPrimaryKey: true,
                          name: "id",
                          isNotNull: true,
                          type: "INT"
                        ),
                        [2]: TableInfo(
                          defaultValue: "0",
                          isPrimaryKey: false,
                          name: "isCompleted",
                          isNotNull: true,
                          type: "INTEGER"
                        ),
                        [3]: TableInfo(
                          defaultValue: nil,
                          isPrimaryKey: false,
                          name: "newFeature",
                          isNotNull: true,
                          type: "INTEGER"
                        ),
                        [4]: TableInfo(
                          defaultValue: nil,
                          isPrimaryKey: false,
                          name: "priority",
                          isNotNull: false,
                          type: "INTEGER"
                        ),
                        [5]: TableInfo(
                          defaultValue: nil,
                          isPrimaryKey: false,
                          name: "remindersListID",
                          isNotNull: true,
                          type: "INTEGER"
                        ),
                        [6]: TableInfo(
                          defaultValue: "\'\'",
                          isPrimaryKey: false,
                          name: "title",
                          isNotNull: true,
                          type: "TEXT"
                        )
                      ]
                    )
                    """#
                }
            }

            @Test func `a table added by a migration syncs once it is passed to the sync engine`() async throws {
                let recordTypes = try await syncEngine.metadatabase.read { db in
                    try RecordType.order(by: \.tableName).fetch.all(db)
                }
                syncEngine.stop()
                try await syncEngine.tearDownSyncEngine()

                try await userDatabase.userWrite { db in
                    try #sql(
                        """
                        CREATE TABLE "foos" (
                          "id" INTEGER PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid())
                        ) 
                        """
                    )
                    .execute(db)
                    try Foo
                        .insert { Foo(id: 1) }
                        .execute(db)
                }

                do {
                    let relaunchedSyncEngine = try await SyncEngine(
                        container: container,
                        userDatabase: userDatabase,
                        tables: syncEngine.tables,
                        privateTables: syncEngine.privateTables
                    )
                    let recordTypesAfterMigration = try await syncEngine.metadatabase.read { db in
                        try RecordType.order(by: \.tableName).fetch.all(db)
                    }
                    #expect(recordTypesAfterMigration == recordTypes)
                    relaunchedSyncEngine.stop()
                    try await relaunchedSyncEngine.tearDownSyncEngine()
                    await snapshot(as: .state) {
                        container
                    } matches: {
                        """
                        MockCloudContainer(
                          privateCloudDatabase: MockCloudDatabase(
                            databaseScope: .private,
                            storage: []
                          ),
                          sharedCloudDatabase: MockCloudDatabase(
                            databaseScope: .shared,
                            storage: []
                          )
                        )
                        """
                    }
                }

                do {
                    let relaunchedSyncEngine = try await SyncEngine(
                        container: container,
                        userDatabase: userDatabase,
                        tables: syncEngine.tables + [SynchronizedTable(for: Foo.self)],
                        privateTables: syncEngine.privateTables
                    )
                    try await relaunchedSyncEngine.processPendingRecordZoneChanges(scope: .private)
                    await snapshot(as: .state) {
                        container
                    } matches: {
                        """
                        MockCloudContainer(
                          privateCloudDatabase: MockCloudDatabase(
                            databaseScope: .private,
                            storage: [
                              [0]: CKRecord(
                                recordID: CKRecord.ID(1:foos/zone/__defaultOwner__),
                                recordType: "foos",
                                parent: nil,
                                share: nil,
                                id: 1
                              )
                            ]
                          ),
                          sharedCloudDatabase: MockCloudDatabase(
                            databaseScope: .shared,
                            storage: []
                          )
                        )
                        """
                    }
                }
            }
        }
    }

    @Table("foos")
    private struct Foo {
        let id: Int
    }
#endif
