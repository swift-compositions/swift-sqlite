#if CloudKit
    import GRDB
    import CloudKit
    import Foundation
    import InlineSnapshotTesting
    import SQL
    import SQLite
    import Synchronization
    import Testing

    extension CloudKitTestBase {
        @MainActor
        final class `Mock cloud database`: CloudKitTestBase, @unchecked Sendable {
            init() async throws {
                try await super.init()
                let (saveZoneResults, _) = try syncEngine.private.database.modifyRecordZones(
                    saving: [
                        CKRecordZone(
                            zoneID: CKRecord(recordType: "A\(Int.random(in: 1...999_999_999))").recordID.zoneID
                        )
                    ],
                    deleting: []
                )
                #expect(saveZoneResults.allSatisfy({ (try? $1.get()) != nil }))
            }

            @Test func `fetching a record in an unknown zone fails with zone not found`() async throws {
                let error = #expect(throws: CKError.self) {
                    try self.syncEngine.private.database.record(
                        for: CKRecord.ID(
                            recordName: "A",
                            zoneID: CKRecordZone.ID(zoneName: "unknownZone")
                        )
                    )
                }
                #expect(error == CKError(.zoneNotFound))
            }

            @Test func `fetching an unknown record fails with unknown item`() async throws {
                let error = #expect(throws: CKError.self) {
                    try self.syncEngine.private.database.record(for: CKRecord.ID(recordName: "A"))
                }
                #expect(error == CKError(.unknownItem))
            }

            @Test func `assets use the temporary directory`() async throws {
                let recordID = CKRecord.ID(recordName: "record")
                let record = CKRecord(recordType: "Record", recordID: recordID)
                let sourceURL = URL(fileURLWithPath: "/sqlite-data-test-assets/asset.jpg")
                try inMemoryDataManager.save(Data("image".utf8), to: sourceURL)
                record["asset"] = CKAsset(fileURL: sourceURL)

                let database = syncEngine.private.database
                let (saveResults, _) = try database.modifyRecords(
                    saving: [record],
                    deleting: []
                )
                _ = try saveResults[recordID]?.get()

                let fetched = try database.record(for: recordID)
                let asset = fetched["asset"] as? CKAsset
                let assetDirectory = try #require(asset?.fileURL?.path())
                #expect(
                    assetDirectory
                        .hasPrefix(inMemoryDataManager.temporaryDirectory.path())
                )
            }

            @Test func `save transaction with the child before the parent`() async throws {
                let parent = CKRecord(recordType: "A", recordID: CKRecord.ID(recordName: "A"))
                let child = CKRecord(recordType: "B", recordID: CKRecord.ID(recordName: "B"))
                child.parent = CKRecord.Reference(record: parent, action: .none)

                let (saveRecordResults, _) = try syncEngine.private.database.modifyRecords(
                    saving: [child, parent],
                    deleting: []
                )
                #expect(saveRecordResults.allSatisfy({ (try? $1.get()) != nil }))

                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(A/_defaultZone/__defaultOwner__),
                            recordType: "A",
                            parent: nil,
                            share: nil
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(B/_defaultZone/__defaultOwner__),
                            recordType: "B",
                            parent: CKReference(recordID: CKRecord.ID(A/_defaultZone/__defaultOwner__)),
                            share: nil
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

            @Test func `save transaction with a child and no parent`() async throws {
                let parent = CKRecord(recordType: "Parent", recordID: CKRecord.ID(recordName: "Parent"))
                let child = CKRecord(recordType: "Child", recordID: CKRecord.ID(recordName: "Child"))
                child.parent = CKRecord.Reference(record: parent, action: .none)

                let (saveRecordResults, _) = try syncEngine.private.database.modifyRecords(
                    saving: [child],
                    deleting: []
                )
                let error = #expect(throws: CKError.self) {
                    try saveRecordResults[child.recordID]?.get()
                }
                #expect(error == CKError(.referenceViolation))

                try await syncEngine.modifyRecords(scope: .private, saving: [child]).notify()

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

            @Test func `saving in an unknown zone`() async throws {
                let record = CKRecord(
                    recordType: "Record",
                    recordID: CKRecord.ID(
                        recordName: "Record",
                        zoneID: CKRecordZone.ID(zoneName: "unknownZone")
                    )
                )

                let (saveRecordResults, _) = try syncEngine.private.database.modifyRecords(
                    saving: [record],
                    deleting: []
                )
                let error = #expect(throws: CKError.self) {
                    try saveRecordResults[record.recordID]?.get()
                }
                #expect(error == CKError(.zoneNotFound))

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

            @Test func `delete transaction with the parent before the child`() async throws {
                let parent = CKRecord(recordType: "A", recordID: CKRecord.ID(recordName: "A"))
                let child = CKRecord(recordType: "B", recordID: CKRecord.ID(recordName: "B"))
                child.parent = CKRecord.Reference(record: parent, action: .none)

                let _ = try syncEngine.private.database.modifyRecords(saving: [child, parent])
                let (_, deleteResults) = try syncEngine.private.database.modifyRecords(
                    deleting: [parent.recordID, child.recordID]
                )
                #expect(deleteResults.allSatisfy({ (try? $1.get()) != nil }))

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

            @Test func `deleting an unknown record`() async throws {
                let record = CKRecord(recordType: "A", recordID: CKRecord.ID(recordName: "A"))

                let (_, deleteResults) = try syncEngine.private.database.modifyRecords(
                    deleting: [record.recordID]
                )
                #expect(deleteResults.allSatisfy({ (try? $1.get()) != nil }))

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

            @Test func `deleting a record in an unknown zone`() async throws {
                let record = CKRecord(
                    recordType: "A",
                    recordID: CKRecord.ID(recordName: "A", zoneID: CKRecordZone.ID(zoneName: "unknownZone"))
                )

                let (_, deleteResults) = try syncEngine.private.database.modifyRecords(
                    deleting: [record.recordID]
                )
                let error = #expect(throws: CKError.self) {
                    try deleteResults[record.recordID]?.get()
                }
                #expect(error == CKError(.zoneNotFound))

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

            @Test func `delete transaction deleting the parent but not the child`() async throws {
                let parent = CKRecord(recordType: "A", recordID: CKRecord.ID(recordName: "A"))
                let child = CKRecord(recordType: "B", recordID: CKRecord.ID(recordName: "B"))
                child.parent = CKRecord.Reference(record: parent, action: .none)

                _ = try syncEngine.private.database.modifyRecords(saving: [child, parent])
                let (_, deleteResults) = try syncEngine.private.database.modifyRecords(
                    deleting: [parent.recordID]
                )
                let error = #expect(throws: CKError.self) {
                    try deleteResults[CKRecord.ID(recordName: "A")]?.get()
                }
                #expect(error == CKError(.referenceViolation))

                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(A/_defaultZone/__defaultOwner__),
                            recordType: "A",
                            parent: nil,
                            share: nil
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(B/_defaultZone/__defaultOwner__),
                            recordType: "B",
                            parent: CKReference(recordID: CKRecord.ID(A/_defaultZone/__defaultOwner__)),
                            share: nil
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

            @Test func `deleting an unknown zone`() async throws {
                let (_, deleteResults) = try syncEngine.private.database.modifyRecordZones(
                    saving: [],
                    deleting: [CKRecordZone.ID(zoneName: "unknownZone")]
                )
                let error = #expect(throws: CKError.self) {
                    try deleteResults[CKRecordZone.ID(zoneName: "unknownZone")]?.get()
                }
                #expect(error == CKError(.zoneNotFound))
            }

            @Test func `account temporarily unavailable`() async throws {
                container._accountStatus.withLock { $0 = .temporarilyUnavailable }
                var error = #expect(throws: CKError.self) {
                    _ = try self.syncEngine.private.database.modifyRecordZones()
                }
                #expect(error == CKError(.accountTemporarilyUnavailable))
                error = #expect(throws: CKError.self) {
                    _ = try self.syncEngine.private.database.modifyRecords()
                }
                #expect(error == CKError(.accountTemporarilyUnavailable))
                error = #expect(throws: CKError.self) {
                    _ = try self.syncEngine.private.database.record(for: CKRecord.ID(recordName: "test"))
                }
                #expect(error == CKError(.accountTemporarilyUnavailable))
                error = await #expect(throws: CKError.self) {
                    _ = try await self.syncEngine.private.database.records(for: [
                        CKRecord.ID(recordName: "test")
                    ])
                }
                #expect(error == CKError(.accountTemporarilyUnavailable))
            }

            @Test func `no account`() async throws {
                container._accountStatus.withLock { $0 = .noAccount }
                var error = #expect(throws: CKError.self) {
                    _ = try self.syncEngine.private.database.modifyRecordZones()
                }
                #expect(error == CKError(.notAuthenticated))
                error = #expect(throws: CKError.self) {
                    _ = try self.syncEngine.private.database.modifyRecords()
                }
                #expect(error == CKError(.notAuthenticated))
                error = #expect(throws: CKError.self) {
                    _ = try self.syncEngine.private.database.record(for: CKRecord.ID(recordName: "test"))
                }
                #expect(error == CKError(.notAuthenticated))
                error = await #expect(throws: CKError.self) {
                    _ = try await self.syncEngine.private.database.records(for: [
                        CKRecord.ID(recordName: "test")
                    ])
                }
                #expect(error == CKError(.notAuthenticated))
            }

            @Test func `account not determined`() async throws {
                container._accountStatus.withLock { $0 = .couldNotDetermine }
                var error = #expect(throws: CKError.self) {
                    _ = try self.syncEngine.private.database.modifyRecordZones()
                }
                #expect(error == CKError(.notAuthenticated))
                error = #expect(throws: CKError.self) {
                    _ = try self.syncEngine.private.database.modifyRecords()
                }
                #expect(error == CKError(.notAuthenticated))
                error = #expect(throws: CKError.self) {
                    _ = try self.syncEngine.private.database.record(for: CKRecord.ID(recordName: "test"))
                }
                #expect(error == CKError(.notAuthenticated))
                error = await #expect(throws: CKError.self) {
                    _ = try await self.syncEngine.private.database.records(for: [
                        CKRecord.ID(recordName: "test")
                    ])
                }
                #expect(error == CKError(.notAuthenticated))
            }

            @Test func `restricted account`() async throws {
                container._accountStatus.withLock { $0 = .restricted }
                var error = #expect(throws: CKError.self) {
                    _ = try self.syncEngine.private.database.modifyRecordZones()
                }
                #expect(error == CKError(.notAuthenticated))
                error = #expect(throws: CKError.self) {
                    _ = try self.syncEngine.private.database.modifyRecords()
                }
                #expect(error == CKError(.notAuthenticated))
                error = #expect(throws: CKError.self) {
                    _ = try self.syncEngine.private.database.record(for: CKRecord.ID(recordName: "test"))
                }
                #expect(error == CKError(.notAuthenticated))
                error = await #expect(throws: CKError.self) {
                    _ = try await self.syncEngine.private.database.records(for: [
                        CKRecord.ID(recordName: "test")
                    ])
                }
                #expect(error == CKError(.notAuthenticated))
            }

            @Test func `saving a share without its root record`() async throws {
                let record = CKRecord(recordType: "A", recordID: CKRecord.ID(recordName: "1"))
                let share = CKShare(rootRecord: record, shareID: CKRecord.ID(recordName: "share"))
                let (saveResults, _) = try syncEngine.private.database.modifyRecords(saving: [share])
                let error = #expect(throws: CKError.self) {
                    try saveResults.values.first?.get()
                }
                #expect(error?.code == .invalidArguments)
            }

            @Test func `saving a share with its root record, then saving the share alone`() async throws {
                let record = CKRecord(recordType: "A", recordID: CKRecord.ID(recordName: "1"))
                let share = CKShare(rootRecord: record, shareID: CKRecord.ID(recordName: "share"))
                _ = try syncEngine.private.database.modifyRecords(saving: [share, record])

                let newShare = try syncEngine.private.database.record(for: CKRecord.ID(recordName: "share"))
                let (saveResults, _) = try syncEngine.private.database.modifyRecords(saving: [newShare])
                #expect(throws: Never.self) {
                    _ = try saveResults.values.first?.get()
                }
            }

            @Test func `saving a record that was previously deleted`() async throws {
                let record = CKRecord(recordType: "A", recordID: CKRecord.ID(recordName: "1"))
                _ = try syncEngine.private.database.modifyRecords(saving: [record])
                let freshRecord = try syncEngine.private.database.record(for: record.recordID)
                _ = try syncEngine.private.database.modifyRecords(deleting: [record.recordID])
                let (saveResults, _) = try syncEngine.private.database.modifyRecords(saving: [freshRecord])
                let error = #expect(throws: CKError.self) {
                    try saveResults.values.first?.get()
                }
                #expect(error?.code == .unknownItem)
            }

            @Test func `saving a shared record without a parent`() async throws {
                let record = CKRecord(recordType: "A", recordID: CKRecord.ID(recordName: "1"))
                let (saveResults, _) = try syncEngine.shared.database.modifyRecords(saving: [record])
                let error = #expect(throws: CKError.self) {
                    _ = try saveResults.values.first?.get()
                }
                #expect(error?.code == .permissionFailure)
            }

            @Test func `deleting a share owned by the current user deletes the share and not the associated data`() async throws {
                let zone = syncEngine.defaultZone
                _ = try syncEngine.private.database.modifyRecordZones(saving: [zone])

                let recordA = CKRecord(
                    recordType: "A",
                    recordID: CKRecord.ID(recordName: "A1", zoneID: zone.zoneID)
                )
                let recordB = CKRecord(
                    recordType: "B",
                    recordID: CKRecord.ID(recordName: "B1", zoneID: zone.zoneID)
                )
                recordB.parent = CKRecord.Reference(recordID: recordA.recordID, action: .none)
                let share = CKShare(
                    rootRecord: recordA,
                    shareID: CKRecord.ID(recordName: "share", zoneID: zone.zoneID)
                )
                _ = try syncEngine.private.database.modifyRecords(saving: [share, recordA, recordB])

                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(A1/zone/__defaultOwner__),
                            recordType: "A",
                            parent: nil,
                            share: CKReference(recordID: CKRecord.ID(share/zone/__defaultOwner__))
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(B1/zone/__defaultOwner__),
                            recordType: "B",
                            parent: CKReference(recordID: CKRecord.ID(A1/zone/__defaultOwner__)),
                            share: nil
                          ),
                          [2]: CKRecord(
                            recordID: CKRecord.ID(share/zone/__defaultOwner__),
                            recordType: "cloudkit.share",
                            parent: nil,
                            share: nil
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

                _ = try syncEngine.private.database.modifyRecords(deleting: [share.recordID])

                assertInlineSnapshot(of: container, as: .customDump) {
                    """
                    MockCloudContainer(
                      privateCloudDatabase: MockCloudDatabase(
                        databaseScope: .private,
                        storage: [
                          [0]: CKRecord(
                            recordID: CKRecord.ID(A1/zone/__defaultOwner__),
                            recordType: "A",
                            parent: nil,
                            share: CKReference(recordID: CKRecord.ID(share/zone/__defaultOwner__))
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(B1/zone/__defaultOwner__),
                            recordType: "B",
                            parent: CKReference(recordID: CKRecord.ID(A1/zone/__defaultOwner__)),
                            share: nil
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

            @Test func `deleting a share not owned by the current user deletes only the share and not the associated records`() async throws {
                let externalZone = CKRecordZone(
                    zoneID: CKRecordZone.ID(zoneName: "external.zone", ownerName: "external.owner")
                )
                _ = try syncEngine.shared.database.modifyRecordZones(saving: [externalZone])

                let recordA = CKRecord(
                    recordType: "A",
                    recordID: CKRecord.ID(recordName: "A1", zoneID: externalZone.zoneID)
                )
                let recordB = CKRecord(
                    recordType: "B",
                    recordID: CKRecord.ID(recordName: "B1", zoneID: externalZone.zoneID)
                )
                recordB.parent = CKRecord.Reference(recordID: recordA.recordID, action: .none)
                let share = CKShare(
                    rootRecord: recordA,
                    shareID: CKRecord.ID(recordName: "share", zoneID: externalZone.zoneID)
                )
                _ = try syncEngine.shared.database.modifyRecords(saving: [share, recordA, recordB])

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
                            recordID: CKRecord.ID(A1/external.zone/external.owner),
                            recordType: "A",
                            parent: nil,
                            share: CKReference(recordID: CKRecord.ID(share/external.zone/external.owner))
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(B1/external.zone/external.owner),
                            recordType: "B",
                            parent: CKReference(recordID: CKRecord.ID(A1/external.zone/external.owner)),
                            share: nil
                          ),
                          [2]: CKRecord(
                            recordID: CKRecord.ID(share/external.zone/external.owner),
                            recordType: "cloudkit.share",
                            parent: nil,
                            share: nil
                          )
                        ]
                      )
                    )
                    """
                }

                _ = try syncEngine.shared.database.modifyRecords(deleting: [share.recordID])

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
                            recordID: CKRecord.ID(A1/external.zone/external.owner),
                            recordType: "A",
                            parent: nil,
                            share: CKReference(recordID: CKRecord.ID(share/external.zone/external.owner))
                          ),
                          [1]: CKRecord(
                            recordID: CKRecord.ID(B1/external.zone/external.owner),
                            recordType: "B",
                            parent: CKReference(recordID: CKRecord.ID(A1/external.zone/external.owner)),
                            share: nil
                          )
                        ]
                      )
                    )
                    """
                }
            }

            @Test func `batch request failed`() async throws {
                let record1ID = CKRecord.ID(recordName: "1")
                let record2ID = CKRecord.ID(recordName: "2")

                do {
                    let record1 = CKRecord(recordType: "record1", recordID: record1ID)
                    let record2 = CKRecord(recordType: "record2", recordID: record2ID)
                    let (saveResults, _) = try syncEngine.private.database.modifyRecords(saving: [
                        record1, record2,
                    ])
                    #expect(saveResults.values.count(where: { (try? $0.get()) != nil }) == 2)
                }

                let freshRecord2 = try syncEngine.private.database.record(for: record2ID)
                do {
                    let freshRecord1 = try syncEngine.private.database.record(for: record1ID)
                    freshRecord1["isOn"] = true
                    freshRecord2["isOn"] = true
                    let (saveResults, _) = try syncEngine.private.database.modifyRecords(
                        saving: [freshRecord1, freshRecord2]
                    )
                    #expect(saveResults.values.count(where: { (try? $0.get()) != nil }) == 2)
                }

                do {
                    let freshRecord1 = try syncEngine.private.database.record(for: record1ID)
                    freshRecord1["isOn"] = true
                    freshRecord2["isOn"] = false
                    let (saveResults, _) = try syncEngine.private.database.modifyRecords(
                        saving: [freshRecord1, freshRecord2]
                    )
                    #expect(
                        saveResults.compactMapValues { ($0.error as? CKError)?.code } == [
                            record1ID: .batchRequestFailed,
                            record2ID: .serverRecordChanged,
                        ]
                    )
                }
            }

            @Test func `modifying records beyond the limit fails with limit exceeded`() async throws {
                let remindersListRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue(1, forKey: "id", at: now)
                remindersListRecord.setValue("Personal", forKey: "title", at: now)

                let reminderRecords = (1...400).map { index in
                    let reminderRecord = CKRecord(
                        recordType: Reminder.tableName,
                        recordID: Reminder.recordID(for: index)
                    )
                    reminderRecord.setValue(index, forKey: "id", at: now)
                    reminderRecord.setValue("Reminder #\(index)", forKey: "title", at: now)
                    reminderRecord.setValue(1, forKey: "remindersListID", at: now)
                    reminderRecord.parent = CKRecord.Reference(
                        record: remindersListRecord,
                        action: .none
                    )
                    return reminderRecord
                }

                let error = #expect(throws: CKError.self) {
                    _ = try syncEngine.private.database.modifyRecords(
                        saving: reminderRecords + [remindersListRecord]
                    )
                }
                #expect(error?.code == .limitExceeded)
            }

            @Test func `fetching records beyond the limit fails with limit exceeded`() async throws {
                let remindersListRecord = CKRecord(
                    recordType: RemindersList.tableName,
                    recordID: RemindersList.recordID(for: 1)
                )
                remindersListRecord.setValue(1, forKey: "id", at: now)
                remindersListRecord.setValue("Personal", forKey: "title", at: now)

                let reminderRecords = (1...400).map { index in
                    let reminderRecord = CKRecord(
                        recordType: Reminder.tableName,
                        recordID: Reminder.recordID(for: index)
                    )
                    reminderRecord.setValue(index, forKey: "id", at: now)
                    reminderRecord.setValue("Reminder #\(index)", forKey: "title", at: now)
                    reminderRecord.setValue(1, forKey: "remindersListID", at: now)
                    reminderRecord.parent = CKRecord.Reference(
                        record: remindersListRecord,
                        action: .none
                    )
                    return reminderRecord
                }

                _ = try syncEngine.private.database.modifyRecords(saving: [remindersListRecord])
                _ = try syncEngine.private.database.modifyRecords(saving: Array(reminderRecords[0...100]))
                _ = try syncEngine.private.database.modifyRecords(saving: Array(reminderRecords[101...200]))
                _ = try syncEngine.private.database.modifyRecords(saving: Array(reminderRecords[201...300]))
                _ = try syncEngine.private.database.modifyRecords(saving: Array(reminderRecords[301...399]))

                let error = await #expect(throws: CKError.self) {
                    _ = try await syncEngine.private.database.records(
                        for: [remindersListRecord.recordID] + reminderRecords.map(\.recordID)
                    )
                }
                #expect(error?.code == .limitExceeded)
            }

            @Test func `mutating record returned from modifyRecords does not mutate database`() async throws {
                let record = CKRecord(recordType: "A", recordID: CKRecord.ID(recordName: "1"))
                record["title"] = "original"
                let (saveResults, _) = try syncEngine.private.database.modifyRecords(saving: [record])
                let savedRecord = try #require(try saveResults[record.recordID]?.get())
                savedRecord["title"] = "mutated"

                let storedRecord = try syncEngine.private.database.record(for: record.recordID)
                #expect(storedRecord["title"] as? String == "original")
            }

            @Test func `mutating record returned from non-atomic modifyRecords does not mutate database`() async throws {
                let record = CKRecord(recordType: "A", recordID: CKRecord.ID(recordName: "1"))
                record["title"] = "original"
                let (saveResults, _) = try syncEngine.private.database.modifyRecords(
                    saving: [record],
                    atomically: false
                )
                let savedRecord = try #require(try saveResults[record.recordID]?.get())
                savedRecord["title"] = "mutated"

                let storedRecord = try syncEngine.private.database.record(for: record.recordID)
                #expect(storedRecord["title"] as? String == "original")
            }

            @Test func `mutating record returned from shareMetadata does not mutate database`() async throws {
                let record = CKRecord(recordType: "A", recordID: CKRecord.ID(recordName: "1"))
                record["title"] = "original"
                let share = CKShare(rootRecord: record, shareID: CKRecord.ID(recordName: "share"))
                _ = try syncEngine.private.database.modifyRecords(saving: [share, record])

                let metadata = try await container.shareMetadata(for: share, shouldFetchRootRecord: true)
                let rootRecord = try #require(metadata.rootRecord)
                rootRecord["title"] = "mutated"

                let storedRecord = try syncEngine.private.database.record(for: record.recordID)
                #expect(storedRecord["title"] as? String == "original")
            }

        }
    }
#endif

