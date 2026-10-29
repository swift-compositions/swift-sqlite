public import SQLite_SQL
#if GRDB
    package import GRDB
    public import ISO_9075_Call_Level_Interface

    extension SQLite {
        /// A SQLite database: one file, or one in memory, and the connections that read and write it.
        ///
        /// Reads and writes run their closure on a connection of their own, inside a transaction, serialised with every
        /// other write. Each comes synchronous and asynchronous; the asynchronous ones that take a closure throwing
        /// `ISO_9075.Error` are the call-level interface swift-sql's `Migrator` runs on.
        public struct Database: ISO_9075.Database {
            public typealias Connection = SQLite.Connection

            package let writer: any DatabaseWriter

            package init(_ writer: any DatabaseWriter) {
                self.writer = writer
            }

            /// A new, empty database in memory, gone when the last copy of this value is.
            public init(configuration: SQLite.Configuration = SQLite.Configuration()) throws(SQLite.Error) {
                self.init(try executing { try DatabaseQueue(configuration: configuration.driver) })
            }

            /// The database at `path`, created when there is none.
            ///
            /// - Parameters:
            ///   - kind: ``Kind/pool``, the default, reads concurrently with a write in WAL mode; ``Kind/queue`` serialises
            ///     every access on one connection.
            public init(
                path: String,
                kind: Kind = .pool,
                configuration: SQLite.Configuration = SQLite.Configuration()
            ) throws(SQLite.Error) {
                let writer: any DatabaseWriter = try executing {
                    switch kind {
                    case .queue: try DatabaseQueue(path: path, configuration: configuration.driver)
                    case .pool: try DatabasePool(path: path, configuration: configuration.driver)
                    }
                }
                self.init(writer)
            }

            /// How a database file is opened.
            public enum Kind: Sendable {
                /// One connection, every read and write serialised on it.
                case queue
                /// A writer and concurrent readers, in WAL mode.
                case pool
            }

            /// The path of the database file; for a database in memory, `:memory:`.
            public var path: String { writer.path }
        }
    }

    extension SQLite.Database {
        @_disfavoredOverload
        public func read<T>(_ body: (SQLite.Connection) throws -> T) throws -> T {
            try translatingErrors { try writer.read { database in try body(SQLite.Connection(database)) } }
        }

        @_disfavoredOverload
        public func write<T>(_ body: (SQLite.Connection) throws -> T) throws -> T {
            try translatingErrors { try writer.write { database in try body(SQLite.Connection(database)) } }
        }

        /// Runs `body` outside of any transaction: what it executes commits statement by statement, unless it opens a
        /// transaction itself.
        public func writeWithoutTransaction<T>(_ body: (SQLite.Connection) throws -> T) throws -> T {
            try translatingErrors {
                try writer.writeWithoutTransaction { database in try body(SQLite.Connection(database)) }
            }
        }

        @_disfavoredOverload
        public func read<T: Sendable>(_ body: @Sendable (SQLite.Connection) throws -> T) async throws -> T {
            try await translatingErrors { try await writer.read { database in try body(SQLite.Connection(database)) } }
        }

        @_disfavoredOverload
        public func write<T: Sendable>(_ body: @Sendable (SQLite.Connection) throws -> T) async throws -> T {
            try await translatingErrors { try await writer.write { database in try body(SQLite.Connection(database)) } }
        }

        public func writeWithoutTransaction<T: Sendable>(
            _ body: @Sendable (SQLite.Connection) throws -> T
        ) async throws -> T {
            try await translatingErrors {
                try await writer.writeWithoutTransaction { database in try body(SQLite.Connection(database)) }
            }
        }

        /// Copies every page of this database into `destination`, replacing what it held.
        public func backup(to destination: SQLite.Database) throws(SQLite.Error) {
            try executing { try writer.backup(to: destination.writer) }
        }

        /// Closes the database's connections. A read or write after this throws.
        public func close() throws(SQLite.Error) {
            try executing {
                switch writer {
                case let queue as DatabaseQueue: try queue.close()
                case let pool as DatabasePool: try pool.close()
                default: break
                }
            }
        }
    }

    // A closure that throws only ``SQLite/Error`` (or nothing) runs typed: what fails is an ``SQLite/Error``.
    extension SQLite.Database {
        public func read<T>(_ body: (SQLite.Connection) throws(SQLite.Error) -> T) throws(SQLite.Error) -> T {
            try executing { try writer.read { database in try body(SQLite.Connection(database)) } }
        }

        public func write<T>(_ body: (SQLite.Connection) throws(SQLite.Error) -> T) throws(SQLite.Error) -> T {
            try executing { try writer.write { database in try body(SQLite.Connection(database)) } }
        }

        public func read<T: Sendable>(
            _ body: @Sendable (SQLite.Connection) throws(SQLite.Error) -> T
        ) async throws(SQLite.Error) -> T {
            try await executing { try await writer.read { database in try body(SQLite.Connection(database)) } }
        }

        public func write<T: Sendable>(
            _ body: @Sendable (SQLite.Connection) throws(SQLite.Error) -> T
        ) async throws(SQLite.Error) -> T {
            try await executing { try await writer.write { database in try body(SQLite.Connection(database)) } }
        }
    }

    extension SQLite.Database {
        @_disfavoredOverload
        public func read<Value: Sendable>(
            _ body: @Sendable (Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value {
            try await scope { try await writer.read { database in try body(Connection(database)) } }
        }

        @_disfavoredOverload
        public func write<Value: Sendable>(
            _ body: @Sendable (Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value {
            try await scope { try await writer.write { database in try body(Connection(database)) } }
        }

        public func withRollback<Value: Sendable>(
            _ body: @Sendable (Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value {
            try await scope {
                try await writer.writeWithoutTransaction { database in
                    try database.beginTransaction()
                    defer { try? database.rollback() }
                    return try body(Connection(database))
                }
            }
        }

        private func scope<Value>(_ run: () async throws -> Value) async throws(ISO_9075.Error) -> Value {
            do {
                return try await run()
            } catch let error as ISO_9075.Error {
                throw error
            } catch {
                throw .transaction("\(SQLite.Error.translated(error))")
            }
        }
    }
#endif
