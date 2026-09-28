#if canImport(CloudKit)
  package import CloudKit
  package import SQLiteData
  import Testing

  @TaskLocal package var prepareDatabase: @Sendable (UserDatabase) async throws -> Void = { _ in }
  @TaskLocal package var startImmediately = true
  @TaskLocal package var attachMetadatabase = false
  @TaskLocal package var accountStatus = CKAccountStatus.available
  @TaskLocal package var syncEngineDelegate: (any SyncEngineDelegate)? = nil
#endif
