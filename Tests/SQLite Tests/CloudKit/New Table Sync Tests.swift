#if CloudKit
    import GRDB
    import CloudKit
    import InlineSnapshotTesting
    import SQL
    import SQLite
    import SQLite_Test_Support
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `New table sync`: CloudKitTestBase, @unchecked Sendable {
            init() async throws {
                try await super.init(prepareDatabase: { userDatabase in
                    try await userDatabase.userWrite { db in
                        try db.seed {
                            RemindersList(id: 1, title: "Personal")
                            Reminder(id: 1, title: "Write blog post", remindersListID: 1)
                        }
                    }
                })
            }

            @Test func `sends records created before the sync engine started`() async throws {
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
                            title: "Write blog post"
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

                assertQuery(
                    SyncMetadata.order(by: \.recordName).select(\.recordName),
                    database: syncEngine.metadatabase
                ) {
                    """
                    ┌────────────────────┐
                    │ "1:reminders"      │
                    │ "1:remindersLists" │
                    └────────────────────┘
                    """
                }
            }
        }
    }
#endif
