public import ISO_9075_Call_Level_Interface
public import Lent_Interface
public import PostgreSQL
public import PostgreSQL_SQL

extension PostgreSQL {
    /// A conformer whose `Connection` is swift-postgresql's connection as it is today: copyable and escapable. The
    /// protocol allows a connection that cannot escape; it does not require one. With this conformer a body can
    /// return the connection (Sources/Conform/main.swift). The guarantee is the conformer's, through its handle type.
    public struct Direct: Lent.Database, Sendable {
        public typealias Connection = PostgreSQL.Connection

        let lending: PostgreSQL.Lending

        public init(_ database: PostgreSQL.Database) {
            self.lending = PostgreSQL.Lending(database)
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func read<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing PostgreSQL.Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try await lending.read { handle throws(Thrown) in try body(handle.connection) }
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func write<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing PostgreSQL.Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try await lending.write { handle throws(Thrown) in try body(handle.connection) }
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func withRollback<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing PostgreSQL.Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try await lending.withRollback { handle throws(Thrown) in try body(handle.connection) }
        }
    }
}
