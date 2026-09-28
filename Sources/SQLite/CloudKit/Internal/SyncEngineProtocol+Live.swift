#if CloudKit
#if canImport(CloudKit)
  public import CloudKit

  extension CKSyncEngine: SyncEngineProtocol {
    package func recordZoneChangeBatch(
      pendingChanges: [PendingRecordZoneChange],
      recordProvider: @Sendable (CKRecord.ID) async -> CKRecord?
    ) async -> RecordZoneChangeBatch? {
      await CKSyncEngine
        .RecordZoneChangeBatch(pendingChanges: pendingChanges, recordProvider: recordProvider)
    }
  }

  extension CKSyncEngine.State: CKSyncEngineStateProtocol {
  }
#endif

#endif
