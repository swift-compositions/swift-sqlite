internal import SQLite_Shims
internal import ISO_9075_Call_Level_Interface
internal import SQLite_SQL
internal import Synchronization

extension SQLite.Connection {
    /// Where one connection lives: behind a lock, until the database closes. Every use of the connection goes
    /// through ``run(_:_:)``, which holds the lock for the whole scope, so one thread at a time is inside it. A use
    /// after ``close()`` finds the slot empty and throws; none reaches a closed connection.
    final class Slot: Sendable {
        private let core: Mutex<Core?>

        /// The log's page count at which the write that commits copies the log back; `nil` when the driver does
        /// not checkpoint on this connection.
        private let limit: Int?

        /// The log's page count from which the log is copied back beside the writer; `nil` as ``limit`` is.
        let threshold: Int?

        /// How many pages the log held after the last commit on this connection, when the driver checkpoints on it.
        let logged = Atomic<Int>(0)

        init(path: String, flags: Int32, configuration: SQLite.Configuration, journal: Journal) throws(SQLite.Error) {
            let core = try Core(path: path, flags: flags)
            core.busy(timeout: configuration.busyTimeout)
            var limit: Int?
            var threshold: Int?
            switch journal {
            case .writeAheadLog:
                try core.control("PRAGMA journal_mode = WAL; PRAGMA synchronous = NORMAL")
                try core.establishWriteAheadLog(at: path)
                switch configuration.checkpoint {
                case nil: break
                case .automatic(let pages): core.checkpointAutomatically(at: pages)
                case .concurrent(let pages, let most):
                    core.checkpointAutomatically(at: 0)
                    core.followLog()
                    threshold = max(1, pages)
                    limit = max(1, pages, most)
                }
            case .asFound: break
            }
            self.limit = limit
            self.threshold = threshold
            if let bytes = configuration.memoryMappedByteCount {
                try core.control("PRAGMA mmap_size = \(max(0, bytes))")
            }
            switch configuration.cache {
            case nil: break
            case .pages(let pages): try core.control("PRAGMA cache_size = \(max(0, pages))")
            case .kibibytes(let kibibytes): try core.control("PRAGMA cache_size = -\(max(0, kibibytes))")
            }
            try core.control("PRAGMA foreign_keys = \(configuration.foreignKeysEnabled ? "ON" : "OFF")")
            for preparation in configuration.preparations {
                do throws(ISO.`9075`.Error) {
                    try preparation(SQLite.Connection(core))
                } catch {
                    throw SQLite.Error(error)
                }
            }
            self.core = Mutex(core)
        }

        enum Journal {
            /// Sets the write-ahead log, where readers do not wait for the writer.
            case writeAheadLog
            /// Leaves the journal mode as the file has it: a read-only connection cannot change it.
            case asFound
        }

        /// What a scope does around its body.
        enum Scope {
            /// A deferred transaction on a connection that only reads.
            case read
            /// A deferred transaction on a connection that can write, which refuses writes for as long as it runs.
            case guardedRead
            /// An immediate transaction, committed when the body returns and rolled back when it throws.
            case write
            /// An immediate transaction that is always rolled back.
            case rollback
            /// No transaction.
            case bare
        }
    }
}

