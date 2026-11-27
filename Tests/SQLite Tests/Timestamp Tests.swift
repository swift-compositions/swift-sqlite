import ISO_9075_Call_Level_Interface
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

@Suite(.timeLimit(.minutes(5))) struct `A timestamp column` {
    @Test func `round-trips an instant through insert and update`() async throws {
        let database = try SQLite.Database()
        try await database.write { connection throws(ISO.`9075`.Error) in
            try #sql(
                """
                CREATE TABLE "record" (
                  "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                  "instant" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(connection)
        }
        let instant = try Time.Instant(secondsSinceUnixEpoch: 1_771_416_482, nanosecondFraction: 61_000_000)
        let inserted = try #require(
            try await database.write { connection throws(ISO.`9075`.Error) in
                try Record.insert { Record.Draft(instant: instant) }.returning(\.self).fetch.one(connection)
            }
        )
        let updated = try #require(
            try await database.write { connection throws(ISO.`9075`.Error) in
                try Record.update(inserted).returning(\.self).fetch.one(connection)
            }
        )
        #expect(inserted.instant == instant)
        #expect(updated.instant == instant)
    }
}
