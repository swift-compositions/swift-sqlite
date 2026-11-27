internal import Byte
internal import GRDBSQLite
internal import ISO_9075_Call_Level_Interface
internal import RFC_4122
internal import SQLite_SQL

extension SQLite.Connection {
    /// The one owner of a `sqlite3 *`, opened with `SQLITE_OPEN_NOMUTEX`: SQLite takes no lock of its own for it, so
    /// at most one thread may be inside it at a time. Its ``SQLite/Connection/Slot`` holds it behind a lock and lends it
    /// only as a ``SQLite/Connection``, which cannot escape. It closes when the slot lets it go.
    ///
    /// Not Sendable, and never shared: the slot's lock is the only way to it.
    @safe
    final class Core {
        let pointer: OpaquePointer

        /// The prepared statements, by their text. A statement in use is not handed out twice.
        private var statements: [String: OpaquePointer]

        /// True while a statement runs that a cancelled task must not interrupt: the end of a transaction.
        private var shielded = false

        init(path: String, flags: Int32) throws(SQLite.Error) {
            var opened: OpaquePointer?
            let code = unsafe sqlite3_open_v2(path, &opened, flags | SQLITE_OPEN_NOMUTEX, nil)
            guard code == SQLITE_OK, let opened = unsafe opened else {
                let error =
                    unsafe opened.map { unsafe SQLite.Error(connection: $0) } ?? SQLite.Error(code: code)
                unsafe sqlite3_close_v2(opened)
                throw SQLite.Error(extendedCode: error.extendedCode, message: error.message.map { "\($0): \(path)" })
            }
            unsafe self.pointer = opened
            unsafe self.statements = [:]
            unsafe sqlite3_extended_result_codes(opened, 1)
            // A quoted name that matches no column is an error, not a string literal.
            unsafe _disableDoubleQuotedStringLiterals(opened)
            // A cancelled task interrupts the statement it runs. The handler runs on the thread that steps the
            // statement, which is the thread of the task that asked for it, so it reads that task's cancellation.
            unsafe sqlite3_progress_handler(
                opened,
                2048,
                { context in
                    guard let context = unsafe context else { return 0 }
                    let core = unsafe Unmanaged<Core>.fromOpaque(context).takeUnretainedValue()
                    return !core.shielded && Task.isCancelled ? 1 : 0
                },
                unsafe Unmanaged.passUnretained(self).toOpaque()
            )
        }

        deinit {
            for statement in unsafe statements.values { unsafe sqlite3_finalize(statement) }
            unsafe sqlite3_progress_handler(pointer, 0, nil, nil)
            unsafe sqlite3_close_v2(pointer)
        }
    }
}

extension SQLite.Connection.Core {
    var isInsideTransaction: Bool { unsafe sqlite3_get_autocommit(pointer) == 0 }

    var changes: Int { Int(unsafe sqlite3_changes(pointer)) }

    /// Runs every statement in `script`, with no bindings and no rows: the statements that open and end transactions
    /// and configure the connection. A cancelled task does not interrupt them.
    func run(script: String) throws(SQLite.Error) {
        shielded = true
        defer { shielded = false }
        guard unsafe sqlite3_exec(pointer, script, nil, nil, nil) == SQLITE_OK else {
            throw unsafe SQLite.Error(connection: pointer, statement: script)
        }
    }

    func busy(timeout: Duration?) {
        guard let timeout else { return }
        let (seconds, attoseconds) = timeout.components
        unsafe sqlite3_busy_timeout(pointer, Int32(clamping: seconds * 1000 + attoseconds / 1_000_000_000_000_000))
    }

    /// Steps `rendering` to its end, giving each row to `body`.
    func step(
        _ rendering: ISO.`9075`.Rendering,
        _ body: (SQLite.Row) throws(ISO.`9075`.Error) -> Void
    ) throws(ISO.`9075`.Error) {
        if Task.isCancelled { throw ISO.`9075`.Error(SQLite.Error.cancelled) }
        let sql = rendering.sql.isEmpty ? "SELECT 1 WHERE 0" : rendering.sql
        let (statement, cached) = unsafe try prepare(sql)
        defer {
            if cached {
                unsafe sqlite3_reset(statement)
                unsafe sqlite3_clear_bindings(statement)
            } else {
                unsafe sqlite3_finalize(statement)
            }
        }
        for (index, value) in zip(Int32(1)..., rendering.values) {
            let code = unsafe try value.bind(to: statement, at: index)
            guard code == SQLITE_OK else { throw unsafe ISO.`9075`.Error(SQLite.Error(connection: pointer, statement: sql)) }
        }
        let count = unsafe sqlite3_column_count(statement)
        var columns: [String]?
        while true {
            switch unsafe sqlite3_step(statement) {
            case SQLITE_ROW:
                let names =
                    columns
                    ?? (0..<count).map { unsafe String(cString: sqlite3_column_name(statement, $0)) }
                columns = names
                try body(
                    SQLite.Row(columns: names, values: (0..<count).map { unsafe Self.value(statement, $0) })
                )
            case SQLITE_DONE:
                return
            default:
                throw unsafe ISO.`9075`.Error(SQLite.Error(connection: pointer, statement: sql))
            }
        }
    }

