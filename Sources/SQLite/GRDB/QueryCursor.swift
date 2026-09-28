#if GRDB
    public import GRDB
    internal import GRDBSQLite
    public import SQL

    public class QueryCursor<Element>: DatabaseCursor {
        public var _isDone = false
        public let _statement: GRDB.Statement
        @usableFromInline
        var decoder: SQLiteQueryDecoder

        @usableFromInline
        init(db: GRDB.Database, query: ISO_9075.Fragment, cached: Bool) throws {
            (_statement, decoder) = try db.prepare(SQLite().render(query), cached: cached)
        }

        deinit {
            unsafe sqlite3_reset(_statement.sqliteStatement)
            unsafe sqlite3_clear_bindings(_statement.sqliteStatement)
        }

        public func _element(sqliteStatement _: SQLiteStatement) throws -> Element {
            fatalError("Abstract method should be overridden in subclass")
        }

        @usableFromInline
        func decoding<Value>(_ body: (inout SQLiteQueryDecoder) throws(QueryDecodingError) -> Value) throws -> Value {
            do {
                let value = try body(&decoder)
                decoder.next()
                return value
            } catch {
                let index = Int(decoder.currentIndex) - 1
                throw ISO_9075.Error.decoding(
                    "column \(index) (\(_statement.columnNames[index])): \(error) in \(_statement.sql)"
                )
            }
        }
    }

    @usableFromInline
    final class QueryValueCursor<QueryValue: QueryRepresentable>: QueryCursor<QueryValue.QueryOutput> {
        @usableFromInline
        override init(db: GRDB.Database, query: ISO_9075.Fragment, cached: Bool) throws {
            try super.init(db: db, query: query, cached: cached)
        }

        @inlinable
        override func _element(sqliteStatement _: SQLiteStatement) throws -> QueryValue.QueryOutput {
            try decoding { decoder throws(QueryDecodingError) in try QueryValue(decoder: &decoder).queryOutput }
        }
    }

    @usableFromInline
    final class QuerySectionedCursor<
        Element: QueryRepresentable,
        SectionName: QueryRepresentable
    >: QueryCursor<(Element.QueryOutput, SectionName.QueryOutput)> {
        @usableFromInline
        override init(db: GRDB.Database, query: ISO_9075.Fragment, cached: Bool) throws {
            try super.init(db: db, query: query, cached: cached)
        }

        @inlinable
        override func _element(
            sqliteStatement _: SQLiteStatement
        ) throws -> (Element.QueryOutput, SectionName.QueryOutput) {
            try decoding { decoder throws(QueryDecodingError) in
                (try Element(decoder: &decoder).queryOutput, try SectionName(decoder: &decoder).queryOutput)
            }
        }
    }

    @usableFromInline
    final class QueryPackCursor<
        each QueryValue: QueryRepresentable
    >: QueryCursor<(repeat (each QueryValue).QueryOutput)> {
        @usableFromInline
        override init(db: GRDB.Database, query: ISO_9075.Fragment, cached: Bool) throws {
            try super.init(db: db, query: query, cached: cached)
        }

        @inlinable
        override func _element(sqliteStatement _: SQLiteStatement) throws -> (repeat (each QueryValue).QueryOutput) {
            try decoding { decoder throws(QueryDecodingError) in
                try decoder.decodeColumns((repeat each QueryValue).self)
            }
        }
    }

    @usableFromInline
    final class QueryVoidCursor: QueryCursor<Void> {
        @usableFromInline
        override init(db: GRDB.Database, query: ISO_9075.Fragment, cached: Bool) throws {
            try super.init(db: db, query: query, cached: cached)
        }

        @inlinable
        override func _element(sqliteStatement _: SQLiteStatement) throws {
            try decoding { decoder throws(QueryDecodingError) in try decoder.decodeColumns(Void.self) }
        }
    }

    extension GRDB.Database {
        @usableFromInline
        func prepare(
            _ rendering: ISO_9075.Rendering,
            cached: Bool
        ) throws -> (GRDB.Statement, SQLiteQueryDecoder) {
            let sql = rendering.sql.isEmpty ? "SELECT 1 WHERE 0" : rendering.sql
            let statement = cached ? try cachedStatement(sql: sql) : try makeStatement(sql: sql)
            if cached { unsafe sqlite3_reset(statement.sqliteStatement) }
            for (index, value) in zip(Int32(1)..., rendering.values) {
                try value.bind(to: statement.sqliteStatement, at: index)
            }
            return (statement, SQLiteQueryDecoder(statement: statement.sqliteStatement))
        }
    }

    extension ISO_9075.Value {
        func bind(to statement: SQLiteStatement, at index: Int32) throws {
            let result: Int32 =
                switch self {
                case .null: unsafe sqlite3_bind_null(statement, index)
                case .bool(let bool): unsafe sqlite3_bind_int64(statement, index, bool ? 1 : 0)
                case .int(let int): unsafe sqlite3_bind_int64(statement, index, int)
                case .double(let double): unsafe sqlite3_bind_double(statement, index, double)
                case .text(let text), .decimal(let text): text.bind(to: statement, at: index)
                case .timestamp(let instant): try ISO_9075.Literal.timestamp(instant).bind(to: statement, at: index)
                case .uuid(let uuid): String(uuid).lowercased().bind(to: statement, at: index)
                case .json(let bytes): String(decoding: bytes.map(\.underlying), as: UTF8.self).bind(to: statement, at: index)
                case .blob(let blob) where blob.isEmpty: unsafe sqlite3_bind_zeroblob(statement, index, 0)
                case .blob(let blob):
                    unsafe blob.map(\.underlying).withUnsafeBytes {
                        unsafe sqlite3_bind_blob(statement, index, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
                    }
                case .array: throw ISO_9075.Error.binding(ISO_9075.Value.Failure("SQLite has no array values"))
                case .invalid(let failure): throw ISO_9075.Error.binding(failure)
                }
            guard result == SQLITE_OK else { throw DatabaseError(resultCode: ResultCode(rawValue: result)) }
        }
    }

    extension String {
        fileprivate func bind(to statement: SQLiteStatement, at index: Int32) -> Int32 {
            var text = self
            return text.withUTF8 { utf8 in
                unsafe utf8.withMemoryRebound(to: CChar.self) {
                    unsafe sqlite3_bind_text(statement, index, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
                }
            }
        }
    }
#endif
