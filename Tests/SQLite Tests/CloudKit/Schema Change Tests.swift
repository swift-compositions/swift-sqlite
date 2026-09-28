#if CloudKit
    import Byte
    import CloudKit
    import Foundation
    import InlineSnapshotTesting
    import SQL
    import SQL_Macros
    import SQLite
    import SQLite_Test_Support
    import Synchronization
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Schema changes`: CloudKitTestBase, @unchecked Sendable {
            @Test func `adds a column to reminders and reminders lists`() async throws {
                let personalList = RemindersList(id: 1, title: "Personal")
                let businessList = RemindersList(id: 2, title: "Business")
                let reminder = Reminder(id: 1, title: "Get milk", remindersListID: 1)
                try await userDatabase.userWrite { db in
                    try db.seed {
                        personalList
                        businessList
                        reminder
                    }
                }

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 60) {
                    let personalListRecord = try syncEngine.private.database.record(
                        for: RemindersList.recordID(for: 1)
                    )
                    personalListRecord.setValue(1, forKey: "position", at: now)

                    let businessListRecord = try syncEngine.private.database.record(
                        for: RemindersList.recordID(for: 2)
                    )
                    businessListRecord.setValue(2, forKey: "position", at: now)

                    let reminderRecord = try syncEngine.private.database.record(
                        for: Reminder.recordID(for: 1)
                    )
                    reminderRecord.setValue(3, forKey: "position", at: now)

                    try await syncEngine.modifyRecords(
                        scope: .private,
                        saving: [personalListRecord, businessListRecord, reminderRecord]
                    )
                    .notify()

                    try await userDatabase.userWrite { db in
                        try #sql(
                            """
                            ALTER TABLE "remindersLists" 
                            ADD COLUMN "position" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
                            """
                        )
                        .execute(db)
                        try #sql(
                            """
                            ALTER TABLE "reminders" 
                            ADD COLUMN "position" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
                            """
                        )
                        .execute(db)
                    }

                    let relaunchedSyncEngine = try await relaunchSyncEngine(
                        tables: syncEngine.tables
                            .filter { $0.base != Reminder.self && $0.base != RemindersList.self }
                            + [
                                SynchronizedTable(for: ReminderWithPosition.self),
                                SynchronizedTable(for: RemindersListWithPosition.self),
                            ]
                    )
                    defer { _ = relaunchedSyncEngine }

                    let remindersLists = try await userDatabase.read { db in
                        try RemindersListWithPosition.order(by: \.id).fetchAll(db)
                    }
                    let reminders = try await userDatabase.read { db in
                        try ReminderWithPosition.order(by: \.id).fetchAll(db)
                    }

                    #expect(
                        remindersLists == [
                            RemindersListWithPosition(id: 1, title: "Personal", position: 1),
                            RemindersListWithPosition(id: 2, title: "Business", position: 2),
                        ]
                    )
                    #expect(
                        reminders == [
                            ReminderWithPosition(
                                id: 1,
                                title: "Get milk",
                                position: 3,
                                remindersListID: 1
                            )
                        ]
                    )
                }
            }

            @Test func `the old schema updates a record from the new schema`() async throws {
                let remindersListRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue(1, forKey: "id", at: now)
                remindersListRecord.setValue("Personal", forKey: "title", at: now)
                remindersListRecord.setValue(42, forKey: "position", at: 0)

                try await syncEngine.modifyRecords(scope: .private, saving: [remindersListRecord]).notify()

                try await userDatabase.userWrite { db in
                    try #expect(RemindersList.fetchCount(db) == 1)
                    try #expect(RemindersList.find(1).fetchOne(db) == RemindersList(id: 1, title: "Personal"))
                    try RemindersList.find(1).update { $0.title = "My Stuff" }.execute(db)
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                assertQuery(SyncMetadata.all, database: syncEngine.metadatabase) {
                    """
                    ┌────────────────────────────────────────────────────────────────────┐
                    │ SyncMetadata(                                                      │
                    │   id: SyncMetadata.ID(                                             │
                    │     recordPrimaryKey: "1",                                         │
                    │     recordType: "remindersLists"                                   │
                    │   ),                                                               │
                    │   zoneName: "zone",                                                │
                    │   ownerName: "__defaultOwner__",                                   │
                    │   recordName: "1:remindersLists",                                  │
                    │   parentRecordID: nil,                                             │
                    │   parentRecordName: nil,                                           │
                    │   lastKnownServerRecord: CKRecord(                                 │
                    │     recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__), │
                    │     recordType: "remindersLists",                                  │
                    │     parent: nil,                                                   │
                    │     share: nil                                                     │
                    │   ),                                                               │
                    │   _lastKnownServerRecordAllFields: CKRecord(                       │
                    │     recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__), │
                    │     recordType: "remindersLists",                                  │
                    │     parent: nil,                                                   │
                    │     share: nil,                                                    │
                    │     id: 1,                                                         │
                    │     position: 42,                                                  │
                    │     title: "My Stuff"                                              │
                    │   ),                                                               │
                    │   share: nil,                                                      │
                    │   _isDeleted: false,                                               │
                    │   _hasLastKnownServerRecord: true,                                 │
                    │   _isShared: false,                                                │
                    │   userModificationTime: 0                                          │
                    │ )                                                                  │
                    └────────────────────────────────────────────────────────────────────┘
                    """
                }
                assertInlineSnapshot(of: syncEngine.container, as: .customDump) {
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
                            position: 42,
                            title: "My Stuff"
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

            @Test func `adding a column syncs old records to the new schema`() async throws {
                let remindersList = RemindersList(id: 1, title: "Personal")
                try await userDatabase.userWrite { db in
                    try db.seed {
                        remindersList
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                syncEngine.stop()

                try await userDatabase.userWrite { db in
                    try #sql(
                        """
                        ALTER TABLE "remindersLists" 
                        ADD COLUMN "position" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 42
                        """
                    )
                    .execute(db)
                }

                _ = try await relaunchSyncEngine(
                    tables: syncEngine.tables
                        .filter { $0.base != Reminder.self && $0.base != RemindersList.self }
                        + [
                            SynchronizedTable(for: ReminderWithPosition.self),
                            SynchronizedTable(for: RemindersListWithPosition.self),
                        ]
                )

                try await userDatabase.read { db in
                    try #expect(
                        RemindersListWithPosition.fetchAll(db) == [
                            RemindersListWithPosition(id: 1, title: "Personal", position: 42)
                        ]
                    )
                }
            }

            @Test func `adding a nullable column syncs old records to the new schema`() async throws {
                let remindersList = RemindersList(id: 1, title: "Personal")
                try await userDatabase.userWrite { db in
                    try db.seed {
                        remindersList
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                syncEngine.stop()

                try await userDatabase.userWrite { db in
                    try #sql(
                        """
                        ALTER TABLE "remindersLists" 
                        ADD COLUMN "color" INTEGER DEFAULT 42
                        """
                    )
                    .execute(db)
                }

                _ = try await relaunchSyncEngine(
                    tables: syncEngine.tables
                        .filter { $0.base != RemindersList.self }
                    + [
                        SynchronizedTable(for: RemindersListWithColor.self),
                    ]
                )

                try await userDatabase.read { db in
                    try #expect(
                        RemindersListWithColor.fetchAll(db) == [
                            RemindersListWithColor(id: 1, title: "Personal", color: 42)
                        ]
                    )
                }
            }

            @Test func `adding a nullable column uses the default when an old device syncs a missing color`() async throws {
                syncEngine.stop()

                try await userDatabase.userWrite { db in
                    try #sql(
                        """
                        ALTER TABLE "remindersLists" 
                        ADD COLUMN "color" INTEGER DEFAULT 42
                        """
                    )
                    .execute(db)
                }

                let relaunchedSyncEngine = try await relaunchSyncEngine(
                    tables: syncEngine.tables
                        .filter { $0.base != RemindersList.self }
                    + [
                        SynchronizedTable(for: RemindersListWithColor.self),
                    ]
                )

                try await withTime(advancedBy: 1) {
                    let remindersListRecord = CKRecord(
                        recordType: RemindersList.tableName,
                        recordID: RemindersList.recordID(for: 1)
                    )
                    remindersListRecord.setValue(1, forKey: "id", at: now)
                    remindersListRecord.setValue("My stuff", forKey: "title", at: now)
                    try await relaunchedSyncEngine
                        .modifyRecords(scope: .private, saving: [remindersListRecord])
                        .notify()

                    try await userDatabase.read { db in
                        try #expect(
                            RemindersListWithColor.fetchAll(db) == [
                                RemindersListWithColor(id: 1, title: "My stuff", color: 42)
                            ]
                        )
                    }
                    assertInlineSnapshot(of: relaunchedSyncEngine.container, as: .customDump) {
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
            }

            @Test func `adding a nullable column keeps null when a new device syncs a null color`() async throws {
                syncEngine.stop()

                try await userDatabase.userWrite { db in
                    try #sql(
                        """
                        ALTER TABLE "remindersLists" 
                        ADD COLUMN "color" INTEGER DEFAULT 42
                        """
                    )
                    .execute(db)
                }

                let relaunchedSyncEngine = try await relaunchSyncEngine(
                    tables: syncEngine.tables
                        .filter { $0.base != RemindersList.self }
                    + [
                        SynchronizedTable(for: RemindersListWithColor.self),
                    ]
                )

                try await withTime(advancedBy: 1) {
                    let remindersListRecord = CKRecord(
                        recordType: RemindersList.tableName,
                        recordID: RemindersList.recordID(for: 1)
                    )
                    remindersListRecord.setValue(1, forKey: "id", at: now)
                    remindersListRecord.setValue("My stuff", forKey: "title", at: now)
                    remindersListRecord.removeValue(forKey: "color", at: now)
                    try await relaunchedSyncEngine
                        .modifyRecords(scope: .private, saving: [remindersListRecord])
                        .notify()

                    try await userDatabase.read { db in
                        try #expect(
                            RemindersListWithColor.fetchAll(db) == [
                                RemindersListWithColor(id: 1, title: "My stuff", color: nil)
                            ]
                        )
                    }
                    assertInlineSnapshot(of: relaunchedSyncEngine.container, as: .customDump) {
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
            }

            @Test func `the new schema updates a record from the old schema`() async throws {
                let remindersList = RemindersList(id: 1, title: "Personal")
                try await userDatabase.userWrite { db in
                    try db.seed { remindersList }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let remindersListRecord = try syncEngine.private.database.record(
                    for: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue("My Stuff", forKey: "title", at: 1_000_000_000)
                remindersListRecord.setValue(42, forKey: "position", at: 1_000_000_000)
                try await syncEngine.modifyRecords(scope: .private, saving: [remindersListRecord]).notify()

                try await userDatabase.read { db in
                    try #expect(RemindersList.find(1).fetchOne(db) == RemindersList(id: 1, title: "My Stuff"))
                }

                assertQuery(SyncMetadata.all, database: syncEngine.metadatabase) {
                    """
                    ┌────────────────────────────────────────────────────────────────────┐
                    │ SyncMetadata(                                                      │
                    │   id: SyncMetadata.ID(                                             │
                    │     recordPrimaryKey: "1",                                         │
                    │     recordType: "remindersLists"                                   │
                    │   ),                                                               │
                    │   zoneName: "zone",                                                │
                    │   ownerName: "__defaultOwner__",                                   │
                    │   recordName: "1:remindersLists",                                  │
                    │   parentRecordID: nil,                                             │
                    │   parentRecordName: nil,                                           │
                    │   lastKnownServerRecord: CKRecord(                                 │
                    │     recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__), │
                    │     recordType: "remindersLists",                                  │
                    │     parent: nil,                                                   │
                    │     share: nil                                                     │
                    │   ),                                                               │
                    │   _lastKnownServerRecordAllFields: CKRecord(                       │
                    │     recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__), │
                    │     recordType: "remindersLists",                                  │
                    │     parent: nil,                                                   │
                    │     share: nil,                                                    │
                    │     id: 1,                                                         │
                    │     position: 42,                                                  │
                    │     title: "My Stuff"                                              │
                    │   ),                                                               │
                    │   share: nil,                                                      │
                    │   _isDeleted: false,                                               │
                    │   _hasLastKnownServerRecord: true,                                 │
                    │   _isShared: false,                                                │
                    │   userModificationTime: 1000000000                                 │
                    │ )                                                                  │
                    └────────────────────────────────────────────────────────────────────┘
                    """
                }
                assertInlineSnapshot(of: syncEngine.container, as: .customDump) {
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
                            position: 42,
                            title: "My Stuff"
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

            @Test func `running with the new schema when the old schema saves a record and the new schema updates it`() async throws {
                syncEngine.stop()
                try syncEngine.tearDownSyncEngine()

                try await userDatabase.userWrite { db in
                    try #sql(
                        """
                        ALTER TABLE "remindersLists"
                        ADD COLUMN "position" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
                        """
                    )
                    .execute(db)
                }
                let newSyncEngine = try await relaunchSyncEngine(
                    tables: syncEngine.tables
                        .filter { $0.base != RemindersList.self }
                        + [
                            SynchronizedTable(for: RemindersListWithPosition.self)
                        ]
                )
                defer { _ = newSyncEngine }

                let remindersListRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue(1, forKey: "id", at: now)
                remindersListRecord.setValue("Personal", forKey: "title", at: now)

                try await newSyncEngine.modifyRecords(scope: .private, saving: [remindersListRecord])
                    .notify()

                try await userDatabase.read { db in
                    try #expect(
                        RemindersListWithPosition.find(1).fetchOne(db)
                            == RemindersListWithPosition(id: 1, title: "Personal", position: 0)
                    )
                }

                assertQuery(SyncMetadata.all, database: syncEngine.metadatabase) {
                    """
                    ┌────────────────────────────────────────────────────────────────────┐
                    │ SyncMetadata(                                                      │
                    │   id: SyncMetadata.ID(                                             │
                    │     recordPrimaryKey: "1",                                         │
                    │     recordType: "remindersLists"                                   │
                    │   ),                                                               │
                    │   zoneName: "zone",                                                │
                    │   ownerName: "__defaultOwner__",                                   │
                    │   recordName: "1:remindersLists",                                  │
                    │   parentRecordID: nil,                                             │
                    │   parentRecordName: nil,                                           │
                    │   lastKnownServerRecord: CKRecord(                                 │
                    │     recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__), │
                    │     recordType: "remindersLists",                                  │
                    │     parent: nil,                                                   │
                    │     share: nil                                                     │
                    │   ),                                                               │
                    │   _lastKnownServerRecordAllFields: CKRecord(                       │
                    │     recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__), │
                    │     recordType: "remindersLists",                                  │
                    │     parent: nil,                                                   │
                    │     share: nil,                                                    │
                    │     id: 1,                                                         │
                    │     title: "Personal"                                              │
                    │   ),                                                               │
                    │   share: nil,                                                      │
                    │   _isDeleted: false,                                               │
                    │   _hasLastKnownServerRecord: true,                                 │
                    │   _isShared: false,                                                │
                    │   userModificationTime: 0                                          │
                    │ )                                                                  │
                    └────────────────────────────────────────────────────────────────────┘
                    """
                }

                try await userDatabase.userWrite { db in
                    try RemindersListWithPosition.find(1).update {
                        $0.title = "My Stuff"
                        $0.position = 42
                    }
                    .execute(db)
                }
                try await newSyncEngine.processPendingRecordZoneChanges(scope: .private)

                assertQuery(SyncMetadata.all, database: syncEngine.metadatabase) {
                    """
                    ┌────────────────────────────────────────────────────────────────────┐
                    │ SyncMetadata(                                                      │
                    │   id: SyncMetadata.ID(                                             │
                    │     recordPrimaryKey: "1",                                         │
                    │     recordType: "remindersLists"                                   │
                    │   ),                                                               │
                    │   zoneName: "zone",                                                │
                    │   ownerName: "__defaultOwner__",                                   │
                    │   recordName: "1:remindersLists",                                  │
                    │   parentRecordID: nil,                                             │
                    │   parentRecordName: nil,                                           │
                    │   lastKnownServerRecord: CKRecord(                                 │
                    │     recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__), │
                    │     recordType: "remindersLists",                                  │
                    │     parent: nil,                                                   │
                    │     share: nil                                                     │
                    │   ),                                                               │
                    │   _lastKnownServerRecordAllFields: CKRecord(                       │
                    │     recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__), │
                    │     recordType: "remindersLists",                                  │
                    │     parent: nil,                                                   │
                    │     share: nil,                                                    │
                    │     id: 1,                                                         │
                    │     position: 42,                                                  │
                    │     title: "My Stuff"                                              │
                    │   ),                                                               │
                    │   share: nil,                                                      │
                    │   _isDeleted: false,                                               │
                    │   _hasLastKnownServerRecord: true,                                 │
                    │   _isShared: false,                                                │
                    │   userModificationTime: 0                                          │
                    │ )                                                                  │
                    └────────────────────────────────────────────────────────────────────┘
                    """
                }
                assertInlineSnapshot(of: syncEngine.container, as: .customDump) {
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
                            position: 42,
                            title: "My Stuff"
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

            @Test func `adds an asset column to reminders lists`() async throws {
                let personalList = RemindersList(id: 1, title: "Personal")
                try await userDatabase.userWrite { db in
                    try db.seed {
                        personalList
                    }
                }

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 60) {
                    let personalListRecord = try syncEngine.private.database.record(
                        for: RemindersList.recordID(for: 1)
                    )
                    try personalListRecord.setBytes(
                        [Byte](utf8: "image"),
                        forKey: "image",
                        at: now,
                        dataManager: inMemoryDataManager
                    )

                    try await syncEngine.modifyRecords(
                        scope: .private,
                        saving: [personalListRecord]
                    )
                    .notify()

                    try await userDatabase.userWrite { db in
                        try #sql(
                            """
                            ALTER TABLE "remindersLists" 
                            ADD COLUMN "image" BLOB NOT NULL ON CONFLICT REPLACE DEFAULT X''
                            """
                        )
                        .execute(db)
                    }

                    let relaunchedSyncEngine = try await relaunchSyncEngine(
                        tables: syncEngine.tables
                            .filter { $0.base != RemindersList.self }
                            + [SynchronizedTable(for: RemindersListWithData.self)]
                    )
                    defer { _ = relaunchedSyncEngine }

                    let remindersLists = try await userDatabase.read { db in
                        try RemindersListWithData.order(by: \.id).fetchAll(db)
                    }

                    #expect(
                        remindersLists == [
                            RemindersListWithData(id: 1, image: [Byte](utf8: "image"), title: "Personal")
                        ]
                    )
                }
            }

            @Test func `adds an asset column to reminders lists and redownloads the assets`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                        RemindersList(id: 2, title: "Business")
                        RemindersList(id: 3, title: "Secret")
                    }
                }

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 60) {
                    let personalListRecord = try syncEngine.private.database.record(
                        for: RemindersList.recordID(for: 1)
                    )
                    try personalListRecord.setBytes(
                        [Byte](utf8: "personal-image"),
                        forKey: "image",
                        at: now,
                        dataManager: inMemoryDataManager
                    )
                    let businessListRecord = try syncEngine.private.database.record(
                        for: RemindersList.recordID(for: 2)
                    )
                    try businessListRecord.setBytes(
                        [Byte](utf8: "business-image"),
                        forKey: "image",
                        at: now,
                        dataManager: inMemoryDataManager
                    )
                    let secretListRecord = try syncEngine.private.database.record(
                        for: RemindersList.recordID(for: 3)
                    )
                    try secretListRecord.setBytes(
                        [Byte](utf8: "secret-image"),
                        forKey: "image",
                        at: now,
                        dataManager: inMemoryDataManager
                    )

                    try await syncEngine.modifyRecords(
                        scope: .private,
                        saving: [personalListRecord, businessListRecord, secretListRecord]
                    )
                    .notify()

                    inMemoryDataManager.storage.withLock { $0.removeAll() }

                    try await userDatabase.userWrite { db in
                        try #sql(
                            """
                            ALTER TABLE "remindersLists" 
                            ADD COLUMN "image" BLOB NOT NULL ON CONFLICT REPLACE DEFAULT X''
                            """
                        )
                        .execute(db)
                    }

                    let relaunchedSyncEngine = try await relaunchSyncEngine(
                        tables: syncEngine.tables
                            .filter { $0.base != RemindersList.self }
                            + [SynchronizedTable(for: RemindersListWithData.self)]
                    )
                    defer { _ = relaunchedSyncEngine }

                    let remindersLists = try await userDatabase.read { db in
                        try RemindersListWithData.order(by: \.id).fetchAll(db)
                    }

                    #expect(
                        remindersLists == [
                            RemindersListWithData(id: 1, image: [Byte](utf8: "personal-image"), title: "Personal"),
                            RemindersListWithData(id: 2, image: [Byte](utf8: "business-image"), title: "Business"),
                            RemindersListWithData(id: 3, image: [Byte](utf8: "secret-image"), title: "Secret"),
                        ]
                    )
                }
            }

            @Test func `syncs a new table`() async throws {
                try await withTime(advancedBy: 60) {
                    let imageRecord = CKRecord(
                        recordType: "images",
                        recordID: Image.recordID(for: 1)
                    )
                    imageRecord.setValue(1, forKey: "id", at: now)
                    imageRecord.setValue("A good image", forKey: "caption", at: now)
                    imageRecord.setValue(Data("image".utf8), forKey: "image", at: now)

                    try await syncEngine.modifyRecords(
                        scope: .private,
                        saving: [imageRecord]
                    )
                    .notify()
                    syncEngine.stop()

                    inMemoryDataManager.storage.withLock { $0.removeAll() }

                    try await userDatabase.userWrite { db in
                        try #sql(
                            """
                            CREATE TABLE "images" (
                              "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                              "caption" TEXT NOT NULL,
                              "image" BLOB NOT NULL
                            )
                            """
                        )
                        .execute(db)
                    }

                    let relaunchedSyncEngine = try await relaunchSyncEngine(
                        tables: syncEngine.tables + [SynchronizedTable(for: Image.self)]
                    )
                    defer { _ = relaunchedSyncEngine }

                    try await userDatabase.read { db in
                        #expect(
                            try Image.order(by: \.id).fetchAll(db) == [
                                Image(id: 1, image: [Byte](utf8: "image"), caption: "A good image")
                            ]
                        )
                    }

                    assertInlineSnapshot(of: relaunchedSyncEngine.container, as: .customDump) {
                        """
                        MockCloudContainer(
                          privateCloudDatabase: MockCloudDatabase(
                            databaseScope: .private,
                            storage: [
                              [0]: CKRecord(
                                recordID: CKRecord.ID(1:images/zone/__defaultOwner__),
                                recordType: "images",
                                parent: nil,
                                share: nil,
                                caption: "A good image",
                                id: 1,
                                image: Data(5 bytes)
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

            @Test func `ignores an outside record`() async throws {
                let customRecord = CKRecord(
                    recordType: "customRecord",
                    recordID: CKRecord.ID(
                        recordName: "customRecord",
                        zoneID: SyncEngine.defaultTestZone.zoneID
                    )
                )
                try await syncEngine.modifyRecords(scope: .private, saving: [customRecord]).notify()
                assertQuery(SyncMetadata.all, database: syncEngine.metadatabase) {
                    """
                    (No results)
                    """
                }
            }

            @Test func `ignores an outside record with a colon`() async throws {
                let customRecord = CKRecord(
                    recordType: "customRecord",
                    recordID: CKRecord.ID(
                        recordName: "1:customRecord",
                        zoneID: SyncEngine.defaultTestZone.zoneID
                    )
                )
                try await syncEngine.modifyRecords(scope: .private, saving: [customRecord]).notify()
                assertQuery(SyncMetadata.all, database: syncEngine.metadatabase) {
                    """
                    (No results)
                    """
                }
            }

            private func relaunchSyncEngine(tables: [any SynchronizableTable]) async throws -> SyncEngine {
                try await SyncEngine(
                    container: container,
                    userDatabase: userDatabase,
                    tables: tables,
                    privateTables: syncEngine.privateTables,
                    notificationCenter: notificationCenter,
                    dataManager: inMemoryDataManager,
                    now: { [time] in time() },
                    uuid: { [uuid] in uuid() },
                    clock: testClock
                )
            }
        }
    }

    @Table("remindersLists")
    private struct RemindersListWithPosition: Equatable, Identifiable {
        let id: Int
        var title = ""
        var position = 0
    }

    @Table("remindersLists")
    private struct RemindersListWithColor: Equatable, Identifiable {
        let id: Int
        var title = ""
        var color: Int?
    }

    @Table("reminders")
    private struct ReminderWithPosition: Equatable, Identifiable {
        let id: Int
        var title = ""
        var position = 0
        var remindersListID: RemindersList.ID
    }

    @Table("remindersLists")
    private struct RemindersListWithData: Equatable, Identifiable {
        let id: Int
        var image: [Byte]
        var title = ""
    }

    @Table
    private struct Image: Equatable, Identifiable {
        let id: Int
        var image: [Byte]
        var caption = ""
    }
#endif
