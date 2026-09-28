#if GRDB
    import GRDB
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    @Table
    private struct Number {
        var value = 0
    }

    @Suite struct `A query cursor` {
        let queue: DatabaseQueue

        init() throws {
            queue = try DatabaseQueue()
            try queue.write { database in
                try database.execute(sql: #"CREATE TABLE "numbers" ("value" INTEGER NOT NULL)"#)
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
