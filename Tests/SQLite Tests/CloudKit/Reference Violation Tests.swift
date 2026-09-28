#if CloudKit
    import CloudKit
    import InlineSnapshotTesting
    import SQL
    import SQL_Macros
    import SQLite
    import SQLite_Test_Support
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Reference violations`: CloudKitTestBase, @unchecked Sendable {
            @Test func `moving a reminder to a list the remote deletes deletes the reminder`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                        RemindersList(id: 2, title: "Business")
                        Reminder(id: 1, title: "Get milk", remindersListID: 1)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let modifications = try syncEngine.modifyRecords(
                    scope: .private,
                    deleting: [RemindersList.recordID(for: 2)]
                )
                try withTime(advancedBy: 1) {
                    try userDatabase.userWrite { db in
                        try Reminder.find(1).update { $0.remindersListID = 2 }.execute(db)
                    }
                }

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                await modifications.notify()
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await userDatabase.read { db in
                    try #expect(Reminder.find(1).fetchCount(db) == 0)
                    try #expect(RemindersList.find(2).fetchCount(db) == 0)
                }
                assertInlineSnapshot(of: container, as: .customDump) {
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

                try await userDatabase.read { db in
                    try #expect(Reminder.count().fetchOne(db) == 0)
                    try #expect(
                        RemindersList.all.fetchAll(db) == [
                            RemindersList(id: 1, title: "Personal")
                        ]
                    )
                }
            }

            @Test func `deleting a list the remote adds a reminder to is rejected when local changes are sent first`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 1) {
                    try await userDatabase.userWrite { db in
                        try RemindersList.find(1).delete().execute(db)
                    }
                }
                let modifications = try withTime(advancedBy: 2) {
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
                    return try syncEngine.modifyRecords(scope: .private, saving: [reminderRecord])
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                await modifications.notify()

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

                try await userDatabase.read { db in
                    try #expect(
                        Reminder.all.fetchAll(db) == [Reminder(id: 1, title: "Get milk", remindersListID: 1)]
                    )
                    try #expect(
                        RemindersList.all.fetchAll(db) == [RemindersList(id: 1, title: "Personal")]
                    )
                }
            }

            @Test func `deleting a list the remote adds a reminder to is rejected when remote changes arrive first`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 1) {
                    try await userDatabase.userWrite { db in
                        try RemindersList.find(1).delete().execute(db)
                    }
                }
                let modifications = try withTime(advancedBy: 2) {
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
                    return try syncEngine.modifyRecords(scope: .private, saving: [reminderRecord])
                }
                await modifications.notify()
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

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

                try await userDatabase.read { db in
                    try #expect(
                        Reminder.all.fetchAll(db) == [Reminder(id: 1, title: "Get milk", remindersListID: 1)]
                    )
                    try #expect(
                        RemindersList.all.fetchAll(db) == [RemindersList(id: 1, title: "Personal")]
                    )
                }
            }

            @Test func `moving a child to a parent the remote deletes sets the reference to null`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        Parent(id: 1)
                        Parent(id: 2)
                        ChildWithOnDeleteSetNull(id: 1, parentID: 1)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let modifications = try syncEngine.modifyRecords(
                    scope: .private,
                    deleting: [Parent.recordID(for: 2)]
                )
                try await withTime(advancedBy: 1) {
                    try await userDatabase.userWrite { db in
                        try ChildWithOnDeleteSetNull.find(1).update { $0.parentID = #bind(2) }.execute(db)
                    }
                }
                try await withTime(advancedBy: 2) {
                    try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                    await modifications.notify()
                    try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                    assertInlineSnapshot(of: container, as: .customDump) {
                        """
                        MockCloudContainer(
                          privateCloudDatabase: MockCloudDatabase(
                            databaseScope: .private,
                            storage: [
                              [0]: CKRecord(
                                recordID: CKRecord.ID(1:childWithOnDeleteSetNulls/zone/__defaultOwner__),
                                recordType: "childWithOnDeleteSetNulls",
                                parent: nil,
                                share: nil,
                                id: 1
                              ),
                              [1]: CKRecord(
                                recordID: CKRecord.ID(1:parents/zone/__defaultOwner__),
                                recordType: "parents",
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
                    assertQuery(ChildWithOnDeleteSetNull.all, database: userDatabase.database) {
                        """
                        ┌───────────────────────────┐
                        │ ChildWithOnDeleteSetNull( │
                        │   id: 1,                  │
                        │   parentID: nil           │
                        │ )                         │
                        └───────────────────────────┘
                        """
                    }
                    assertQuery(Parent.all, database: userDatabase.database) {
                        """
                        ┌───────────────┐
                        │ Parent(id: 1) │
                        └───────────────┘
                        """
                    }
                }
            }

            @Test func `moving a child to a parent the remote deletes sets the reference to its default`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        Parent(id: 0)
                        Parent(id: 1)
                        Parent(id: 2)
                        ChildWithOnDeleteSetDefault(id: 1, parentID: 1)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let modifications = try syncEngine.modifyRecords(
                    scope: .private,
                    deleting: [Parent.recordID(for: 2)]
                )
                try await withTime(advancedBy: 1) {
                    try await userDatabase.userWrite { db in
                        try ChildWithOnDeleteSetDefault.find(1).update { $0.parentID = 2 }.execute(db)
                    }
                }
                try await withTime(advancedBy: 2) {
                    try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                    await modifications.notify()
                    try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                    assertInlineSnapshot(of: container, as: .customDump) {
                        """
                        MockCloudContainer(
                          privateCloudDatabase: MockCloudDatabase(
                            databaseScope: .private,
                            storage: [
                              [0]: CKRecord(
                                recordID: CKRecord.ID(1:childWithOnDeleteSetDefaults/zone/__defaultOwner__),
                                recordType: "childWithOnDeleteSetDefaults",
                                parent: CKReference(recordID: CKRecord.ID(0:parents/zone/__defaultOwner__)),
                                share: nil,
                                id: 1,
                                parentID: 0
                              ),
                              [1]: CKRecord(
                                recordID: CKRecord.ID(0:parents/zone/__defaultOwner__),
                                recordType: "parents",
                                parent: nil,
                                share: nil,
                                id: 0
                              ),
                              [2]: CKRecord(
                                recordID: CKRecord.ID(1:parents/zone/__defaultOwner__),
                                recordType: "parents",
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
                    try await userDatabase.read { db in
                        try #expect(
                            ChildWithOnDeleteSetDefault.all.fetchAll(db) == [
                                ChildWithOnDeleteSetDefault(id: 1, parentID: 0)
                            ]
                        )
                        try #expect(
                            Parent.all.fetchAll(db) == [Parent(id: 0), Parent(id: 1)]
                        )
                    }
                }
            }
        }
    }
#endif
