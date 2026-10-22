import SQL
import SQL_Macros
import SQLite
import Testing

@Table
private struct Record {
    let id: Int
}

extension SQLite.Pragma {
    @Suite struct Test {
        @Suite struct Unit {}

        #if GRDB
            @Suite struct Integration {}
        #endif
    }
}

extension SQLite.Pragma.Test.Unit {
    @Test func `scalar reads render their pragma names`() {
        #expect(SQLite().render(SQLite.Pragma.ForeignKeys.get.query).sql == "PRAGMA foreign_keys")
        #expect(SQLite().render(SQLite.Pragma.DeferForeignKeys.get.query).sql == "PRAGMA defer_foreign_keys")
        #expect(SQLite().render(SQLite.Pragma.JournalMode.get.query).sql == "PRAGMA journal_mode")
        #expect(SQLite().render(SQLite.Pragma.UserVersion.get.query).sql == "PRAGMA user_version")
    }

    @Test func `checks render their pragma names`() {
        #expect(SQLite().render(SQLite.Pragma.QuickCheck.get.query).sql == "PRAGMA quick_check")
        #expect(SQLite().render(SQLite.Pragma.IntegrityCheck.get.query).sql == "PRAGMA integrity_check")
    }

    @Test func `boolean writes render numeric SQLite booleans`() {
        #expect(SQLite().render(SQLite.Pragma.ForeignKeys.set(true).query).sql == "PRAGMA foreign_keys = 1")
        #expect(SQLite().render(SQLite.Pragma.ForeignKeys.set(false).query).sql == "PRAGMA foreign_keys = 0")
        #expect(SQLite().render(SQLite.Pragma.DeferForeignKeys.set(true).query).sql == "PRAGMA defer_foreign_keys = 1")
        #expect(SQLite().render(SQLite.Pragma.DeferForeignKeys.set(false).query).sql == "PRAGMA defer_foreign_keys = 0")
    }

    @Test func `typed writes render values without bindings`() {
        #expect(SQLite().render(SQLite.Pragma.JournalMode.set(.wal).query).sql == "PRAGMA journal_mode = wal")
        #expect(SQLite().render(SQLite.Pragma.UserVersion.set(42).query).sql == "PRAGMA user_version = 42")
    }

    @Test func `table valued pragmas render typed selections`() {
        #expect(
            SQLite().render(SQLite.Pragma.Database.List.select(\.file).query).sql
                .contains("FROM pragma_database_list()")
        )
        #expect(
            SQLite().render(SQLite.Pragma.ForeignKey.Check.select(\.parent).query).sql
                .contains("FROM pragma_foreign_key_check()")
        )
        #expect(
            SQLite().render(SQLite.Pragma.ForeignKey.List<Record>.select(\.onDelete).query).sql
                .contains("FROM pragma_foreign_key_list('record')")
        )
        #expect(
            SQLite().render(SQLite.Pragma.Index.List<Record>.select(\.name).query).sql
                .contains("FROM pragma_index_list('record')")
        )
        #expect(
            SQLite().render(SQLite.Pragma.Table.Info<Record>.select(\.name).query).sql
                .contains("FROM pragma_table_info('record')")
        )
    }
}

#if GRDB
    import GRDB

    extension SQLite.Pragma.Test.Integration {
        @Test func `scalar pragmas round trip typed values`() throws {
            let database = try DatabaseQueue()

            try database.writeWithoutTransaction { db in
                try SQLite.Pragma.ForeignKeys.set(true).execute(db)
                #expect(try SQLite.Pragma.ForeignKeys.get.fetchOne(db) == true)

                try SQLite.Pragma.DeferForeignKeys.set(true).execute(db)
                #expect(try SQLite.Pragma.DeferForeignKeys.get.fetchOne(db) == true)

                let mode = try SQLite.Pragma.JournalMode.set(.memory).fetchOne(db)
                #expect(mode == .memory)
                #expect(try SQLite.Pragma.JournalMode.get.fetchOne(db) == .memory)

                try SQLite.Pragma.UserVersion.set(42).execute(db)
                #expect(try SQLite.Pragma.UserVersion.get.fetchOne(db) == 42)
            }
        }

        @Test func `checks report an intact database`() throws {
            let database = try DatabaseQueue()

            try database.read { db in
                let quick = try SQLite.Pragma.QuickCheck.get.fetchAll(db)
                let integrity = try SQLite.Pragma.IntegrityCheck.get.fetchAll(db)
                #expect(quick == ["ok"])
                #expect(integrity == ["ok"])
            }
        }
    }
#endif
