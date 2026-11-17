#if CloudKit && canImport(CloudKit)
    import CloudKit
    import GRDB
    import SQL
    import SQLite
    import SQLite_CloudKit
    import SQLite_Test_Support
    import Testing
    import Tests_Inline_Snapshot

    extension CloudKitTestBase {
        @MainActor
        final class `Attached metadatabase`: CloudKitTestBase, @unchecked Sendable {
            @Test func `basics`() async throws {
                let remindersList = RemindersList(id: 1, title: "Personal")
                try await userDatabase.userWrite { db in
                    try db.seed {
                        remindersList
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                await snapshot(as: .rows(writing: userDatabase.sqliteDatabase, drawing: State.draw)) {
                    RemindersList
                        .leftJoin(SyncMetadata.all) { $0.syncMetadataID.eq($1.id) }
                } matches: {
                    """
                    ┌─────────────────────┬────────────────────────────────────────────────────────────────────┐
                    │ RemindersList(      │ SyncMetadata(                                                      │
                    │   id: 1,            │   id: ID(recordPrimaryKey: "1", recordType: "remindersLists"),     │
                    │   title: "Personal" │   zoneName: "zone",                                                │
                    │ )                   │   ownerName: "__defaultOwner__",                                   │
                    │                     │   recordName: "1:remindersLists",                                  │
                    │                     │   parentRecordID: nil,                                             │
                    │                     │   parentRecordName: nil,                                           │
                    │                     │   lastKnownServerRecord: CKRecord(                                 │
                    │                     │     recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__), │
                    │                     │     recordType: "remindersLists",                                  │
                    │                     │     parent: nil,                                                   │
                    │                     │     share: nil                                                     │
                    │                     │   ),                                                               │
                    │                     │   _lastKnownServerRecordAllFields: CKRecord(                       │
                    │                     │     recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__), │
                    │                     │     recordType: "remindersLists",                                  │
                    │                     │     parent: nil,                                                   │
                    │                     │     share: nil,                                                    │
                    │                     │     id: 1,                                                         │
                    │                     │     title: "Personal"                                              │
                    │                     │   ),                                                               │
                    │                     │   share: nil,                                                      │
                    │                     │   _isDeleted: false,                                               │
                    │                     │   _hasLastKnownServerRecord: true,                                 │
                    │                     │   _isShared: false,                                                │
                    │                     │   userModificationTime: 0                                          │
                    │                     │ )                                                                  │
                    └─────────────────────┴────────────────────────────────────────────────────────────────────┘
                    """
                }
            }
        }
    }
#endif
