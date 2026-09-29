#if GRDB
    import GRDB
    import SQL
    import SQL_Macros
    import SQLite
    import Testing
    import Time

    @Table
    private struct Record: Equatable {
        let id: Int
        var instant: Time.Instant
    }

    @Suite struct `A timestamp column` {
        @Test func `round-trips an instant through insert and update`() throws {
            let queue = try DatabaseQueue()
            try queue.write { database in
                try database.execute(
                    sql: """
                        CREATE TABLE "record" (
                          "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                          "instant" TEXT NOT NULL
                        ) STRICT
                        """
                )
            }
            let instant = try Time.Instant(secondsSinceUnixEpoch: 1_771_416_482, nanosecondFraction: 61_000_000)
            let inserted = try #require(
                try queue.write { database in
                    try Record.insert { Record.Draft(instant: instant) }.returning(\.self).fetchOne(database)
                }
            )
            let updated = try #require(
                try queue.write { database in
                    try Record.update(inserted).returning(\.self).fetchOne(database)
                }
            )
            #expect(inserted.instant == instant)
            #expect(updated.instant == instant)
        }
    }
#endif
