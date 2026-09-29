#if CloudKit
#if canImport(CloudKit)
  import CloudKit
  import Foundation
  import SQL
  import SQL_Macros

  extension PrimaryKeyedTable {
    static func metadataTriggers(
      parentForeignKey: ForeignKey?,
      defaultZone: CKRecordZone,
      privateTables: [any SynchronizableTable]
    ) -> [TemporaryTrigger<Self>] {
      [
        afterInsert(
          parentForeignKey: parentForeignKey,
          defaultZone: defaultZone,
          privateTables: privateTables
        ),
        afterUpdate(
          parentForeignKey: parentForeignKey,
          defaultZone: defaultZone,
          privateTables: privateTables
        ),
        afterDeleteFromUser(
          parentForeignKey: parentForeignKey,
          defaultZone: defaultZone,
          privateTables: privateTables
        ),
        afterDeleteFromSyncEngine,
        afterPrimaryKeyChange(
          parentForeignKey: parentForeignKey,
          defaultZone: defaultZone,
          privateTables: privateTables
        ),
      ]
    }

    fileprivate static func afterPrimaryKeyChange(
      parentForeignKey: ForeignKey?,
      defaultZone: CKRecordZone,
      privateTables: [any SynchronizableTable]
    ) -> TemporaryTrigger<Self> {
      createTemporaryTrigger(
        "\(String.sqliteCloudKitSchemaName)_after_primary_key_change_on_\(tableName)",
        ifNotExists: true,
        after: .update(of: \.primaryKey) { old, new in
          checkWritePermissions(
            alias: new,
            parentForeignKey: parentForeignKey,
            defaultZone: defaultZone,
            privateTables: privateTables
          )
          SyncMetadata
            .where {
              $0.recordPrimaryKey.eq(#sql("\(old.primaryKey)"))
                && $0.recordType.eq(tableName)
            }
            .update { $0._isDeleted = true }
        } when: { old, new in
          old.primaryKey.neq(new.primaryKey)
        }
      )
    }

    fileprivate static func afterInsert(
      parentForeignKey: ForeignKey?,
      defaultZone: CKRecordZone,
      privateTables: [any SynchronizableTable]
    ) -> TemporaryTrigger<Self> {
      createTemporaryTrigger(
        "\(String.sqliteCloudKitSchemaName)_after_insert_on_\(tableName)",
        ifNotExists: true,
        after: .insert { new in
          checkWritePermissions(
            alias: new,
            parentForeignKey: parentForeignKey,
            defaultZone: defaultZone,
            privateTables: privateTables
          )
          SyncMetadata.insert(
            new: new,
            parentForeignKey: parentForeignKey,
            defaultZone: defaultZone,
            privateTables: privateTables
          )
        }
      )
    }

    fileprivate static func afterUpdate(
      parentForeignKey: ForeignKey?,
      defaultZone: CKRecordZone,
      privateTables: [any SynchronizableTable]
    ) -> TemporaryTrigger<Self> {
      createTemporaryTrigger(
        "\(String.sqliteCloudKitSchemaName)_after_update_on_\(tableName)",
        ifNotExists: true,
        after: .update { _, new in
          checkWritePermissions(
            alias: new,
            parentForeignKey: parentForeignKey,
            defaultZone: defaultZone,
            privateTables: privateTables
          )
          SyncMetadata.insert(
            new: new,
            parentForeignKey: parentForeignKey,
            defaultZone: defaultZone,
            privateTables: privateTables
          )
          SyncMetadata.update(
            new: new,
            parentForeignKey: parentForeignKey,
            defaultZone: defaultZone,
            privateTables: privateTables
          )
        }
      )
    }

    fileprivate static func afterDeleteFromUser(
      parentForeignKey: ForeignKey?,
      defaultZone: CKRecordZone,
      privateTables: [any SynchronizableTable]
    ) -> TemporaryTrigger<
      Self
    > {
      createTemporaryTrigger(
        "\(String.sqliteCloudKitSchemaName)_after_delete_on_\(tableName)_from_user",
        ifNotExists: true,
        after: .delete { old in
          checkWritePermissions(
            alias: old,
            parentForeignKey: parentForeignKey,
            defaultZone: defaultZone,
            privateTables: privateTables
          )
          SyncMetadata
            .where {
              $0.recordPrimaryKey.eq(#sql("\(old.primaryKey)"))
                && $0.recordType.eq(tableName)
            }
            .update { $0._isDeleted = true }
        } when: { _ in
          !SyncEngine.$isSynchronizing
        }
      )
    }

    fileprivate static var afterDeleteFromSyncEngine: TemporaryTrigger<Self> {
      createTemporaryTrigger(
        "\(String.sqliteCloudKitSchemaName)_after_delete_on_\(tableName)_from_sync_engine",
        ifNotExists: true,
        after: .delete { old in
          SyncMetadata
            .where {
              $0.recordPrimaryKey.eq(#sql("\(old.primaryKey)"))
                && $0.recordType.eq(tableName)
            }
            .delete()
        } when: { _ in
          SyncEngine.$isSynchronizing
        }
      )
    }
  }

  extension SyncMetadata {
    fileprivate static func insert<T: PrimaryKeyedTable, Name>(
      new: SQL::TableAlias<T, Name>.TableColumns,
      parentForeignKey: ForeignKey?,
      defaultZone: CKRecordZone,
      privateTables: [any SynchronizableTable]
    ) -> some SQL::Statement {
      let (parentRecordPrimaryKey, parentRecordType, zoneName, ownerName) = parentFields(
        alias: new,
        parentForeignKey: parentForeignKey,
        defaultZone: defaultZone,
        privateTables: privateTables
      )
      let defaultZoneName = #sql(
        "\(text: defaultZone.zoneID.zoneName)",
        as: String.self
      )
      let defaultOwnerName = #sql(
        "\(text: defaultZone.zoneID.ownerName)",
        as: String.self
      )
      return insert {
        (
          $0.recordPrimaryKey,
          $0.recordType,
          $0.zoneName,
          $0.ownerName,
          $0.parentRecordPrimaryKey,
          $0.parentRecordType
        )
      } select: {
        Select(
          #sql("\(new.primaryKey)"),
          T.tableName,
          zoneName ?? defaultZoneName,
          ownerName ?? defaultOwnerName,
          parentRecordPrimaryKey,
          parentRecordType
        )
      } onConflictDoUpdate: { _ in
      }
    }

    fileprivate static func update<T: PrimaryKeyedTable, Name>(
      new: SQL::TableAlias<T, Name>.TableColumns,
      parentForeignKey: ForeignKey?,
      defaultZone: CKRecordZone,
      privateTables: [any SynchronizableTable]
    ) -> some SQL::Statement {
      let (parentRecordPrimaryKey, parentRecordType, zoneName, ownerName) = parentFields(
        alias: new,
        parentForeignKey: parentForeignKey,
        defaultZone: defaultZone,
        privateTables: privateTables
      )
      return Self.where {
        $0.recordPrimaryKey.eq(#sql("\(new.primaryKey)"))
          && $0.recordType.eq(T.tableName)
      }
      .update {
        $0.zoneName = zoneName ?? $0.zoneName
        $0.ownerName = ownerName ?? $0.ownerName
        $0.parentRecordPrimaryKey = parentRecordPrimaryKey
        $0.parentRecordType = parentRecordType
        $0.userModificationTime = #sql("swiftsqlite_icloud_currentTime()")
      }
    }
  }

  extension SyncMetadata {
    static func callbackTriggers(for syncEngine: SyncEngine) -> [TemporaryTrigger<Self>] {
      [
        afterInsertTrigger(for: syncEngine),
        afterZoneUpdateTrigger(),
        afterUpdateTrigger(for: syncEngine),
        afterSoftDeleteTrigger(for: syncEngine),
      ]
    }

    fileprivate static func afterInsertTrigger(for syncEngine: SyncEngine) -> TemporaryTrigger<Self>
    {
      createTemporaryTrigger(
        "\(String.sqliteCloudKitSchemaName)_after_insert_on_swiftsqlite_icloud_metadata",
        ifNotExists: true,
        after: .insert { new in
          validate(recordName: new.recordName)
          #sql(
            """
            SELECT \(
            syncEngine.$didUpdate(
              recordName: new.recordName,
              zoneName: new.zoneName,
              ownerName: new.ownerName,
              oldZoneName: new.zoneName,
              oldOwnerName: new.ownerName,
              descendantRecordNames: #bind(nil)
            )
            )
            """,
            as: Never.self
          )
        } when: { _ in
          !SyncEngine.$isSynchronizing
        }
      )
    }

    fileprivate static func afterZoneUpdateTrigger() -> TemporaryTrigger<Self> {
      createTemporaryTrigger(
        "\(String.sqliteCloudKitSchemaName)_after_zone_update_on_swiftsqlite_icloud_metadata",
        ifNotExists: true,
        after: .update {
          ($0.zoneName, $0.ownerName)
        } forEachRow: { old, new in
          let selfAndDescendantRecordNames = descendantRecordNames(
            recordName: new.recordName,
            includeSelf: true
          ) {
            $0.select(\.recordName)
          }
          SyncMetadata
            .where {
              $0.recordName.in(selfAndDescendantRecordNames)
            }
            .update {
              $0.zoneName = new.zoneName
              $0.ownerName = new.ownerName
              $0.lastKnownServerRecord = #bind(nil)
              $0._lastKnownServerRecordAllFields = #bind(nil)
            }
        } when: { old, new in
          new.zoneName.neq(old.zoneName) || new.ownerName.neq(old.ownerName)
        }
      )
    }

    fileprivate static func afterUpdateTrigger(for syncEngine: SyncEngine) -> TemporaryTrigger<Self>
    {
      createTemporaryTrigger(
        "\(String.sqliteCloudKitSchemaName)_after_update_on_swiftsqlite_icloud_metadata",
        ifNotExists: true,
        after: .update { old, new in
          let zoneChanged = new.zoneName.neq(old.zoneName) || new.ownerName.neq(old.ownerName)
          let descendantRecordNamesJSON = descendantRecordNames(
            recordName: new.recordName,
            includeSelf: false
          ) {
            $0.select { $0.recordName.jsonGroupArray() }
          }

          validate(recordName: new.recordName)
          #sql(
            """
            SELECT \(
            syncEngine.$didUpdate(
              recordName: new.recordName,
              zoneName: new.zoneName,
              ownerName: new.ownerName,
              oldZoneName: old.zoneName,
              oldOwnerName: old.ownerName,
              descendantRecordNames: Case().when(zoneChanged, then: descendantRecordNamesJSON)
            )
            )
            """,
            as: Never.self
          )
        } when: { old, new in
          old._isDeleted.eq(new._isDeleted) && !SyncEngine.$isSynchronizing
        }
      )
    }

    fileprivate static func afterSoftDeleteTrigger(
      for syncEngine: SyncEngine
    ) -> TemporaryTrigger<Self> {
      createTemporaryTrigger(
        "\(String.sqliteCloudKitSchemaName)_after_delete_on_swiftsqlite_icloud_metadata",
        ifNotExists: true,
        after: .update(of: \._isDeleted) { _, new in
          #sql(
            """
            SELECT \(
            syncEngine.$didDelete(
              recordName: new.recordName,
              record: new.lastKnownServerRecord
                ?? rootServerRecord(recordName: new.recordName),
              share: new.share
            )
            )
            """,
            as: Never.self
          )
        } when: { old, new in
          !old._isDeleted && new._isDeleted && !SyncEngine.$isSynchronizing
        }
      )
    }
  }

  private func parentFields<Base, Name>(
    alias: SQL::TableAlias<Base, Name>.TableColumns,
    parentForeignKey: ForeignKey?,
    defaultZone: CKRecordZone,
    privateTables: [any SynchronizableTable]
  ) -> (
    parentRecordPrimaryKey: SQLQueryExpression<String>?,
    parentRecordType: SQLQueryExpression<String>?,
    zoneName: SQLQueryExpression<String?>,
    ownerName: SQLQueryExpression<String?>
  ) {
    let zoneNameOverride: SQLQueryExpression<String?>
    let ownerNameOverride: SQLQueryExpression<String?>
    if privateTables.contains(where: { $0.base.tableName == Base.tableName }) {
      zoneNameOverride = #sql("\(text: defaultZone.zoneID.zoneName)")
      ownerNameOverride = #sql("\(text: defaultZone.zoneID.ownerName)")
    } else {
      zoneNameOverride = #sql("NULL")
      ownerNameOverride = #sql("NULL")
    }
    return
      parentForeignKey
      .map { foreignKey in
        let parentRecordPrimaryKey = #sql(
          #"\#(type(of: alias).QueryValue.self).\#(quote: foreignKey.from)"#,
          as: String.self
        )
        let parentRecordType = #sql("\(bind: foreignKey.table)", as: String.self)
        let parentMetadata = SyncMetadata.where {
          $0.recordPrimaryKey.eq(parentRecordPrimaryKey)
            && $0.recordType.eq(parentRecordType)
        }
        return (
          parentRecordPrimaryKey,
          parentRecordType,
          #sql(
            "coalesce(\(zoneNameOverride), \($currentZoneName()), (\(parentMetadata.select(\.zoneName))))"
          ),
          #sql(
            "coalesce(\(ownerNameOverride), \($currentOwnerName()), (\(parentMetadata.select(\.ownerName))))"
          )
        )
      }
      ?? (
        nil,
        nil,
        SQLQueryExpression($currentZoneName()),
        SQLQueryExpression($currentOwnerName())
      )
  }

  private func validate(
    recordName: some QueryExpression<String>
  ) -> some SQL::Statement<Never> {
    #sql(
      """
      SELECT RAISE(ABORT, \(text: SyncEngine.invalidRecordNameError))
      WHERE NOT \(recordName.isValidCloudKitRecordName)
      """,
      as: Never.self
    )
  }

  private func checkWritePermissions<Base, Name>(
    alias: SQL::TableAlias<Base, Name>.TableColumns,
    parentForeignKey: ForeignKey?,
    defaultZone: CKRecordZone,
    privateTables: [any SynchronizableTable]
  ) -> some SQL::Statement<Never> {
    let (parentRecordPrimaryKey, parentRecordType, _, _) = parentFields(
      alias: alias,
      parentForeignKey: parentForeignKey,
      defaultZone: defaultZone,
      privateTables: privateTables
    )

    return With {
      SyncMetadata
        .where {
          $0.recordPrimaryKey.is(parentRecordPrimaryKey)
            && $0.recordType.is(parentRecordType)
        }
        .select { RootShare.Columns(parentRecordName: $0.parentRecordName, share: $0.share) }
        .union(
          all: true,
          SyncMetadata
            .select {
              RootShare.Columns(parentRecordName: $0.parentRecordName, share: $0.share)
            }
            .join(RootShare.all) { $0.recordName.is($1.parentRecordName) }
        )
    } query: {
      RootShare
        .select { _ in
          #sql(
            "RAISE(ABORT, \(text: SyncEngine.writePermissionError))",
            as: Never.self
          )
        }
        .where {
          !SyncEngine.$isSynchronizing
            && $0.parentRecordName.is(nil)
            && !$hasPermission($0.share)
        }
    }
  }

  private func descendantRecordNames<T>(
    recordName: some QueryExpression<String>,
    includeSelf: Bool,
    select: (Where<DescendantMetadata>) -> Select<T, DescendantMetadata, ()>
  ) -> some Statement<T> {
    With {
      SyncMetadata
        .where { $0.recordName.eq(recordName) }
        .select {
          DescendantMetadata.Columns(recordName: $0.recordName, parentRecordName: #bind(nil))
        }
        .union(
          all: true,
          SyncMetadata
            .select {
              DescendantMetadata.Columns(
                recordName: $0.recordName,
                parentRecordName: $0.parentRecordName
              )
            }
            .join(DescendantMetadata.all) { $0.parentRecordName.eq($1.recordName) }
        )
    } query: {
      select(
        DescendantMetadata.where {
          if !includeSelf {
            $0.recordName.neq(recordName)
          }
        }
      )
    }
  }

  private func rootServerRecord(
    recordName: some QueryExpression<String>
  ) -> some QueryExpression<_SystemFieldsRepresentation<CKRecord>?> {
    With {
      SyncMetadata
        .where { $0.recordName.eq(recordName) }
        .select { AncestorMetadata.Columns($0) }
        .union(
          all: true,
          SyncMetadata
            .select { AncestorMetadata.Columns($0) }
            .join(AncestorMetadata.all) { $0.recordName.is($1.parentRecordName) }
        )
    } query: {
      AncestorMetadata
        .select(\.lastKnownServerRecord)
        .where { $0.parentRecordName.is(nil) }
    }
  }

  private func parentLastKnownServerRecord(
    parentRecordPrimaryKey: some QueryExpression<String?>,
    parentRecordType: some QueryExpression<String?>
  ) -> some QueryExpression<_SystemFieldsRepresentation<CKRecord>?> {
    SyncMetadata
      .select(\.lastKnownServerRecord)
      .where {
        $0.recordPrimaryKey.is(parentRecordPrimaryKey)
          && $0.recordType.is(parentRecordType)
      }
  }

  extension AncestorMetadata.Selection {
    init(_ metadata: SyncMetadata.TableColumns) {
      self.init(
        recordName: metadata.recordName,
        parentRecordName: metadata.parentRecordName,
        lastKnownServerRecord: metadata.lastKnownServerRecord
      )
    }
  }

  extension QueryExpression<String> {
    fileprivate var isValidCloudKitRecordName: some QueryExpression<Bool> {
      substr(1, 1).neq("_") && octetLength().lte(255) && octetLength().eq(length())
    }
  }

  @Selection
  private struct DescendantMetadata {
    let recordName: String
    let parentRecordName: String?
  }

  @Selection
  private struct AncestorMetadata {
    let recordName: String
    let parentRecordName: String?
    @Column(as: _SystemFieldsRepresentation<CKRecord>?.self)
    let lastKnownServerRecord: CKRecord?
  }

  @Selection
  struct RecordWithRoot {
    let parentRecordName: String?
    let recordName: String
    @Column(as: _SystemFieldsRepresentation<CKRecord>?.self)
    let lastKnownServerRecord: CKRecord?
    let rootRecordName: String
    @Column(as: _SystemFieldsRepresentation<CKRecord>?.self)
    let rootLastKnownServerRecord: CKRecord?
  }

  @Selection
  private struct RootShare {
    let parentRecordName: String?
    @Column(as: _SystemFieldsRepresentation<CKShare>?.self)
    let share: CKShare?
  }
#endif

#endif
