#if CloudKit
    import GRDB
    import CloudKit
    import InlineSnapshotTesting
    import SQL
    import SQLite
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Atomic zone changes`: CloudKitTestBase, @unchecked Sendable {
            @Test func `an edit conflict and a new record`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                let remindersListRecord = try syncEngine.private.database.record(
                    for: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue("My stuff", forKey: "title", at: 1_000_000_000)
                let (saveResults, _) = try syncEngine.private.database.modifyRecords(saving: [
                    remindersListRecord
                ])
                #expect(saveResults.values.allSatisfy { $0.error == nil })

                try await withTime(advancedBy: 2) {
                    try await userDatabase.userWrite { db in
                        try RemindersList.find(1).update { $0.title = "Stuff" }.execute(db)
                        try RemindersList.insert { RemindersList(id: 2, title: "Business") }.execute(db)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(
                    scope: .private,
                    forceAtomicByZone: true
                )

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

                try await syncEngine.processPendingRecordZoneChanges(
                    scope: .private,
                    forceAtomicByZone: true
                )

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
                            title: "Stuff"
                          ),
                          [1]: CKRecord(
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

            @Test func `an edit conflict and a deleted record`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                        RemindersList(id: 2, title: "Business")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(
                    scope: .private,
                    forceAtomicByZone: true
                )

                let remindersListRecord = try syncEngine.private.database.record(
                    for: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue("My stuff", forKey: "title", at: 1_000_000_000)
                let (saveResults, _) = try syncEngine.private.database.modifyRecords(saving: [
                    remindersListRecord
                ])
                #expect(saveResults.values.allSatisfy { $0.error == nil })

                try await withTime(advancedBy: 2) {
                    try await userDatabase.userWrite { db in
                        try RemindersList.find(1).update { $0.title = "Stuff" }.execute(db)
                        try RemindersList.find(2).delete().execute(db)
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(
                    scope: .private,
                    forceAtomicByZone: true
                )

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
                            title: "My stuff"
                          ),
                          [1]: CKRecord(
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

                try await syncEngine.processPendingRecordZoneChanges(
                    scope: .private,
                    forceAtomicByZone: true
                )

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
                            title: "Stuff"
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
#endif
