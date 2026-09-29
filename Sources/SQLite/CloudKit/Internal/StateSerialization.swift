#if CloudKit
#if canImport(CloudKit)
  package import CloudKit
  package import SQL
  import SQL_Macros

  @Table("swiftsqlite_icloud_stateSerialization")
  package struct StateSerialization {
    @Column(as: CKDatabase.Scope.RawValueRepresentation.self, primaryKey: true)
    package var scope: CKDatabase.Scope
    @Column(as: JSONRepresentation<CKSyncEngine.State.Serialization>.self)
    package var data: CKSyncEngine.State.Serialization
  }
#endif

#endif
