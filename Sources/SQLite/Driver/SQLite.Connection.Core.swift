internal import Byte
#if canImport(Darwin)
    internal import Darwin
#elseif canImport(Glibc)
    internal import Glibc
#elseif canImport(Musl)
    internal import Musl
#endif
internal import SQLite_Shims
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
        private var statements: [String: Kept]

        /// A prepared statement that is kept, and what it reads and writes.
        struct Kept {
            let pointer: OpaquePointer
            var footprint: SQLite.Footprint
        }

        /// What SQLite reported since it was last taken: filled while a statement compiles.
        private var pending = SQLite.Footprint()

        /// What the statements of the scope that runs have read and written so far. The slot empties it when a
        /// scope begins. The driver's own statements, such as the ones that begin and end a transaction, are not in it.
        var footprint = SQLite.Footprint()

        /// The lowest SQLite the driver runs on: 3.29.0, the first that can refuse double-quoted string literals.
        static let lowestVersion: Int32 = 3_029_000

        /// True while a statement runs that a cancelled task must not interrupt: the end of a transaction.
        private var shielded = false

        init(path: String, flags: Int32) throws(SQLite.Error) {
            guard sqlite3_libversion_number() >= Self.lowestVersion else {
                throw SQLite.Error(
                    extendedCode: .misuse,
                    message: "the system's SQLite is \(unsafe String(cString: sqlite3_libversion())); the driver needs 3.29.0 or later"
                )
            }
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
            let configured = unsafe sqlite_shims_disable_double_quoted_strings(opened)
            guard configured == SQLITE_OK else {
                unsafe sqlite3_close_v2(opened)
                throw SQLite.Error(code: configured)
            }
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
            // SQLite reports here, while it compiles a statement, each table the statement reads and each it writes.
            unsafe sqlite3_set_authorizer(
                opened,
                { context, action, first, second, _, _ in
                    guard let context = unsafe context else { return SQLITE_OK }
                    let core = unsafe Unmanaged<Core>.fromOpaque(context).takeUnretainedValue()
                    switch action {
                    case SQLITE_READ:
                        if let first = unsafe first { core.pending.reads.tables.insert(unsafe String(cString: first)) }
                    case SQLITE_INSERT, SQLITE_UPDATE, SQLITE_DELETE:
                        if let first = unsafe first { core.pending.writes.tables.insert(unsafe String(cString: first)) }
                    case SQLITE_SELECT, SQLITE_FUNCTION, SQLITE_TRANSACTION, SQLITE_SAVEPOINT, SQLITE_RECURSIVE:
                        break
                    case SQLITE_PRAGMA:
                        // A pragma with a value sets something that no table names.
                        if unsafe second != nil { core.pending.writes.everything = true }
                    default:
                        // The schema, an attached database, an analysis: no table names what a reader then sees.
                        core.pending.writes.everything = true
                    }
                    return SQLITE_OK
                },
                unsafe Unmanaged.passUnretained(self).toOpaque()
            )
        }

        deinit {
            for unsafe statement in unsafe statements.values { unsafe sqlite3_finalize(statement.pointer) }
            unsafe sqlite3_progress_handler(pointer, 0, nil, nil)
            unsafe sqlite3_set_authorizer(pointer, nil, nil)
            unsafe sqlite3_close_v2(pointer)
        }
    }
}

extension SQLite.Connection.Core {
    var isInsideTransaction: Bool { unsafe sqlite3_get_autocommit(pointer) == 0 }

    var changes: Int { Int(unsafe sqlite3_changes(pointer)) }

    /// Runs every statement in `script`, with no bindings and no rows, for the body of a scope. A cancelled task does
    /// not interrupt them. What they read and write is added to ``footprint``.
    func run(script: String) throws(SQLite.Error) {
        shielded = true
        defer {
            shielded = false
            footprint.formUnion(pending)
            pending = SQLite.Footprint()
        }
        guard unsafe sqlite3_exec(pointer, script, nil, nil, nil) == SQLITE_OK else {
            throw unsafe SQLite.Error(connection: pointer, statement: script)
        }
    }

    /// Runs the driver's own `script`: the pragmas that configure the connection. It is compiled each time, because
    /// some pragmas act while they are compiled. It is not part of ``footprint``.
    func control(_ script: String) throws(SQLite.Error) {
        shielded = true
        defer {
            shielded = false
            pending = SQLite.Footprint()
        }
        guard unsafe sqlite3_exec(pointer, script, nil, nil, nil) == SQLITE_OK else {
            throw unsafe SQLite.Error(connection: pointer, statement: script)
        }
    }

