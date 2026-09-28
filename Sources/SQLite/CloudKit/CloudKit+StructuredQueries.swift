#if CloudKit
#if canImport(CloudKit)
  public import Byte
  public import CloudKit
  import CryptoKit
  public import SQL
  import Time

  public struct _SystemFieldsRepresentation<Record: CKRecord>: QueryBindable, QueryRepresentable {
    public let queryOutput: Record

    public var queryBinding: ISO_9075.Value {
      let archiver = NSKeyedArchiver(requiringSecureCoding: true)
      queryOutput.encodeSystemFields(with: archiver)
      if let recordChangeTag = queryOutput._recordChangeTag {
        archiver.encode(recordChangeTag, forKey: "_recordChangeTag")
      }
      return .blob([Byte](archiver.encodedData))
    }

    public init(queryOutput: Record) {
      self.queryOutput = queryOutput
    }

    public init(decoder: inout some SQL.QueryDecoder) throws(QueryDecodingError) {
      let bytes = try [Byte](decoder: &decoder)
      do {
        try self.init(data: Data(bytes))
      } catch {
        throw .dataCorrupted("\(bytes.count) bytes as \(Record.self)")
      }
    }

    private init(data: Data) throws {
      let coder = try NSKeyedUnarchiver(forReadingFrom: data)
      coder.requiresSecureCoding = true
      guard let queryOutput = Record(coder: coder) else {
        throw DecodingError()
      }
      if let recordChangeTag = coder
        .decodeObject(of: NSNumber.self, forKey: "_recordChangeTag")?.intValue
      {
        queryOutput._recordChangeTag = recordChangeTag
      }
      self.init(queryOutput: queryOutput)
    }

    private struct DecodingError: Error {}
  }

  public struct _AllFieldsRepresentation<Record: CKRecord>: QueryBindable, QueryRepresentable {
    public let queryOutput: Record

    public var queryBinding: ISO_9075.Value {
      let archiver = NSKeyedArchiver(requiringSecureCoding: true)
      queryOutput.encode(with: archiver)
      if let recordChangeTag = queryOutput._recordChangeTag {
        archiver.encode(recordChangeTag, forKey: "_recordChangeTag")
      }
      return .blob([Byte](archiver.encodedData))
    }

    public init(queryOutput: Record) {
      self.queryOutput = queryOutput
    }

    public init(decoder: inout some SQL.QueryDecoder) throws(QueryDecodingError) {
      let bytes = try [Byte](decoder: &decoder)
      do {
        try self.init(data: Data(bytes))
      } catch {
        throw .dataCorrupted("\(bytes.count) bytes as \(Record.self)")
      }
    }

    private init(data: Data) throws {
      let coder = try NSKeyedUnarchiver(forReadingFrom: data)
      coder.requiresSecureCoding = true
      guard let queryOutput = Record(coder: coder) else {
        throw DecodingError()
      }
      if let recordChangeTag = coder
        .decodeObject(of: NSNumber.self, forKey: "_recordChangeTag")?.intValue
      {
        queryOutput._recordChangeTag = recordChangeTag
      }
      self.init(queryOutput: queryOutput)
    }

    private struct DecodingError: Error {}
  }

  extension CKDatabase.Scope {
    public struct RawValueRepresentation: QueryBindable, QueryRepresentable {
      public let queryOutput: CKDatabase.Scope
      public var queryBinding: ISO_9075.Value {
        .int(Int64(queryOutput.rawValue))
      }
      public init(queryOutput: CKDatabase.Scope) {
        self.queryOutput = queryOutput
      }
      public init(decoder: inout some QueryDecoder) throws(QueryDecodingError) {
        let rawValue = try Int(decoder: &decoder)
        guard let queryOutput = CKDatabase.Scope(rawValue: rawValue)
        else { throw .dataCorrupted("\(rawValue) as a database scope") }
        self.init(queryOutput: queryOutput)
      }
    }
  }

  extension CKRecordKeyValueSetting {
    fileprivate subscript(at key: String) -> Int64 {
      get {
        self["\(CKRecord.userModificationTimeKey)_\(key)"] as? Int64 ?? -1
      }
      set {
        self["\(CKRecord.userModificationTimeKey)_\(key)"] = max(self[at: key], newValue)
      }
    }
    fileprivate subscript(hash key: String) -> Data? {
      get { self["\(key)_hash"] as? Data }
      set { self["\(key)_hash"] = newValue }
    }
  }

  extension CKRecord {
    func hasSet(key: String) -> Bool {
      self.encryptedValues["\(CKRecord.userModificationTimeKey)_\(key)"] != nil
    }

    @discardableResult
    package func setValue(
      _ newValue: some CKRecordValueProtocol & Equatable,
      forKey key: CKRecord.FieldKey,
      at userModificationTime: Int64
    ) -> Bool {
      guard
        encryptedValues[at: key] <= userModificationTime,
        encryptedValues[key] != newValue
      else { return false }
      encryptedValues[key] = newValue
      encryptedValues[at: key] = userModificationTime
      self.userModificationTime = userModificationTime
      return true
    }

    @discardableResult
    package func setAsset(
      _ newValue: CKAsset,
      forKey key: CKRecord.FieldKey,
      at userModificationTime: Int64,
      dataManager: some DataManager
    ) -> Bool {
      guard
        let fileURL = newValue.fileURL,
        let hash = dataManager.sha256(of: fileURL)
      else { return false }
      guard
        encryptedValues[at: key] <= userModificationTime,
        encryptedValues[hash: key] != hash
      else { return false }

      self[key] = newValue
      encryptedValues[hash: key] = hash
      encryptedValues[at: key] = userModificationTime
      self.userModificationTime = userModificationTime
      return true
    }

    @discardableResult
    package func setBytes(
      _ newValue: [Byte],
      forKey key: CKRecord.FieldKey,
      at userModificationTime: Int64,
      dataManager: some DataManager
    ) throws -> Bool {
      guard encryptedValues[at: key] <= userModificationTime
      else { return false }

      let hash = newValue.sha256
      let fileURL = dataManager.temporaryDirectory.appending(
        component:
          hash
          .compactMap { String(format: "%02hhx", $0) }
          .joined()
      )
      let asset = CKAsset(fileURL: fileURL)
      try dataManager.save(Data(newValue), to: fileURL)
      self[key] = asset
      encryptedValues[at: key] = userModificationTime
      encryptedValues[hash: key] = hash
      self.userModificationTime = userModificationTime
      return true
    }

    @discardableResult
    package func removeValue(
      forKey key: CKRecord.FieldKey,
      at userModificationTime: Int64
    ) -> Bool {
      guard encryptedValues[at: key] <= userModificationTime
      else {
        return false
      }
      if encryptedValues[key] != nil {
        encryptedValues[key] = nil
        encryptedValues[at: key] = userModificationTime
        self.userModificationTime = userModificationTime
        return true
      } else if self[key] != nil {
        self[key] = nil
        encryptedValues[at: key] = userModificationTime
        self.userModificationTime = userModificationTime
        return true
      } else if !hasSet(key: key) {
        encryptedValues[at: key] = userModificationTime
        self.userModificationTime = userModificationTime
      }
      return false
    }

    func update<T: PrimaryKeyedTable>(
      with row: T,
      userModificationTime: Int64,
      dataManager: some DataManager
    ) throws {
      var failures: [String: SyncEngine.Error] = [:]
      for column in T.TableColumns.writableColumns {
        func open<Root, Value>(
          _ column: some WritableTableColumnExpression<Root, Value>
        ) throws {
          let keyPath = column.keyPath as! KeyPath<T, Value.QueryOutput>
          let column = column as! any WritableTableColumnExpression<T, Value>
          let value = Value(queryOutput: row[keyPath: keyPath])
          switch value.queryBinding {
          case .blob(let value):
            try setBytes(
              value,
              forKey: column.name,
              at: userModificationTime,
              dataManager: dataManager
            )
          case .bool(let value):
            setValue(value, forKey: column.name, at: userModificationTime)
          case .double(let value):
            setValue(value, forKey: column.name, at: userModificationTime)
          case .timestamp(let value):
            setValue(Date(value), forKey: column.name, at: userModificationTime)
          case .int(let value):
            setValue(value, forKey: column.name, at: userModificationTime)
          case .null:
            removeValue(forKey: column.name, at: userModificationTime)
          case .text(let value), .decimal(let value):
            setValue(value, forKey: column.name, at: userModificationTime)
          case .json(let value):
            setValue(
              String(decoding: value, as: UTF8.self),
              forKey: column.name,
              at: userModificationTime
            )
          case .uuid(let value):
            setValue(String(value).lowercased(), forKey: column.name, at: userModificationTime)
          case .array:
            throw ISO_9075.Value.Failure("SQLite has no array values")
          case .invalid(let failure):
            throw failure
          }
        }
        do {
          try open(column)
        } catch {
          failures[column.name] = SyncEngine.Error(error)
        }
      }
      guard failures.isEmpty
      else {
        throw SyncEngine.Error.unencodableColumns(recordName: recordID.recordName, failures)
      }
    }

    func update<T: PrimaryKeyedTable>(
      with other: CKRecord,
      row: T,
      columnNames: inout [String],
      parentForeignKey: ForeignKey?,
      dataManager: some DataManager
    ) throws {
      typealias EquatableCKRecordValueProtocol = CKRecordValueProtocol & Equatable

      var failures: [String: SyncEngine.Error] = [:]
      self.userModificationTime = other.userModificationTime
      for column in T.TableColumns.writableColumns {
        func open<Root, Value>(_ column: some WritableTableColumnExpression<Root, Value>) {
          let key = column.name
          let keyPath = column.keyPath as! KeyPath<T, Value.QueryOutput>
          let didSet: Bool
          if let value = other[key] as? CKAsset {
            didSet = setAsset(
              value,
              forKey: key,
              at: other.encryptedValues[at: key],
              dataManager: dataManager
            )
          } else if let value = other.encryptedValues[key] as? any EquatableCKRecordValueProtocol {
            didSet = setValue(value, forKey: key, at: other.encryptedValues[at: key])
          } else if other.encryptedValues[key] == nil {
            didSet = removeValue(forKey: key, at: other.encryptedValues[at: key])
          } else {
            didSet = false
          }
          var isRowValueModified: Bool {
            switch Value(queryOutput: row[keyPath: keyPath]).queryBinding {
            case .blob(let value):
              return other.encryptedValues[hash: key] != value.sha256
            case .bool(let value):
              return other.encryptedValues[key] != value
            case .double(let value):
              return other.encryptedValues[key] != value
            case .timestamp(let value):
              return other.encryptedValues[key] != Date(value)
            case .int(let value):
              return other.encryptedValues[key] != value
            case .null:
              return other.encryptedValues[key] != nil
            case .text(let value), .decimal(let value):
              return other.encryptedValues[key] != value
            case .json(let value):
              return other.encryptedValues[key] != String(decoding: value, as: UTF8.self)
            case .uuid(let value):
              return other.encryptedValues[key] != String(value).lowercased()
            case .array:
              failures[key] = .binding(ISO_9075.Value.Failure("SQLite has no array values"))
              return false
            case .invalid(let failure):
              failures[key] = .binding(failure)
              return false
            }
          }
          if didSet || isRowValueModified {
            columnNames.removeAll(where: { $0 == key })
            if didSet, let parentForeignKey, key == parentForeignKey.from {
              self.parent = other.parent
            }
          }
        }
        open(column)
      }
      guard failures.isEmpty
      else {
        throw SyncEngine.Error.unencodableColumns(recordName: recordID.recordName, failures)
      }
    }

    package var userModificationTime: Int64 {
      get { encryptedValues[Self.userModificationTimeKey] as? Int64 ?? -1 }
      set {
        encryptedValues[Self.userModificationTimeKey] = Swift.max(userModificationTime, newValue)
      }
    }

    package static let userModificationTimeKey =
      "\(String.sqliteCloudKitSchemaName)_userModificationTime"
  }

  extension __CKRecordObjCValue {
    var queryFragment: ISO_9075.Fragment {
      switch self {
      case let value as Int64: value.queryFragment
      case let value as Double: value.queryFragment
      case let value as String: value.queryFragment
      case let value as Data: [Byte](value).queryFragment
      case let value as Date: Time.Instant(value).queryFragment
      default:
        "\(ISO_9075.Value.invalid(ISO_9075.Value.Failure("\(type(of: self)) is not bindable")))"
      }
    }
  }

  extension CKRecord {
    package var _recordChangeTag: Int? {
      get { self[#function] }
      set { self[#function] = newValue }
    }
  }

  extension [Byte] {
    fileprivate var sha256: Data {
      Data(SHA256.hash(data: Data(self)))
    }
  }
#endif

#endif