extension SQLite.Connection.Slot {
    /// Lends the connection to `body` inside `scope`. The body comes in by `sending` and its result leaves by
    /// `sending`: neither has to be Sendable, and neither can keep the connection.
    func run<Value, Thrown: Swift.Error>(
        _ scope: Scope,
        publishing receipt: SQLite.Hub.Receipt? = nil,
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        if Task.isCancelled { throw .database(ISO.`9075`.Error(SQLite.Error.cancelled)) }
        return try core.withLock { (core: inout sending SQLite.Connection.Core?) throws(ISO.`9075`.Failure<Thrown>) -> Value in
            guard let live = core else { throw .database(ISO.`9075`.Error(SQLite.Error.closed)) }
            do throws(SQLite.Error) {
                try scope.begin(live)
            } catch {
                throw .database(ISO.`9075`.Error(error))
            }
            live.footprint = SQLite.Footprint()
            let value: Value
            do throws(Thrown) {
                value = try body(SQLite.Connection(live))
            } catch {
                scope.abandon(live)
                throw .body(error)
            }
            do throws(SQLite.Error) {
                try scope.end(live)
            } catch {
                scope.abandon(live)
                throw .database(ISO.`9075`.Error(error))
            }
            // Committed. The followed reads are read again here, on the writer, so their answers are in commit order.
            if let receipt, !live.isInsideTransaction { receipt.hub.publish(on: live, into: receipt) }
            if let limit {
                // The copy beside the writer did not keep up: this write copies the log back, as SQLite's automatic
                // checkpoint would.
                if live.logged >= limit, !live.isInsideTransaction {
                    live.checkpoint()
                    live.logged = 0
                }
                logged.store(live.logged, ordering: .relaxed)
            }
            return value
        }
    }

    /// Copies the write-ahead log back into the database file, as far as the readers allow. Does nothing on a slot
    /// that is closed.
    func checkpoint() {
        core.withLock { (core: inout sending SQLite.Connection.Core?) in
            guard let live = core else { return }
            live.checkpoint()
        }
    }

    /// Lets the connection go, which closes it. Waits for a scope that is running. Closing twice does nothing.
    func close() {
        core.withLock { $0 = nil }
    }

    /// Copies every page of `source`'s database into this slot's, replacing what it held.
    func restore(from source: SQLite.Connection.Slot) throws(SQLite.Error) {
        guard source !== self else {
            throw SQLite.Error(extendedCode: .misuse, message: "a database is not backed up to itself")
        }
        try core.withLock { (destination: inout sending SQLite.Connection.Core?) throws(SQLite.Error) -> Void in
            guard let destination else { throw .closed }
            // The address, not the pointer: the two connections stay in the regions of their own locks.
            let address = unsafe UInt(bitPattern: destination.pointer)
            try source.core.withLock { (source: inout sending SQLite.Connection.Core?) throws(SQLite.Error) -> Void in
                guard let source, let destination = unsafe OpaquePointer(bitPattern: address) else { throw .closed }
                guard let backup = unsafe sqlite3_backup_init(destination, "main", source.pointer, "main") else {
                    throw unsafe SQLite.Error(connection: destination)
                }
                let stepped = unsafe sqlite3_backup_step(backup, -1)
                let finished = unsafe sqlite3_backup_finish(backup)
                guard stepped == SQLITE_DONE else { throw SQLite.Error(code: stepped) }
                guard finished == SQLITE_OK else { throw unsafe SQLite.Error(connection: destination) }
            }
        }
    }
}

extension SQLite.Connection.Slot.Scope {
    fileprivate func begin(_ core: SQLite.Connection.Core) throws(SQLite.Error) {
        switch self {
        case .read: try core.transact("BEGIN DEFERRED TRANSACTION")
        case .guardedRead:
            try core.control("PRAGMA query_only = 1")
            try core.transact("BEGIN DEFERRED TRANSACTION")
        case .write, .rollback: try core.transact("BEGIN IMMEDIATE TRANSACTION")
        case .bare: break
        }
    }

    fileprivate func end(_ core: SQLite.Connection.Core) throws(SQLite.Error) {
        switch self {
        case .read, .write: try core.transact("COMMIT TRANSACTION")
        case .guardedRead:
            try core.transact("COMMIT TRANSACTION")
            try core.control("PRAGMA query_only = 0")
        case .rollback: try core.transact("ROLLBACK TRANSACTION")
        case .bare: break
        }
    }

    /// Leaves the connection as the next scope expects it, after a body or a commit that failed.
    fileprivate func abandon(_ core: SQLite.Connection.Core) {
        if case .bare = self { return }
        if core.isInsideTransaction { try? core.transact("ROLLBACK TRANSACTION") }
        if case .guardedRead = self { try? core.control("PRAGMA query_only = 0") }
    }
}
