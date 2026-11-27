#if CloudKit && canImport(CloudKit)
    import CloudKit
    import SQL
    import SQLite
    import SQLite_CloudKit
    import SQLite_Test_Support
    import Testing
    import Tests_Inline_Snapshot

    extension CloudKitTestBase {
        @MainActor
        final class `Attached metadatabase`: CloudKitTestBase, @unchecked Sendable {
            init() async throws {
                try await super.init(attachMetadatabase: true)
            }

            /// `attachMetadatabase` in `prepareDatabase` runs on every connection the driver opens: the writer, each
            /// reader, and the connection of the synchronous read.
            @Test func `every connection of the database sees the metadata`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)
                let database = userDatabase.sqliteDatabase
                let count = SyncMetadata.count()

                let onWriter = try await database.write { try count.fetch.one($0) }
                let onReader = try await database.read { try count.fetch.one($0) }
                // In a synchronous function, so that the synchronous read is the one called.
                func read() throws -> Int? { try database.read { try count.fetch.one($0) } }
                let synchronous = try read()

                #expect(onWriter == 1)
                #expect(onReader == 1)
                #expect(synchronous == 1)
            }

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
