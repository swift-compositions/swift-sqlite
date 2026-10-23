#if GRDB
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    @Table
    private struct Number {
        var value = 0
    }

    @Suite struct `A query cursor` {
        let queue: SQLite.Database

        init() throws {
            queue = try SQLite.Database()
            try queue.write { database in
                try #sql(#"CREATE TABLE "number" ("value" INTEGER NOT NULL)"#).execute(database)
            }
        }

        @Test func `executes an insert of no rows`() throws {
            try queue.write { database in try Number.insert { [] }.execute(database) }
        }

        @Test func `executes an update of no columns`() throws {
            try queue.write { database in try Number.update { _ in }.execute(database) }
        }
    }
#endif
