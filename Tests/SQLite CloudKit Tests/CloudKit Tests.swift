#if CloudKit && canImport(CloudKit)
    import CloudKit
    import SQL
    import SQL_Macros
    import SQLite
    import SQLite_CloudKit
    import SQLite_Test_Support
    import Testing
    import Tests_Inline_Snapshot

    extension CloudKitTestBase {
        @MainActor
        final class `CloudKit synchronization`: CloudKitTestBase, @unchecked Sendable {
            @Test func `set up records the record types`() throws {
                let zones = try syncEngine.metadatabase.read { db in
                    try RecordType.all.fetch.all(db)
                }
                snapshot(as: .state) {
                    zones
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

            @Test func `tears down and sets up again`() async throws {
                try await syncEngine.tearDownSyncEngine()
                try await syncEngine.setUpSyncEngine()
                try await syncEngine.start()

                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                await snapshot(as: .rows(in: syncEngine.metadatabase.database, drawing: State.draw)) {
                    SyncMetadata.select(\.recordName)
                } matches: {
                    """
                    ┌────────────────────┐
                    │ "1:remindersLists" │
                    └────────────────────┘
                    """
                }
                await snapshot(as: .state) {
                    container
                } matches: {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            title: "Personal"
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

            @Test func `adds and removes database functions`() async throws {
                let query = #sql(
                    """
                    SELECT name
                    FROM pragma_function_list
                    WHERE name LIKE \(bind: String.sqliteCloudKitSchemaName + "_%")
                    ORDER BY name
                    """,
                    as: String.self
                )
                let snapshotValue1 = try await userDatabase.write { try query.fetch.all($0) }
                await snapshot(as: .state) {
                    snapshotValue1
                } matches: {
                    """
                    [
                      [0]: "swiftsqlite_icloud_currentownername",
                      [1]: "swiftsqlite_icloud_currenttime",
                      [2]: "swiftsqlite_icloud_currentzonename",
                      [3]: "swiftsqlite_icloud_diddelete",
                      [4]: "swiftsqlite_icloud_didupdate",
                      [5]: "swiftsqlite_icloud_haspermission",
                      [6]: "swiftsqlite_icloud_syncengineissynchronizingchanges"
                    ]
                    """
                }
                try await syncEngine.tearDownSyncEngine()

                let snapshotValue2 = try { try userDatabase.read { try query.fetch.all($0) } }()
                await snapshot(as: .state) {
                    snapshotValue2
                } matches: {
                    """
                    []
                    """
                }

                try await syncEngine.setUpSyncEngine()
            }

            @Test func `inserts, updates and deletes`() async throws {
                try await userDatabase.userWrite { db in
                    try RemindersList
                        .insert { RemindersList(id: 1, title: "Personal") }
                        .execute(db)
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                await snapshot(as: .state) {
                    container
                } matches: {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            title: "Personal"
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

                try await withTime(advancedBy: 60) {
                    try await userDatabase.userWrite { db in
                        try RemindersList
                            .find(1)
                            .update { $0.title = "Work" }
                            .execute(db)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                await snapshot(as: .state) {
                    container
                } matches: {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            title: "Work"
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

                try await userDatabase.userWrite { db in
                    try RemindersList
                        .find(1)
                        .delete()
                        .execute(db)
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
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

            @Test func `remote server record update`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 60) {
                    let record = try syncEngine.private.database.record(for: RemindersList.recordID(for: 1))
                    record.setValue("Work", forKey: "title", at: now)
                    try await syncEngine.modifyRecords(scope: .private, saving: [record]).notify()
                }

                await snapshot(as: .rows(in: userDatabase.sqliteDatabase, drawing: State.draw)) {
                    RemindersList.all
                } matches: {
                    """
                    ┌─────────────────┐
                    │ RemindersList(  │
                    │   id: 1,        │
                    │   title: "Work" │
                    │ )               │
                    └─────────────────┘
                    """
                }
                await snapshot(as: .rows(in: syncEngine.metadatabase.database, drawing: State.draw)) {
                    SyncMetadata.select(\.userModificationTime)
                } matches: {
                    """
                    ┌─────────────┐
                    │ 60000000000 │
                    └─────────────┘
                    """
                }
                await snapshot(as: .state) {
                    container
                } matches: {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            title: "Work"
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

            /// An append-only table guarded by a trigger that lets the sync engine
            /// through: a remote edit of an existing row, from a freshly fetched
            /// server record, is applied, while a local edit is still refused.
            @Test func `remote edit of an existing row passes a sync-aware append-only trigger`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                    try db.execute(
                        sql: """
                            CREATE TEMP TRIGGER "appendOnlyRemindersLists" BEFORE UPDATE ON "remindersLists"
                            WHEN NOT "swiftsqlite_icloud_syncEngineIsSynchronizingChanges"()
                              AND (NEW."title" IS NOT OLD."title")
                            BEGIN SELECT RAISE(ABORT, 'append-only'); END
                            """
                    )
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 60) {
                    let record = try syncEngine.private.database.record(for: RemindersList.recordID(for: 1))
                    record.setValue("Work", forKey: "title", at: now)
                    try await syncEngine.modifyRecords(scope: .private, saving: [record]).notify()
                }

                #expect(
                    try await userDatabase.read { db in try RemindersList.find(1).fetch.one(db)?.title } == "Work"
                )
                await #expect(throws: (any Swift.Error).self) {
                    try await userDatabase.userWrite { db in
                        try RemindersList.find(1).update { $0.title = "Local" }.execute(db)
                    }
                }
            }

            @Test func `remote server sends a record with no changes`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 1) {
                    try await userDatabase.userWrite { db in
                        try RemindersList.find(1).update { $0.title = "My stuff" }.execute(db)
                    }
                }

                let record = try syncEngine.private.database.record(for: RemindersList.recordID(for: 1))
                try await syncEngine.modifyRecords(scope: .private, saving: [record]).notify()
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                await snapshot(as: .state) {
                    container
                } matches: {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            title: "My stuff"
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

            @Test func `remote server record update with an old record`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let record = try syncEngine.private.database.record(for: RemindersList.recordID(for: 1))
                record.setValue("Work", forKey: "title", at: now)
                record._recordChangeTag = .random(in: 9999 ... .max)
                try await syncEngine.modifyRecords(scope: .private, saving: [record]).notify()

                await snapshot(as: .rows(in: userDatabase.sqliteDatabase, drawing: State.draw)) {
                    Reminder.all
                } matches: {
                    """
                    (No results)
                    """
                }
                await snapshot(as: .rows(in: syncEngine.metadatabase.database, drawing: State.draw)) {
                    SyncMetadata.select(\.userModificationTime)
                } matches: {
                    """
                    ┌───┐
                    │ 0 │
                    └───┘
                    """
                }
                await snapshot(as: .state) {
                    container
                } matches: {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            title: "Personal"
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

            @Test func `remote server record deleted`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await syncEngine.modifyRecords(
                    scope: .private,
                    deleting: [RemindersList.recordID(for: 1)]
                )
                .notify()

                await snapshot(as: .rows(in: userDatabase.sqliteDatabase, drawing: State.draw)) {
                    RemindersList.all
                } matches: {
                    """
                    (No results)
                    """
                }
                await snapshot(as: .rows(in: syncEngine.metadatabase.database, drawing: State.draw)) {
                    SyncMetadata.all
                } matches: {
                    """
                    (No results)
                    """
                }
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

            @Test func `cascading deletion order`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        Tag(title: "fun")
                        Tag(title: "weekend")
                    }
                }
                for _ in 1...100 {
                    try await userDatabase.userWrite { db in
                        try db.seed {
                            RemindersList(id: 1, title: "Personal")
                            RemindersListPrivate(remindersListID: 1, position: 1)
                            Reminder(id: 1, title: "", remindersListID: 1)
                            Reminder(id: 2, title: "", remindersListID: 1)
                            Reminder(id: 3, title: "", remindersListID: 1)
                            Reminder(id: 4, title: "", remindersListID: 1)
                            ReminderTag(id: 1, reminderID: 1, tagID: "fun")
                            ReminderTag(id: 2, reminderID: 2, tagID: "fun")
                            ReminderTag(id: 3, reminderID: 3, tagID: "fun")
                            ReminderTag(id: 4, reminderID: 4, tagID: "fun")
                            ReminderTag(id: 5, reminderID: 1, tagID: "weekend")
                            ReminderTag(id: 6, reminderID: 2, tagID: "weekend")
                            ReminderTag(id: 7, reminderID: 3, tagID: "weekend")
                            ReminderTag(id: 8, reminderID: 4, tagID: "weekend")
                        }
                    }

                    try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                    try await userDatabase.userWrite { db in
                        try RemindersList.find(1).delete().execute(db)
                    }

                    try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                    await snapshot(as: .state) {
                        container
                    } matches: {
                        """
                        MockCloudContainer(
                          privateCloudDatabase: MockCloudDatabase(
                            databaseScope: .private,
                            storage: [
                              [0]: CKRecord(
                                recordID: CKRecord.ID(fun:tags/zone/__defaultOwner__),
                                recordType: "tags",
                                parent: nil,
                                share: nil,
                                title: "fun"
                              ),
                              [1]: CKRecord(
                                recordID: CKRecord.ID(weekend:tags/zone/__defaultOwner__),
                                recordType: "tags",
                                parent: nil,
                                share: nil,
                                title: "weekend"
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

            @Test func `sends changes`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.sendChanges(CKSyncEngine.SendChangesOptions())
            }

            @Test func `generated columns`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        ModelA(id: 1, count: 42, isEven: true)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                await snapshot(as: .state) {
                    container
                } matches: {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:modelAs/zone/__defaultOwner__),
                            recordType: "modelAs",
                            parent: nil,
                            share: nil,
                            count: 42,
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

                let record = try syncEngine.private.database.record(for: ModelA.recordID(for: 1))
                record.setValue(false, forKey: "isEven", at: 0)
                try await syncEngine.modifyRecords(scope: .private, saving: [record]).notify()

                await snapshot(as: .state) {
                    container
                } matches: {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:modelAs/zone/__defaultOwner__),
                            recordType: "modelAs",
                            parent: nil,
                            share: nil,
                            count: 42,
                            id: 1,
                            isEven: 0
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

                try await userDatabase.read { db in
                    let modelA = try #require(try ModelA.find(1).fetch.one(db))
                    #expect(modelA.isEven == true)
                }
            }
        }
    }
#endif
