public import SQLite_SQL
#if GRDB
    #if canImport(Darwin)
        import Darwin
    #elseif canImport(Glibc)
        import Glibc
    #elseif canImport(Musl)
        import Musl
    #endif
    package import GRDB
    public import ISO_9075_Call_Level_Interface
    public import Path

    extension SQLite {
        /// A SQLite database: one file, or one in memory, and the connections that read and write it.
        ///
        /// Reads and writes run their closure on a connection of their own, inside a transaction, serialised with every
        /// other write. Each comes synchronous and asynchronous; the asynchronous ones that take a closure throwing
        /// `ISO_9075.Error` are the call-level interface swift-sql's `Migrator` runs on.
        public struct Database: ISO_9075.Database {
            public typealias Connection = SQLite.Connection

            package let writer: any DatabaseWriter

            /// Holds the `-shm` file of a read-only database that had none. Declared after `writer` so that it closes
            /// last: only a connection that can write removes the `-shm` and `-wal` files when it closes.
            private let holder: DatabaseQueue?

            package init(_ writer: any DatabaseWriter, holder: DatabaseQueue? = nil) {
                self.writer = writer
                self.holder = holder
            }

            /// A new, empty database in memory, gone when the last copy of this value is.
            public init(configuration: SQLite.Configuration = SQLite.Configuration()) throws(SQLite.Error) {
                self.init(try executing { try DatabaseQueue(configuration: configuration.driver) })
            }

            /// The database at `path`, created when there is none. A read-only database is never created: with none
            /// at `path` this throws ``SQLite/Error/Code/cannotOpen``. One with no `-shm` file beside it, such as a
            /// copied or restored one, gets that file for as long as the database stays open, which takes write access
            /// to its folder.
            ///
            /// - Parameters:
            ///   - kind: ``Kind/pool``, the default, reads concurrently with a write in WAL mode; ``Kind/queue`` serialises
            ///     every access on one connection.
            public init(
                path: Path::Path,
                kind: Kind = .pool,
                configuration: SQLite.Configuration = SQLite.Configuration()
            ) throws(SQLite.Error) {
                let path = path.string
                var holder: DatabaseQueue?
                if configuration.readonly {
                    guard unsafe access(path, F_OK) == 0 else {
                        throw SQLite.Error(extendedCode: .cannotOpen, message: "no database at \(path)")
                    }
                    if unsafe access(path + "-shm", F_OK) != 0 {
                        holder = try executing { try DatabaseQueue(path: path, configuration: configuration.holder) }
                    }
                }
                let writer: any DatabaseWriter = try executing {
                    switch kind {
                    case .queue: try DatabaseQueue(path: path, configuration: configuration.driver)
                    case .pool: try DatabasePool(path: path, configuration: configuration.driver)
                    }
                }
                self.init(writer, holder: holder)
            }

            /// How a database file is opened.
            public enum Kind: Sendable {
                /// One connection, every read and write serialised on it.
                case queue
                /// A writer and concurrent readers, in WAL mode.
                case pool
            }

            /// The path of the database file; for a database in memory, `:memory:`.
            // swift-linter:disable:next raw concept
            // REASON: GRDB's report of the database location: a file path, or :memory: or an empty text for a database with no file, which File.Path does not describe and refuses when empty.
            public var path: String { writer.path }
        }
    }

    extension SQLite.Database {
        @_disfavoredOverload
        public func read<T>(_ body: (SQLite.Connection) throws -> T) throws -> T {
            try translatingErrors {
                try requireOpen()
                return try writer.read { database in try body(SQLite.Connection(database)) }
            }
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
            try await translatingErrors {
                try await requireOpen()
                return try await writer.read { database in try body(SQLite.Connection(database)) }
            }
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
                try holder?.close()
            }
        }
    }

    extension SQLite.Database {
        /// Throws ``SQLite/Error/Code/misuse`` when a queue is closed. A queue's read starts with
        /// `sqlite3_get_autocommit`, which on a SQLite built without API armor, as Linux's is, dereferences a closed
        /// connection. So a read asks first. A pool's read and every write throw by themselves.
        private func requireOpen() throws(SQLite.Error) {
            guard let queue = writer as? DatabaseQueue else { return }
            if queue.inDatabase({ unsafe $0.sqliteConnection == nil }) {
                throw SQLite.Error(extendedCode: .misuse, message: "Connection is closed")
            }
        }

        /// Throws ``SQLite/Error/Code/misuse`` when a queue is closed, without blocking the caller's thread.
        private func requireOpen() async throws(SQLite.Error) {
            guard let queue = writer as? DatabaseQueue else { return }
            let closed = try await executing {
                try await queue.writeWithoutTransaction { unsafe $0.sqliteConnection == nil }
            }
            if closed {
                throw SQLite.Error(extendedCode: .misuse, message: "Connection is closed")
            }
        }
    }

    extension SQLite.Database {
        public func read<T>(_ body: (SQLite.Connection) throws(SQLite.Error) -> T) throws(SQLite.Error) -> T {
            try executing {
                try requireOpen()
                return try writer.read { database in try body(SQLite.Connection(database)) }
            }
        }

        public func write<T>(_ body: (SQLite.Connection) throws(SQLite.Error) -> T) throws(SQLite.Error) -> T {
            try executing { try writer.write { database in try body(SQLite.Connection(database)) } }
        }

        public func read<T: Sendable>(
            _ body: @Sendable (SQLite.Connection) throws(SQLite.Error) -> T
        ) async throws(SQLite.Error) -> T {
            try await executing {
                try await requireOpen()
                return try await writer.read { database in try body(SQLite.Connection(database)) }
            }
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
            try await scope {
                try await requireOpen()
                return try await writer.read { database in try body(Connection(database)) }
            }
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
