#if GRDB
public import Byte
internal import GRDBSQLite
internal import ISO_9075_Foundation
public import RFC_4122
public import SQL
public import Time

struct SQLiteFunctionDecoder: QueryDecoder {
  let name: String
  var argumentCount: Int32 = 0
  var arguments: UnsafeMutablePointer<OpaquePointer?>?
  var currentIndex: Int32 = 0

  init(name: String) {
    self.name = name
  }

  mutating func reset(argumentCount: Int32, arguments: UnsafeMutablePointer<OpaquePointer?>?) {
    self.argumentCount = argumentCount
    unsafe self.arguments = arguments
    self.currentIndex = 0
  }

  mutating func next() {
    currentIndex = 0
  }

  private var currentStorage: Int32 {
    currentIndex < argumentCount
      ? unsafe sqlite3_value_type(arguments?[Int(currentIndex)])
      : SQLITE_NULL
  }

  private mutating func argument<Value>(
    expecting storage: Int32,
    as _: Value.Type,
    _ read: (OpaquePointer?) throws(QueryDecodingError) -> Value
  ) throws(QueryDecodingError) -> Value? {
    guard currentIndex < argumentCount else { throw .missingRequiredColumn }
    defer { currentIndex += 1 }
    let value = unsafe arguments?[Int(currentIndex)]
    switch unsafe sqlite3_value_type(value) {
    case SQLITE_NULL: return nil
    case storage: return try read(value)
    case let found:
      throw .typeMismatch(
        expected: """
          \(Value.self) for argument \(currentIndex) of \(name.debugDescription), \
          found \(storageClassName(found))
          """
      )
    }
  }

  mutating func decode(_ columnType: [Byte].Type) throws(QueryDecodingError) -> [Byte]? {
    try argument(expecting: SQLITE_BLOB, as: [Byte].self) { value in
      guard let blob = unsafe sqlite3_value_blob(value) else { return [] }
      return unsafe UnsafeRawBufferPointer(start: blob, count: Int(sqlite3_value_bytes(value)))
        .map(Byte.init(bitPattern:))
    }
  }

  mutating func decode(_ columnType: Bool.Type) throws(QueryDecodingError) -> Bool? {
    try decode(Int64.self).map { $0 != 0 }
  }

  mutating func decode(_ columnType: Double.Type) throws(QueryDecodingError) -> Double? {
    switch currentStorage {
    case SQLITE_INTEGER: try decode(Int64.self).map(Double.init)
    default: try argument(expecting: SQLITE_FLOAT, as: Double.self) { unsafe sqlite3_value_double($0) }
    }
  }

  mutating func decode(_ columnType: Int.Type) throws(QueryDecodingError) -> Int? {
    try decode(Int64.self).map(Int.init)
  }

  mutating func decode(_ columnType: Int64.Type) throws(QueryDecodingError) -> Int64? {
    try argument(expecting: SQLITE_INTEGER, as: Int64.self) { unsafe sqlite3_value_int64($0) }
  }

  mutating func decode(_ columnType: String.Type) throws(QueryDecodingError) -> String? {
    try argument(expecting: SQLITE_TEXT, as: String.self) { value in
      unsafe String(
        decoding: UnsafeBufferPointer(
          start: sqlite3_value_text(value),
          count: Int(sqlite3_value_bytes(value))
        ),
        as: UTF8.self
      )
    }
  }

  mutating func decode(_ columnType: UInt64.Type) throws(QueryDecodingError) -> UInt64? {
    try decode(Int64.self).map { value throws(QueryDecodingError) in
      guard let unsigned = UInt64(exactly: value) else { throw .overflow("\(value) as UInt64") }
      return unsigned
    }
  }

  mutating func decode(_ columnType: Time.Instant.Type) throws(QueryDecodingError) -> Time.Instant? {
    try decode(String.self).map { string throws(QueryDecodingError) in
      do {
        return try ISO_9075.Literal.instant(string)
      } catch {
        throw .dataCorrupted("\(string) as a timestamp")
      }
    }
  }

  mutating func decode(_ columnType: RFC_4122.UUID.Type) throws(QueryDecodingError) -> RFC_4122.UUID? {
    try decode(String.self).map { string throws(QueryDecodingError) in
      do {
        return try RFC_4122.UUID(string)
      } catch {
        throw .dataCorrupted("\(string) as a UUID")
      }
    }
  }
}

#endif
