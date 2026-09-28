#if GRDB
    public import Byte
    public import GRDB
    internal import GRDBSQLite
    public import ISO_9075_Call_Level_Interface

    extension SQLite {
        public struct Row: ISO_9075.Row {
            public let columns: [String]
            let values: [ISO_9075.Value]

            public func value(at index: Int) throws(ISO_9075.Error) -> ISO_9075.Value {
                guard values.indices.contains(index) else { throw .decoding("no column \(index)") }
                return values[index]
            }
        }

        public struct Connection: ISO_9075.Connection {
            public let dialect = SQLite()
            let database: GRDB.Database

            public init(_ database: GRDB.Database) {
                self.database = database
            }

            public func execute(_ statement: ISO_9075.Rendering) throws(ISO_9075.Error) -> Int {
                try step(statement) { _ in }
                return Int(unsafe sqlite3_changes(database.sqliteConnection))
            }

            public func fetchAll<Value>(
                _ statement: ISO_9075.Rendering,
                decode: (SQLite.Row) throws(ISO_9075.Error) -> Value
            ) throws(ISO_9075.Error) -> [Value] {
                var values: [Value] = []
                try step(statement) { row throws(ISO_9075.Error) in values.append(try decode(row)) }
                return values
            }

            private func step(
                _ rendering: ISO_9075.Rendering,
                _ body: (SQLite.Row) throws(ISO_9075.Error) -> Void
            ) throws(ISO_9075.Error) {
                let statement: GRDB.Statement
                do {
                    (statement, _) = try database.prepare(rendering, cached: true)
                } catch let error as ISO_9075.Error {
                    throw error
                } catch {
                    throw .execution("\(error)")
                }
                let handle = statement.sqliteStatement
                defer { unsafe sqlite3_reset(handle) }
                let columns = statement.columnNames
                while true {
                    switch unsafe sqlite3_step(handle) {
                    case SQLITE_DONE: return
                    case SQLITE_ROW:
                        try body(SQLite.Row(columns: columns, values: columns.indices.map { unsafe value(handle, Int32($0)) }))
                    case let code:
                        throw .execution("\(String(cString: unsafe sqlite3_errmsg(database.sqliteConnection))) (\(code)) in \(rendering.sql)")
                    }
                }
            }

            private func value(_ handle: SQLiteStatement, _ index: Int32) -> ISO_9075.Value {
                switch unsafe sqlite3_column_type(handle, index) {
                case SQLITE_INTEGER: .int(unsafe sqlite3_column_int64(handle, index))
                case SQLITE_FLOAT: .double(unsafe sqlite3_column_double(handle, index))
                case SQLITE_TEXT:
                    .text(
                        unsafe String(
                            decoding: UnsafeBufferPointer(
                                start: sqlite3_column_text(handle, index),
                                count: Int(sqlite3_column_bytes(handle, index))
                            ),
                            as: UTF8.self
                        )
                    )
                case SQLITE_BLOB:
                    .blob(
                        unsafe UnsafeRawBufferPointer(
                            start: sqlite3_column_blob(handle, index),
                            count: Int(sqlite3_column_bytes(handle, index))
                        )
                        .map(Byte.init)
                    )
                default: .null
                }
            }
        }

        public struct Database<Writer: DatabaseWriter>: ISO_9075.Database {
            public let writer: Writer

            public init(_ writer: Writer) {
                self.writer = writer
            }

            public func read<Value: Sendable>(
                _ body: @Sendable (Connection) throws(ISO_9075.Error) -> Value
            ) async throws(ISO_9075.Error) -> Value {
                try await scope { try await writer.read { database in try body(Connection(database)) } }
            }

            public func write<Value: Sendable>(
                _ body: @Sendable (Connection) throws(ISO_9075.Error) -> Value
            ) async throws(ISO_9075.Error) -> Value {
                try await scope { try await writer.write { database in try body(Connection(database)) } }
            }

            public func withRollback<Value: Sendable>(
                _ body: @Sendable (Connection) throws(ISO_9075.Error) -> Value
            ) async throws(ISO_9075.Error) -> Value {
                try await scope {
                    try await writer.writeWithoutTransaction { database in
                        try database.execute(sql: "BEGIN")
                        defer { try? database.execute(sql: "ROLLBACK") }
                        return try body(Connection(database))
                    }
                }
            }

            private func scope<Value>(_ run: () async throws -> Value) async throws(ISO_9075.Error) -> Value {
                do {
                    return try await run()
                } catch let error as ISO_9075.Error {
                    throw error
                } catch {
                    throw .transaction("\(error)")
                }
            }
        }
    }
#endif
