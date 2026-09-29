#if GRDB
    import GRDB
    import SQL
    import SQL_Macros
    import SQLite
    import Testing

    @Table
    private struct Record: Equatable {
        let id: Int
        var value: String
    }

    @Suite struct `The statement cache` {
        let queue: DatabaseQueue

        init() throws {
            queue = try DatabaseQueue()
            try queue.write { database in
                try database.execute(
                    sql: #"CREATE TABLE "record" ("id" INTEGER PRIMARY KEY, "value" TEXT NOT NULL)"#
                )
                for id in 1...10 {
                    try Record.insert { Record(id: id, value: "value \(id)") }.execute(database)
                }
            }
        }

        @Test func `rebinds a reused statement`() throws {
            try queue.read { database in
                for id in 1...10 {
                    let record = try Record.where { $0.id.eq(id) }.fetchOne(database)
                    #expect(record?.id == id)
                    #expect(record?.value == "value \(id)")
                }
            }
        }

        @Test func `does not share a statement with an escaping cursor`() throws {
            try queue.read { database in
                let query = Record.where { $0.id.lte(3) }
                let cursor = try query.fetchCursor(database)
                #expect(try cursor.next()?.id == 1)
                #expect(try query.fetchAll(database).map(\.id) == [1, 2, 3])
                #expect(try cursor.next()?.id == 2)
                #expect(try cursor.next()?.id == 3)
                #expect(try cursor.next() == nil)
            }
        }

        @Test func `reuses a cached execute`() throws {
            try queue.write { database in
                for id in 11...20 {
                    try Record.insert { Record(id: id, value: "value \(id)") }.execute(database)
                }
                #expect(try Record.all.fetchCount(database) == 20)
            }
        }

        @Test func `survives a schema change between uses`() throws {
            try queue.write { database in
                #expect(try Record.all.fetchCount(database) == 10)
                try database.execute(sql: #"ALTER TABLE "record" ADD COLUMN "extra" TEXT"#)
                #expect(try Record.all.fetchCount(database) == 10)
                #expect(try Record.where { $0.id.eq(5) }.fetchOne(database)?.value == "value 5")
            }
        }
    }
#endif
