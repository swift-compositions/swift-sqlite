#if CloudKit
    #if canImport(CloudKit)
        package import CloudKit
        package import Synchronization

        package final class MockCloudDatabase: CloudDatabase {
            package let state = Mutex(State())
            package let databaseScope: CKDatabase.Scope
            let _container = IsolatedWeakVar<MockCloudContainer>()
            let dataManager: any DataManager

            package struct State {
                private var lastRecordChangeTag = 0
                package var storage: [CKRecordZone.ID: Zone] = [:]
                var assets: [AssetID: Data] = [:]
                /// Every deletion with the change tag it was made at, kept so that each device fetching after it
                /// receives it once (a deviation from upstream, which forgets a deletion after its first fetch).
                var deletedRecords: [(CKRecord.ID, CKRecord.RecordType, changeTag: Int)] = []
                mutating func recordDeletion(_ recordID: CKRecord.ID, _ recordType: CKRecord.RecordType) {
                    deletedRecords.append((recordID, recordType, changeTag: nextRecordChangeTag()))
                }
                mutating func nextRecordChangeTag() -> Int {
                    lastRecordChangeTag += 1
                    return lastRecordChangeTag
                }
            }

            struct AssetID: Hashable {
                let recordID: CKRecord.ID
                let key: String
            }

            package struct Zone {
                package var zone: CKRecordZone
                package var records: [CKRecord.ID: CKRecord] = [:]
            }

            package init(
                databaseScope: CKDatabase.Scope,
                dataManager: some DataManager = InMemoryDataManager()
            ) {
                self.databaseScope = databaseScope
                self.dataManager = dataManager
            }

            package func set(container: MockCloudContainer) {
                _container.set(container)
            }

            package var container: MockCloudContainer {
                guard let container = _container.value
                else { fatalError("MockCloudDatabase has no container; call set(container:) first.") }
                return container
            }

            package func record(for recordID: CKRecord.ID) throws -> CKRecord {
                let accountStatus = container.accountStatus()
                guard accountStatus == .available
                else { throw ckError(forAccountStatus: accountStatus) }
                let record = try state.withLock { state throws -> CKRecord in
                    guard let zone = state.storage[recordID.zoneID]
                    else { throw CKError(.zoneNotFound) }
                    guard let record = zone.records[recordID]
                    else { throw CKError(.unknownItem) }
                    guard let record = record.copy() as? CKRecord
                    else { fatalError("Could not copy CKRecord.") }
                    return record
                }

                try state.withLock { state throws in
                    for key in record.allKeys() {
                        guard let assetData = state.assets[AssetID(recordID: record.recordID, key: key)]
                        else { continue }
                        let url = dataManager.temporaryDirectory.appending(path: UUID().uuidString)
                        try dataManager.save(assetData, to: url)
                        record[key] = CKAsset(fileURL: url)
                    }
                }

                return record
            }

            package func records(
                for ids: [CKRecord.ID],
                desiredKeys: [CKRecord.FieldKey]?
            ) throws -> [CKRecord.ID: Result<CKRecord, any Swift.Error>] {
                let accountStatus = container.accountStatus()
                guard accountStatus == .available
                else { throw ckError(forAccountStatus: accountStatus) }

                guard ids.count < 200
                else { throw CKError(.limitExceeded) }

                var results: [CKRecord.ID: Result<CKRecord, any Swift.Error>] = [:]
                for id in ids {
                    results[id] = Result { try record(for: id) }
                }
                return results
            }

            package func modifyRecords(
                saving recordsToSave: [CKRecord] = [],
                deleting recordIDsToDelete: [CKRecord.ID] = [],
                savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .ifServerRecordUnchanged,
                atomically: Bool = true
            ) throws -> (
                saveResults: [CKRecord.ID: Result<CKRecord, any Swift.Error>],
                deleteResults: [CKRecord.ID: Result<Void, any Swift.Error>]
            ) {
                let accountStatus = container.accountStatus()
                guard accountStatus == .available
                else { throw ckError(forAccountStatus: accountStatus) }

                guard (recordsToSave.count + recordIDsToDelete.count) < 200
                else {
                    throw CKError(.limitExceeded)
                }

                return state.withLock { state in
                    let previousStorage = state.storage
                    var saveResults: [CKRecord.ID: Result<CKRecord, any Swift.Error>] = [:]
                    var deleteResults: [CKRecord.ID: Result<Void, any Swift.Error>] = [:]

                    switch savePolicy {
                    case .ifServerRecordUnchanged:
                        for recordToSave in recordsToSave {
                            if let share = recordToSave as? CKShare {
                                let isSavingRootRecord = recordsToSave.contains(where: {
                                    $0.share?.recordID == share.recordID
                                })
                                let shareWasPreviouslySaved =
                                    state.storage[share.recordID.zoneID]?.records[share.recordID] != nil
                                guard shareWasPreviouslySaved || isSavingRootRecord
                                else {
                                    saveResults[recordToSave.recordID] = .failure(CKError(.invalidArguments))
                                    continue
                                }
                            } else if databaseScope == .shared,
                                recordToSave.parent == nil,
                                recordToSave.share == nil
                            {
                                saveResults[recordToSave.recordID] = .failure(CKError(.permissionFailure))
                                continue
                            }

                            guard state.storage[recordToSave.recordID.zoneID] != nil
                            else {
                                saveResults[recordToSave.recordID] = .failure(CKError(.zoneNotFound))
                                continue
                            }

                            let existingRecord = state.storage[recordToSave.recordID.zoneID]?.records[
                                recordToSave.recordID
                            ]

                            func saveRecordToDatabase() {
                                let hasReferenceViolation =
                                    recordToSave.parent.map { parent in
                                        state.storage[parent.recordID.zoneID]?.records[parent.recordID] == nil
                                            && !recordsToSave.contains { $0.recordID == parent.recordID }
                                    }
                                    ?? false
                                guard !hasReferenceViolation
                                else {
                                    saveResults[recordToSave.recordID] = .failure(CKError(.referenceViolation))
                                    return
                                }

                                func root(of record: CKRecord) -> CKRecord {
                                    guard let parent = record.parent
                                    else { return record }
                                    return (state.storage[parent.recordID.zoneID]?.records[parent.recordID]).map(
                                        root
                                    ) ?? record
                                }
                                func share(for rootRecord: CKRecord) -> CKShare? {
                                    for (_, record) in state.storage[rootRecord.recordID.zoneID]?.records ?? [:] {
                                        guard record.recordID == rootRecord.share?.recordID
                                        else { continue }
                                        return record as? CKShare
                                    }
                                    return nil
                                }
                                let rootRecord = root(of: recordToSave)
                                let share = share(for: rootRecord)
                                let isSavingShare = recordsToSave.contains { $0.recordID == share?.recordID }
                                if !isSavingShare,
                                    !(recordToSave is CKShare),
                                    let share,
                                    !(share.publicPermission == .readWrite
                                        || share.currentUserParticipant?.permission == .readWrite)
                                {
                                    saveResults[recordToSave.recordID] = .failure(CKError(.permissionFailure))
                                    return
                                }

                                guard let databaseCopy = recordToSave.copy() as? CKRecord
                                else { fatalError("Could not copy CKRecord.") }
                                databaseCopy._recordChangeTag = state.nextRecordChangeTag()

                                for key in databaseCopy.allKeys() {
                                    guard let assetURL = (databaseCopy[key] as? CKAsset)?.fileURL
                                    else { continue }
                                    state.assets[AssetID(recordID: databaseCopy.recordID, key: key)] =
                                        try? dataManager
                                        .load(assetURL)
                                }

                                state.storage[recordToSave.recordID.zoneID]?.records[recordToSave.recordID] =
                                    databaseCopy
                                guard let savedCopy = databaseCopy.copy() as? CKRecord
                                else { fatalError("Could not copy CKRecord.") }
                                saveResults[recordToSave.recordID] = .success(savedCopy)

                                if let parent = recordToSave.parent,
                                    !recordsToSave.contains(where: { $0.recordID == parent.recordID }),
                                    let parentRecord = state.storage[parent.recordID.zoneID]?.records[parent.recordID]?
                                        .copy()
                                        as? CKRecord
                                {
                                    parentRecord._recordChangeTag = state.nextRecordChangeTag()
                                    state.storage[parent.recordID.zoneID]?.records[parent.recordID] = parentRecord
                                }
                            }

                            switch (existingRecord, recordToSave._recordChangeTag) {
                            case (.some(let existingRecord), .some(let recordToSaveChangeTag)):
                                if existingRecord._recordChangeTag == recordToSaveChangeTag {
                                    precondition(existingRecord._recordChangeTag != nil)
                                    saveRecordToDatabase()
                                } else {
                                    saveResults[recordToSave.recordID] = .failure(
                                        CKError(
                                            .serverRecordChanged,
                                            userInfo: [
                                                CKRecordChangedErrorServerRecordKey: existingRecord.copy() as Any,
                                                CKRecordChangedErrorClientRecordKey: recordToSave.copy(),
                                            ]
                                        )
                                    )
                                }
                                break
                            case (.some(let existingRecord), .none):
                                saveResults[recordToSave.recordID] = .failure(
                                    CKError(
                                        .serverRejectedRequest,
                                        userInfo: [
                                            CKRecordChangedErrorServerRecordKey: existingRecord.copy() as Any,
                                            CKRecordChangedErrorClientRecordKey: recordToSave.copy(),
                                        ]
                                    )
                                )
                            case (.none, .some):
                                saveResults[recordToSave.recordID] = .failure(CKError(.unknownItem))
                            case (.none, .none):
                                saveRecordToDatabase()
                            }
                        }
                    case .allKeys, .changedKeys:
                        fatalError()
                    @unknown default:
                        fatalError()
                    }
                    for recordIDToDelete in recordIDsToDelete {
                        guard state.storage[recordIDToDelete.zoneID] != nil
                        else {
                            deleteResults[recordIDToDelete] = .failure(CKError(.zoneNotFound))
                            continue
                        }
                        let hasReferenceViolation = !Set(
                            state.storage[recordIDToDelete.zoneID]?.records.values
                                .compactMap { $0.parent?.recordID == recordIDToDelete ? $0.recordID : nil }
                                ?? []
                        )
                        .subtracting(recordIDsToDelete)
                        .isEmpty

                        guard !hasReferenceViolation
                        else {
                            deleteResults[recordIDToDelete] = .failure(CKError(.referenceViolation))
                            continue
                        }
                        let recordToDelete = state.storage[recordIDToDelete.zoneID]?.records[recordIDToDelete]
                        state.storage[recordIDToDelete.zoneID]?.records[recordIDToDelete] = nil
                        deleteResults[recordIDToDelete] = .success(())
                        if let recordType = recordToDelete?.recordType {
                            state.recordDeletion(recordIDToDelete, recordType)
                        }

                        if databaseScope == .shared,
                            let shareToDelete = recordToDelete as? CKShare,
                            shareToDelete.recordID.zoneID.ownerName == CKCurrentUserDefaultName
                        {
                            func deleteRecords(referencing recordID: CKRecord.ID) {
                                for recordToDelete in (state.storage[recordIDToDelete.zoneID]?.records ?? [:]).values {
                                    guard
                                        recordToDelete.share?.recordID == recordID
                                            || recordToDelete.parent?.recordID == recordID
                                    else {
                                        continue
                                    }
                                    state.storage[recordIDToDelete.zoneID]?.records[recordToDelete.recordID] = nil
                                    deleteResults[recordToDelete.recordID] = .success(())
                                    state.recordDeletion(recordIDToDelete, recordToDelete.recordType)
                                    deleteRecords(referencing: recordToDelete.recordID)
                                }
                            }
                            deleteRecords(referencing: shareToDelete.recordID)
                        }
                    }

                    guard atomically
                    else {
                        return (saveResults: saveResults, deleteResults: deleteResults)
                    }

                    let affectedZones = Set(
                        recordsToSave.map(\.recordID.zoneID) + recordIDsToDelete.map(\.zoneID)
                    )
                    for zoneID in affectedZones {
                        let saveResultsInZone = saveResults.filter { recordID, _ in recordID.zoneID == zoneID }
                        let deleteResultsInZone = deleteResults.filter { recordID, _ in
                            recordID.zoneID == zoneID
                        }
                        let saveSuccessRecordIDs = saveResultsInZone.compactMap { recordID, result in
                            (try? result.get()) == nil ? nil : recordID
                        }
                        let deleteSuccessRecordIDs = deleteResultsInZone.compactMap { recordID, result in
                            (try? result.get()) == nil ? nil : recordID
                        }
                        guard
                            saveSuccessRecordIDs.count != saveResultsInZone.count
                                || deleteSuccessRecordIDs.count != deleteResultsInZone.count
                        else {
                            continue
                        }
                        for saveSuccessRecordID in saveSuccessRecordIDs {
                            saveResults[saveSuccessRecordID] = .failure(CKError(.batchRequestFailed))
                        }
                        for deleteSuccessRecordID in deleteSuccessRecordIDs {
                            deleteResults[deleteSuccessRecordID] = .failure(CKError(.batchRequestFailed))
                        }
                        state.storage[zoneID]?.records = previousStorage[zoneID]?.records ?? [:]
                    }
                    return (saveResults: saveResults, deleteResults: deleteResults)
                }
            }

            package func modifyRecordZones(
                saving recordZonesToSave: [CKRecordZone] = [],
                deleting recordZoneIDsToDelete: [CKRecordZone.ID] = []
            ) throws -> (
                saveResults: [CKRecordZone.ID: Result<CKRecordZone, any Swift.Error>],
                deleteResults: [CKRecordZone.ID: Result<Void, any Swift.Error>]
            ) {
                let accountStatus = container.accountStatus()
                guard accountStatus == .available
                else { throw ckError(forAccountStatus: accountStatus) }

                return state.withLock { state in
                    var saveResults: [CKRecordZone.ID: Result<CKRecordZone, any Swift.Error>] = [:]
                    var deleteResults: [CKRecordZone.ID: Result<Void, any Swift.Error>] = [:]

                    for recordZoneToSave in recordZonesToSave {
                        state.storage[recordZoneToSave.zoneID] =
                            state.storage[recordZoneToSave.zoneID] ?? Zone(zone: recordZoneToSave)
                        saveResults[recordZoneToSave.zoneID] = .success(recordZoneToSave)
                    }

                    for recordZoneIDsToDelete in recordZoneIDsToDelete {
                        guard state.storage[recordZoneIDsToDelete] != nil
                        else {
                            deleteResults[recordZoneIDsToDelete] = .failure(CKError(.zoneNotFound))
                            continue
                        }
                        state.storage[recordZoneIDsToDelete] = nil
                        deleteResults[recordZoneIDsToDelete] = .success(())
                    }

                    return (saveResults: saveResults, deleteResults: deleteResults)
                }
            }

            package nonisolated static func == (lhs: MockCloudDatabase, rhs: MockCloudDatabase) -> Bool {
                lhs === rhs
            }

            package nonisolated func hash(into hasher: inout Hasher) {
                hasher.combine(ObjectIdentifier(self))
            }
        }

        private func ckError(forAccountStatus accountStatus: CKAccountStatus) -> CKError {
            switch accountStatus {
            case .couldNotDetermine, .restricted, .noAccount:
                return CKError(.notAuthenticated)
            case .temporarilyUnavailable:
                return CKError(.accountTemporarilyUnavailable)
            case .available:
                fatalError()
            @unknown default:
                fatalError()
            }
        }
    #endif

#endif
