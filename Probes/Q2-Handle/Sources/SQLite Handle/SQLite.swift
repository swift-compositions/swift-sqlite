internal import CSQLite
public import ISO_9075_Call_Level_Interface
public import Lent_Interface

public enum SQLite {}

extension SQLite {
    public struct Dialect: ISO.`9075`.Dialect {
        public init() {}
        public func placeholder(_ offset: Int) -> String { "?" }
    }

    /// A decoded row. `ISO_9075.Row` is copyable and escapable today, so it copies the values out of the statement.
    public struct Row: ISO.`9075`.Row {
        public let columns: [String]
        let values: [ISO.`9075`.Value]

        public func value(at index: Int) throws(ISO.`9075`.Error) -> ISO.`9075`.Value {
            guard values.indices.contains(index) else { throw .decoding("no column \(index)") }
            return values[index]
        }
    }

    /// The connection: the one owner of a `sqlite3 *`. Not copyable; closed when it goes.
    @safe
    public struct Connection: ~Copyable {
        private let pointer: OpaquePointer

        /// - Parameter flags: more `SQLITE_OPEN_*` flags, beside read-write and create.
        public init(path: String, flags: Int32 = 0) throws(ISO.`9075`.Error) {
            var opened: OpaquePointer?
            let code = unsafe sqlite3_open_v2(path, &opened, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | flags, nil)
            guard code == SQLITE_OK, let opened = unsafe opened else {
                unsafe sqlite3_close_v2(opened)
                throw .connection("sqlite3_open_v2: \(code)")
            }
            unsafe self.pointer = opened
        }

        deinit {
            unsafe sqlite3_close_v2(pointer)
        }

        /// Lends the connection to `body` as a handle that cannot outlive the call.
        public borrowing func lend<Value, Thrown: Swift.Error>(
            _ body: (borrowing Handle) throws(Thrown) -> Value
        ) throws(Thrown) -> Value {
            try body(handle)
        }

        /// The handle as a property: its lifetime is the borrow of `self`.
        public var handle: Handle {
            @_lifetime(borrow self)
            borrowing get {
                unsafe Handle(pointer: pointer, borrowing: self)
            }
        }
    }

    /// What a body is given: the connection's pointer, for as long as the connection is borrowed and no longer.
    @safe
    public struct Handle: Lent.Connection, ~Copyable, ~Escapable {
        public let dialect = SQLite.Dialect()
        private let pointer: OpaquePointer

        @_lifetime(borrow connection)
        fileprivate init(pointer: OpaquePointer, borrowing connection: borrowing Connection) {
            unsafe self.pointer = pointer
        }
    }
}

extension SQLite.Handle {
    public func execute(_ statement: ISO.`9075`.Rendering) throws(ISO.`9075`.Error) -> Int {
        let prepared = unsafe try prepare(statement)
        defer { unsafe sqlite3_finalize(prepared) }
        while true {
            switch unsafe sqlite3_step(prepared) {
            case SQLITE_ROW: continue
            case SQLITE_DONE: return unsafe Int(sqlite3_changes(pointer))
            default: throw failure(statement.sql)
            }
        }
    }

    public func fetchAll<Value>(
        _ statement: ISO.`9075`.Rendering,
        decode: (SQLite.Row) throws(ISO.`9075`.Error) -> Value
    ) throws(ISO.`9075`.Error) -> [Value] {
        let prepared = unsafe try prepare(statement)
        defer { unsafe sqlite3_finalize(prepared) }
        let count = unsafe sqlite3_column_count(prepared)
        let columns = (0..<count).map { unsafe String(cString: sqlite3_column_name(prepared, $0)) }
        var values: [Value] = []
        while true {
            switch unsafe sqlite3_step(prepared) {
            case SQLITE_ROW:
                let row = SQLite.Row(
                    columns: columns,
                    values: (0..<count).map { column -> ISO.`9075`.Value in
                        switch unsafe sqlite3_column_type(prepared, column) {
                        case SQLITE_INTEGER: .int(unsafe sqlite3_column_int64(prepared, column))
                        case SQLITE_FLOAT: .double(unsafe sqlite3_column_double(prepared, column))
                        case SQLITE_TEXT: .text(unsafe String(cString: sqlite3_column_text(prepared, column)))
                        default: .null
                        }
                    }
                )
                values.append(try decode(row))
            case SQLITE_DONE: return values
            default: throw failure(statement.sql)
            }
        }
    }

    private func prepare(_ statement: ISO.`9075`.Rendering) throws(ISO.`9075`.Error) -> OpaquePointer {
        var prepared: OpaquePointer?
        guard unsafe sqlite3_prepare_v2(pointer, statement.sql, -1, &prepared, nil) == SQLITE_OK,
            let prepared = unsafe prepared
        else { throw failure(statement.sql) }
        for (offset, value) in statement.values.enumerated() {
            let index = Int32(offset + 1)
            let code =
                switch value {
                case .int(let int): unsafe sqlite3_bind_int64(prepared, index, int)
                case .double(let double): unsafe sqlite3_bind_double(prepared, index, double)
                case .text(let text):
                    unsafe sqlite3_bind_text(
                        prepared, index, text, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
                default: unsafe sqlite3_bind_null(prepared, index)
                }
            guard code == SQLITE_OK else {
                unsafe sqlite3_finalize(prepared)
                throw failure(statement.sql)
            }
        }
        return unsafe prepared
    }

    private func failure(_ sql: String) -> ISO.`9075`.Error {
        .execution("\(unsafe String(cString: sqlite3_errmsg(pointer))): \(sql)")
    }
}
