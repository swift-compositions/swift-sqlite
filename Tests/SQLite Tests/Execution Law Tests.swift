#if GRDB
    import ISO_9075_Call_Level_Interface
    import SQLite
    import SQL_Test_Support
    import Testing

    @Suite struct `Execution laws` {
        @Test func `swift-sql's statements run on SQLite in memory as the laws expect`() async throws {
            #expect(try await ExecutionLaws.violations(of: SQLite.Database()) == [])
        }

        @Test func `the laws find a connection that drops the last row of every fetch`() async throws {
            let violations = try await ExecutionLaws.violations(of: Dropping(base: SQLite.Database()))
            #expect(violations.map(\.law).contains("a table fetches every row it holds"))
            #expect(violations.map(\.law).contains("a join fetches each pair of rows"))
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

        func read<Value: Sendable>(
            _ body: @Sendable (Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value {
            try await base.read { connection throws(ISO_9075.Error) in try body(Connection(base: connection)) }
        }

        func write<Value: Sendable>(
            _ body: @Sendable (Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value {
            try await base.write { connection throws(ISO_9075.Error) in try body(Connection(base: connection)) }
        }

        func withRollback<Value: Sendable>(
            _ body: @Sendable (Connection) throws(ISO_9075.Error) -> Value
        ) async throws(ISO_9075.Error) -> Value {
            try await base.withRollback { connection throws(ISO_9075.Error) in try body(Connection(base: connection)) }
        }
    }
#endif