    /// Runs the driver's own `statement`, one that begins or ends a transaction or a savepoint, from the kept
    /// statements: it is compiled once. A cancelled task does not interrupt it. It is not part of ``footprint``.
    func transact(_ statement: String) throws(SQLite.Error) {
        shielded = true
        defer {
            shielded = false
            pending = SQLite.Footprint()
        }
        let prepared: (statement: OpaquePointer, cached: Bool, footprint: SQLite.Footprint)
        do throws(ISO.`9075`.Error) {
            prepared = unsafe try prepare(statement)
        } catch {
            throw SQLite.Error(error)
        }
        defer {
            if unsafe prepared.cached {
                unsafe sqlite3_reset(prepared.statement)
            } else {
                unsafe sqlite3_finalize(prepared.statement)
            }
        }
        while true {
            switch unsafe sqlite3_step(prepared.statement) {
            case SQLITE_ROW: continue
            case SQLITE_DONE: return
            default: throw unsafe SQLite.Error(connection: pointer, statement: statement)
            }
        }
    }

    /// Runs `body` and gives what its statements read, apart from the scope around it.
    func measure<Value>(_ body: () -> Value) -> (value: Value, reads: SQLite.Region) {
        let outer = footprint
        footprint = SQLite.Footprint()
        defer { footprint = outer }
        let value = body()
        return (value, footprint.reads)
    }

    func busy(timeout: Duration?) {
        guard let timeout else { return }
        let (seconds, attoseconds) = timeout.components
        unsafe sqlite3_busy_timeout(pointer, Int32(clamping: seconds * 1000 + attoseconds / 1_000_000_000_000_000))
    }

    /// Makes the write-ahead log the same on every platform, on the connection that writes.
    ///
    /// The log and its index are removed when the last connection closes: Apple's SQLite keeps them by default, and
    /// this turns that off. And the log exists before a reader opens: a read-only connection cannot create it, and on
    /// Apple's SQLite it then fails with `SQLITE_CANTOPEN`. A read opens the log, which creates its file. Only if
    /// there is still no file, the user version is written back as it is: one page, and no change to the schema.
    func establishWriteAheadLog(at path: String) throws(SQLite.Error) {
        var persistent: Int32 = 0
        _ = unsafe sqlite3_file_control(pointer, nil, SQLITE_FCNTL_PERSIST_WAL, &persistent)
        try control("SELECT 1 FROM sqlite_master LIMIT 1")
        var status = stat()
        guard unsafe stat(path + "-wal", &status) != 0 else { return }
        let versions: [ISO.`9075`.Value]
        do throws(ISO.`9075`.Error) {
            versions = try SQLite.Connection(self).fetchAll("PRAGMA user_version") { row throws(ISO.`9075`.Error) in
                try row.value(at: 0)
            }
        } catch {
            throw SQLite.Error(error)
        }
        guard case .int(let version)? = versions.first else { return }
        try control("PRAGMA user_version = \(version)")
    }

    /// Steps `rendering` to its end, giving each row to `body`.
    func step(
        _ rendering: ISO.`9075`.Rendering,
        _ body: (SQLite.Row) throws(ISO.`9075`.Error) -> Void
    ) throws(ISO.`9075`.Error) {
        if Task.isCancelled { throw ISO.`9075`.Error(SQLite.Error.cancelled) }
        let sql = rendering.sql.isEmpty ? "SELECT 1 WHERE 0" : rendering.sql
        let (statement, cached, compiled) = unsafe try prepare(sql)
        footprint.formUnion(compiled)
        defer {
            // What SQLite compiled while the statement ran: a virtual table's own statements, or the statement again
            // after a change of the schema.
            if !pending.isEmpty {
                footprint.formUnion(pending)
                if cached { unsafe statements[sql]?.footprint.formUnion(pending) }
                pending = SQLite.Footprint()
            }
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
    private func prepare(
        _ sql: String
    ) throws(ISO.`9075`.Error) -> (statement: OpaquePointer, cached: Bool, footprint: SQLite.Footprint) {
        if let kept = unsafe statements[sql], unsafe sqlite3_stmt_busy(kept.pointer) == 0 {
            return unsafe (kept.pointer, true, kept.footprint)
        }
        pending = SQLite.Footprint()
        defer { pending = SQLite.Footprint() }
        var prepared: OpaquePointer?
        var text = sql
        let (code, rest): (Int32, Bool) = text.withUTF8 { utf8 in
            unsafe utf8.withMemoryRebound(to: CChar.self) { characters in
                var tail: UnsafePointer<CChar>?
                let code = unsafe sqlite3_prepare_v3(
                    pointer, characters.baseAddress, Int32(characters.count), UInt32(SQLITE_PREPARE_PERSISTENT), &prepared, &tail)
                var rest = false
                if let tail = unsafe tail, let start = characters.baseAddress {
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
            unsafe statements[sql] = Kept(pointer: prepared, footprint: pending)
            return unsafe (prepared, true, pending)
        }
        return unsafe (prepared, false, pending)
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
