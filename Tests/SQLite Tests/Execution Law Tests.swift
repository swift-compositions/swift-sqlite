#if GRDB
    import ISO_9075_Call_Level_Interface
    import SQLite
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

    struct Committing: ISO_9075.Database {
        let base: SQLite.Database

        @_disfavoredOverload
        func read<Value: Sendable, Thrown: Swift.Error>(
            _ body: @Sendable (SQLite.Connection) throws(Thrown) -> Value
        ) async throws(ISO_9075.Failure<Thrown>) -> Value {
            try await base.read(body)
        }

        @_disfavoredOverload
        func write<Value: Sendable, Thrown: Swift.Error>(
            _ body: @Sendable (SQLite.Connection) throws(Thrown) -> Value
        ) async throws(ISO_9075.Failure<Thrown>) -> Value {
            let outcome: Result<Value, Thrown>
            do throws(ISO_9075.Error) {
                outcome = try await base.write { connection throws(ISO_9075.Error) in
                    Result { () throws(Thrown) in try body(connection) }
                }
            } catch {
                throw .database(error)
            }
            do throws(Thrown) {
                return try outcome.get()
            } catch {
                throw .body(error)
            }
        }

        @_disfavoredOverload
        func withRollback<Value: Sendable, Thrown: Swift.Error>(
            _ body: @Sendable (SQLite.Connection) throws(Thrown) -> Value
        ) async throws(ISO_9075.Failure<Thrown>) -> Value {
            try await base.withRollback(body)
        }
    }

    struct Dropping: ISO_9075.Database {
        let base: SQLite.Database

        struct Connection: ISO_9075.Connection {
            let base: SQLite.Connection

            var dialect: SQLite { base.dialect }

            func execute(_ statement: ISO_9075.Rendering) throws(ISO_9075.Error) -> Int {
                try base.execute(statement)
            }

            func fetchAll<Value>(
                _ statement: ISO_9075.Rendering,
                decode: (SQLite.Row) throws(ISO_9075.Error) -> Value
            ) throws(ISO_9075.Error) -> [Value] {
                Array(try base.fetchAll(statement, decode: decode).dropLast())
            }
        }

        @_disfavoredOverload
        func read<Value: Sendable, Thrown: Swift.Error>(
            _ body: @Sendable (Connection) throws(Thrown) -> Value
        ) async throws(ISO_9075.Failure<Thrown>) -> Value {
            try await base.read { connection throws(Thrown) in try body(Connection(base: connection)) }
        }

        @_disfavoredOverload
        func write<Value: Sendable, Thrown: Swift.Error>(
            _ body: @Sendable (Connection) throws(Thrown) -> Value
        ) async throws(ISO_9075.Failure<Thrown>) -> Value {
            try await base.write { connection throws(Thrown) in try body(Connection(base: connection)) }
        }

        @_disfavoredOverload
        func withRollback<Value: Sendable, Thrown: Swift.Error>(
            _ body: @Sendable (Connection) throws(Thrown) -> Value
        ) async throws(ISO_9075.Failure<Thrown>) -> Value {
            try await base.withRollback { connection throws(Thrown) in try body(Connection(base: connection)) }
        }
    }
#endif
