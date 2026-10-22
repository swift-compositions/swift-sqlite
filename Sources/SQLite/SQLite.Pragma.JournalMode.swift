public import SQL

extension SQLite.Pragma {
    /// A database's rollback-journal or write-ahead-log mode.
    public enum JournalMode: String, QueryBindable, Sendable {
        /// Deletes the rollback journal at the conclusion of each transaction.
        case delete = "delete"

        /// Truncates the rollback journal to zero bytes at the conclusion of each transaction.
        case truncate = "truncate"

        /// Leaves the rollback journal in place and invalidates its header after each transaction.
        case persist = "persist"

        /// Stores the rollback journal in volatile memory.
        case memory = "memory"

        /// Uses a write-ahead log.
        case wal = "wal"

        /// Disables the rollback journal.
        case off = "off"
    }
}

extension SQLite.Pragma.JournalMode {
    /// A statement that reads the current journal mode of the main database.
    public static var get: some Statement<Self> {
        SQLQueryExpression("PRAGMA journal_mode")
    }

    /// Returns a statement that requests a journal mode and returns the mode SQLite actually selected.
    ///
    /// SQLite may retain the current mode when the requested transition is unavailable.
    public static func set(_ mode: Self) -> some Statement<Self> {
        SQLQueryExpression("PRAGMA journal_mode = \(raw: mode.rawValue)")
    }
}
