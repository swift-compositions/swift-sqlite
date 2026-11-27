import ISO_9075_Call_Level_Interface
@testable import SQLite
import SQL_Test_Support
import Testing

extension SQLite.Database {
    @Suite struct Test {
        @Suite struct Integration {}
    }
}

extension SQLite.Database.Test.Integration {
    @Test func `swift-sql's statements run on SQLite in memory as the laws expect`() async throws {
        #expect(try await Laws.violations(of: SQLite.Database()) == [])
    }

    @Test func `swift-sql's statements run on SQLite in a file as the laws expect`() async throws {
        #expect(try await Laws.violations(of: SQLite.Database(path: Scratch.path())) == [])
    }

    @Test func `the laws find a connection that drops the last row of every fetch`() async throws {
        let violations = try await Laws.violations(of: Dropping(base: SQLite.Database()))
        #expect(violations.map(\.law).contains("a table fetches every row it holds"))
        #expect(violations.map(\.law).contains("a join fetches each pair of rows"))
    }

    @Test func `the laws find a database whose write commits when its body throws`() async throws {
        let violations = try await Laws.violations(of: Committing(base: SQLite.Database()))
        #expect(violations.map(\.law).contains("a write whose body throws its own error rolls back every statement it ran"))
        #expect(violations.map(\.law).contains("a write whose second statement fails rolls back the first"))
    }
}

/// A database that commits what a failing body ran: it runs the body outside of any transaction.
struct Committing: ISO.`9075`.Database {
    let base: SQLite.Database

    @_disfavoredOverload
    nonisolated(nonsending) func read<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await base.read(body)
    }

    @_disfavoredOverload
    nonisolated(nonsending) func write<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await base.writeWithoutTransaction(body)
    }

    @_disfavoredOverload
    nonisolated(nonsending) func withRollback<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing SQLite.Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await base.withRollback(body)
    }
}

/// A database whose connection loses the last row of every fetch.
struct Dropping: ISO.`9075`.Database {
    let base: SQLite.Database

    struct Connection: ISO.`9075`.Connection, ~Copyable, ~Escapable {
        let core: SQLite.Connection.Core

        @_lifetime(borrow base)
        init(_ base: borrowing SQLite.Connection) {
            self.core = base.core
        }

        var dialect: SQLite { SQLite() }

        func execute(_ statement: ISO.`9075`.Rendering) throws(ISO.`9075`.Error) -> Int {
            try SQLite.Connection(core).execute(statement)
        }

        func fetchAll<Value>(
            _ statement: ISO.`9075`.Rendering,
            decode: (SQLite.Row) throws(ISO.`9075`.Error) -> Value
        ) throws(ISO.`9075`.Error) -> [Value] {
            Array(try SQLite.Connection(core).fetchAll(statement, decode: decode).dropLast())
        }
    }

    @_disfavoredOverload
    nonisolated(nonsending) func read<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await base.read { (connection: borrowing SQLite.Connection) throws(Thrown) in try body(Connection(connection)) }
    }

    @_disfavoredOverload
    nonisolated(nonsending) func write<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await base.write { (connection: borrowing SQLite.Connection) throws(Thrown) in try body(Connection(connection)) }
    }

    @_disfavoredOverload
    nonisolated(nonsending) func withRollback<Value, Thrown: Swift.Error>(
        _ body: sending (borrowing Connection) throws(Thrown) -> sending Value
    ) async throws(ISO.`9075`.Failure<Thrown>) -> sending Value {
        try await base.withRollback { (connection: borrowing SQLite.Connection) throws(Thrown) in try body(Connection(connection)) }
    }
}
