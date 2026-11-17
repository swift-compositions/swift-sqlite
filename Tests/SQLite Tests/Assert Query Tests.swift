#if GRDB
    import SQL
    import SQL_Macros
    import SQL_Test_Support
    import SQLite
    import SQLite_Test_Support
    import Testing
    import Tests_Apple_Testing_Bridge
    import Tests_Inline_Snapshot
    import Time

    @Table
    private struct Record: Equatable {
        let id: Int
        var date = Time.Instant(secondsSinceUnixEpoch: 42)
    }

    @Suite(.timeLimit(.minutes(5))) struct `An asserted query` {
        let database: SQLite.Database

        init() throws {
            database = try SQLite.Database()
            try database.write { db in
                try #sql(
                    """
                    CREATE TABLE "record" (
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
            snapshot(as: .rows(in: database)) {
                Record.all.select(\.id)
            } matches: {
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
            snapshot(as: .rows(in: database)) {
                Record.find(1)
            } matches: {
                """
                ┌─────────────────────────────────────────────┐
                │ Record(                                     │
                │   id: 1,                                    │
                │   date: TIMESTAMP '1970-01-01 00:00:42.000' │
                │ )                                           │
                └─────────────────────────────────────────────┘
                """
            }
        }

        @Test func `snapshots an empty result`() {
            snapshot(as: .rows(in: database)) {
                Record.all.where { $0.id.eq(-1) }.select(\.id)
            } matches: {
                """
                (No results)
                """
            }
        }

        @Test(.snapshots(record: .never))
        func `fails when an empty result meets a non-empty snapshot`() {
            withKnownIssue {
                snapshot(as: .rows(in: database)) {
                    Record.all.where { _ in false }
                } matches: {
                    """
                    XYZ
                    """
                }
            }
        }

        @Test func `snapshots the SQL when asked`() {
            snapshot(as: .sql) {
                Record.all.select(\.id)
            } matches: {
                """
                SELECT "record"."id"
                FROM "record"
                """
            }
            snapshot(as: .rows(in: database)) {
                Record.all.select(\.id)
            } matches: {
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
            snapshot(as: .rows(writing: database)) {
                Record.all
                    .update { $0.date = Time.Instant(secondsSinceUnixEpoch: 45) }
                    .returning { ($0.id, $0.date) }
            } matches: {
                """
                ┌───┬─────────────────────────────────────┐
                │ 1 │ TIMESTAMP '1970-01-01 00:00:45.000' │
                │ 2 │ TIMESTAMP '1970-01-01 00:00:45.000' │
                │ 3 │ TIMESTAMP '1970-01-01 00:00:45.000' │
                └───┴─────────────────────────────────────┘
                """
            }
            #expect(
                try database.read { db in try Record.all.select(\.date).fetch.all(db) }
                    == Array(repeating: Time.Instant(secondsSinceUnixEpoch: 45), count: 3)
            )
        }

        @Test func `writes an update and snapshots its returned rows`() {
            snapshot(as: .rows(writing: database)) {
                Record
                    .where { $0.id.eq(1) }
                    .update { $0.date = Time.Instant(secondsSinceUnixEpoch: 45) }
                    .returning(\.self)
            } matches: {
                """
                ┌─────────────────────────────────────────────┐
                │ Record(                                     │
                │   id: 1,                                    │
                │   date: TIMESTAMP '1970-01-01 00:00:45.000' │
                │ )                                           │
                └─────────────────────────────────────────────┘
                """
            }
        }

        @Test func `writes an insert and snapshots its returned rows`() throws {
            snapshot(as: .rows(writing: database)) {
                Record
                    .insert { Record.Draft(date: Time.Instant(secondsSinceUnixEpoch: 7)) }
                    .returning(\.self)
            } matches: {
                """
                ┌─────────────────────────────────────────────┐
                │ Record(                                     │
                │   id: 4,                                    │
                │   date: TIMESTAMP '1970-01-01 00:00:07.000' │
                │ )                                           │
                └─────────────────────────────────────────────┘
                """
            }
            #expect(try database.read { db in try Record.fetch.count(db) } == 4)
        }

        @Test func `writes with the SQL when asked`() {
            snapshot(as: .sql) {
                Record.where { $0.id.eq(2) }.delete().returning(\.id)
            } matches: {
                """
                DELETE FROM "record"
                WHERE (("record"."id") = (2))
                RETURNING "id"
                """
            }
            snapshot(as: .rows(writing: database)) {
                Record.where { $0.id.eq(2) }.delete().returning(\.id)
            } matches: {
                """
                ┌───┐
                │ 2 │
                └───┘
                """
            }
        }
    }
#endif
