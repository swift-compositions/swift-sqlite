public import ISO_9075_Call_Level_Interface
public import SQLite_SQL

extension SQLite {
    /// How a ``SQLite/Database`` opens its connections.
    public struct Configuration: Sendable {
        /// Opens every connection read-only: a write throws a diagnostic with code ``SQLite/Error/Code/readonly``.
        public var readonly = false

        /// Enforces foreign keys on every connection (`PRAGMA foreign_keys = ON`). On by default.
        public var foreignKeysEnabled = true

        /// How long a connection waits on a database another connection has locked before it throws
        /// ``SQLite/Error/Code/busy``. `nil`, the default, throws at once.
        public var busyTimeout: Duration?

        /// The most connections a database with a file reads with at once, each on a thread of its own. Five by
        /// default. They open as reads need them.
        public var maximumReaderCount = 5

        var preparations: [@Sendable (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Void] = []

        public init() {}

        /// Runs `body` on each connection as it opens, before any other statement: to add functions and collations
        /// or attach databases.
        public mutating func prepareDatabase(
            _ body: @escaping @Sendable (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Void
        ) {
            preparations.append(body)
        }
    }
}
