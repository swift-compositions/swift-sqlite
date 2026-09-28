#if CloudKit
    import CloudKit
    import InlineSnapshotTesting
    import SQL
    import SQLite
    import SQLite_Test_Support
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Foreign key constraints`: CloudKitTestBase, @unchecked Sendable {
            @Test func `synchronizes a child record received before its parent`() async throws {
                let remindersListRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue(1, forKey: "id", at: now)
                remindersListRecord.setValue("Personal", forKey: "title", at: now)

                let reminderRecord = CKRecord(
                    recordType: Reminder.tableName,
                    recordID: Reminder.recordID(for: 1)
                )
                reminderRecord.setValue(1, forKey: "id", at: now)
                reminderRecord.setValue("Get milk", forKey: "title", at: now)
                reminderRecord.setValue(1, forKey: "remindersListID", at: now)
                reminderRecord.parent = CKRecord.Reference(
                    record: remindersListRecord,
                    action: .none
                )

                let remindersListModification = try syncEngine.modifyRecords(
                    scope: .private,
                    saving: [remindersListRecord]
                )
                try await syncEngine.modifyRecords(scope: .private, saving: [reminderRecord]).notify()
                await remindersListModification.notify()

                try await withTime(advancedBy: 1) {
                    try await userDatabase.userWrite { db in
                        try Reminder.find(1).update { $0.title = "Buy milk" }.execute(db)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                assertQuery(Reminder.all, database: userDatabase.database) {
                    """
                    ┌───────────────────────┐
                    │ Reminder(             │
                    │   id: 1,              │
                    │   dueDate: nil,       │
                    │   isCompleted: false, │
                    │   priority: nil,      │
                    │   title: "Buy milk",  │
                    │   remindersListID: 1  │
                    │ )                     │
                    └───────────────────────┘
                    """
                }
                assertQuery(RemindersList.all, database: userDatabase.database) {
                    """
                    ┌─────────────────────┐
                    │ RemindersList(      │
                    │   id: 1,            │
                    │   title: "Personal" │
                    │ )                   │
                    └─────────────────────┘
                    """
                }
                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:reminders/zone/__defaultOwner__),
                            recordType: "reminders",
                            parent: CKReference(recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__)),
                            share: nil,
                            id: 1,
                            isCompleted: 0,
                            remindersListID: 1,
                            title: "Buy milk"
                          ),
                          [1]: CKRecord(
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

            @Test func `remote creates records A, B and C, local receives A and C, remote deletes B and C`() async throws {
                let modelARecord = CKRecord(recordType: ModelA.tableName, recordID: ModelA.recordID(for: 1))
                modelARecord.setValue(1, forKey: "id", at: now)
                let modelBRecord = CKRecord(recordType: ModelB.tableName, recordID: ModelB.recordID(for: 1))
                modelBRecord.setValue(1, forKey: "id", at: now)
                modelBRecord.setValue(1, forKey: "modelAID", at: now)
                modelBRecord.parent = CKRecord.Reference(record: modelARecord, action: .none)
                let modelCRecord = CKRecord(recordType: ModelC.tableName, recordID: ModelC.recordID(for: 1))
                modelCRecord.setValue(1, forKey: "id", at: now)
                modelCRecord.setValue(1, forKey: "modelBID", at: now)
                modelCRecord.parent = CKRecord.Reference(record: modelBRecord, action: .none)

                try await syncEngine.modifyRecords(scope: .private, saving: [modelARecord]).notify()
                _ = try syncEngine.modifyRecords(scope: .private, saving: [modelBRecord])
                try await syncEngine.modifyRecords(scope: .private, saving: [modelCRecord]).notify()

                assertQuery(ModelA.all, database: userDatabase.database) {
                    """
                    ┌────────────────┐
                    │ ModelA(        │
                    │   id: 1,       │
                    │   count: 0,    │
                    │   isEven: true │
                    │ )              │
                    └────────────────┘
                    """
                }
                assertQuery(ModelB.all, database: userDatabase.database) {
                    """
                    (No results)
                    """
                }
                assertQuery(ModelC.all, database: userDatabase.database) {
                    """
                    (No results)
                    """
                }
                assertQuery(UnsyncedRecordID.all, database: syncEngine.metadatabase) {
                    """
                    ┌─────────────────────────────────┐
                    │ UnsyncedRecordID(               │
                    │   recordName: "1:modelCs",      │
                    │   zoneName: "zone",             │
                    │   ownerName: "__defaultOwner__" │
                    │ )                               │
                    └─────────────────────────────────┘
                    """
                }

                try await syncEngine.modifyRecords(
                    scope: .private,
                    deleting: [modelCRecord.recordID, modelBRecord.recordID]
                )
                .notify()

                assertQuery(ModelA.all, database: userDatabase.database) {
                    """
                    ┌────────────────┐
                    │ ModelA(        │
                    │   id: 1,       │
                    │   count: 0,    │
                    │   isEven: true │
                    │ )              │
                    └────────────────┘
                    """
                }
                assertQuery(ModelB.all, database: userDatabase.database) {
                    """
                    (No results)
                    """
                }
                assertQuery(ModelC.all, database: userDatabase.database) {
                    """
                    (No results)
                    """
                }
                assertQuery(UnsyncedRecordID.all, database: syncEngine.metadatabase) {
                    """
                    (No results)
                    """
                }
                assertInlineSnapshot(of: container, as: .customDump) {
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

            @Test func `receives a child record before its parent, then the child and parent together`() async throws {
                let remindersListRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue(1, forKey: "id", at: now)
                remindersListRecord.setValue("Personal", forKey: "title", at: now)

                let reminderRecord = CKRecord(
                    recordType: Reminder.tableName,
                    recordID: Reminder.recordID(for: 1)
                )
                reminderRecord.setValue(1, forKey: "id", at: now)
                reminderRecord.setValue("Get milk", forKey: "title", at: now)
                reminderRecord.setValue(1, forKey: "remindersListID", at: now)
                reminderRecord.parent = CKRecord.Reference(
                    record: remindersListRecord,
                    action: .none
                )

                _ = try syncEngine.modifyRecords(scope: .private, saving: [remindersListRecord])
                try await syncEngine.modifyRecords(scope: .private, saving: [reminderRecord]).notify()
                let freshReminderRecord = try syncEngine.private.database.record(
                    for: Reminder.recordID(for: 1)
                )
                let freshRemindersListRecord = try syncEngine.private.database.record(
                    for: RemindersList.recordID(for: 1)
                )
                try await syncEngine.modifyRecords(
                    scope: .private,
                    saving: [freshReminderRecord, freshRemindersListRecord]
                )
                .notify()

                assertQuery(Reminder.all, database: userDatabase.database) {
                    """
                    ┌───────────────────────┐
                    │ Reminder(             │
                    │   id: 1,              │
                    │   dueDate: nil,       │
                    │   isCompleted: false, │
                    │   priority: nil,      │
                    │   title: "Get milk",  │
                    │   remindersListID: 1  │
                    │ )                     │
                    └───────────────────────┘
                    """
                }
                assertQuery(RemindersList.all, database: userDatabase.database) {
                    """
                    ┌─────────────────────┐
                    │ RemindersList(      │
                    │   id: 1,            │
                    │   title: "Personal" │
                    │ )                   │
                    └─────────────────────┘
                    """
                }
                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:reminders/zone/__defaultOwner__),
                            recordType: "reminders",
                            parent: CKReference(recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__)),
                            share: nil,
                            id: 1,
                            remindersListID: 1,
                            title: "Get milk"
                          ),
                          [1]: CKRecord(
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

            @Test func `receives a child, relaunches, then receives the parent`() async throws {
                let remindersListRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue(1, forKey: "id", at: now)
                remindersListRecord.setValue("Personal", forKey: "title", at: now)

                let reminderRecord = CKRecord(
                    recordType: Reminder.tableName,
                    recordID: Reminder.recordID(for: 1)
                )
                reminderRecord.setValue(1, forKey: "id", at: now)
                reminderRecord.setValue("Get milk", forKey: "title", at: now)
                reminderRecord.setValue(1, forKey: "remindersListID", at: now)
                reminderRecord.parent = CKRecord.Reference(
                    recordID: RemindersList.recordID(for: 1),
                    action: .none
                )

                _ = try syncEngine.modifyRecords(scope: .private, saving: [remindersListRecord])
                try await syncEngine.modifyRecords(scope: .private, saving: [reminderRecord]).notify()

                assertQuery(Reminder.all, database: userDatabase.database) {
                    """
                    (No results)
                    """
                }

                let relaunchedSyncEngine = try await SyncEngine(
                    container: container,
                    userDatabase: userDatabase,
                    tables: syncEngine.tables,
                    privateTables: syncEngine.privateTables,
                    notificationCenter: notificationCenter,
                    dataManager: inMemoryDataManager,
                    now: time.callAsFunction,
                    uuid: uuid.callAsFunction,
                    clock: testClock
                )

                await relaunchedSyncEngine
                    .handleEvent(
                        .fetchedRecordZoneChanges(modifications: [remindersListRecord], deletions: []),
                        syncEngine: relaunchedSyncEngine.private
                    )

                assertQuery(
                    SyncMetadata.order(by: \.recordName).select { ($0.recordName, $0.parentRecordName) },
                    database: syncEngine.metadatabase
                ) {
                    """
                    ┌────────────────────┬────────────────────┐
                    │ "1:reminders"      │ "1:remindersLists" │
                    │ "1:remindersLists" │ nil                │
                    └────────────────────┴────────────────────┘
                    """
                }
                assertQuery(Reminder.all, database: userDatabase.database) {
                    """
                    ┌───────────────────────┐
                    │ Reminder(             │
                    │   id: 1,              │
                    │   dueDate: nil,       │
                    │   isCompleted: false, │
                    │   priority: nil,      │
                    │   title: "Get milk",  │
                    │   remindersListID: 1  │
                    │ )                     │
                    └───────────────────────┘
                    """
                }
                assertQuery(RemindersList.all, database: userDatabase.database) {
                    """
                    ┌─────────────────────┐
                    │ RemindersList(      │
                    │   id: 1,            │
                    │   title: "Personal" │
                    │ )                   │
                    └─────────────────────┘
                    """
                }

                try await withTime(advancedBy: 1) {
                    try await userDatabase.userWrite { db in
                        try Reminder.find(1).update { $0.title = "Buy milk" }.execute(db)
                    }

                    try await relaunchedSyncEngine.processPendingRecordZoneChanges(scope: .private)
                }

                assertQuery(Reminder.all, database: userDatabase.database) {
                    """
                    ┌───────────────────────┐
                    │ Reminder(             │
                    │   id: 1,              │
                    │   dueDate: nil,       │
                    │   isCompleted: false, │
                    │   priority: nil,      │
                    │   title: "Buy milk",  │
                    │   remindersListID: 1  │
                    │ )                     │
                    └───────────────────────┘
                    """
                }
                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:reminders/zone/__defaultOwner__),
                            recordType: "reminders",
                            parent: CKReference(recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__)),
                            share: nil,
                            id: 1,
                            isCompleted: 0,
                            remindersListID: 1,
                            title: "Buy milk"
                          ),
                          [1]: CKRecord(
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

            @Test func `changes the parent relationship to an unknown record`() async throws {
                let personalListRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: RemindersList.recordID(for: 1)
                )
                personalListRecord.setValue(1, forKey: "id", at: now)
                personalListRecord.setValue("Personal", forKey: "title", at: now)

                let businessListRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: RemindersList.recordID(for: 2)
                )
                businessListRecord.setValue(2, forKey: "id", at: now)
                businessListRecord.setValue("Business", forKey: "title", at: now)

                let reminderRecord = CKRecord(
                    recordType: Reminder.tableName,
                    recordID: Reminder.recordID(for: 1)
                )
                reminderRecord.setValue(1, forKey: "id", at: now)
                reminderRecord.setValue("Get milk", forKey: "title", at: now)
                reminderRecord.setValue(1, forKey: "remindersListID", at: now)
                reminderRecord.parent = CKRecord.Reference(
                    record: personalListRecord,
                    action: .none
                )

                try await syncEngine.modifyRecords(
                    scope: .private,
                    saving: [reminderRecord, personalListRecord]
                ).notify()

                let modifications = try await withTime(advancedBy: 1) {
                    let reminderRecord = try syncEngine.private.database.record(
                        for: Reminder.recordID(for: 1)
                    )
                    reminderRecord.setValue(2, forKey: "remindersListID", at: now)
                    reminderRecord.parent = CKRecord.Reference(record: businessListRecord, action: .none)

                    let modifications = try syncEngine.modifyRecords(
                        scope: .private,
                        saving: [businessListRecord]
                    )
                    try await syncEngine.modifyRecords(scope: .private, saving: [reminderRecord]).notify()
                    return modifications
                }

                await modifications.notify()

                assertQuery(
                    SyncMetadata.order(by: \.recordName).select { ($0.recordName, $0.parentRecordName) },
                    database: syncEngine.metadatabase
                ) {
                    """
                    ┌────────────────────┬────────────────────┐
                    │ "1:reminders"      │ "2:remindersLists" │
                    │ "1:remindersLists" │ nil                │
                    │ "2:remindersLists" │ nil                │
                    └────────────────────┴────────────────────┘
                    """
                }
                assertQuery(Reminder.all, database: userDatabase.database) {
                    """
                    ┌───────────────────────┐
                    │ Reminder(             │
                    │   id: 1,              │
                    │   dueDate: nil,       │
                    │   isCompleted: false, │
                    │   priority: nil,      │
                    │   title: "Get milk",  │
                    │   remindersListID: 2  │
                    │ )                     │
                    └───────────────────────┘
                    """
                }
                assertQuery(RemindersList.all, database: userDatabase.database) {
                    """
                    ┌─────────────────────┐
                    │ RemindersList(      │
                    │   id: 1,            │
                    │   title: "Personal" │
                    │ )                   │
                    ├─────────────────────┤
                    │ RemindersList(      │
                    │   id: 2,            │
                    │   title: "Business" │
                    │ )                   │
                    └─────────────────────┘
                    """
                }
                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:reminders/zone/__defaultOwner__),
                            recordType: "reminders",
                            parent: CKReference(recordID: CKRecord.ID(2:remindersLists/zone/__defaultOwner__)),
                            share: nil,
                            id: 1,
                            remindersListID: 2,
                            title: "Get milk"
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            title: "Personal"
                          ),
                          [2]: CKRecord(
                            recordID: CKRecord.ID(2:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 2,
                            title: "Business"
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

            @Test func `changes the parent relationship remotely then locally`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                        RemindersList(id: 2, title: "Business")
                        RemindersList(id: 3, title: "Secret")
                        Reminder(id: 1, title: "Get milk", remindersListID: 1)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let modifications = try withTime(advancedBy: 1) {
                    let reminderRecord = try syncEngine.private.database
                        .record(for: Reminder.recordID(for: 1))
                    reminderRecord.setValue(2, forKey: "remindersListID", at: now)
                    reminderRecord.parent = CKRecord.Reference(
                        recordID: RemindersList.recordID(for: 2),
                        action: .none
                    )
                    return try syncEngine.modifyRecords(scope: .private, saving: [reminderRecord])
                }

                try await withTime(advancedBy: 2) {
                    try await userDatabase.userWrite { db in
                        try Reminder.find(1)
                            .update {
                                $0.title = "Buy milk"
                                $0.remindersListID = 3
                            }
                            .execute(db)
                    }
                }

                await modifications.notify()
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                assertQuery(
                    SyncMetadata.select { ($0.recordName, $0.parentRecordName) },
                    database: syncEngine.metadatabase
                ) {
                    """
                    ┌────────────────────┬────────────────────┐
                    │ "1:remindersLists" │ nil                │
                    │ "2:remindersLists" │ nil                │
                    │ "3:remindersLists" │ nil                │
                    │ "1:reminders"      │ "3:remindersLists" │
                    └────────────────────┴────────────────────┘
                    """
                }
                assertQuery(Reminder.all, database: userDatabase.database) {
                    """
                    ┌───────────────────────┐
                    │ Reminder(             │
                    │   id: 1,              │
                    │   dueDate: nil,       │
                    │   isCompleted: false, │
                    │   priority: nil,      │
                    │   title: "Buy milk",  │
                    │   remindersListID: 3  │
                    │ )                     │
                    └───────────────────────┘
                    """
                }
                assertInlineSnapshot(
                    of: syncEngine.private.database.state.withLock {
                        $0.storage[syncEngine.defaultZone.zoneID]?.records[Reminder.recordID(for: 1)]
                    },
                    as: .customDump
                ) {
                    """
                    CKRecord(
                      recordID: CKRecord.ID(1:reminders/zone/__defaultOwner__),
                      recordType: "reminders",
                      parent: CKReference(recordID: CKRecord.ID(3:remindersLists/zone/__defaultOwner__)),
                      share: nil,
                      id: 1,
                      isCompleted: 0,
                      remindersListID: 3,
                      title: "Buy milk"
                    )
                    """
                }
            }

            @Test func `changes the parent relationship remotely first and locally second, sends the batch, then receives from CloudKit`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                        RemindersList(id: 2, title: "Business")
                        RemindersList(id: 3, title: "Secret")
                        Reminder(id: 1, title: "Get milk", remindersListID: 1)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let modifications = try withTime(advancedBy: 1) {
                    let reminderRecord = try syncEngine.private.database
                        .record(for: Reminder.recordID(for: 1))
                    reminderRecord.setValue(2, forKey: "remindersListID", at: now)
                    reminderRecord.parent = CKRecord.Reference(
                        recordID: RemindersList.recordID(for: 2),
                        action: .none
                    )
                    return try syncEngine.modifyRecords(scope: .private, saving: [reminderRecord])
                }

                try await withTime(advancedBy: 2) {
                    try await userDatabase.userWrite { db in
                        try Reminder.find(1).update { $0.remindersListID = 3 }.execute(db)
                    }
                }

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                await modifications.notify()
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                assertQuery(
                    SyncMetadata.select { ($0.recordName, $0.parentRecordName) },
                    database: syncEngine.metadatabase
                ) {
                    """
                    ┌────────────────────┬────────────────────┐
                    │ "1:remindersLists" │ nil                │
                    │ "2:remindersLists" │ nil                │
                    │ "3:remindersLists" │ nil                │
                    │ "1:reminders"      │ "3:remindersLists" │
                    └────────────────────┴────────────────────┘
                    """
                }
                assertQuery(Reminder.all, database: userDatabase.database) {
                    """
                    ┌───────────────────────┐
                    │ Reminder(             │
                    │   id: 1,              │
                    │   dueDate: nil,       │
                    │   isCompleted: false, │
                    │   priority: nil,      │
                    │   title: "Get milk",  │
                    │   remindersListID: 3  │
                    │ )                     │
                    └───────────────────────┘
                    """
                }
                assertInlineSnapshot(
                    of: syncEngine.private.database.state.withLock {
                        $0.storage[syncEngine.defaultZone.zoneID]?.records[Reminder.recordID(for: 1)]
                    },
                    as: .customDump
                ) {
                    """
                    CKRecord(
                      recordID: CKRecord.ID(1:reminders/zone/__defaultOwner__),
                      recordType: "reminders",
                      parent: CKReference(recordID: CKRecord.ID(3:remindersLists/zone/__defaultOwner__)),
                      share: nil,
                      id: 1,
                      isCompleted: 0,
                      remindersListID: 3,
                      title: "Get milk"
                    )
                    """
                }
            }

            @Test func `cascading deletes`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                        Reminder(id: 1, title: "Get milk", remindersListID: 1)
                        RemindersList(id: 2, title: "Work")
                        Reminder(id: 2, title: "Call accountant", remindersListID: 2)
                        RemindersList(id: 3, title: "Secret")
                        Reminder(id: 3, title: "Schedule secret meeting", remindersListID: 3)
                    }
                }

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await userDatabase.userWrite { db in
                    try RemindersList.where { $0.id <= 2 }.delete().execute(db)
                }

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(3:reminders/zone/__defaultOwner__),
                            recordType: "reminders",
                            parent: CKReference(recordID: CKRecord.ID(3:remindersLists/zone/__defaultOwner__)),
                            share: nil,
                            id: 3,
                            isCompleted: 0,
                            remindersListID: 3,
                            title: "Schedule secret meeting"
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(3:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 3,
                            title: "Secret"
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

            @Test func `insert with a foreign key constraint failure`() async throws {
                await #expect(throws: (any Error).self) {
                    try await userDatabase.userWrite { db in
                        try db.seed {
                            Reminder(id: 1, title: "Get milk", remindersListID: 1)
                        }
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                assertQuery(SyncMetadata.all, database: syncEngine.metadatabase) {
                    """
                    (No results)
                    """
                }
                assertInlineSnapshot(of: container, as: .customDump) {
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

            @Test func `batches associations`() async throws {
                let remindersListRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue(1, forKey: "id", at: now)
                remindersListRecord.setValue("Personal", forKey: "title", at: now)
                let remindersListModification = try syncEngine.modifyRecords(
                    scope: .private,
                    saving: [remindersListRecord]
                )

                let reminderRecords = (1...500).map { index in
                    let reminderRecord = CKRecord(
                        recordType: Reminder.tableName,
                        recordID: Reminder.recordID(for: index)
                    )
                    reminderRecord.setValue(index, forKey: "id", at: now)
                    reminderRecord.setValue("Reminder #\(index)", forKey: "title", at: now)
                    reminderRecord.setValue(1, forKey: "remindersListID", at: now)
                    reminderRecord.parent = CKRecord.Reference(
                        record: remindersListRecord,
                        action: .none
                    )
                    return reminderRecord
                }

                try await syncEngine.modifyRecords(
                    scope: .private,
                    saving: Array(reminderRecords[0...100])
                ).notify()
                try await syncEngine.modifyRecords(
                    scope: .private,
                    saving: Array(reminderRecords[101...200])
                ).notify()
                try await syncEngine.modifyRecords(
                    scope: .private,
                    saving: Array(reminderRecords[201...300])
                ).notify()
                try await syncEngine.modifyRecords(
                    scope: .private,
                    saving: Array(reminderRecords[301...400])
                ).notify()
                try await syncEngine.modifyRecords(
                    scope: .private,
                    saving: Array(reminderRecords[401...499])
                ).notify()
                await remindersListModification.notify()

                try await userDatabase.read { db in
                    try #expect(RemindersList.fetchCount(db) == 1)
                    try #expect(Reminder.fetchCount(db) == 500)
                }
            }
        }
    }
#endif

