#if CloudKit
#if canImport(CloudKit)
  package import CloudKit
  package import Synchronization

  package final class MockCloudContainer: CloudContainer {
    package static let containers = Mutex<[String: MockCloudContainer]>([:])
    package let _accountStatus: Mutex<CKAccountStatus>
    package let containerIdentifier: String?
    package let privateCloudDatabase: MockCloudDatabase
    package let sharedCloudDatabase: MockCloudDatabase

    package init(
      accountStatus: CKAccountStatus = .available,
      containerIdentifier: String?,
      privateCloudDatabase: MockCloudDatabase,
      sharedCloudDatabase: MockCloudDatabase
    ) {
      self._accountStatus = Mutex(accountStatus)
      self.containerIdentifier = containerIdentifier
      self.privateCloudDatabase = privateCloudDatabase
      self.sharedCloudDatabase = sharedCloudDatabase

      guard let containerIdentifier else { return }
      Self.containers.withLock { $0[containerIdentifier] = self }
    }

    package func accountStatus() -> CKAccountStatus {
      _accountStatus.withLock { $0 }
    }

    package var rawValue: CKContainer {
      fatalError("This should never be called in tests.")
    }

    package func accountStatus() async throws -> CKAccountStatus {
      _accountStatus.withLock { $0 }
    }

    package func shareMetadata(
      for share: CKShare,
      shouldFetchRootRecord: Bool
    ) async throws -> ShareMetadata {
      let database =
        share.recordID.zoneID.ownerName == CKCurrentUserDefaultName
        ? privateCloudDatabase
        : sharedCloudDatabase

      let rootRecord: CKRecord? = database.state.withLock {
        $0.storage[share.recordID.zoneID]?.records.values.first { record in
          record.share?.recordID == share.recordID
        }?
          .copy() as? CKRecord
      }

      return ShareMetadata(
        containerIdentifier: containerIdentifier!,
        hierarchicalRootRecordID: rootRecord?.recordID,
        rootRecord: shouldFetchRootRecord ? rootRecord : nil,
        share: share
      )
    }

    package func accept(_ metadata: ShareMetadata) async throws -> CKShare {
      guard let rootRecord = metadata.rootRecord
      else {
        fatalError("Must provide root record in mock shares during tests.")
      }

      let (saveResults, _) = try sharedCloudDatabase.modifyRecords(
        saving: [metadata.share, rootRecord]
      )
      try saveResults.values.forEach { _ = try $0.get() }
      return metadata.share
    }

    package static func createContainer(identifier containerIdentifier: String)
      -> MockCloudContainer
    {
      containers.withLock { $0[containerIdentifier] }
        ?? {
          let container = MockCloudContainer(
            accountStatus: .available,
            containerIdentifier: containerIdentifier,
            privateCloudDatabase: MockCloudDatabase(databaseScope: .private),
            sharedCloudDatabase: MockCloudDatabase(databaseScope: .shared)
          )
          container.privateCloudDatabase.set(container: container)
          container.sharedCloudDatabase.set(container: container)
          return container
        }()
    }

    package static func == (lhs: MockCloudContainer, rhs: MockCloudContainer) -> Bool {
      lhs === rhs
    }

    package func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(self))
    }
  }
#endif

#endif
