#if CloudKit
#if canImport(CloudKit)
  public import CloudKit

  package protocol CloudDatabase: AnyObject, Hashable, Sendable {
    var databaseScope: CKDatabase.Scope { get }

    func record(for recordID: CKRecord.ID) async throws -> CKRecord

    func records(
      for ids: [CKRecord.ID],
      desiredKeys: [CKRecord.FieldKey]?
    ) async throws -> [CKRecord.ID: Result<CKRecord, any Error>]

    func modifyRecords(
      saving recordsToSave: [CKRecord],
      deleting recordIDsToDelete: [CKRecord.ID],
      savePolicy: CKModifyRecordsOperation.RecordSavePolicy,
      atomically: Bool
    ) async throws -> (
      saveResults: [CKRecord.ID: Result<CKRecord, any Error>],
      deleteResults: [CKRecord.ID: Result<Void, any Error>]
    )

    func modifyRecordZones(
      saving recordZonesToSave: [CKRecordZone],
      deleting recordZoneIDsToDelete: [CKRecordZone.ID]
    ) async throws -> (
      saveResults: [CKRecordZone.ID: Result<CKRecordZone, any Error>],
      deleteResults: [CKRecordZone.ID: Result<Void, any Error>]
    )
  }

  extension CloudDatabase {
    func modifyRecords(
      saving recordsToSave: [CKRecord],
      deleting recordIDsToDelete: [CKRecord.ID]
    ) async throws -> (
      saveResults: [CKRecord.ID: Result<CKRecord, any Error>],
      deleteResults: [CKRecord.ID: Result<Void, any Error>]
    ) {
      try await modifyRecords(
        saving: recordsToSave,
        deleting: recordIDsToDelete,
        savePolicy: .ifServerRecordUnchanged,
        atomically: true
      )
    }

    package func records(
      for ids: [CKRecord.ID]
    ) async throws -> [CKRecord.ID: Result<CKRecord, any Error>] {
      try await records(for: ids, desiredKeys: nil)
    }
  }

  extension CKDatabase: CloudDatabase {}

  final class AnyCloudDatabase: CloudDatabase {
    let rawValue: any CloudDatabase
    init(_ rawValue: any CloudDatabase) {
      self.rawValue = rawValue
    }

    var databaseScope: CKDatabase.Scope {
      rawValue.databaseScope
    }

    func record(for recordID: CKRecord.ID) async throws -> CKRecord {
      try await rawValue.record(for: recordID)
    }

    func records(
      for ids: [CKRecord.ID],
      desiredKeys: [CKRecord.FieldKey]?
    ) async throws -> [CKRecord.ID: Result<CKRecord, any Error>] {
      try await rawValue.records(for: ids)
    }

    func modifyRecords(
      saving recordsToSave: [CKRecord],
      deleting recordIDsToDelete: [CKRecord.ID],
      savePolicy: CKModifyRecordsOperation.RecordSavePolicy,
      atomically: Bool
    ) async throws -> (
      saveResults: [CKRecord.ID: Result<CKRecord, any Error>],
      deleteResults: [CKRecord.ID: Result<Void, any Error>]
    ) {
      try await rawValue.modifyRecords(
        saving: recordsToSave,
        deleting: recordIDsToDelete,
        savePolicy: savePolicy,
        atomically: atomically
      )
    }

    func modifyRecordZones(
      saving recordZonesToSave: [CKRecordZone],
      deleting recordZoneIDsToDelete: [CKRecordZone.ID]
    ) async throws -> (
      saveResults: [CKRecordZone.ID: Result<CKRecordZone, any Error>],
      deleteResults: [CKRecordZone.ID: Result<Void, any Error>]
    ) {
      try await rawValue.modifyRecordZones(
        saving: recordZonesToSave, deleting: recordZoneIDsToDelete)
    }

    static func == (lhs: AnyCloudDatabase, rhs: AnyCloudDatabase) -> Bool {
      lhs.rawValue === rhs.rawValue
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(ObjectIdentifier(rawValue))
    }
  }
#endif

#endif
