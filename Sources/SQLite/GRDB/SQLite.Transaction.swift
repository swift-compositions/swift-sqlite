public import SQLite_SQL
#if GRDB
    extension SQLite {
        /// Statements that change a database together, with the deciding between them: the writing counterpart of a
        /// ``FetchKeyRequest``. A ``SQLite/Database/write(_:)`` runs it with `try transaction.run(connection)`, so what
        /// it reads and writes commits together or not at all.
        public protocol Transaction<Value>: Sendable {
            associatedtype Value

            func run(_ connection: SQLite.Connection) throws -> Value
        }
    }
#endif
