#if CloudKit
    import Synchronization
    import CloudKit
    import GRDB
    import SQL
    import SQLite
    import Testing

    extension PrimaryKeyedTable where PrimaryKey.QueryOutput: IdentifierStringConvertible {
        static func recordID(
            for id: PrimaryKey.QueryOutput,
            zoneID: CKRecordZone.ID? = nil
        ) -> CKRecord.ID {
            CKRecord.ID(
                recordName: recordName(for: id),
                zoneID: zoneID ?? SyncEngine.defaultTestZone.zoneID
            )
        }
    }

    extension SyncEngine {
        struct ModifyRecordsCallback {
            fileprivate let operation: @Sendable () async -> Void

            func notify() async {
                await operation()
            }
        }

        func modifyRecordZones(
            scope: CKDatabase.Scope,
            saving recordZonesToSave: [CKRecordZone] = [],
            deleting recordZoneIDsToDelete: [CKRecordZone.ID] = []
        ) throws -> ModifyRecordsCallback {
            let syncEngine = syncEngine(for: scope)
            let (saveResults, deleteResults) = try syncEngine.database.modifyRecordZones(
                saving: recordZonesToSave,
                deleting: recordZoneIDsToDelete
            )
            return ModifyRecordsCallback {
                await syncEngine.parentSyncEngine.handleEvent(
                    .fetchedDatabaseChanges(
                        modifications: saveResults.values.compactMap { try? $0.get().zoneID },
                        deletions: deleteResults.compactMap { zoneID, result in
                            (try? result.get()) != nil ? (zoneID, .deleted) : nil
                        }
                    ),
                    syncEngine: syncEngine
                )
            }
        }

        func modifyRecords(
            scope: CKDatabase.Scope,
            saving recordsToSave: [CKRecord] = [],
            deleting recordIDsToDelete: [CKRecord.ID] = [],
            atomically: Bool = true
        ) throws -> ModifyRecordsCallback {
            let syncEngine = syncEngine(for: scope)
            let recordsToDeleteByID = Dictionary(
                grouping: syncEngine.database.state.withLock { state in
                    recordIDsToDelete.compactMap { recordID in
                        state.storage[recordID.zoneID]?.records[recordID]
                    }
                },
                by: \.recordID
            )
            .compactMapValues(\.first)
            let (saveResults, deleteResults) = try syncEngine.database.modifyRecords(
                saving: recordsToSave,
                deleting: recordIDsToDelete,
                atomically: atomically
            )
            return ModifyRecordsCallback {
                let savedRecordIDs = saveResults.compactMap { recordID, result in
                    (try? result.get()) != nil ? recordID : nil
                }
                let deletedRecordIDs = deleteResults.compactMap { recordID, result in
                    (try? result.get()) != nil ? recordID : nil
                }
                let freshRecords =
                    (try? syncEngine.database.records(
                        for: savedRecordIDs + deletedRecordIDs,
                        desiredKeys: nil
                    )) ?? [:]
                await syncEngine.parentSyncEngine.handleEvent(
                    .fetchedRecordZoneChanges(
                        modifications: savedRecordIDs.compactMap { recordID in
                            try? freshRecords[recordID]?.get()
                        },
                        deletions: deletedRecordIDs.compactMap { recordID in
                            (try? freshRecords[recordID]?.get()) == nil
                                ? recordsToDeleteByID[recordID].map { (recordID, $0.recordType) }
                                : nil
                        }
                    ),
                    syncEngine: syncEngine
                )
            }
        }
    }

    extension MockSyncEngine {
        func assertFetchChangesScopes(
            _ scopes: [CKSyncEngine.FetchChangesOptions.Scope],
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            _fetchChangesScopes.withLock { fetchChangesScopes in
                #expect(scopes == fetchChangesScopes, sourceLocation: sourceLocation)
                fetchChangesScopes.removeAll()
            }
        }

        func assertAcceptedShareMetadata(
            _ shareMetadata: Set<ShareMetadata>,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            _acceptedShareMetadata.withLock { acceptedShareMetadata in
                #expect(shareMetadata == acceptedShareMetadata, sourceLocation: sourceLocation)
                acceptedShareMetadata.removeAll()
            }
        }
    }

    extension MockSyncEngineState {
        func assertPendingRecordZoneChanges(
            _ changes: Set<CKSyncEngine.PendingRecordZoneChange>,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            let pending = pendingRecordZoneChanges
            #expect(changes == Set(pending), sourceLocation: sourceLocation)
            remove(pendingRecordZoneChanges: pending)
        }

        func assertPendingDatabaseChanges(
            _ changes: Set<CKSyncEngine.PendingDatabaseChange>,
            sourceLocation: SourceLocation = #_sourceLocation
        ) {
            let pending = pendingDatabaseChanges
            #expect(changes == Set(pending), sourceLocation: sourceLocation)
            remove(pendingDatabaseChanges: pending)
        }
    }

    extension UserDatabase {
        func userWrite<T: Sendable>(
            _ updates: @Sendable (Database) throws -> T
        ) async throws -> T {
            try await database.write { db in
                try $_isSynchronizingChanges.withValue(false) {
                    try updates(db)
                }
            }
        }

        @_disfavoredOverload
        func userWrite<T>(
            _ updates: (Database) throws -> T
        ) throws -> T {
            try database.write { db in
                try $_isSynchronizingChanges.withValue(false) {
                    try updates(db)
                }
            }
        }
    }

    extension Result {
        var error: Failure? {
            switch self {
            case .success: nil
            case .failure(let error): error
            }
        }
    }
#endif
