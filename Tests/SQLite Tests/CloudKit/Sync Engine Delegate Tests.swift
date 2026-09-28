#if CloudKit
    import CloudKit
    import InlineSnapshotTesting
    import SQL
    import SQLite
    import SQLite_Test_Support
    import Synchronization
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Sync engine delegate`: CloudKitTestBase, @unchecked Sendable {
            init() async throws {
                try await super.init(delegate: AccountChangeRecordingDelegate())
            }

            @Test func `account change calls the delegate`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                await signOut()

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

                try await userDatabase.userWrite { db in
                    try RemindersList.find(1).update { $0.title = "My stuff" }.execute(db)
                }

                assertQuery(RemindersList.all, database: userDatabase.database) {
                    """
                    ┌─────────────────────┐
                    │ RemindersList(      │
                    │   id: 1,            │
                    │   title: "My stuff" │
                    │ )                   │
                    └─────────────────────┘
                    """
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

                await signIn()
                try await syncEngine.processPendingDatabaseChanges(scope: .private)
            }
        }

        @MainActor
        final class `Sync engine delegate default implementation`: CloudKitTestBase, @unchecked Sendable {
            init() async throws {
                try await super.init(delegate: DefaultImplementationDelegate())
            }

            @Test func `account change with the default implementation deletes local data`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                await signOut()

                assertQuery(RemindersList.all, database: userDatabase.database) {
                    """
                    (No results)
                    """
                }
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
        }
    }

    private final class AccountChangeRecordingDelegate: SyncEngineDelegate {
        let wasCalled = Mutex(false)
        func syncEngine(
            _ syncEngine: SyncEngine,
            accountChanged changeType: CKSyncEngine.Event.AccountChange.ChangeType
        ) async {
            wasCalled.withLock { $0 = true }
        }
        deinit {
            guard wasCalled.withLock({ $0 }) || Test.current == nil
            else {
                Issue.record("Delegate method 'syncEngine(_:accountChanged:)' was not called.")
                return
            }
        }
    }

    private final class DefaultImplementationDelegate: SyncEngineDelegate {}
#endif
