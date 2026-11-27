public import ISO_9075_Call_Level_Interface

/// A conformer with no engine under it: a log of statements, lent to the body as a handle that cannot escape.
public enum Memory {}

extension Memory {
    public struct Dialect: ISO.`9075`.Dialect {
        public init() {}
        public func placeholder(_ offset: Int) -> String { "?" }
    }

    public struct Row: ISO.`9075`.Row {
        public let columns: [String]
        let values: [ISO.`9075`.Value]
        public func value(at index: Int) throws(ISO.`9075`.Error) -> ISO.`9075`.Value {
            guard values.indices.contains(index) else { throw .decoding("no column \(index)") }
            return values[index]
        }
    }

    /// Not Sendable, and not copyable: one owner, the database's.
    public final class Log {
        public var statements: [String] = []
    }

    public struct Connection: Lent.Connection, ~Copyable, ~Escapable {
        public let dialect = Memory.Dialect()
        let log: Log

        @_lifetime(borrow log)
        init(_ log: borrowing Log) {
            self.log = copy log
        }

        public func execute(_ statement: ISO.`9075`.Rendering) throws(ISO.`9075`.Error) -> Int {
            guard !statement.sql.hasPrefix("FAIL") else { throw .execution(statement.sql) }
            log.statements.append(statement.sql)
            return log.statements.count
        }

        public func fetchAll<Value>(
            _ statement: ISO.`9075`.Rendering,
            decode: (Memory.Row) throws(ISO.`9075`.Error) -> Value
        ) throws(ISO.`9075`.Error) -> [Value] {
            try log.statements.map { sql throws(ISO.`9075`.Error) in
                try decode(Memory.Row(columns: ["sql"], values: [.text(sql)]))
            }
        }
    }

    public actor Database: Lent.Database {
        let log = Log()

        public init() {}

        @_disfavoredOverload
        public nonisolated(nonsending) func read<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try await run(body)
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func write<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try await run(body)
        }

        @_disfavoredOverload
        public nonisolated(nonsending) func withRollback<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
        ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            try await run(body)
        }

        /// On the actor: the body arrives here by `sending`, and its result leaves by `sending`.
        func run<Value, Thrown: Swift.Error>(
            _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
        ) throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
            // A local copy of the reference: a handle that borrows the actor's stored `log` directly is rejected with
            // "lifetime-dependent variable 'connection' escapes its scope" (Rejected/BorrowOfActorStoredProperty.swift).
            let log = self.log
            let connection = Connection(log)
            do throws(Thrown) {
                return try body(connection)
            } catch {
                throw .body(error)
            }
        }
    }
}
