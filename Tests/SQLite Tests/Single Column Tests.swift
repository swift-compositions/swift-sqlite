#if GRDB
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    @Table
    private struct Reading {
        let id: Int
        var value = 0
    }

    @Table
    private struct Source {
        let id: Int
        var reading: Int
        var origin: String?
    }

    @Suite(.timeLimit(.minutes(5))) struct `A single column` {
        let queue: SQLite.Database

        init() throws {
            queue = try SQLite.Database()
            try queue.write { database in
                try #sql(#"CREATE TABLE "reading" ("id" INTEGER PRIMARY KEY, "value" INTEGER NOT NULL)"#).execute(database)
                try #sql(#"CREATE TABLE "source" ("id" INTEGER PRIMARY KEY, "reading" INTEGER NOT NULL, "origin" TEXT)"#).execute(database)
                try Reading.insert { Reading(id: 7, value: 3) }.execute(database)
                try Source.insert { Source(id: 1, reading: 7, origin: "a") }.execute(database)
            }
        }

        @Test func `fetched and converted in one chain keeps its value`() throws {
            let maximum = try queue.read { database in
                let maximum = try Reading.select { $0.id.max() }.fetch.one(database).flatMap { $0 }.map(Int64.init)
                return maximum
            }
            #expect(maximum == 7)
        }

        @Test func `selected from a join and converted in one chain keeps its value`() throws {
            let maximum = try queue.read { database in
                let maximum = try Reading.join(Source.all) { $0.id.eq($1.reading) }
                    .where { _, source in source.origin.eq("a") }
                    .select { reading, _ in reading.id.max() }.fetch.one(database).flatMap { $0 }.map(Int64.init)
                return maximum
            }
            #expect(maximum == 7)
        }

        @Test func `a single returned column is its value`() throws {
            let id = try queue.write { database in
                func insert(_ value: Int) throws -> Int {
                    try Reading.insert { Reading.Draft(value: value) }.returning(\.id).fetch.one(database)!
                }
                return try insert(4)
            }
            #expect(id == 8)
        }

        @Test func `fetched first keeps its value`() throws {
            let maximum = try queue.read { database in try Reading.select { $0.id.max() }.fetch.one(database) }
            #expect(maximum == 7)
        }
    }
#endif
