import SQL
import SQL_Macros
import SQLite
import Testing
import Time

@Table
private struct Model {
    var date: Time.Instant
}

@Suite(.timeLimit(.minutes(5))) struct `A migrated timestamp` {
    /// GRDB wrote a `Date` as text, `yyyy-MM-dd HH:mm:ss.SSS` in UTC. Databases made before the driver hold it.
    @Test func `written by GRDB decodes as an instant`() async throws {
        let database = try SQLite.Database()
        let instant = try await database.write { db in
            try #sql(#"CREATE TABLE "model" ("date" TEXT NOT NULL)"#).execute(db)
            // What GRDB wrote for Date(timeIntervalSince1970: 123.456).
            try #sql(#"INSERT INTO "model" ("date") VALUES ('1970-01-01 00:02:03.456')"#).execute(db)
            return try Model.all.fetch.one(db)?.date
        }
        let date = try #require(instant)
        #expect(date.secondsSinceUnixEpoch == 123)
        #expect(date.nanosecondFraction == 456_000_000)
    }
}
