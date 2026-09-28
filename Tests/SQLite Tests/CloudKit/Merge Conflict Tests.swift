#if CloudKit
    import CloudKit
    import Foundation
    import InlineSnapshotTesting
    import SQL
    import SQL_Macros
    import SQLite
    import SQLite_Test_Support
    import Testing
    import Time

    extension CloudKitTestBase {
        @MainActor
        final class `Merge conflicts`: CloudKitTestBase, @unchecked Sendable {
            @Test func `merge when the client record was updated before the server record`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "")
                        Reminder(id: 1, title: "", remindersListID: 1)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                assertInlineSnapshot(of: container, as: .customDump(timestamps: true)) {
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
                            dueDate🗓️: 0,
                            id: 1,
                            id🗓️: 0,
                            isCompleted: 0,
                            isCompleted🗓️: 0,
                            priority🗓️: 0,
                            remindersListID: 1,
                            remindersListID🗓️: 0,
                            title: "",
                            title🗓️: 0,
                            🗓️: 0
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            id🗓️: 0,
                            title: "",
                            title🗓️: 0,
                            🗓️: 0
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

                let record = try syncEngine.private.database.record(for: Reminder.recordID(for: 1))
                record.setValue("Buy milk", forKey: "title", at: 60_000_000_000)
                let modificationCallback = try syncEngine.modifyRecords(scope: .private, saving: [record])

                try await withTime(advancedBy: 30) {
                    try await userDatabase.userWrite { db in
                        try Reminder.find(1).update { $0.isCompleted = true }.execute(db)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                assertInlineSnapshot(of: container, as: .customDump(timestamps: true)) {
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
                            dueDate🗓️: 0,
                            id: 1,
                            id🗓️: 0,
                            isCompleted: 0,
                            isCompleted🗓️: 0,
                            priority🗓️: 0,
                            remindersListID: 1,
                            remindersListID🗓️: 0,
                            title: "Buy milk",
                            title🗓️: 60000000000,
                            🗓️: 60000000000
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            id🗓️: 0,
                            title: "",
                            title🗓️: 0,
                            🗓️: 0
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

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                await modificationCallback.notify()

                assertInlineSnapshot(of: container, as: .customDump(timestamps: true)) {
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
                            dueDate🗓️: 0,
                            id: 1,
                            id🗓️: 0,
                            isCompleted: 1,
                            isCompleted🗓️: 30000000000,
                            priority🗓️: 0,
                            remindersListID: 1,
                            remindersListID🗓️: 0,
                            title: "Buy milk",
                            title🗓️: 60000000000,
                            🗓️: 60000000000
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            id🗓️: 0,
                            title: "",
                            title🗓️: 0,
                            🗓️: 0
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

            @Test func `merge when the server record was updated before the client record`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "")
                        Reminder(id: 1, title: "", remindersListID: 1)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                assertInlineSnapshot(of: container, as: .customDump(timestamps: true)) {
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
                            dueDate🗓️: 0,
                            id: 1,
                            id🗓️: 0,
                            isCompleted: 0,
                            isCompleted🗓️: 0,
                            priority🗓️: 0,
                            remindersListID: 1,
                            remindersListID🗓️: 0,
                            title: "",
                            title🗓️: 0,
                            🗓️: 0
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            id🗓️: 0,
                            title: "",
                            title🗓️: 0,
                            🗓️: 0
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

                let record = try syncEngine.private.database.record(for: Reminder.recordID(for: 1))
                record.setValue("Buy milk", forKey: "title", at: 30_000_000_000)
                let modificationCallback = try syncEngine.modifyRecords(scope: .private, saving: [record])

                try await withTime(advancedBy: 60) {
                    try await userDatabase.userWrite { db in
                        try Reminder.find(1).update { $0.isCompleted = true }.execute(db)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                assertInlineSnapshot(of: container, as: .customDump(timestamps: true)) {
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
                            dueDate🗓️: 0,
                            id: 1,
                            id🗓️: 0,
                            isCompleted: 0,
                            isCompleted🗓️: 0,
                            priority🗓️: 0,
                            remindersListID: 1,
                            remindersListID🗓️: 0,
                            title: "Buy milk",
                            title🗓️: 30000000000,
                            🗓️: 30000000000
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            id🗓️: 0,
                            title: "",
                            title🗓️: 0,
                            🗓️: 0
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

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                await modificationCallback.notify()

                assertInlineSnapshot(of: container, as: .customDump(timestamps: true)) {
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
                            dueDate🗓️: 0,
                            id: 1,
                            id🗓️: 0,
                            isCompleted: 1,
                            isCompleted🗓️: 60000000000,
                            priority🗓️: 0,
                            remindersListID: 1,
                            remindersListID🗓️: 0,
                            title: "Buy milk",
                            title🗓️: 30000000000,
                            🗓️: 60000000000
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            id🗓️: 0,
                            title: "",
                            title🗓️: 0,
                            🗓️: 0
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

            @Test func `merge when the server and the client edit different fields`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "")
                        Reminder(id: 1, title: "", remindersListID: 1)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let record = try syncEngine.private.database.record(for: Reminder.recordID(for: 1))
                record.setValue("Buy milk", forKey: "title", at: 30_000_000_000)
                let modificationCallback = try syncEngine.modifyRecords(scope: .private, saving: [record])

                try await withTime(advancedBy: 60) {
                    try await userDatabase.userWrite { db in
                        try Reminder.find(1).update { $0.isCompleted = true }.execute(db)
                    }
                }
                await modificationCallback.notify()
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                assertInlineSnapshot(of: container, as: .customDump(timestamps: true)) {
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
                            dueDate🗓️: 0,
                            id: 1,
                            id🗓️: 0,
                            isCompleted: 1,
                            isCompleted🗓️: 60000000000,
                            priority🗓️: 0,
                            remindersListID: 1,
                            remindersListID🗓️: 0,
                            title: "Buy milk",
                            title🗓️: 30000000000,
                            🗓️: 60000000000
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            id🗓️: 0,
                            title: "",
                            title🗓️: 0,
                            🗓️: 0
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

            @Test func `merge when the server record was edited after the client but processed before the client`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "")
                        Reminder(id: 1, title: "", remindersListID: 1)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 30) {
                    try await userDatabase.userWrite { db in
                        try Reminder.find(1).update { $0.title = "Get milk" }.execute(db)
                    }
                    try await withTime(advancedBy: 30) {
                        let record = try syncEngine.private.database.record(for: Reminder.recordID(for: 1))
                        record.setValue("Buy milk", forKey: "title", at: now)
                        let modificationCallback = try syncEngine.modifyRecords(scope: .private, saving: [record])

                        await modificationCallback.notify()
                        try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                    }
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
                assertInlineSnapshot(of: container, as: .customDump(timestamps: true)) {
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
                            dueDate🗓️: 0,
                            id: 1,
                            id🗓️: 0,
                            isCompleted: 0,
                            isCompleted🗓️: 0,
                            priority🗓️: 0,
                            remindersListID: 1,
                            remindersListID🗓️: 0,
                            title: "Get milk",
                            title🗓️: 60000000000,
                            🗓️: 60000000000
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            id🗓️: 0,
                            title: "",
                            title🗓️: 0,
                            🗓️: 0
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

            @Test func `merge when the server record was edited and processed before the client`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "")
                        Reminder(id: 1, title: "", remindersListID: 1)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let record = try syncEngine.private.database.record(for: Reminder.recordID(for: 1))
                record.setValue("Buy milk", forKey: "title", at: 30_000_000_000)
                let modificationCallback = try syncEngine.modifyRecords(scope: .private, saving: [record])

                try await withTime(advancedBy: 60) {
                    try await userDatabase.userWrite { db in
                        try Reminder.find(1).update { $0.title = "Get milk" }.execute(db)
                    }
                }
                await modificationCallback.notify()
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                assertInlineSnapshot(of: container, as: .customDump(timestamps: true)) {
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
                            dueDate🗓️: 0,
                            id: 1,
                            id🗓️: 0,
                            isCompleted: 0,
                            isCompleted🗓️: 0,
                            priority🗓️: 0,
                            remindersListID: 1,
                            remindersListID🗓️: 0,
                            title: "Get milk",
                            title🗓️: 60000000000,
                            🗓️: 60000000000
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            id🗓️: 0,
                            title: "",
                            title🗓️: 0,
                            🗓️: 0
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

            @Test func `merge when the server record was edited before the client but processed after the client`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "")
                        Reminder(id: 1, title: "", remindersListID: 1)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let record = try syncEngine.private.database.record(for: Reminder.recordID(for: 1))
                record.setValue("Buy milk", forKey: "title", at: 30_000_000_000)
                let modificationCallback = try syncEngine.modifyRecords(scope: .private, saving: [record])

                try await withTime(advancedBy: 60) {
                    try await userDatabase.userWrite { db in
                        try Reminder.find(1).update { $0.title = "Get milk" }.execute(db)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                await modificationCallback.notify()
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                assertInlineSnapshot(of: container, as: .customDump(timestamps: true)) {
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
                            dueDate🗓️: 0,
                            id: 1,
                            id🗓️: 0,
                            isCompleted: 0,
                            isCompleted🗓️: 0,
                            priority🗓️: 0,
                            remindersListID: 1,
                            remindersListID🗓️: 0,
                            title: "Get milk",
                            title🗓️: 60000000000,
                            🗓️: 60000000000
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                            recordType: "remindersLists",
                            parent: nil,
                            share: nil,
                            id: 1,
                            id🗓️: 0,
                            title: "",
                            title🗓️: 0,
                            🗓️: 0
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

            @Test func `merge with nullable fields`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                        Reminder(id: 1, remindersListID: 1)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 1) {
                    let reminderRecord = try syncEngine.private.database.record(
                        for: Reminder.recordID(for: 1)
                    )
                    reminderRecord.setValue(
                        Date(timeIntervalSince1970: Double(30)),
                        forKey: "dueDate",
                        at: now
                    )
                    let modificationsFinished = try syncEngine.modifyRecords(
                        scope: .private,
                        saving: [reminderRecord]
                    )

                    try await withTime(advancedBy: 1) {
                        try await userDatabase.userWrite { db in
                            try Reminder.find(1).update { $0.priority = #bind(3) }.execute(db)
                        }
                        await modificationsFinished.notify()
                        try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                    }

                    assertInlineSnapshot(of: container, as: .customDump(timestamps: true)) {
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
                                dueDate: Date(1970-01-01T00:00:30.000Z),
                                dueDate🗓️: 1000000000,
                                id: 1,
                                id🗓️: 0,
                                isCompleted: 0,
                                isCompleted🗓️: 0,
                                priority: 3,
                                priority🗓️: 2000000000,
                                remindersListID: 1,
                                remindersListID🗓️: 0,
                                title: "",
                                title🗓️: 0,
                                🗓️: 2000000000
                              ),
                              [1]: CKRecord(
                                recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                                recordType: "remindersLists",
                                parent: nil,
                                share: nil,
                                id: 1,
                                id🗓️: 0,
                                title: "Personal",
                                title🗓️: 0,
                                🗓️: 0
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
                        let reminder = try #require(try Reminder.find(1).fetchOne(db))
                        #expect(
                            reminder
                                == Reminder(
                                    id: 1,
                                    dueDate: Time.Instant(secondsSinceUnixEpoch: 30),
                                    priority: 3,
                                    remindersListID: 1
                                )
                        )
                    }
                }
            }
        }
    }
#endif

