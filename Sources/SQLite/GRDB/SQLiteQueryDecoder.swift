#if GRDB
    public import Byte
    internal import GRDBSQLite
    internal import ISO_9075_Foundation
    public import RFC_4122
    public import SQL
    public import Time

    struct SQLiteQueryDecoder: QueryDecoder {
        let statement: OpaquePointer
        var currentIndex: Int32 = 0

        init(statement: OpaquePointer) {
            self.statement = statement
        }

        mutating func next() {
            currentIndex = 0
        }

        private mutating func column<Value>(
            expecting storage: Int32,
            as _: Value.Type,
            _ read: (OpaquePointer, Int32) throws(QueryDecodingError) -> Value
        ) throws(QueryDecodingError) -> Value? {
            defer { currentIndex += 1 }
            switch unsafe sqlite3_column_type(statement, currentIndex) {
            case SQLITE_NULL: return nil
            case storage: return try read(statement, currentIndex)
            case let found: throw .typeMismatch(expected: "\(Value.self), found \(storageClassName(found))")
            }
        }

        private static func text(_ statement: OpaquePointer, _ index: Int32) -> String {
            unsafe String(
                decoding: UnsafeBufferPointer(
                    start: sqlite3_column_text(statement, index),
                    count: Int(sqlite3_column_bytes(statement, index))
                ),
                as: UTF8.self
            )
        }

        mutating func decode(_ columnType: [Byte].Type) throws(QueryDecodingError) -> [Byte]? {
            try column(expecting: SQLITE_BLOB, as: [Byte].self) { statement, index in
                unsafe UnsafeRawBufferPointer(
                    start: sqlite3_column_blob(statement, index),
                    count: Int(sqlite3_column_bytes(statement, index))
                )
                .map(Byte.init(bitPattern:))
            }
        }

        mutating func decode(_ columnType: Bool.Type) throws(QueryDecodingError) -> Bool? {
            try decode(Int64.self).map { $0 != 0 }
        }

        mutating func decode(_ columnType: Double.Type) throws(QueryDecodingError) -> Double? {
            switch unsafe sqlite3_column_type(statement, currentIndex) {
            case SQLITE_INTEGER: try decode(Int64.self).map(Double.init)
            default: try column(expecting: SQLITE_FLOAT, as: Double.self) { unsafe sqlite3_column_double($0, $1) }
            }
        }

        mutating func decode(_ columnType: Int.Type) throws(QueryDecodingError) -> Int? {
            try decode(Int64.self).map(Int.init)
        }

        mutating func decode(_ columnType: Int64.Type) throws(QueryDecodingError) -> Int64? {
            try column(expecting: SQLITE_INTEGER, as: Int64.self) { unsafe sqlite3_column_int64($0, $1) }
        }

        mutating func decode(_ columnType: String.Type) throws(QueryDecodingError) -> String? {
            try column(expecting: SQLITE_TEXT, as: String.self) { Self.text($0, $1) }
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
