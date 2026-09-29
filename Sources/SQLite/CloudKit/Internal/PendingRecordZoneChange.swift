#if CloudKit
#if canImport(CloudKit)
  import Byte
  package import CloudKit
  public import SQL
  import SQL_Macros

  @Table("sqlite_icloud_pendingRecordZoneChanges")
  package struct PendingRecordZoneChange {
    @Column(as: CKSyncEngine.PendingRecordZoneChange.DataRepresentation.self)
    package let pendingRecordZoneChange: CKSyncEngine.PendingRecordZoneChange
  }

  extension PendingRecordZoneChange {
    package init(_ pendingRecordZoneChange: CKSyncEngine.PendingRecordZoneChange) {
      self.pendingRecordZoneChange = pendingRecordZoneChange
    }
  }

  extension CKSyncEngine.PendingRecordZoneChange {
    package struct DataRepresentation: QueryBindable, QueryRepresentable {
      package var queryOutput: CKSyncEngine.PendingRecordZoneChange

      package init(queryOutput: CKSyncEngine.PendingRecordZoneChange) {
        self.queryOutput = queryOutput
      }

      package var queryBinding: ISO_9075.Value {
        let archiver = NSKeyedArchiver(requiringSecureCoding: true)
        switch queryOutput {
        case .saveRecord(let recordID):
          recordID.encode(with: archiver)
          archiver.encode("saveRecord", forKey: "changeType")
        case .deleteRecord(let recordID):
          recordID.encode(with: archiver)
          archiver.encode("deleteRecord", forKey: "changeType")
        @unknown default:
          return .invalid(ISO_9075.Value.Failure("Unknown pending record zone change: \(queryOutput)"))
        }
        return .blob([Byte](archiver.encodedData))
      }

      package init(decoder: inout some SQL::QueryDecoder) throws(QueryDecodingError) {
        let bytes = try [Byte](decoder: &decoder)
        do {
          try self.init(data: Data(bytes))
        } catch {
          throw .dataCorrupted("\(bytes.count) bytes as a pending record zone change")
        }
      }

      private init(data: Data) throws {
        let coder = try NSKeyedUnarchiver(forReadingFrom: data)
        coder.requiresSecureCoding = true
        guard let recordID = CKRecord.ID(coder: coder) else {
          throw DecodingError()
        }
        let changeType = coder.decodeObject(of: NSString.self, forKey: "changeType") as? String
        switch changeType {
        case "saveRecord":
          self.init(queryOutput: .saveRecord(recordID))
        case "deleteRecord":
          self.init(queryOutput: .deleteRecord(recordID))
        default:
          throw DecodingError()
        }
      }
    }

    private struct DecodingError: Error {}
  }
#endif

#endif