    /// The statement for `sql`: the one kept for that text, or, while that one is in use by an outer fetch, one of its
    /// own that the caller finalizes. More than one statement in `sql` is refused, as a statement that would be dropped.
    @unsafe
    private func prepare(_ sql: String) throws(ISO.`9075`.Error) -> (statement: OpaquePointer, cached: Bool) {
        if let kept = unsafe statements[sql], unsafe sqlite3_stmt_busy(kept) == 0 {
            return unsafe (kept, true)
        }
        var prepared: OpaquePointer?
        var text = sql
        let (code, rest): (Int32, Bool) = unsafe text.withUTF8 { utf8 in
            unsafe utf8.withMemoryRebound(to: CChar.self) { characters in
                var tail: UnsafePointer<CChar>?
                let code = unsafe sqlite3_prepare_v3(
                    pointer, characters.baseAddress, Int32(characters.count), UInt32(SQLITE_PREPARE_PERSISTENT), &prepared, &tail)
                var rest = false
                if let tail = unsafe tail, let start = unsafe characters.baseAddress {
                    let consumed = unsafe start.distance(to: tail)
                    rest = unsafe characters[consumed...].contains { !Self.isBlank($0) }
                }
                return (code, rest)
            }
        }
        guard code == SQLITE_OK else {
            unsafe sqlite3_finalize(prepared)
            throw unsafe ISO.`9075`.Error(SQLite.Error(connection: pointer, statement: sql))
        }
        guard !rest else {
            unsafe sqlite3_finalize(prepared)
            throw ISO.`9075`.Error(
                SQLite.Error(extendedCode: .misuse, message: "more than one statement in one execution", statement: sql)
            )
        }
        guard let prepared = unsafe prepared else {
            // Only whitespace or a comment: nothing to run.
            return unsafe try prepare("SELECT 1 WHERE 0")
        }
        if unsafe statements[sql] == nil {
            unsafe statements[sql] = prepared
            return unsafe (prepared, true)
        }
        return unsafe (prepared, false)
    }

    private static func isBlank(_ character: CChar) -> Bool {
        character == 0x20 || character == 0x09 || character == 0x0A || character == 0x0D || character == 0x3B
    }

    @unsafe
    private static func value(_ statement: OpaquePointer, _ index: Int32) -> ISO.`9075`.Value {
        switch unsafe sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER: .int(unsafe sqlite3_column_int64(statement, index))
        case SQLITE_FLOAT: .double(unsafe sqlite3_column_double(statement, index))
        case SQLITE_TEXT:
            .text(
                unsafe String(
                    decoding: UnsafeBufferPointer(
                        start: sqlite3_column_text(statement, index),
                        count: Int(sqlite3_column_bytes(statement, index))
                    ),
                    as: UTF8.self
                )
            )
        case SQLITE_BLOB:
            .blob(
                unsafe [Byte](
                    copying: UnsafeRawBufferPointer(
                        start: sqlite3_column_blob(statement, index),
                        count: Int(sqlite3_column_bytes(statement, index))
                    )
                )
            )
        default: .null
        }
    }
}

extension ISO.`9075`.Value {
    /// Binds this value at `index`, and gives SQLite's result code.
    @unsafe
    fileprivate func bind(to statement: OpaquePointer, at index: Int32) throws(ISO.`9075`.Error) -> Int32 {
        switch self {
        case .null: return unsafe sqlite3_bind_null(statement, index)
        case .bool(let bool): return unsafe sqlite3_bind_int64(statement, index, bool ? 1 : 0)
        case .int(let int): return unsafe sqlite3_bind_int64(statement, index, int)
        case .double(let double): return unsafe sqlite3_bind_double(statement, index, double)
        case .text(let text), .decimal(let text): return unsafe text.bind(to: statement, at: index)
        case .timestamp(let instant):
            do throws(ISO.`9075`.Value.Failure) {
                return unsafe try ISO.`9075`.Literal.timestamp(instant).bind(to: statement, at: index)
            } catch {
                throw .binding(error)
            }
        case .uuid(let uuid): return unsafe String(uuid).lowercased().bind(to: statement, at: index)
        case .json(let bytes):
            return unsafe bytes.withUnsafeBytes { unsafe String(decoding: $0, as: UTF8.self) }.bind(to: statement, at: index)
        case .blob(let blob) where blob.isEmpty: return unsafe sqlite3_bind_zeroblob(statement, index, 0)
        case .blob(let blob):
            return blob.withUnsafeBytes {
                unsafe sqlite3_bind_blob(statement, index, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
            }
        case .array: throw .binding(ISO.`9075`.Value.Failure("SQLite has no array values"))
        case .invalid(let failure): throw .binding(failure)
        }
    }
}

extension String {
    @unsafe
    fileprivate func bind(to statement: OpaquePointer, at index: Int32) -> Int32 {
        var text = self
        return text.withUTF8 { utf8 in
            unsafe utf8.withMemoryRebound(to: CChar.self) {
                unsafe sqlite3_bind_text(statement, index, $0.baseAddress, Int32($0.count), SQLITE_TRANSIENT)
            }
        }
    }
}
