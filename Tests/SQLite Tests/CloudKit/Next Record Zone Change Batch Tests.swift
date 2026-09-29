#if CloudKit
    import GRDB
    import CloudKit
    import InlineSnapshotTesting
    import SQL
    import SQL_Macros
    import SQLite
    import SQLite_Test_Support
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Next record zone change batch`: CloudKitTestBase, @unchecked Sendable {
            @Test func `sends nothing for a record without metadata`() async throws {
                syncEngine.private.state.add(
                    pendingRecordZoneChanges: [.saveRecord(Reminder.recordID(for: 1))]
                )

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
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

            @Test func `sends nothing for a non-existent table`() async throws {
                try await userDatabase.userWrite { db in
                    try SyncMetadata.insert {
                        SyncMetadata(
                            recordPrimaryKey: "1",
                            recordType: UnrecognizedTable.tableName,
                            zoneName: "zone-name",
                            ownerName: "owner-name",
                            userModificationTime: 0
                        )
                    }
                    .execute(db)
                }

                try await syncEngine.processPendingRecordZoneChanges(scope: .shared)
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

            @Test func `CloudKit sending a non-existent table`() async throws {
                let record = CKRecord(
                    recordType: UnrecognizedTable.tableName,
                    recordID: UnrecognizedTable.recordID(for: 1)
                )
                record.setValue(1, forKey: "id", at: now)
                try await syncEngine.modifyRecords(scope: .private, saving: [record]).notify()

                assertQuery(SyncMetadata.select(\.recordName), database: syncEngine.metadatabase) {
                    """
                    ┌────────────────────────┐
                    │ "1:unrecognizedTables" │
                    └────────────────────────┘
                    """
                }

                try await syncEngine.modifyRecords(scope: .private, deleting: [record.recordID]).notify()

                assertQuery(SyncMetadata.select(\.recordName), database: syncEngine.metadatabase) {
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

            @Test func `sends nothing for a metadata row with no corresponding record row`() async throws {
                try await userDatabase.userWrite { db in
                    try SyncMetadata.insert {
                        SyncMetadata(
                            recordPrimaryKey: "1",
                            recordType: RemindersList.tableName,
                            zoneName: syncEngine.defaultZone.zoneID.zoneName,
                            ownerName: syncEngine.defaultZone.zoneID.ownerName,
                            userModificationTime: 0
                        )
                    }
                    .execute(db)
                }

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
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

            @Test func `saves a record`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
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
            }

            @Test func `saves a record with a parent`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                        Reminder(id: 1, title: "Get milk", remindersListID: 1)
                    }
                }

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
                            isCompleted: 0,
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

            @Test func `saves a private record`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                        RemindersListPrivate(remindersListID: 1, position: 42)
                    }
                }

                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(1:remindersListPrivates/zone/__defaultOwner__),
                            recordType: "remindersListPrivates",
                            parent: nil,
                            share: nil,
                            position: 42,
                            remindersListID: 1
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

            @Test func `editing between the batch and the sent record zone changes`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 1) {
                    try await userDatabase.userWrite { db in
                        try RemindersList.find(1).update { $0.title = "Personal 2" }.execute(db)
                    }

                    let changes = try await syncEngine.sendPendingRecordZoneChanges(scope: .private)

                    try await withTime(advancedBy: 1) {
                        try await userDatabase.userWrite { db in
                            try RemindersList.find(1).update { $0.title = "Personal 3" }.execute(db)
                        }
                        await changes.receive()
                        try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                        try await userDatabase.read { db in
                            try #expect(RemindersList.fetchAll(db) == [RemindersList(id: 1, title: "Personal 3")])
                        }
                        assertInlineSnapshot(of: syncEngine.container, as: .customDump(timestamps: true, recordChangeTags: true)) {
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
                                    recordChangeTag: 3,
                                    id: 1,
                                    id🗓️: 0,
                                    title: "Personal 3",
                                    title🗓️: 2000000000,
                                    🗓️: 2000000000
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
    }

    @Table("unrecognizedTables")
    private struct UnrecognizedTable {
        let id: Int
    }
#endif
