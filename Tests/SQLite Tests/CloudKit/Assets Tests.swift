#if CloudKit
    import SQL_Macros
    import GRDB
    import Byte
    import CloudKit
    import Foundation
    import InlineSnapshotTesting
    import SQL
    import SQLite
    import SQLite_Test_Support
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Asset synchronization`: CloudKitTestBase, @unchecked Sendable {
            @Test func `uploads bytes as an asset and re-uploads them when they change`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                        RemindersListAsset(remindersListID: 1, coverImage: [Byte](utf8: "image"))
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
                            recordID: CKRecord.ID(1:remindersListAssets/zone/__defaultOwner__),
                            recordType: "remindersListAssets",
                            parent: CKReference(recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__)),
                            share: nil,
                            coverImage_hash: Data(32 bytes),
                            remindersListID: 1,
                            coverImage: CKAsset(
                              fileURL: URL(file:///tmp/6105d6cc76af400325e94d588ce511be5bfdbb73b437dc51eca43917d7a43e3d),
                              dataString: "image"
                            )
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

                #expect(
                    try inMemoryDataManager.load(
                        #require(URL(string: "file:///tmp/6105d6cc76af400325e94d588ce511be5bfdbb73b437dc51eca43917d7a43e3d"))
                    ) == Data("image".utf8)
                )

                try await withTime(advancedBy: 1) {
                    try await userDatabase.userWrite { db in
                        try RemindersListAsset
                            .find(1)
                            .update { $0.coverImage = #bind([Byte](utf8: "new-image")) }
                            .execute(db)
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
                            recordID: CKRecord.ID(1:remindersListAssets/zone/__defaultOwner__),
                            recordType: "remindersListAssets",
                            parent: CKReference(recordID: CKRecord.ID(1:remindersLists/zone/__defaultOwner__)),
                            share: nil,
                            coverImage_hash: Data(32 bytes),
                            remindersListID: 1,
                            coverImage: CKAsset(
                              fileURL: URL(file:///tmp/97e67a5645969953f1a4cfe2ea75649864ff99789189cdd3f6db03e59f8a8ebf),
                              dataString: "new-image"
                            )
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

                #expect(
                    try inMemoryDataManager.load(
                        #require(URL(string: "file:///tmp/97e67a5645969953f1a4cfe2ea75649864ff99789189cdd3f6db03e59f8a8ebf"))
                    ) == Data("new-image".utf8)
                )
            }

            @Test func `stores a received asset as bytes`() async throws {
                let remindersListRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue("1", forKey: "id", at: now)
                remindersListRecord.setValue("Personal", forKey: "title", at: now)

                let fileURL = URL(fileURLWithPath: ProcessInfo.processInfo.globallyUniqueString)
                try inMemoryDataManager.save(Data("image".utf8), to: fileURL)
                let remindersListAssetRecord = CKRecord(
                    recordType: RemindersListAsset.tableName,
                    recordID: RemindersListAsset.recordID(for: 1)
                )
                remindersListAssetRecord.setValue("1", forKey: "id", at: now)
                remindersListAssetRecord.setAsset(
                    CKAsset(fileURL: fileURL),
                    forKey: "coverImage",
                    at: now,
                    dataManager: inMemoryDataManager
                )
                remindersListAssetRecord.setValue("1", forKey: "remindersListID", at: now)
                remindersListAssetRecord.parent = CKRecord.Reference(
                    record: remindersListRecord,
                    action: .none
                )

                try await syncEngine.modifyRecords(
                    scope: .private,
                    saving: [remindersListAssetRecord, remindersListRecord]
                )
                .notify()

                try await userDatabase.read { db in
                    let remindersListAsset = try #require(
                        try RemindersListAsset.find(1).fetchOne(db)
                    )
                    #expect(remindersListAsset.coverImage == [Byte](utf8: "image"))
                }
            }

            @Test func `stores a received asset over existing local bytes`() async throws {
                try await userDatabase.userWrite { db in
                    try db.seed {
                        RemindersList(id: 1, title: "Personal")
                        RemindersListAsset(remindersListID: 1, coverImage: [Byte](utf8: "image"))
                    }
                }
                try await syncEngine.processPendingRecordZoneChanges(scope: .private)

                try await withTime(advancedBy: 1) {
                    let fileURL = URL(fileURLWithPath: ProcessInfo.processInfo.globallyUniqueString)
                    try inMemoryDataManager.save(Data("new-image".utf8), to: fileURL)
                    let remindersListAssetRecord = try syncEngine.private.database.record(
                        for: RemindersListAsset.recordID(for: 1)
                    )
                    remindersListAssetRecord.setAsset(
                        CKAsset(fileURL: fileURL),
                        forKey: "coverImage",
                        at: now,
                        dataManager: inMemoryDataManager
                    )
                    try await syncEngine.modifyRecords(
                        scope: .private,
                        saving: [remindersListAssetRecord]
                    )
                    .notify()
                }

                try await userDatabase.read { db in
                    let remindersListAsset = try #require(
                        try RemindersListAsset.find(1).fetchOne(db)
                    )
                    #expect(remindersListAsset.coverImage == [Byte](utf8: "new-image"))
                }
            }

            @Test func `keeps the freshest of two received assets`() async throws {
                do {
                    let remindersListRecord = CKRecord(
                        recordType: RemindersList.tableName,
                        recordID: RemindersList.recordID(for: 1)
                    )
                    remindersListRecord.setValue("1", forKey: "id", at: now)
                    remindersListRecord.setValue("Personal", forKey: "title", at: now)

                    let fileURL = URL(fileURLWithPath: ProcessInfo.processInfo.globallyUniqueString)
                    try inMemoryDataManager.save(Data("image".utf8), to: fileURL)
                    let remindersListAssetRecord = CKRecord(
                        recordType: RemindersListAsset.tableName,
                        recordID: RemindersListAsset.recordID(for: 1)
                    )
                    remindersListAssetRecord.setValue("1", forKey: "id", at: now)
                    remindersListAssetRecord.setAsset(
                        CKAsset(fileURL: fileURL),
                        forKey: "coverImage",
                        at: now,
                        dataManager: inMemoryDataManager
                    )
                    remindersListAssetRecord.setValue("1", forKey: "remindersListID", at: now)
                    remindersListAssetRecord.parent = CKRecord.Reference(
                        record: remindersListRecord,
                        action: .none
                    )

                    try await syncEngine.modifyRecords(
                        scope: .private,
                        saving: [remindersListAssetRecord, remindersListRecord]
                    )
                    .notify()
                }

                try await withTime(advancedBy: 1) {
                    let fileURL = URL(fileURLWithPath: ProcessInfo.processInfo.globallyUniqueString)
                    try inMemoryDataManager.save(Data("new-image".utf8), to: fileURL)
                    let remindersListAssetRecord = try syncEngine.private.database.record(
                        for: RemindersListAsset.recordID(for: 1)
                    )
                    remindersListAssetRecord.setAsset(
                        CKAsset(fileURL: fileURL),
                        forKey: "coverImage",
                        at: now,
                        dataManager: inMemoryDataManager
                    )
                    try await syncEngine.modifyRecords(
                        scope: .private,
                        saving: [remindersListAssetRecord]
                    )
                    .notify()
                }

                try await userDatabase.read { db in
                    let remindersListAsset = try #require(
                        try RemindersListAsset.find(1).fetchOne(db)
                    )
                    #expect(remindersListAsset.coverImage == [Byte](utf8: "new-image"))
                }
            }

            @Test func `synchronizes an asset received before its parent record`() async throws {
                let remindersListRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue("1", forKey: "id", at: now)
                remindersListRecord.setValue("Personal", forKey: "title", at: now)

                let remindersListAssetRecord = CKRecord(
                    recordType: RemindersListAsset.tableName,
                    recordID: RemindersListAsset.recordID(for: 1)
                )
                remindersListAssetRecord.setValue("1", forKey: "id", at: now)
                try remindersListAssetRecord.setBytes(
                    [Byte](utf8: "image"),
                    forKey: "coverImage",
                    at: now,
                    dataManager: inMemoryDataManager
                )
                remindersListAssetRecord.setValue(
                    "1",
                    forKey: "remindersListID",
                    at: now
                )
                remindersListAssetRecord.parent = CKRecord.Reference(
                    record: remindersListRecord,
                    action: .none
                )

                let remindersListModification = try syncEngine.modifyRecords(
                    scope: .private,
                    saving: [remindersListRecord]
                )
                try await syncEngine.modifyRecords(scope: .private, saving: [remindersListAssetRecord])
                    .notify()
                await remindersListModification.notify()

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
                assertQuery(RemindersListAsset.all, database: userDatabase.database) {
                    """
                    ┌───────────────────────────────┐
                    │ RemindersListAsset(           │
                    │   remindersListID: 1,         │
                    │   coverImage: [Byte](5 bytes) │
                    │ )                             │
                    └───────────────────────────────┘
                    """
                }

            }
        }
    }
#endif

