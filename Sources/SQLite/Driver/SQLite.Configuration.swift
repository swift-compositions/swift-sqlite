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

        /// When the write-ahead log of a database with a file is copied back into the file. `nil`, the default,
        /// leaves it as the system's SQLite has it: on Apple platforms, by the write that brings the log to 1,000
        /// pages. A database in memory and a read-only one have no log to copy. A `PRAGMA wal_autocheckpoint` in
        /// ``prepareDatabase(_:)`` replaces it.
        public var checkpoint: Checkpoint?

        /// The most bytes of the database file that each connection reads through a memory mapping in place of
        /// a copy. `nil`, the default, leaves it as the system's SQLite has it: on Apple platforms, none. The
        /// system's SQLite has a limit of its own (on Apple platforms 1 GB) and maps no more than that. An I/O
        /// error on a mapped file cannot be caught: it ends the process.
        public var memoryMappedByteCount: Int?

        /// How much of the database each connection keeps in memory. `nil`, the default, leaves it as the
        /// system's SQLite has it. Every connection has a cache of its own: the writer, each reader, and the
        /// one of the synchronous read.
        public var cache: Cache?

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
