#if GRDB
    import Foundation
    import GRDB
    import SQL
    import SQL_Macros
    import SQLite
    import Testing
    import Time

    @Table
    private struct Model {
        var date: Time.Instant
    }

    @Suite struct `A migrated timestamp` {
        @Test func `written by GRDB decodes as an instant`() throws {
            let database = try DatabaseQueue()
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "model" (
                      "date" TEXT NOT NULL
                    )
                    """
                )
                .execute(db)
            }

            let timestamp = 123.456
            try database.write { db in
                try db.execute(
                    literal: "INSERT INTO model (date) VALUES (\(Date(timeIntervalSince1970: timestamp)))"
                )
            }
            try database.read { db in
                let grdbDate = try Date.fetchOne(db, sql: "SELECT * FROM model")
                try #expect(abs(#require(grdbDate).timeIntervalSince1970 - timestamp) < 0.001)

                let instant = try #require(try Model.all.fetchOne(db)).date
                #expect(
                    abs(
                        Double(instant.secondsSinceUnixEpoch)
                            + Double(instant.nanosecondFraction) / 1_000_000_000
                            - timestamp
                    ) < 0.001
                )
            }
        }
    }
#endif
