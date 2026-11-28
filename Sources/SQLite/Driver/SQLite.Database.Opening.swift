public import ISO_9075_Call_Level_Interface
public import SQL
public import SQLite_SQL

extension SQLite.Database {
    /// A database that is still opening: for a place that cannot wait, such as a synchronous initializer.
    ///
    /// It opens, and does what else `open` does, such as migrating, in a task that starts at once. Every read, write
    /// and followed read awaits that task first. When `open` threw, each of them throws that error as the
    /// database's; nothing is opened a second time.
    public struct Opening: Sendable {
        let opened: Task<Result<SQLite.Database, ISO.`9075`.Error>, Never>

        public init(_ open: @escaping @Sendable () async throws(ISO.`9075`.Error) -> SQLite.Database) {
            self.opened = Task {
                do throws(ISO.`9075`.Error) {
                    return .success(try await open())
                } catch {
                    return .failure(error)
                }
            }
        }

        /// The database, once it is open; throws what `open` threw.
        public var database: SQLite.Database {
            get async throws(ISO.`9075`.Error) { try await opened.value.get() }
        }
    }
}

// MARK: - The call-level interface

extension SQLite.Database.Opening: ISO.`9075`.Database {
    public typealias Connection = SQLite.Connection

    @_disfavoredOverload
    public nonisolated(nonsending) func read<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await open(Thrown.self).reading(body)
    }

    @_disfavoredOverload
    public nonisolated(nonsending) func write<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await open(Thrown.self).publishing(.write, body)
    }

    @_disfavoredOverload
    public nonisolated(nonsending) func withRollback<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await open(Thrown.self).writer.run(.rollback, body)
    }

    /// The database, with the error `open` threw as a failure of the database.
    private nonisolated(nonsending) func open<Thrown: Swift.Error>(
        _: Thrown.Type = Thrown.self
    ) async throws(ISO.`9075`.Failure<Thrown>) -> SQLite.Database {
        switch await opened.value {
        case .success(let database): return database
        case .failure(let error): throw .database(error)
        }
    }
}

// MARK: - A body that throws any error

extension SQLite.Database.Opening {
    @_disfavoredOverload
    public nonisolated(nonsending) func read<Value>(
        _ body: sending (borrowing SQLite.Connection) throws -> sending Value
    ) async throws -> sending Value {
        do throws(ISO.`9075`.Failure<any Swift.Error>) {
            return try await open((any Swift.Error).self).reading(body)
        } catch {
            throw error.thrown
        }
    }

    @_disfavoredOverload
    public nonisolated(nonsending) func write<Value>(
        _ body: sending (borrowing SQLite.Connection) throws -> sending Value
    ) async throws -> sending Value {
        do throws(ISO.`9075`.Failure<any Swift.Error>) {
            return try await open((any Swift.Error).self).publishing(.write, body)
        } catch {
            throw error.thrown
        }
    }

    @_disfavoredOverload
    public nonisolated(nonsending) func withRollback<Value>(
        _ body: sending (borrowing SQLite.Connection) throws -> sending Value
    ) async throws -> sending Value {
        do throws(ISO.`9075`.Failure<any Swift.Error>) {
            return try await open((any Swift.Error).self).writer.run(.rollback, body)
        } catch {
            throw error.thrown
        }
    }
}

// MARK: - Following

extension SQLite.Database.Opening: FollowingDatabase {
    public func follow<Value: Equatable & Sendable>(
        on isolation: isolated any Actor,
        _ body: @escaping @Sendable (borrowing SQLite.Connection) throws(ISO.`9075`.Error) -> Value
    ) async throws(ISO.`9075`.Error) -> FollowedRead<Value> {
        try await database.follow(on: isolation, body)
    }

    /// ``SQLite/Database/commits(to:)`` of the database, from when it is open. The stream ends when the database
    /// could not open.
    public func commits(to tables: [String]? = nil) -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let task = Task {
                if let database = try? await database {
                    for await _ in database.commits(to: tables) { continuation.yield(()) }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
