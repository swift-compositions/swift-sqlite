internal import SQLite_Shims
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

        /// The worker that copies the write-ahead log back beside the writer, on a connection of its own; `nil`
        /// unless the configuration asks for ``SQLite/Configuration/Checkpoint/concurrent(pages:limit:)``.
        let checkpointer: SQLite.Worker?

        /// The followed reads of this database.
        let hub: SQLite.Hub

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
            self.checkpointer = nil
            self.readers = nil
            self.direct = slot
            self.holder = nil
            self.hub = SQLite.Hub()
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
            // SQLite's name for a database in memory: each connection that opened it by path would get an empty
            // database of its own, so it is the one database in memory that every read and write shares.
            guard path != ":memory:" else {
                self = try Self(configuration: configuration)
                return
            }
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
            var checkpointer: SQLite.Worker?
            if case .concurrent = configuration.checkpoint, !configuration.readonly {
                var plain = SQLite.Configuration()
                plain.busyTimeout = configuration.busyTimeout
                // As the writer's: its first read tells it that the database has a write-ahead log, without which
                // its checkpoint does nothing, and it does not keep the log's files when it is the last to close.
                let slot = try SQLite.Connection.Slot(
                    path: path, flags: SQLITE_OPEN_READWRITE, configuration: plain, journal: .writeAheadLog)
                checkpointer = SQLite.Worker(slot: slot)
            }
            self.checkpointer = checkpointer
            self.writer = SQLite.Worker(slot: writer, checkpointer: checkpointer)
            self.readers = SQLite.Readers(path: path, configuration: configuration)
            self.direct = try SQLite.Readers.slot(path: path, configuration: configuration)
            self.holder = holder
            self.hub = SQLite.Hub()
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
        try await reading(body)
    }

    /// The asynchronous read for a body that throws the database's error. Declared here, beside the synchronous
    /// ``read(_:)-(_)``, so that asynchronous code gets this one and does not block its thread.
    public nonisolated(nonsending) func read<Value>(
        _ body: sending (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> sending Value
    ) async throws(ISO.`9075`.Error) -> sending Value {
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            return try await reading(body)
        } catch {
            throw error.error
        }
    }

    nonisolated(nonsending) func reading<Value, Thrown: Swift.Error>(
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
        try await publishing(.write, body)
    }

    @_disfavoredOverload
    public nonisolated(nonsending) func withRollback<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await writer.run(.rollback, body)
    }
}

extension SQLite.Database {
    /// Runs `body` on the writer in `scope`. With followed reads, the writer publishes their new answers after the
    /// commit, and this returns when each listener has run its loop body for them.
    nonisolated(nonsending) func publishing<Value, Thrown: Swift.Error>(
        _ scope: SQLite.Connection.Slot.Scope,
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        // Whether there is a followed read is decided on the writer, at the commit: a read that registered just
        // before this write, on the writer, then gets this write's answer.
        let receipt = SQLite.Hub.Receipt(hub: hub)
        let value = try await writer.run(scope, publishing: receipt, body)
        await hub.settle(receipt)
        return value
    }
}

// MARK: - A body that throws any error

// A body with an untyped `throws` has its error thrown as it threw it, not wrapped in `ISO.9075.Failure.body`, and an
// error of the database is thrown as its `ISO.9075.Error`: so `catch let error as Mine` matches what the body threw.
// A body with a typed `throws` gets the overloads above, whose error says which of the two it was.

extension SQLite.Database {
    @_disfavoredOverload
    public nonisolated(nonsending) func read<Value>(
        _ body: sending (borrowing SQLite.Connection) throws -> sending Value
    ) async throws -> sending Value {
        do throws(ISO.`9075`.Failure<any Swift.Error>) {
            return try await reading(body)
        } catch {
            throw error.thrown
        }
    }

    @_disfavoredOverload
    public nonisolated(nonsending) func write<Value>(
        _ body: sending (borrowing SQLite.Connection) throws -> sending Value
    ) async throws -> sending Value {
        do throws(ISO.`9075`.Failure<any Swift.Error>) {
            return try await publishing(.write, body)
        } catch {
            throw error.thrown
        }
    }

    @_disfavoredOverload
    public nonisolated(nonsending) func withRollback<Value>(
        _ body: sending (borrowing SQLite.Connection) throws -> sending Value
    ) async throws -> sending Value {
        do throws(ISO.`9075`.Failure<any Swift.Error>) {
            return try await writer.run(.rollback, body)
        } catch {
            throw error.thrown
        }
    }

    @_disfavoredOverload
    public nonisolated(nonsending) func writeWithoutTransaction<Value>(
        _ body: sending (borrowing SQLite.Connection) throws -> sending Value
    ) async throws -> sending Value {
        do throws(ISO.`9075`.Failure<any Swift.Error>) {
            return try await publishing(.bare, body)
        } catch {
            throw error.thrown
        }
    }

    /// The synchronous ``read(_:)-(_)`` for a body that throws any error.
    @_disfavoredOverload
    public func read<Value>(
        _ body: sending (borrowing SQLite.Connection) throws -> sending Value
    ) throws -> sending Value {
        do throws(ISO.`9075`.Failure<any Swift.Error>) {
            return try direct.run(readers == nil ? .guardedRead : .read, body)
        } catch {
            throw error.thrown
        }
    }
}

extension ISO.`9075`.Failure {
    /// The error as the body threw it, or the database's. A body that ran a scope of its own and let that scope's
    /// failure pass throws what that scope's body threw.
    var thrown: any Swift.Error {
        switch self {
        case .database(let error): error
        case .body(let error): (error as? ISO.`9075`.Failure<any Swift.Error>)?.thrown ?? error
        }
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
        try await publishing(.bare, body)
    }

    public nonisolated(nonsending) func writeWithoutTransaction<Value>(
        _ body: sending (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> sending Value
    ) async throws(ISO.`9075`.Error) -> sending Value {
        do throws(ISO.`9075`.Failure<ISO.`9075`.Error>) {
            return try await publishing(.bare, body)
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

    /// Runs `body` in a write transaction on the writer's connection, on the caller's thread: it waits behind a lock
    /// for a write that is running, and it sees what is attached to that connection alone. The followed reads of
    /// the database are not told of what it changes. For test support, whose snapshots are synchronous.
    ///
    /// Do not call it from the body of a read or write of the same database: it would wait for itself.
    package func writeOnCaller<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try writer.slot.run(.write, body)
    }

    /// Returns when no copy of the write-ahead log that an earlier write started is running. For tests.
    package nonisolated(nonsending) func checkpointsSettled() async {
        await writer.settled()
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
        checkpointer?.slot.close()
        writer.slot.close()
        holder?.close()
    }
}
