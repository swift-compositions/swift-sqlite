#if GRDB
    internal import Byte
    internal import GRDB
    internal import GRDBSQLite
    internal import ISO_9075_Call_Level_Interface

    extension SQLite.Connection {
        /// The rows of one prepared statement, stepped through GRDB as its own cursors are: GRDB then records what the
        /// statement reads, which an observation follows, and tells its transaction observers what it writes.
        final class Cursor {
            var _isDone = false
            let _statement: GRDB.Statement
            let columns: [String]

            init(_ statement: GRDB.Statement) {
                _statement = statement
                columns = statement.columnNames
            }
        }
    }

    extension SQLite.Connection.Cursor: DatabaseCursor {
        typealias Element = SQLite.Row

        func _element(sqliteStatement: SQLiteStatement) -> SQLite.Row {
            SQLite.Row(columns: columns, values: columns.indices.map { unsafe value(sqliteStatement, Int32($0)) })
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
                    unsafe [Byte](
                        copying: UnsafeRawBufferPointer(
                            start: sqlite3_column_blob(handle, index),
                            count: Int(sqlite3_column_bytes(handle, index))
                        )
                    )
                )
            default: .null
            }
        }
    }
#endif
