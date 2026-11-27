public import ISO_9075_Call_Level_Interface
public import Lent_Interface
public import PostgreSQL
public import PostgreSQL_SQL

extension PostgreSQL {
    /// `PostgreSQL.Database` under the new protocol, written outside swift-postgresql, over its public interface.
    ///
    /// That interface takes a `@Sendable` body and returns a `Sendable` value, and its engine keeps the body for a
    /// thread of a pool. So a `sending`, non-escaping body and its `sending` result cross it in a box that the
    /// compiler does not check. Inside swift-postgresql the box belongs where the body is handed to the thread; with
    /// an actor per connection, as in Q3-Actors, there is no box at all.
    public struct Lending: Lent.Database, Sendable {
        public typealias Connection = PostgreSQL.Handle

        public let database: PostgreSQL.Database

        public init(_ database: PostgreSQL.Database) {
            self.database = database
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func read<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing PostgreSQL.Handle) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try await crossing(body) { body throws(ISO.`9075`.Failure<Thrown>) in try await reading(database, body) }
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func write<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing PostgreSQL.Handle) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try await crossing(body) { body throws(ISO.`9075`.Failure<Thrown>) in try await writing(database, body) }
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func withRollback<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing PostgreSQL.Handle) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try await crossing(body) { body throws(ISO.`9075`.Failure<Thrown>) in try await rollingBack(database, body) }
        }
    }
}

/// What the compiler is not asked to check: a body and a result that are sent, not shared.
struct Parcel<Contents>: @unchecked Sendable {
    let contents: Contents
}

/// Lends `body` to `operation` as a `@Sendable` closure over the connection as it is today, and unpacks the result.
nonisolated(nonsending) func crossing<Value, Thrown: Swift.Error>(
    _ body: sending (borrowing PostgreSQL.Handle) throws(Thrown) -> sending Value,
    _ operation: @Sendable (
        @escaping @Sendable (PostgreSQL.Connection) throws(Thrown) -> Parcel<Value>
    ) async throws(ISO.`9075`.Failure<Thrown>) -> Parcel<Value>
) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
    let parcel: Parcel<Value> = try await withoutActuallyEscaping(body) {
        escaping async throws(ISO.`9075`.Failure<Thrown>) in
        let body = Parcel(contents: escaping)
        return try await operation { connection throws(Thrown) in
            Parcel(contents: try body.contents(PostgreSQL.Handle(connection)))
        }
    }
    nonisolated(unsafe) let value = parcel.contents
    return unsafe value
}

// The requirements of today's `ISO_9075.Database`, called through the protocol so that none of
// `PostgreSQL.Database`'s other overloads is chosen.
func reading<Database: ISO.`9075`.Reader, Value: Sendable, Thrown: Swift.Error>(
    _ database: Database,
    _ body: @Sendable (Database.Connection) throws(Thrown) -> Value
) async throws(ISO.`9075`.Failure<Thrown>) -> Value {
    try await database.read(body)
}

func writing<Database: ISO.`9075`.Database, Value: Sendable, Thrown: Swift.Error>(
    _ database: Database,
    _ body: @Sendable (Database.Connection) throws(Thrown) -> Value
) async throws(ISO.`9075`.Failure<Thrown>) -> Value {
    try await database.write(body)
}

func rollingBack<Database: ISO.`9075`.Database, Value: Sendable, Thrown: Swift.Error>(
    _ database: Database,
    _ body: @Sendable (Database.Connection) throws(Thrown) -> Value
) async throws(ISO.`9075`.Failure<Thrown>) -> Value {
    try await database.withRollback(body)
}
