#if CloudKit
#if canImport(CloudKit)
  package import CloudKit
  package import SQL

  @Table("sqlitedata_icloud_stateSerialization")
  package struct StateSerialization {
    @Column(as: CKDatabase.Scope.RawValueRepresentation.self, primaryKey: true)
    package var scope: CKDatabase.Scope
    @Column(as: CKSyncEngine.State.Serialization.JSONRepresentation.self)
    package var data: CKSyncEngine.State.Serialization
  }
#endif

#endif
