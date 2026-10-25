#if GRDB
    public import Byte
    public import ISO_9075_Foundation
    public import RFC_4122
    public import SQL
    public import SQLite
    public import Time

    extension SQLite.Row {
        /// Decodes one value of a row, as a typed fetch decodes a column.
        public struct Decoder: QueryDecoder {
            let value: ISO_9075.Value

            public init(value: ISO_9075.Value) {
                self.value = value
            }
        }
    }

    extension SQLite.Row.Decoder {
        private func mismatch(_ expected: String) -> QueryDecodingError {
            .typeMismatch(expected: "\(expected), found \(value)")
        }

        public mutating func decode(_ columnType: [Byte].Type) throws(QueryDecodingError) -> [Byte]? {
            switch value {
            case .null: nil
            case .blob(let bytes), .json(let bytes): bytes
            default: throw mismatch("[Byte]")
            }
        }

        public mutating func decode(_ columnType: Double.Type) throws(QueryDecodingError) -> Double? {
            switch value {
            case .null: nil
            case .double(let number): number
            case .int(let number): Double(number)
            default: throw mismatch("Double")
            }
        }

        public mutating func decode(_ columnType: Int64.Type) throws(QueryDecodingError) -> Int64? {
            switch value {
            case .null: nil
            case .int(let number): number
            case .bool(let flag): flag ? 1 : 0
            default: throw mismatch("Int64")
            }
        }

        public mutating func decode(_ columnType: UInt64.Type) throws(QueryDecodingError) -> UInt64? {
            try decode(Int64.self).map { UInt64(bitPattern: $0) }
        }

        public mutating func decode(_ columnType: String.Type) throws(QueryDecodingError) -> String? {
            switch value {
            case .null: nil
            case .text(let text), .decimal(let text): text
            default: throw mismatch("String")
            }
        }

        public mutating func decode(_ columnType: Bool.Type) throws(QueryDecodingError) -> Bool? {
            switch value {
            case .bool(let flag): flag
            default: try decode(Int64.self).map { $0 != 0 }
            }
        }

        public mutating func decode(_ columnType: Int.Type) throws(QueryDecodingError) -> Int? {
            try decode(Int64.self).map(Int.init)
        }

        public mutating func decode(_ columnType: Time.Instant.Type) throws(QueryDecodingError) -> Time.Instant? {
            switch value {
            case .null: nil
            case .timestamp(let instant): instant
            default: throw mismatch("Time.Instant")
            }
        }

        public mutating func decode(_ columnType: RFC_4122.UUID.Type) throws(QueryDecodingError) -> RFC_4122.UUID? {
            switch value {
            case .null: nil
            case .uuid(let uuid): uuid
            default: throw mismatch("RFC_4122.UUID")
            }
        }

        public mutating func decode<Column: _TableColumnExpression>(
            _ column: Column
        ) throws(QueryDecodingError) -> Column.Value.QueryOutput? {
            try decode(Column.Value.self)
        }
    }
#endif
