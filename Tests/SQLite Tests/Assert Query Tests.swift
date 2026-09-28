#if GRDB
    import Byte
    import CustomDump
    import GRDB
    import InlineSnapshotTesting
    import RFC_4122
    import SQL
    import SQL_Macros
    import SQLite
    import SQLite_Test_Support
    import Testing
    import Time

    extension Time.Instant: @retroactive CustomDumpStringConvertible {
        public var customDumpDescription: String {
            nanosecondFraction == 0
                ? "Time.Instant(secondsSinceUnixEpoch: \(secondsSinceUnixEpoch))"
                : "Time.Instant(secondsSinceUnixEpoch: \(secondsSinceUnixEpoch), nanosecondFraction: \(nanosecondFraction))"
        }
    }

    extension RFC_4122.UUID: @retroactive CustomDumpStringConvertible {
        public var customDumpDescription: String {
            "RFC_4122.UUID(\(description))"
        }
    }

    extension Array: @retroactive CustomDumpStringConvertible where Element == Byte {
        public var customDumpDescription: String {
            "[Byte](\(count) bytes)"
        }
    }

    @Table
    private struct Record: Equatable {
        let id: Int
        var date = Time.Instant(secondsSinceUnixEpoch: 42)
    }

    @Suite struct `An asserted query` {
        let database: DatabaseQueue

        init() throws {
            database = try DatabaseQueue()
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "records" (
                      "id" INTEGER PRIMARY KEY AUTOINCREMENT,
                      "date" TEXT NOT NULL
                    )
                    """
                )
                .execute(db)
                for _ in 1...3 {
                    try Record.insert { Record.Draft() }.execute(db)
                }
            }
        }

        @Test func `snapshots the rows of a selection`() {
            assertQuery(Record.all.select(\.id), database: database) {
                """
                ┌───┐
                │ 1 │
                │ 2 │
                │ 3 │
                └───┘
                """
            }
        }

        @Test func `snapshots a table row as a dump`() {
            assertQuery(Record.find(1), database: database) {
                """
                ┌─────────────────────────────────────────────────┐
                │ Record(                                         │
                │   id: 1,                                        │
                │   date: Time.Instant(secondsSinceUnixEpoch: 42) │
                │ )                                               │
                └─────────────────────────────────────────────────┘
                """
            }
        }

        @Test func `snapshots an empty result`() {
            assertQuery(Record.all.where { $0.id.eq(-1) }.select(\.id), database: database) {
                """
                (No results)
                """
            }
        }

        @Test(.snapshots(record: .never))
        func `fails when an empty result meets a non-empty snapshot`() {
            withKnownIssue {
                assertQuery(Record.all.where { _ in false }, database: database) {
                    """
                    XYZ
                    """
                }
            }
        }

        @Test func `snapshots the SQL when asked`() {
            assertQuery(includeSQL: true, Record.all.select(\.id), database: database) {
                """
                SELECT "records"."id"
                FROM "records"
                """
            } results: {
                """
                ┌───┐
                │ 1 │
                │ 2 │
                │ 3 │
                └───┘
                """
            }
        }

        @Test func `writes an update and snapshots its returned columns`() throws {
            assertQuery(
                Record.all
                    .update { $0.date = Time.Instant(secondsSinceUnixEpoch: 45) }
                    .returning { ($0.id, $0.date) },
                writing: database
            ) {
                """
                ┌───┬─────────────────────────────────────────┐
                │ 1 │ Time.Instant(secondsSinceUnixEpoch: 45) │
                │ 2 │ Time.Instant(secondsSinceUnixEpoch: 45) │
                │ 3 │ Time.Instant(secondsSinceUnixEpoch: 45) │
                └───┴─────────────────────────────────────────┘
                """
            }
            #expect(
                try database.read { db in try Record.all.select(\.date).fetchAll(db) }
                    == Array(repeating: Time.Instant(secondsSinceUnixEpoch: 45), count: 3)
            )
        }

        @Test func `writes an update and snapshots its returned rows`() {
            assertQuery(
                Record
                    .where { $0.id.eq(1) }
                    .update { $0.date = Time.Instant(secondsSinceUnixEpoch: 45) }
                    .returning(\.self),
                writing: database
            ) {
                """
                ┌─────────────────────────────────────────────────┐
                │ Record(                                         │
                │   id: 1,                                        │
                │   date: Time.Instant(secondsSinceUnixEpoch: 45) │
                │ )                                               │
                └─────────────────────────────────────────────────┘
                """
            }
        }

        @Test func `writes an insert and snapshots its returned rows`() throws {
            assertQuery(
                Record
                    .insert { Record.Draft(date: Time.Instant(secondsSinceUnixEpoch: 7)) }
                    .returning(\.self),
                writing: database
            ) {
                """
                ┌────────────────────────────────────────────────┐
                │ Record(                                        │
                │   id: 4,                                       │
                │   date: Time.Instant(secondsSinceUnixEpoch: 7) │
                │ )                                              │
                └────────────────────────────────────────────────┘
                """
            }
            #expect(try database.read { db in try Record.fetchCount(db) } == 4)
        }

        @Test func `writes with the SQL when asked`() {
            assertQuery(
                includeSQL: true,
                Record.where { $0.id.eq(2) }.delete().returning(\.id),
                writing: database
            ) {
                """
                DELETE FROM "records"
                WHERE (("records"."id") = (2))
                RETURNING "records"."id"
                """
            } results: {
                """
                ┌───┐
                │ 2 │
                └───┘
                """
            }
        }
    }
#endif
