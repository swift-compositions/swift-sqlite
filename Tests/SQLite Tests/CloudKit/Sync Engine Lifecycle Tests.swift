#if CloudKit
    import CloudKit
    import Foundation
    import InlineSnapshotTesting
    import SQL
    import SQLite
    import SQLite_Test_Support
    import Testing

    extension CloudKitTestBase {
        @Suite struct `Sync engine lifecycle` {
            @MainActor
            final class `Immediately started`: CloudKitTestBase, @unchecked Sendable {
                @Test func `stopping and restarting sends changes written while stopped`() async throws {
                    syncEngine.stop()

                    try await userDatabase.userWrite { db in
                        try db.seed {
                            RemindersList(id: 1, title: "Personal")
                            Reminder(id: 1, title: "Get milk", remindersListID: 1)
                        }
                    }

                    try await Task.sleep(for: .seconds(1))

                    assertQuery(SyncMetadata.all, database: syncEngine.metadatabase) {
                        """
                        ┌──────────────────────────────────────────┐
                        │ SyncMetadata(                            │
                        │   id: SyncMetadata.ID(                   │
                        │     recordPrimaryKey: "1",               │
                        │     recordType: "remindersLists"         │
                        │   ),                                     │
                        │   zoneName: "zone",                      │
                        │   ownerName: "__defaultOwner__",         │
                        │   recordName: "1:remindersLists",        │
                        │   parentRecordID: nil,                   │
                        │   parentRecordName: nil,                 │
                        │   lastKnownServerRecord: nil,            │
                        │   _lastKnownServerRecordAllFields: nil,  │
                        │   share: nil,                            │
                        │   _isDeleted: false,                     │
                        │   _hasLastKnownServerRecord: false,      │
                        │   _isShared: false,                      │
                        │   userModificationTime: 0                │
                        │ )                                        │
                        ├──────────────────────────────────────────┤
                        │ SyncMetadata(                            │
                        │   id: SyncMetadata.ID(                   │
                        │     recordPrimaryKey: "1",               │
                        │     recordType: "reminders"              │
                        │   ),                                     │
                        │   zoneName: "zone",                      │
                        │   ownerName: "__defaultOwner__",         │
                        │   recordName: "1:reminders",             │
                        │   parentRecordID: SyncMetadata.ParentID( │
                        │     parentRecordPrimaryKey: "1",         │
                        │     parentRecordType: "remindersLists"   │
                        │   ),                                     │
                        │   parentRecordName: "1:remindersLists",  │
                        │   lastKnownServerRecord: nil,            │
                        │   _lastKnownServerRecordAllFields: nil,  │
                        │   share: nil,                            │
                        │   _isDeleted: false,                     │
                        │   _hasLastKnownServerRecord: false,      │
                        │   _isShared: false,                      │
                        │   userModificationTime: 0                │
                        │ )                                        │
                        └──────────────────────────────────────────┘
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

                    try await syncEngine.start()
                    try await syncEngine.processPendingDatabaseChanges(scope: .private)
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

                @Test func `a list deleted while stopped is deleted from CloudKit on restart`() async throws {
                    try await userDatabase.userWrite { db in
                        try db.seed {
                            RemindersList(id: 1, title: "Personal")
                        }
                    }
                    try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                    syncEngine.stop()

                    try await userDatabase.userWrite { db in
                        try RemindersList.find(1).delete().execute(db)
                    }

                    try await Task.sleep(for: .seconds(1))

                    try await syncEngine.start()
                    try await syncEngine.processPendingDatabaseChanges(scope: .private)
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

                @Test func `a list edited while stopped is updated in CloudKit on restart`() async throws {
                    try await userDatabase.userWrite { db in
                        try db.seed {
                            RemindersList(id: 1, title: "Personal")
                        }
                    }
                    try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                    syncEngine.stop()

                    try await withTime(advancedBy: 1) {
                        try await userDatabase.userWrite { db in
                            try RemindersList.find(1).update { $0.title += "!" }.execute(db)
                        }
                    }
                    try await Task.sleep(for: .seconds(0.5))

                    assertQuery(PendingRecordZoneChange.all, database: syncEngine.metadatabase) {
                        """
                        ┌─────────────────────────────────────────────────────────────────────────────────────────────┐
                        │ PendingRecordZoneChange(                                                                    │
                        │   pendingRecordZoneChange: .saveRecord(CKRecord.ID(1:remindersLists/zone/__defaultOwner__)) │
                        │ )                                                                                           │
                        └─────────────────────────────────────────────────────────────────────────────────────────────┘
                        """
                    }
                    assertQuery(RemindersList.all, database: userDatabase.database) {
                        """
                        ┌──────────────────────┐
                        │ RemindersList(       │
                        │   id: 1,             │
                        │   title: "Personal!" │
                        │ )                    │
                        └──────────────────────┘
                        """
                    }

                    try await syncEngine.start()
                    try await syncEngine.processPendingDatabaseChanges(scope: .private)
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
                                title: "Personal!"
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
                    assertQuery(PendingRecordZoneChange.all, database: syncEngine.metadatabase) {
                        """
                        (No results)
                        """
                    }
                }

                @Test func `a write to a received shared record while stopped is sent on restart`() async throws {
                    let externalZoneID = CKRecordZone.ID(
                        zoneName: "external.zone",
                        ownerName: "external.owner"
                    )
                    let externalZone = CKRecordZone(zoneID: externalZoneID)

                    let remindersListRecord = CKRecord(
                        recordType: RemindersList.tableName,
                        recordID: RemindersList.recordID(for: 1, zoneID: externalZoneID)
                    )
                    remindersListRecord.setValue(1, forKey: "id", at: now)
                    remindersListRecord.setValue(false, forKey: "isCompleted", at: now)
                    remindersListRecord.setValue("Personal", forKey: "title", at: now)
                    let share = CKShare(
                        rootRecord: remindersListRecord,
                        shareID: CKRecord.ID(
                            recordName: "share-\(remindersListRecord.recordID.recordName)",
                            zoneID: remindersListRecord.recordID.zoneID
                        )
                    )

                    try await syncEngine.modifyRecordZones(scope: .shared, saving: [externalZone]).notify()
                    try await syncEngine.modifyRecords(
                        scope: .shared,
                        saving: [remindersListRecord, share]
                    ).notify()

                    syncEngine.stop()

                    try await withTime(advancedBy: 60) {
                        try await userDatabase.userWrite { db in
                            try db.seed {
                                Reminder(id: 1, title: "Get milk", remindersListID: 1)
                            }
                        }
                    }

                    try await Task.sleep(for: .seconds(1))
                    assertQuery(SyncMetadata.all, database: syncEngine.metadatabase) {
                        """
                        ┌─────────────────────────────────────────────────────────────────────────────────────────────────────┐
                        │ SyncMetadata(                                                                                       │
                        │   id: SyncMetadata.ID(                                                                              │
                        │     recordPrimaryKey: "1",                                                                          │
                        │     recordType: "remindersLists"                                                                    │
                        │   ),                                                                                                │
                        │   zoneName: "external.zone",                                                                        │
                        │   ownerName: "external.owner",                                                                      │
                        │   recordName: "1:remindersLists",                                                                   │
                        │   parentRecordID: nil,                                                                              │
                        │   parentRecordName: nil,                                                                            │
                        │   lastKnownServerRecord: CKRecord(                                                                  │
                        │     recordID: CKRecord.ID(1:remindersLists/external.zone/external.owner),                           │
                        │     recordType: "remindersLists",                                                                   │
                        │     parent: nil,                                                                                    │
                        │     share: CKReference(recordID: CKRecord.ID(share-1:remindersLists/external.zone/external.owner))  │
                        │   ),                                                                                                │
                        │   _lastKnownServerRecordAllFields: CKRecord(                                                        │
                        │     recordID: CKRecord.ID(1:remindersLists/external.zone/external.owner),                           │
                        │     recordType: "remindersLists",                                                                   │
                        │     parent: nil,                                                                                    │
                        │     share: CKReference(recordID: CKRecord.ID(share-1:remindersLists/external.zone/external.owner)), │
                        │     id: 1,                                                                                          │
                        │     isCompleted: 0,                                                                                 │
                        │     title: "Personal"                                                                               │
                        │   ),                                                                                                │
                        │   share: CKRecord(                                                                                  │
                        │     recordID: CKRecord.ID(share-1:remindersLists/external.zone/external.owner),                     │
                        │     recordType: "cloudkit.share",                                                                   │
                        │     parent: nil,                                                                                    │
                        │     share: nil                                                                                      │
                        │   ),                                                                                                │
                        │   _isDeleted: false,                                                                                │
                        │   _hasLastKnownServerRecord: true,                                                                  │
                        │   _isShared: true,                                                                                  │
                        │   userModificationTime: 0                                                                           │
                        │ )                                                                                                   │
                        ├─────────────────────────────────────────────────────────────────────────────────────────────────────┤
                        │ SyncMetadata(                                                                                       │
                        │   id: SyncMetadata.ID(                                                                              │
                        │     recordPrimaryKey: "1",                                                                          │
                        │     recordType: "reminders"                                                                         │
                        │   ),                                                                                                │
                        │   zoneName: "external.zone",                                                                        │
                        │   ownerName: "external.owner",                                                                      │
                        │   recordName: "1:reminders",                                                                        │
                        │   parentRecordID: SyncMetadata.ParentID(                                                            │
                        │     parentRecordPrimaryKey: "1",                                                                    │
                        │     parentRecordType: "remindersLists"                                                              │
                        │   ),                                                                                                │
                        │   parentRecordName: "1:remindersLists",                                                             │
                        │   lastKnownServerRecord: nil,                                                                       │
                        │   _lastKnownServerRecordAllFields: nil,                                                             │
                        │   share: nil,                                                                                       │
                        │   _isDeleted: false,                                                                                │
                        │   _hasLastKnownServerRecord: false,                                                                 │
                        │   _isShared: false,                                                                                 │
                        │   userModificationTime: 60000000000                                                                 │
                        │ )                                                                                                   │
                        └─────────────────────────────────────────────────────────────────────────────────────────────────────┘
                        """
                    }

                    try await Task.sleep(for: .seconds(0.5))
                    try await syncEngine.start()
                    try await syncEngine.processPendingDatabaseChanges(scope: .private)
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
                            storage: [
                              [0]: CKRecord(
                                recordID: CKRecord.ID(share-1:remindersLists/external.zone/external.owner),
                                recordType: "cloudkit.share",
                                parent: nil,
                                share: nil
                              ),
                              [1]: CKRecord(
                                recordID: CKRecord.ID(1:reminders/external.zone/external.owner),
                                recordType: "reminders",
                                parent: CKReference(recordID: CKRecord.ID(1:remindersLists/external.zone/external.owner)),
                                share: nil,
                                id: 1,
                                isCompleted: 0,
                                remindersListID: 1,
                                title: "Get milk"
                              ),
                              [2]: CKRecord(
                                recordID: CKRecord.ID(1:remindersLists/external.zone/external.owner),
                                recordType: "remindersLists",
                                parent: nil,
                                share: CKReference(recordID: CKRecord.ID(share-1:remindersLists/external.zone/external.owner)),
                                id: 1,
                                isCompleted: 0,
                                title: "Personal"
                              )
                            ]
                          )
                        )
                        """
                    }
                }

                @Test func `deleting an external shared root record while stopped deletes only the share on restart`() async throws {
                    let externalZoneID = CKRecordZone.ID(
                        zoneName: "external.zone",
                        ownerName: "external.owner"
                    )
                    let externalZone = CKRecordZone(zoneID: externalZoneID)
                    try await syncEngine.modifyRecordZones(scope: .shared, saving: [externalZone]).notify()

                    let remindersListRecord = CKRecord(
                        recordType: RemindersList.tableName,
                        recordID: RemindersList.recordID(for: 1, zoneID: externalZoneID)
                    )
                    remindersListRecord.setValue(1, forKey: "id", at: now)
                    remindersListRecord.setValue(false, forKey: "isCompleted", at: now)
                    remindersListRecord.setValue("Personal", forKey: "title", at: now)
                    let share = CKShare(
                        rootRecord: remindersListRecord,
                        shareID: CKRecord.ID(
                            recordName: "share-\(remindersListRecord.recordID.recordName)",
                            zoneID: remindersListRecord.recordID.zoneID
                        )
                    )

                    try await syncEngine.modifyRecords(
                        scope: .shared,
                        saving: [remindersListRecord, share]
                    ).notify()

                    assertInlineSnapshot(of: container, as: .customDump) {
                        """
                        MockCloudContainer(
                          privateCloudDatabase: MockCloudDatabase(
                            databaseScope: .private,
                            storage: []
                          ),
                          sharedCloudDatabase: MockCloudDatabase(
                            databaseScope: .shared,
                            storage: [
                              [0]: CKRecord(
                                recordID: CKRecord.ID(share-1:remindersLists/external.zone/external.owner),
                                recordType: "cloudkit.share",
                                parent: nil,
                                share: nil
                              ),
                              [1]: CKRecord(
                                recordID: CKRecord.ID(1:remindersLists/external.zone/external.owner),
                                recordType: "remindersLists",
                                parent: nil,
                                share: CKReference(recordID: CKRecord.ID(share-1:remindersLists/external.zone/external.owner)),
                                id: 1,
                                isCompleted: 0,
                                title: "Personal"
                              )
                            ]
                          )
                        )
                        """
                    }

                    syncEngine.stop()

                    try await userDatabase.userWrite { db in
                        try RemindersList.find(1).delete().execute(db)
                    }
                    try await Task.sleep(for: .seconds(1))

                    try await syncEngine.start()
                    try await syncEngine.processPendingDatabaseChanges(scope: .private)
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
                            storage: [
                              [0]: CKRecord(
                                recordID: CKRecord.ID(1:remindersLists/external.zone/external.owner),
                                recordType: "remindersLists",
                                parent: nil,
                                share: CKReference(recordID: CKRecord.ID(share-1:remindersLists/external.zone/external.owner)),
                                id: 1,
                                isCompleted: 0,
                                title: "Personal"
                              )
                            ]
                          )
                        )
                        """
                    }
                }

                @Test func `deleting an owned shared record while stopped deletes it and its share on restart`() async throws {
                    let remindersList = RemindersList(id: 1, title: "Personal")
                    try await userDatabase.userWrite { db in
                        try db.seed { remindersList }
                    }
                    try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                    _ = try await syncEngine.share(record: remindersList, configure: { _ in })
                    assertInlineSnapshot(of: container, as: .customDump) {
                        """
                        MockCloudContainer(
                          privateCloudDatabase: MockCloudDatabase(
                            databaseScope: .private,
                            storage: [
                              [0]: CKRecord(
                                recordID: CKRecord.ID(share-1:remindersLists/zone/__defaultOwner__),
                                recordType: "cloudkit.share",
                                parent: nil,
                                share: nil
                              ),
                              [1]: CKRecord(
                                recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),
                                recordType: "remindersLists",
                                parent: nil,
                                share: CKReference(recordID: CKRecord.ID(share-1:remindersLists/zone/__defaultOwner__)),
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

                    syncEngine.stop()

                    try await userDatabase.userWrite { db in
                        try RemindersList.find(1).delete().execute(db)
                    }

                    try await Task.sleep(for: .seconds(0.5))
                    try await syncEngine.start()
                    try await syncEngine.processPendingDatabaseChanges(scope: .private)
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
            }

            @MainActor
            final class `Not started immediately`: CloudKitTestBase, @unchecked Sendable {
                init() async throws {
                    try await super.init(startImmediately: false)
                }

                @Test func `rows written before starting get metadata and are sent once started`() async throws {
                    try await userDatabase.userWrite { db in
                        try db.seed {
                            RemindersList(id: 1, title: "Personal")
                            Reminder(id: 1, title: "Get milk", remindersListID: 1)
                        }
                    }
                    try await Task.sleep(for: .seconds(1))

                    assertQuery(SyncMetadata.all, database: syncEngine.metadatabase) {
                        """
                        ┌──────────────────────────────────────────┐
                        │ SyncMetadata(                            │
                        │   id: SyncMetadata.ID(                   │
                        │     recordPrimaryKey: "1",               │
                        │     recordType: "remindersLists"         │
                        │   ),                                     │
                        │   zoneName: "zone",                      │
                        │   ownerName: "__defaultOwner__",         │
                        │   recordName: "1:remindersLists",        │
                        │   parentRecordID: nil,                   │
                        │   parentRecordName: nil,                 │
                        │   lastKnownServerRecord: nil,            │
                        │   _lastKnownServerRecordAllFields: nil,  │
                        │   share: nil,                            │
                        │   _isDeleted: false,                     │
                        │   _hasLastKnownServerRecord: false,      │
                        │   _isShared: false,                      │
                        │   userModificationTime: 0                │
                        │ )                                        │
                        ├──────────────────────────────────────────┤
                        │ SyncMetadata(                            │
                        │   id: SyncMetadata.ID(                   │
                        │     recordPrimaryKey: "1",               │
                        │     recordType: "reminders"              │
                        │   ),                                     │
                        │   zoneName: "zone",                      │
                        │   ownerName: "__defaultOwner__",         │
                        │   recordName: "1:reminders",             │
                        │   parentRecordID: SyncMetadata.ParentID( │
                        │     parentRecordPrimaryKey: "1",         │
                        │     parentRecordType: "remindersLists"   │
                        │   ),                                     │
                        │   parentRecordName: "1:remindersLists",  │
                        │   lastKnownServerRecord: nil,            │
                        │   _lastKnownServerRecordAllFields: nil,  │
                        │   share: nil,                            │
                        │   _isDeleted: false,                     │
                        │   _hasLastKnownServerRecord: false,      │
                        │   _isShared: false,                      │
                        │   userModificationTime: 0                │
                        │ )                                        │
                        └──────────────────────────────────────────┘
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

                    try await syncEngine.start()
                    await signIn()
                    try await syncEngine.processPendingDatabaseChanges(scope: .private)
                    try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                    assertQuery(SyncMetadata.all, database: syncEngine.metadatabase) {
                        """
                        ┌─────────────────────────────────────────────────────────────────────────────────────────┐
                        │ SyncMetadata(                                                                           │
                        │   id: SyncMetadata.ID(                                                                  │
                        │     recordPrimaryKey: "1",                                                              │
                        │     recordType: "remindersLists"                                                        │
                        │   ),                                                                                    │
                        │   zoneName: "zone",                                                                     │
                        │   ownerName: "__defaultOwner__",                                                        │
                        │   recordName: "1:remindersLists",                                                       │
                        │   parentRecordID: nil,                                                                  │
                        │   parentRecordName: nil,                                                                │
                        │   lastKnownServerRecord: CKRecord(                                                      │
                        │     recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),                      │
                        │     recordType: "remindersLists",                                                       │
                        │     parent: nil,                                                                        │
                        │     share: nil                                                                          │
                        │   ),                                                                                    │
                        │   _lastKnownServerRecordAllFields: CKRecord(                                            │
                        │     recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__),                      │
                        │     recordType: "remindersLists",                                                       │
                        │     parent: nil,                                                                        │
                        │     share: nil,                                                                         │
                        │     id: 1,                                                                              │
                        │     title: "Personal"                                                                   │
                        │   ),                                                                                    │
                        │   share: nil,                                                                           │
                        │   _isDeleted: false,                                                                    │
                        │   _hasLastKnownServerRecord: true,                                                      │
                        │   _isShared: false,                                                                     │
                        │   userModificationTime: 0                                                               │
                        │ )                                                                                       │
                        ├─────────────────────────────────────────────────────────────────────────────────────────┤
                        │ SyncMetadata(                                                                           │
                        │   id: SyncMetadata.ID(                                                                  │
                        │     recordPrimaryKey: "1",                                                              │
                        │     recordType: "reminders"                                                             │
                        │   ),                                                                                    │
                        │   zoneName: "zone",                                                                     │
                        │   ownerName: "__defaultOwner__",                                                        │
                        │   recordName: "1:reminders",                                                            │
                        │   parentRecordID: SyncMetadata.ParentID(                                                │
                        │     parentRecordPrimaryKey: "1",                                                        │
                        │     parentRecordType: "remindersLists"                                                  │
                        │   ),                                                                                    │
                        │   parentRecordName: "1:remindersLists",                                                 │
                        │   lastKnownServerRecord: CKRecord(                                                      │
                        │     recordID: CKRecord.ID(1:reminders/zone/__defaultOwner__),                           │
                        │     recordType: "reminders",                                                            │
                        │     parent: CKReference(recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__)), │
                        │     share: nil                                                                          │
                        │   ),                                                                                    │
                        │   _lastKnownServerRecordAllFields: CKRecord(                                            │
                        │     recordID: CKRecord.ID(1:reminders/zone/__defaultOwner__),                           │
                        │     recordType: "reminders",                                                            │
                        │     parent: CKReference(recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__)), │
                        │     share: nil,                                                                         │
                        │     id: 1,                                                                              │
                        │     isCompleted: 0,                                                                     │
                        │     remindersListID: 1,                                                                 │
                        │     title: "Get milk"                                                                   │
                        │   ),                                                                                    │
                        │   share: nil,                                                                           │
                        │   _isDeleted: false,                                                                    │
                        │   _hasLastKnownServerRecord: true,                                                      │
                        │   _isShared: false,                                                                     │
                        │   userModificationTime: 0                                                               │
                        │ )                                                                                       │
                        └─────────────────────────────────────────────────────────────────────────────────────────┘
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
            }
        }
    }
#endif

