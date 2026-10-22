#if Observation
    import GRDB
    import ISO_9075_Call_Level_Interface
    import SQLite
    import Testing

    @Suite(.timeLimit(.minutes(1)))
    struct `Observation Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }

    extension `Observation Tests` {
        static func database() async throws -> SQLite.Database<DatabaseQueue> {
            let database = SQLite.Database(try DatabaseQueue())
            _ = try await database.execute(#"CREATE TABLE "reminder" ("title" TEXT NOT NULL)"#)
            _ = try await database.execute(#"CREATE TABLE "note" ("body" TEXT NOT NULL)"#)
            _ = try await database.execute(#"INSERT INTO "reminder" VALUES ('Groceries')"#)
            return database
        }

        @Sendable static func titles(_ connection: SQLite.Connection) throws(ISO_9075.Error) -> [String] {
            try connection.fetchAll(#"SELECT "title" FROM "reminder" ORDER BY "title""#) { row throws(ISO_9075.Error) in
                guard case .text(let title) = try row.value(at: 0) else { throw .decoding("title is not text") }
                return title
            }
        }
    }

    extension `Observation Tests`.Unit {
        @Test func `a write after observe is the next answer after the current one`() async throws {
            let database = try await `Observation Tests`.database()
            let titles = try await database.observe(`Observation Tests`.titles)
            _ = try await database.execute(#"INSERT INTO "reminder" VALUES ('Call mom')"#)
            var answers = titles.makeAsyncIterator()
            let current = try await answers.next()
            let written = try await answers.next()
            #expect(current == ["Groceries"])
            #expect(written == ["Call mom", "Groceries"])
        }

        @Test func `each write that changes the answer is observed in order`() async throws {
            let database = try await `Observation Tests`.database()
            let titles = try await database.observe(`Observation Tests`.titles)
            var answers = titles.makeAsyncIterator()
            #expect(try await answers.next() == ["Groceries"])
            _ = try await database.execute(#"INSERT INTO "reminder" VALUES ('Taxes')"#)
            #expect(try await answers.next() == ["Groceries", "Taxes"])
            _ = try await database.execute(#"DELETE FROM "reminder" WHERE "title" = 'Groceries'"#)
            #expect(try await answers.next() == ["Taxes"])
        }
    }

    extension `Observation Tests`.`Edge Case` {
        @Test func `a write that leaves the answer unchanged is not an answer`() async throws {
            let database = try await `Observation Tests`.database()
            let titles = try await database.observe(`Observation Tests`.titles)
            _ = try await database.execute(#"INSERT INTO "note" VALUES ('unrelated')"#)
            _ = try await database.execute(#"UPDATE "reminder" SET "title" = 'Groceries'"#)
            _ = try await database.execute(#"INSERT INTO "reminder" VALUES ('Dentist')"#)
            var answers = titles.makeAsyncIterator()
            let current = try await answers.next()
            let written = try await answers.next()
            #expect(current == ["Groceries"])
            #expect(written == ["Dentist", "Groceries"])
        }

        @Test func `a failing first answer is thrown by observe`() async throws {
            let database = try await `Observation Tests`.database()
            await #expect(throws: ISO_9075.Error.self) {
                _ = try await database.observe { connection throws(ISO_9075.Error) in
                    try connection.fetchAll(#"SELECT "title" FROM "missing""#) { _ throws(ISO_9075.Error) in 0 }
                }
            }
        }
    }
#endif
