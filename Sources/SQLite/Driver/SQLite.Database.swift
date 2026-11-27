internal import GRDBSQLite
public import ISO_9075_Call_Level_Interface
public import Path
public import SQLite_SQL

extension SQLite {
    /// A SQLite database: one file, or one in memory, and the connections that read and write it.
    ///
    /// A database with a file is in WAL mode. Its writes run one at a time on the writer, an actor on a thread of its
    /// own, each in a transaction. Its reads run on reader actors, each on a thread of its own, and do not wait for a
    /// write. A database in memory has one connection, the writer's, and its reads take their turn on it.
    ///
    /// A body is lent the connection: it cannot keep it. A body is `sending` and so is its result, so neither has to be
    /// Sendable; a body returns values it made, not ones it captured.
    public struct Database: ISO.`9075`.Database, Sendable {
        public typealias Connection = SQLite.Connection

        let writer: SQLite.Worker

        /// The reader actors of a database with a file; `nil` for a database in memory.
        let readers: SQLite.Readers?

        /// The connection a synchronous read runs on, on the caller's thread: one of its own for a database with a
        /// file, the writer's for a database in memory.
        let direct: SQLite.Connection.Slot

        /// Holds the `-shm` file of a read-only database that had none: only a connection that can write creates it.
        let holder: SQLite.Connection.Slot?

        /// The path of the database file; for a database in memory, `:memory:`.
        // swift-linter:disable:next raw concept
        // REASON: SQLite's name of the database location: a file path, or :memory: for a database with no file, which File.Path does not describe.
        public let path: String

        /// A new, empty database in memory, gone when the last copy of this value is.
        public init(configuration: SQLite.Configuration = SQLite.Configuration()) throws(SQLite.Error) {
            let slot = try SQLite.Connection.Slot(
                path: ":memory:",
                flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
                configuration: configuration,
                journal: .asFound
            )
            self.writer = SQLite.Worker(slot: slot)
            self.readers = nil
            self.direct = slot
            self.holder = nil
            self.path = ":memory:"
        }

        /// The database at `path`, created when there is none, in WAL mode. A read-only database is never created:
        /// with none at `path` this throws ``SQLite/Error/Code/cannotOpen``. One with no `-shm` file beside it, such
        /// as a copied or restored one, gets that file for as long as the database stays open, which takes write
        /// access to its folder.
        public init(
            path: Path::Path,
            configuration: SQLite.Configuration = SQLite.Configuration()
        ) throws(SQLite.Error) {
            let path = path.string
            var holder: SQLite.Connection.Slot?
            if configuration.readonly {
                // Fails with `cannotOpen` when there is no database: a read-only open never creates one.
                _ = try SQLite.Readers.slot(path: path, configuration: SQLite.Configuration())
                var holding = SQLite.Configuration()
                holding.busyTimeout = configuration.busyTimeout
                holder = try? SQLite.Connection.Slot(
                    path: path, flags: SQLITE_OPEN_READWRITE, configuration: holding, journal: .asFound)
                try? holder?.run(.read) { (connection: borrowing SQLite.Connection) throws(ISO.`9075`.Error) in
                    _ = try connection.fetchAll("SELECT 1 FROM sqlite_master LIMIT 1") { _ in () }
                }
            }
            let writer = try SQLite.Connection.Slot(
                path: path,
                flags: configuration.readonly ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE,
                configuration: configuration,
                journal: configuration.readonly ? .asFound : .writeAheadLog
            )
            self.writer = SQLite.Worker(slot: writer)
            self.readers = SQLite.Readers(path: path, configuration: configuration)
            self.direct = try SQLite.Readers.slot(path: path, configuration: configuration)
            self.holder = holder
            self.path = path
        }
    }
}

// MARK: - The call-level interface

extension SQLite.Database {
    @_disfavoredOverload
    public nonisolated(nonsending) func read<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        guard let readers else { return try await writer.run(.guardedRead, body) }
        let lease: SQLite.Readers.Lease
        do throws(SQLite.Error) {
            lease = try readers.lease()
        } catch {
            throw .database(ISO.`9075`.Error(error))
        }
        defer { readers.release(lease) }
        return try await lease.worker.run(.read, body)
    }

    @_disfavoredOverload
    public nonisolated(nonsending) func write<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await writer.run(.write, body)
    }

    @_disfavoredOverload
    public nonisolated(nonsending) func withRollback<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await writer.run(.rollback, body)
    }
}

// MARK: - Beyond the interface

extension SQLite.Database {
    /// Runs `body` on the writer outside of any transaction: what it executes commits statement by statement, unless
    /// it opens a transaction itself with ``SQLite/Connection/transaction(_:)``.
    @_disfavoredOverload
    public nonisolated(nonsending) func writeWithoutTransaction<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await writer.run(.bare, body)
    }

    public nonisolated(nonsending) func writeWithoutTransaction<Value>(
        _ body: sending (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> sending Value
    ) async throws(ISO.`9075`.Error) -> sending Value {
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            return try await writer.run(.bare, body)
        } catch {
            throw error.error
        }
    }

    /// Reads on the caller's thread, for code with no asynchronous context. The read waits behind a lock for the
    /// connection it runs on: for another synchronous read, and on a database in memory for a write too. Its body is
    /// `sending`, as an asynchronous read's is.
    ///
    /// Do not call it from the body of a read or write of the same database in memory: it would wait for itself.
    @_disfavoredOverload
    public func read<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try direct.run(readers == nil ? .guardedRead : .read, body)
    }

    public func read<Value>(
        _ body: sending (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> sending Value
    ) throws(ISO.`9075`.Error) -> sending Value {
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            return try direct.run(readers == nil ? .guardedRead : .read, body)
        } catch {
            throw error.error
        }
    }

    /// Copies every page of this database into `destination`, replacing what it held. Runs on `destination`'s writer.
    public nonisolated(nonsending) func backup(to destination: SQLite.Database) async throws(SQLite.Error) {
        try await destination.writer.restore(from: direct)
    }

    /// Closes the database's connections, after the reads and writes that are running. A read or write after this
    /// throws a diagnostic with code ``SQLite/Error/Code/misuse``. Every copy of this value is closed with it. Closing
    /// twice does nothing.
    public func close() {
        readers?.close()
        direct.close()
        writer.slot.close()
        holder?.close()
    }
}
