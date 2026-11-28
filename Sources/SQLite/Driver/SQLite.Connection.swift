public import ISO_9075_Call_Level_Interface
public import SQL
public import SQLite_SQL

extension SQLite {
    /// One open connection, lent to the body of a ``SQLite/Database`` read or write for as long as the body runs: what
    /// every typed statement executes against.
    ///
    /// A connection is neither copyable nor escapable. A body cannot return it, store it, or capture it in a task or
    /// an escaping closure, so no statement runs on it after its scope is over or from a second thread.
    public struct Connection: ISO.`9075`.Connection, ~Copyable, ~Escapable {
        let core: Core

        @_lifetime(borrow core)
        init(_ core: borrowing Core) {
            self.core = copy core
        }

        public var dialect: SQLite { SQLite() }

        public func execute(_ statement: ISO.`9075`.Rendering) throws(ISO.`9075`.Error) -> Int {
            try core.step(statement) { _ in }
            return core.changes
        }

        public func fetchAll<Value>(
            _ statement: ISO.`9075`.Rendering,
            decode: (SQLite.Connection.Row) throws(ISO.`9075`.Error) -> Value
        ) throws(ISO.`9075`.Error) -> [Value] {
            var values: [Value] = []
            try core.step(statement) { row throws(ISO.`9075`.Error) in values.append(try decode(row)) }
            return values
        }
    }
}

@available(*, unavailable)
extension SQLite.Connection: Sendable {}

extension SQLite.Connection {
    /// Whether a transaction is open on this connection.
    public var isInsideTransaction: Bool { core.isInsideTransaction }

    /// Runs `body` inside a savepoint: what it changes is kept when it returns ``Completion/commit``, and undone when
    /// it returns ``Completion/rollback`` or throws.
    public func savepoint<Thrown: Swift.Error>(
        _ body: () throws(Thrown) -> Completion
    ) throws(ISO.`9075`.Failure<Thrown>) {
        try scope(
            begin: "SAVEPOINT sqlite_scope",
            commit: "RELEASE SAVEPOINT sqlite_scope",
            rollback: "ROLLBACK TRANSACTION TO SAVEPOINT sqlite_scope; RELEASE SAVEPOINT sqlite_scope",
            body
        )
    }

    /// Runs `body` inside a transaction, which must not already be open: what it changes is committed when it
    /// returns ``Completion/commit``, and rolled back when it returns ``Completion/rollback`` or throws. For a
    /// ``SQLite/Database/writeWithoutTransaction(_:)`` that turns foreign keys off around its transaction.
    public func transaction<Thrown: Swift.Error>(
        _ body: () throws(Thrown) -> Completion
    ) throws(ISO.`9075`.Failure<Thrown>) {
        try scope(begin: "BEGIN IMMEDIATE TRANSACTION", commit: "COMMIT TRANSACTION", rollback: "ROLLBACK TRANSACTION", body)
    }

    /// How a savepoint or transaction ends.
    public enum Completion: Sendable {
        case commit
        case rollback
    }

    private func scope<Thrown: Swift.Error>(
        begin: String,
        commit: String,
        rollback: String,
        _ body: () throws(Thrown) -> Completion
    ) throws(ISO.`9075`.Failure<Thrown>) {
        do throws(SQLite.Error) {
            try core.control(begin)
        } catch {
            throw .database(ISO.`9075`.Error(error))
        }
        let completion: Completion
        do throws(Thrown) {
            completion = try body()
        } catch {
            if core.isInsideTransaction { try? core.control(rollback) }
            throw .body(error)
        }
        do throws(SQLite.Error) {
            switch completion {
            case .commit: try core.control(commit)
            case .rollback: try core.control(rollback)
            }
        } catch {
            if core.isInsideTransaction { try? core.control(rollback) }
            throw .database(ISO.`9075`.Error(error))
        }
    }
}

extension SQLite.Connection {
    /// Runs every statement in `script`, in order, with no bindings and no rows: a schema, or a pragma. A statement
    /// with values to bind or rows to read goes through `execute` or the `fetch` family.
    public func execute(script: String) throws(ISO.`9075`.Error) {
        do throws(SQLite.Error) {
            try core.run(script: script)
        } catch {
            throw ISO.`9075`.Error(error)
        }
    }
}

extension SQLite.Row {
    /// Every row `statement` returns, kept: each column by name, whatever its type, for a reader that compares whole
    /// rows.
    public static func fetchAll(
        _ connection: borrowing SQLite.Connection,
        _ statement: some SQL::Statement
    ) throws(ISO.`9075`.Error) -> [SQLite.Row] {
        try connection.fetchAll(statement.query) { row in SQLite.Row(row) }
    }
}
