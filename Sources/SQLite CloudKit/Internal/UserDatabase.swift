#if CloudKit
    #if canImport(CloudKit)
        package import ISO_9075_Call_Level_Interface
        package import SQLite

        /// The database a sync engine synchronizes. A write through it is the engine's own: the triggers that queue
        /// changes for CloudKit see ``_isSynchronizingChanges`` and stay quiet.
        package struct UserDatabase: Sendable {
            package let database: SQLite.Database

            package init(database: SQLite.Database) {
                self.database = database
            }

            /// The same database, as the Institute's ``SQLite/Database``.
            package var sqliteDatabase: SQLite.Database { database }

            var path: String {
                database.path == ":memory:" ? "" : database.path
            }

            /// What the body throws comes out as it was thrown, and a failing statement as `ISO.9075.Error`.
            package func write<T: Sendable>(
                _ updates: @Sendable (borrowing SQLite.Connection) throws -> T
            ) async throws -> T {
                // The task-local value is set around the write: the body runs in this task, on the writer.
                try await $_isSynchronizingChanges.withValue(true) {
                    try await database.write { (connection: borrowing SQLite.Connection) throws -> T in
                        try updates(connection)
                    }
                }
            }

            /// A write outside of any transaction, for what a transaction refuses: attaching a database.
            package func writeWithoutTransaction<T: Sendable>(
                _ updates: @Sendable (borrowing SQLite.Connection) throws -> T
            ) async throws -> T {
                try await $_isSynchronizingChanges.withValue(true) {
                    try await database.writeWithoutTransaction {
                        (connection: borrowing SQLite.Connection) throws -> T in
                        try updates(connection)
                    }
                }
            }

            package func read<T: Sendable>(
                _ updates: @Sendable (borrowing SQLite.Connection) throws -> T
            ) async throws -> T {
                try await database.read { (connection: borrowing SQLite.Connection) throws -> T in
                    try updates(connection)
                }
            }

            /// A read on the caller's thread, for code with no asynchronous context.
            @_disfavoredOverload
            package func read<T: Sendable>(
                _ updates: @Sendable (borrowing SQLite.Connection) throws -> T
            ) throws -> T {
                try database.read { (connection: borrowing SQLite.Connection) throws -> T in
                    try updates(connection)
                }
            }
        }
    #endif

#endif
