import ISO_9075_Call_Level_Interface
import SQL
import SQL_Macros
import SQLite
import Testing

@Table
private struct Record {
    let id: Int
}

@Suite(.timeLimit(.minutes(5))) struct `SQLite pragmas` {
    @Suite(.timeLimit(.minutes(5))) struct Unit {}

    @Suite(.timeLimit(.minutes(5))) struct Integration {}
}

extension `SQLite pragmas`.Unit {
    @Test func `scalar reads render their pragma names`() throws {
        #expect(try SQLite().render(SQLite.Pragma.ForeignKeys.get.query).sql == "PRAGMA foreign_keys")
        #expect(try SQLite().render(SQLite.Pragma.DeferForeignKeys.get.query).sql == "PRAGMA defer_foreign_keys")
        #expect(try SQLite().render(SQLite.Pragma.JournalMode.get.query).sql == "PRAGMA journal_mode")
        #expect(try SQLite().render(SQLite.Pragma.UserVersion.get.query).sql == "PRAGMA user_version")
    }

    @Test func `checks render their pragma names`() throws {
        #expect(try SQLite().render(SQLite.Pragma.QuickCheck.get.query).sql == "PRAGMA quick_check")
        #expect(try SQLite().render(SQLite.Pragma.IntegrityCheck.get.query).sql == "PRAGMA integrity_check")
    }

    @Test func `boolean writes render numeric SQLite booleans`() throws {
        #expect(try SQLite().render(SQLite.Pragma.ForeignKeys.set(true).query).sql == "PRAGMA foreign_keys = 1")
        #expect(try SQLite().render(SQLite.Pragma.ForeignKeys.set(false).query).sql == "PRAGMA foreign_keys = 0")
        #expect(try SQLite().render(SQLite.Pragma.DeferForeignKeys.set(true).query).sql == "PRAGMA defer_foreign_keys = 1")
        #expect(try SQLite().render(SQLite.Pragma.DeferForeignKeys.set(false).query).sql == "PRAGMA defer_foreign_keys = 0")
    }

    @Test func `typed writes render values without bindings`() throws {
        #expect(try SQLite().render(SQLite.Pragma.JournalMode.set(.wal).query).sql == "PRAGMA journal_mode = wal")
        #expect(try SQLite().render(SQLite.Pragma.UserVersion.set(42).query).sql == "PRAGMA user_version = 42")
    }

    @Test func `table valued pragmas render typed selections`() throws {
        #expect(
            try SQLite().render(SQLite.Pragma.Database.List.select(\.file).query).sql
                .contains("FROM pragma_database_list()")
        )
        #expect(
            try SQLite().render(SQLite.Pragma.ForeignKey.Check.select(\.parent).query).sql
                .contains("FROM pragma_foreign_key_check()")
        )
        #expect(
            try SQLite().render(SQLite.Pragma.ForeignKey.List<Record>.select(\.onDelete).query).sql
                .contains("FROM pragma_foreign_key_list('record')")
        )
        #expect(
            try SQLite().render(SQLite.Pragma.Index.List<Record>.select(\.name).query).sql
                .contains("FROM pragma_index_list('record')")
        )
        #expect(
            try SQLite().render(SQLite.Pragma.Table.Info<Record>.select(\.name).query).sql
                .contains("FROM pragma_table_info('record')")
        )
    }
}

extension `SQLite pragmas`.Integration {
    @Test func `scalar pragmas round trip typed values`() async throws {
        let database = try SQLite.Database()

        try await database.writeWithoutTransaction { connection throws(ISO.`9075`.Error) in
            try SQLite.Pragma.ForeignKeys.set(true).execute(connection)
            let foreignKeys = try SQLite.Pragma.ForeignKeys.get.fetch.one(connection)
            #expect(foreignKeys == true)

            try SQLite.Pragma.DeferForeignKeys.set(true).execute(connection)
            let deferred = try SQLite.Pragma.DeferForeignKeys.get.fetch.one(connection)
            #expect(deferred == true)

            let mode = try SQLite.Pragma.JournalMode.set(.memory).fetch.one(connection)
            #expect(mode == .memory)
            let journal = try SQLite.Pragma.JournalMode.get.fetch.one(connection)
            #expect(journal == .memory)

            try SQLite.Pragma.UserVersion.set(42).execute(connection)
            let version = try SQLite.Pragma.UserVersion.get.fetch.one(connection)
            #expect(version == 42)
        }
    }

    @Test func `checks report an intact database`() async throws {
        let database = try SQLite.Database()

        let (quick, integrity) = try await database.read { connection throws(ISO.`9075`.Error) in
            (
                try SQLite.Pragma.QuickCheck.get.fetch.all(connection),
                try SQLite.Pragma.IntegrityCheck.get.fetch.all(connection)
            )
        }
        #expect(quick == ["ok"])
        #expect(integrity == ["ok"])
    }
}
