public import SQLite_SQL
#if GRDB
    package import GRDB
    internal import GRDBSQLite
    public import ISO_9075_Call_Level_Interface
    public import SQL

    extension SQLite {
        public struct Row: ISO_9075.Row {
            public let columns: [String]
            let values: [ISO_9075.Value]

            public func value(at index: Int) throws(ISO_9075.Error) -> ISO_9075.Value {
                guard values.indices.contains(index) else { throw .decoding("no column \(index)") }
                return values[index]
            }
        }

        /// One open connection, for the duration of a ``SQLite/Database`` read or write: what its closure is given, and
        /// what every typed statement executes against.
        ///
        /// A connection is valid only inside the closure it was given to; it must not escape it.
        public struct Connection: ISO_9075.Connection {
            public let dialect = SQLite()
            package let database: GRDB.Database

            package init(_ database: GRDB.Database) {
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
                    throw .execution("\(SQLite.Error.translated(error))")
                }
                defer { unsafe sqlite3_reset(statement.sqliteStatement) }
                let rows = Cursor(statement)
                do {
                    while let row = try rows.next() { try body(row) }
                } catch let error as ISO_9075.Error {
                    throw error
                } catch {
                    throw .execution("\(SQLite.Error.translated(error))")
                }
            }
        }
    }

    extension SQLite.Connection {
        /// Whether a transaction is open on this connection.
        public var isInsideTransaction: Bool { database.isInsideTransaction }

        /// Runs `body` inside a savepoint: what it changes is kept when it returns ``Completion/commit``, and undone when
        /// it returns ``Completion/rollback`` or throws.
        public func savepoint(_ body: () throws -> Completion) throws {
            try translatingErrors {
                try database.inSavepoint {
                    switch try body() {
                    case .commit: .commit
                    case .rollback: .rollback
                    }
                }
            }
        }

        /// Runs `body` inside a transaction, which must not already be open: what it changes is committed when it
        /// returns ``Completion/commit``, and rolled back when it returns ``Completion/rollback`` or throws. For a
        /// ``SQLite/Database/writeWithoutTransaction(_:)`` that turns foreign keys off around its transaction.
        public func transaction(_ body: () throws -> Completion) throws {
            try translatingErrors {
                try database.inTransaction {
                    switch try body() {
                    case .commit: .commit
                    case .rollback: .rollback
                    }
                }
            }
        }

        /// How a savepoint or transaction ends.
        public enum Completion: Sendable {
            case commit
            case rollback
        }
    }

    extension SQLite.Row {
        /// Every row `statement` returns, each column by name, whatever its type: for a reader that compares whole rows.
        public static func fetchAll(_ connection: SQLite.Connection, _ statement: some SQL::Statement) throws(ISO_9075.Error) -> [SQLite.Row] {
            try connection.fetchAll(connection.dialect.render(statement.query)) { $0 }
        }
    }

    extension SQLite.Connection: CustomStringConvertible {
        /// The connection's name, distinct for every open connection of a database: a key for what a caller keeps per
        /// connection.
        public var description: String { database.description }
    }

    extension SQLite.Connection {
        /// What an observation's read depends on, besides the rows it read.
        public enum Region: Sendable {
            /// Every table: a read that answered from what it kept instead of reading still changes with any write.
            case all
        }

        /// Makes the observation this connection reads for depend on `region`.
        public func track(_ region: Region) throws {
            try translatingErrors {
                switch region {
                case .all: try database.registerAccess(to: .fullDatabase)
                }
            }
        }
    }
#endif
