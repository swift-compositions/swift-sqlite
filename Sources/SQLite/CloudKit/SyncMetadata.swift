#if CloudKit
#if canImport(CloudKit)
  public import CloudKit
  public import SQL

  @Table("sqlitedata_icloud_metadata")
  public struct SyncMetadata: Hashable, Identifiable, Sendable {
    @Selection
    public struct ID: Hashable, Sendable {
      public let recordPrimaryKey: String

      public let recordType: String
    }

    public let id: ID

    public var recordPrimaryKey: String { id.recordPrimaryKey }

    public var recordType: String { id.recordType }

    public let zoneName: String

    public let ownerName: String

    @Column(generated: .virtual)
    public let recordName: String

    @Selection
    public struct ParentID: Hashable, Sendable {
      public let parentRecordPrimaryKey: String

      public let parentRecordType: String
    }

    public let parentRecordID: ParentID?

    public var parentRecordPrimaryKey: String? { parentRecordID?.parentRecordPrimaryKey }

    public var parentRecordType: String? { parentRecordID?.parentRecordType }

    @Column(generated: .virtual)
    public let parentRecordName: String?

    @Column(as: CKRecord?.SystemFieldsRepresentation.self)
    public let lastKnownServerRecord: CKRecord?

    @Column(as: CKRecord?._AllFieldsRepresentation.self)
    public let _lastKnownServerRecordAllFields: CKRecord?

    @Column(as: CKShare?.SystemFieldsRepresentation.self)
    public let share: CKShare?

    public let _isDeleted: Bool

    @Column("hasLastKnownServerRecord", generated: .virtual)
    public let _hasLastKnownServerRecord: Bool

    @Column("isShared", generated: .virtual)
    fileprivate let _isShared: Bool

    public let userModificationTime: Int64

    public var hasLastKnownServerRecord: Bool {
      lastKnownServerRecord != nil
    }

    public var isShared: Bool {
      _isShared
    }
  }

  extension SyncMetadata.TableColumns {
    public var recordPrimaryKey: TableColumn<SyncMetadata, String> {
      id.recordPrimaryKey
    }

    public var recordType: TableColumn<SyncMetadata, String> {
      id.recordType
    }

    public var parentRecordPrimaryKey: TableColumn<SyncMetadata, String?> {
      parentRecordID.parentRecordPrimaryKey
    }

    public var parentRecordType: TableColumn<SyncMetadata, String?> {
      parentRecordID.parentRecordType
    }

    // NB: Workaround for https://github.com/groue/GRDB.swift/discussions/1844
    public var hasLastKnownServerRecord: some QueryExpression<Bool> {
      #sql(
        """
        ((\(self._hasLastKnownServerRecord) = 1) AND (\(self.lastKnownServerRecord) OR 1))
        """
      )
    }

    // NB: Workaround for https://github.com/groue/GRDB.swift/discussions/1844
    public var isShared: some QueryExpression<Bool> {
      #sql(
        """
        ((\(self._isShared) = 1) AND (\(self.share) OR 1))
        """
      )
    }
  }

  extension SyncMetadata {
    package init(
      recordPrimaryKey: String,
      recordType: String,
      zoneName: String,
      ownerName: String,
      parentRecordPrimaryKey: String? = nil,
      parentRecordType: String? = nil,
      lastKnownServerRecord: CKRecord? = nil,
      _lastKnownServerRecordAllFields: CKRecord? = nil,
      share: CKShare? = nil,
      userModificationTime: Int64
    ) {
      self.id = ID(recordPrimaryKey: recordPrimaryKey, recordType: recordType)
      self.recordName = "\(recordPrimaryKey):\(recordType)"
      self.zoneName = zoneName
      self.ownerName = ownerName
      if let parentRecordPrimaryKey, let parentRecordType {
        self.parentRecordID = ParentID(
          parentRecordPrimaryKey: parentRecordPrimaryKey,
          parentRecordType: parentRecordType
        )
        self.parentRecordName = "\(parentRecordPrimaryKey):\(parentRecordType)"
      } else {
        self.parentRecordID = nil
        self.parentRecordName = nil
      }
      self.lastKnownServerRecord = lastKnownServerRecord
      self._lastKnownServerRecordAllFields = _lastKnownServerRecordAllFields
      self.share = share
      self._hasLastKnownServerRecord = lastKnownServerRecord != nil
      self._isShared = share != nil
      self.userModificationTime = userModificationTime
      self._isDeleted = false
    }

    package static func find(_ recordID: CKRecord.ID) -> Where<Self> {
      Self.where {
        $0.recordName.eq(recordID.recordName)
          && $0.zoneName.eq(recordID.zoneID.zoneName)
          && $0.ownerName.eq(recordID.zoneID.ownerName)
      }
    }

    package static func findAll(_ recordIDs: some Collection<CKRecord.ID>) -> Where<Self> {
      let condition: QueryFragment = recordIDs.map {
        "(\(bind: $0.recordName), \(bind: $0.zoneID.zoneName), \(bind: $0.zoneID.ownerName))"
      }
      .joined(separator: ", ")
      return Self.where {
        #sql("(\($0.recordName), \($0.zoneName), \($0.ownerName)) IN (\(condition))")
      }
    }
  }

  extension PrimaryKeyedTable where PrimaryKey.QueryOutput: IdentifierStringConvertible {
    @available(*, deprecated, message: "Use 'SyncMetadata.find(record.syncMetadataID)', instead")
    public static func metadata(for primaryKey: PrimaryKey.QueryOutput) -> Where<SyncMetadata> {
      SyncMetadata.where {
        #sql(
          """
          \($0.recordPrimaryKey) = \(PrimaryKey(queryOutput: primaryKey)) \
          AND \($0.recordType) = \(bind: tableName)
          """
        )
      }
    }

    public var syncMetadataID: SyncMetadata.ID {
      SyncMetadata.ID(
        recordPrimaryKey: primaryKey.rawIdentifier,
        recordType: Self.tableName
      )
    }

    package static func recordName(for id: PrimaryKey.QueryOutput) -> String {
      "\(id.rawIdentifier):\(tableName)"
    }

    var recordName: String {
      Self.recordName(for: self[keyPath: Self.columns.primaryKey.keyPath])
    }
  }

  extension PrimaryKeyedTableDefinition where PrimaryKey.QueryOutput: IdentifierStringConvertible {
    @available(
      *,
      deprecated,
      message: """
        Join the 'SyncMetadata' table using 'SyncMetadata.id' and 'Table.syncMetadataID', instead.
        """
    )
    public func hasMetadata(in metadata: SyncMetadata.TableColumns) -> some QueryExpression<Bool> {
      metadata.recordType.eq(QueryValue.tableName)
        && #sql("\(primaryKey)").eq(metadata.recordPrimaryKey)
    }

    public var syncMetadataID: some QueryExpression<SyncMetadata.ID> {
      #sql("\(primaryKey), \(bind: QueryValue.tableName)")
    }
  }

  extension PrimaryKeyedTableDefinition {
    var _recordName: some QueryExpression<String> {
      #sql("\(primaryKey) || ':' || \(quote: QueryValue.tableName, delimiter: .text)")
    }
  }
#endif

#endif
