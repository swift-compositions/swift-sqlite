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
                    do throws(ISO.`9075`.Failure<any Swift.Error>) {
                        return try await database.write { (connection: borrowing SQLite.Connection) throws -> T in
                            try updates(connection)
                        }
                    } catch {
                        throw error.unwrapped
                    }
                }
            }

            /// A write outside of any transaction, for what a transaction refuses: attaching a database.
            package func writeWithoutTransaction<T: Sendable>(
                _ updates: @Sendable (borrowing SQLite.Connection) throws -> T
            ) async throws -> T {
                try await $_isSynchronizingChanges.withValue(true) {
                    do throws(ISO.`9075`.Failure<any Swift.Error>) {
                        return try await database.writeWithoutTransaction {
                            (connection: borrowing SQLite.Connection) throws -> T in
                            try updates(connection)
                        }
                    } catch {
                        throw error.unwrapped
                    }
                }
            }

            package func read<T: Sendable>(
                _ updates: @Sendable (borrowing SQLite.Connection) throws -> T
            ) async throws -> T {
                do throws(ISO.`9075`.Failure<any Swift.Error>) {
                    return try await database.read { (connection: borrowing SQLite.Connection) throws -> T in
                        try updates(connection)
                    }
                } catch {
                    throw error.unwrapped
                }
            }

            /// A read on the caller's thread, for code with no asynchronous context.
            @_disfavoredOverload
            package func read<T: Sendable>(
                _ updates: @Sendable (borrowing SQLite.Connection) throws -> T
            ) throws -> T {
                do throws(ISO.`9075`.Failure<any Swift.Error>) {
                    return try database.read { (connection: borrowing SQLite.Connection) throws -> T in
                        try updates(connection)
                    }
                } catch {
                    throw error.unwrapped
                }
            }
        }

        extension ISO.`9075`.Failure where Thrown == any Swift.Error {
            /// The error itself: the database's, or the one the body threw. A body that ran a transaction of its own
            /// throws that transaction's failure, which is unwrapped in turn.
            package var unwrapped: any Swift.Error {
                switch self {
                case .database(let error): error
                case .body(let error): (error as? Self)?.unwrapped ?? error
                }
            }
        }
    #endif

#endif
